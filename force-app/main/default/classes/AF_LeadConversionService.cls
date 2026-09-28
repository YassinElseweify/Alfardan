public class AF_LeadConversionService {
    private static final String NO_QID = '___AF_NO_QID___';
    private static final String NO_PHONE = '___AF_NO_PHONE___';
    private static final String NO_EMAIL = '___AF_NO_EMAIL___';

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }

    public class Result {
        @InvocableVariable
        public Id accountId;
        @InvocableVariable
        public Id contactId;
        @InvocableVariable
        public Id opportunityId;
        @InvocableVariable
        public Boolean accountWasMatched;
        @InvocableVariable
        public Boolean contactWasMatched;
        // Populated instead of throwing when conversion fails, so the calling Flow can branch on
        // this as a normal output value and show ONLY this text — a thrown exception's message
        // always gets wrapped by the platform as "An Apex error occurred: <ClassName>.<Exception>: ",
        // which is exactly the kind of raw/technical text this field exists to avoid showing users.
        @InvocableVariable
        public String errorMessage;
        // Display-only fields, populated by previewMatches() for the confirm-before-convert screen.
        @InvocableVariable
        public String accountName;
        @InvocableVariable
        public String accountPhone;
        @InvocableVariable
        public String contactName;
        @InvocableVariable
        public String contactPhone;
    }

    @InvocableMethod(label='Convert Lead (Match-First Business Account)' description='Matches an existing Business Account by QID, Phone, or Email; creates one only if no match is found. Always targets the Business_Account record type explicitly, never Person Account. Creates or reuses a Brand Profile Contact for the lead brand, then converts the Lead via Database.convertLead() pointed at those pre-created records so IsConverted, ConvertedAccountId, ConvertedContactId, and ConvertedOpportunityId are set by the platform.')
    public static List<Result> convertLeads(List<Request> requests) {
        try {
            return doConvertLeads(requests);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'AF_LeadConversionService.convertLeads raw failure: ' + e.getMessage());
            String friendly = friendlyConversionError(e.getMessage());
            List<Result> errorResults = new List<Result>();
            for (Request req : requests) {
                Result res = new Result();
                res.errorMessage = friendly;
                errorResults.add(res);
            }
            return errorResults;
        }
    }

    private static List<Result> doConvertLeads(List<Request> requests) {
        Set<Id> leadIds = new Set<Id>();
        for (Request req : requests) {
            leadIds.add(req.leadId);
        }

        Map<Id, Lead> leadsById = new Map<Id, Lead>([
            SELECT Id, OwnerId, FirstName, LastName, Salutation, Company, AF_QID__c, AF_OtherIdNumber__c,
                   AF_Nationality__c, AF_DateOfBirth__c, Email, Phone, MobilePhone,
                   AF_Brand__c, AF_BusinessUnit__c, LeadSource, Description, AF_VehicleOfInterestVehicle__c,
                   AF_Vehicle__c, AF_Vehicle__r.VehicleDefinitionId, AF_SourceOfBusiness__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);

        Id businessAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Id brandProfileRTId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();

        clearPendingSlaScheduledActions(leadsById.values());

        // ---- Bulk-resolve Accounts: one set of match queries for ALL leads, not one per lead. ----
        Map<Id, Account> matchedAccountByLeadId = findMatchingAccountsBulk(leadsById.values(), businessAccountRTId);

        List<Lead> leadsNeedingNewAccount = new List<Lead>();
        Map<Id, Account> accountByLeadId = new Map<Id, Account>();
        Map<Id, Boolean> accountWasMatchedByLeadId = new Map<Id, Boolean>();
        for (Lead ld : leadsById.values()) {
            Account matched = matchedAccountByLeadId.get(ld.Id);
            if (matched != null) {
                accountByLeadId.put(ld.Id, matched);
                accountWasMatchedByLeadId.put(ld.Id, true);
            } else {
                accountWasMatchedByLeadId.put(ld.Id, false);
                leadsNeedingNewAccount.add(ld);
            }
        }

        if (!leadsNeedingNewAccount.isEmpty()) {
            List<Account> newAccounts = new List<Account>();
            for (Lead ld : leadsNeedingNewAccount) {
                newAccounts.add(new Account(
                    RecordTypeId = businessAccountRTId,
                    Name = trimName(ld.Salutation, ld.FirstName, ld.LastName),
                    AF_Salutation__c = ld.Salutation,
                    AF_QID__c = ld.AF_QID__c,
                    AF_OtherIdNumber__c = ld.AF_OtherIdNumber__c,
                    AF_Nationality__c = ld.AF_Nationality__c,
                    AF_DateOfBirth__c = ld.AF_DateOfBirth__c,
                    AF_Email__c = ld.Email,
                    Phone = ld.Phone
                ));
            }
            Database.DMLOptions accountDmlOpts = new Database.DMLOptions();
            accountDmlOpts.duplicateRuleHeader.allowSave = true;
            accountDmlOpts.optAllOrNone = true;
            Database.insert(newAccounts, accountDmlOpts);
            for (Integer i = 0; i < leadsNeedingNewAccount.size(); i++) {
                accountByLeadId.put(leadsNeedingNewAccount[i].Id, newAccounts[i]);
            }
        }

        // ---- Bulk-resolve Brand Profile Contacts against each Lead's now-final Account. ----
        Set<Id> matchedAccountIds = new Set<Id>();
        for (Id leadId : accountWasMatchedByLeadId.keySet()) {
            if (accountWasMatchedByLeadId.get(leadId) == true) {
                matchedAccountIds.add(accountByLeadId.get(leadId).Id);
            }
        }
        Map<String, Contact> contactByAccountBrandKey = findMatchingBrandContactsBulk(matchedAccountIds);

        List<Lead> leadsNeedingNewContact = new List<Lead>();
        Map<Id, Contact> contactByLeadId = new Map<Id, Contact>();
        Map<Id, Boolean> contactWasMatchedByLeadId = new Map<Id, Boolean>();
        for (Lead ld : leadsById.values()) {
            Account acc = accountByLeadId.get(ld.Id);
            Contact matched = contactByAccountBrandKey.get(contactMatchKey(acc.Id, ld.AF_Brand__c));
            if (matched != null) {
                contactByLeadId.put(ld.Id, matched);
                contactWasMatchedByLeadId.put(ld.Id, true);
            } else {
                contactWasMatchedByLeadId.put(ld.Id, false);
                leadsNeedingNewContact.add(ld);
            }
        }

        if (!leadsNeedingNewContact.isEmpty()) {
            List<Contact> newContacts = new List<Contact>();
            for (Lead ld : leadsNeedingNewContact) {
                Account acc = accountByLeadId.get(ld.Id);
                newContacts.add(new Contact(
                    RecordTypeId = brandProfileRTId,
                    AccountId = acc.Id,
                    FirstName = ld.FirstName,
                    LastName = String.isBlank(ld.LastName) ? 'Unknown' : ld.LastName,
                    AF_ContactCategory__c = 'Brand Profile',
                    AF_Brand__c = ld.AF_Brand__c,
                    AF_BusinessUnit__c = ld.AF_BusinessUnit__c,
                    Email = ld.Email,
                    Phone = ld.Phone,
                    MobilePhone = ld.MobilePhone
                ));
            }
            Database.DMLOptions contactDmlOpts = new Database.DMLOptions();
            contactDmlOpts.duplicateRuleHeader.allowSave = true;
            contactDmlOpts.optAllOrNone = true;
            Database.insert(newContacts, contactDmlOpts);
            for (Integer i = 0; i < leadsNeedingNewContact.size(); i++) {
                contactByLeadId.put(leadsNeedingNewContact[i].Id, newContacts[i]);
            }
        }

        // The converted LeadStatus MasterLabel is a constant for the whole batch — one query, not
        // one per Lead.
        LeadStatus convertedStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];

        List<Result> results = new List<Result>();
        List<Database.LeadConvert> convertsToRun = new List<Database.LeadConvert>();
        List<Result> resultsInConvertOrder = new List<Result>();
        List<Lead> leadsInConvertOrder = new List<Lead>();

        for (Request req : requests) {
            Lead ld = leadsById.get(req.leadId);
            if (ld == null) {
                results.add(new Result());
                continue;
            }

            Result res = new Result();

            Account theAccount = accountByLeadId.get(ld.Id);
            res.accountId = theAccount.Id;
            res.accountWasMatched = accountWasMatchedByLeadId.get(ld.Id);

            Contact theContact = contactByLeadId.get(ld.Id);
            res.contactId = theContact.Id;
            res.contactWasMatched = contactWasMatchedByLeadId.get(ld.Id);

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(ld.Id);
            lc.setAccountId(theAccount.Id);
            lc.setContactId(theContact.Id);
            // Converted Account/Contact/Opportunity must be owned by a User. A Lead being converted
            // straight out of a shared BU queue (not yet individually assigned) still has a Queue as
            // OwnerId, which Database.convertLead() rejects outright (INVALID_ID_FIELD). Fall back to
            // whoever is running the conversion.
            Id convertOwnerId = String.valueOf(ld.OwnerId).startsWith('005') ? ld.OwnerId : UserInfo.getUserId();
            lc.setOwnerId(convertOwnerId);
            lc.setDoNotCreateOpportunity(false);
            lc.setOpportunityName(buildOpportunityName(theAccount.Name, ld.AF_Brand__c));
            lc.setConvertedStatus(convertedStatus.MasterLabel);

            convertsToRun.add(lc);
            resultsInConvertOrder.add(res);
            leadsInConvertOrder.add(ld);
        }

        if (!convertsToRun.isEmpty()) {
            List<Database.LeadConvertResult> convertResults = Database.convertLead(convertsToRun, true);
            List<Opportunity> oppsToStamp = new List<Opportunity>();
            // oppId -> the VehicleDefinition (model) to sync pricing/line-item for, resolved below.
            Map<Id, Id> vehicleDefinitionIdByOppId = new Map<Id, Id>();
            // oppId -> the specific in-stock Vehicle unit (if any) selected on the source Lead,
            // so the bulk-created line item can carry AF_Vehicle__c the same way the single-
            // Opportunity "Select Vehicle" action does — see syncOpportunityVehicleModelPricing's
            // vehicleId overload for why this field matters (VIN sync downstream).
            Map<Id, Id> vehicleIdByOppId = new Map<Id, Id>();
            for (Integer i = 0; i < convertResults.size(); i++) {
                Id oppId = convertResults[i].getOpportunityId();
                resultsInConvertOrder[i].opportunityId = oppId;
                if (oppId != null) {
                    // BRD 8.8 FR5 / 8.10 FR1: carry over Lead notes, vehicle of interest, and source of
                    // business. LeadSource maps to the Opportunity automatically via the platform's
                    // standard conversion field mapping, but these do not, so they're stamped explicitly
                    // here. AF_SourceOfBusiness__c write only succeeds because AF_VR_Opp_LockSourceOfBusiness
                    // carves out this exact case (same save also first-setting AF_OpportunityOrigin__c to
                    // 'Lead Conversion') — see that rule's description for why.
                    Lead sourceLead = leadsInConvertOrder[i];
                    oppsToStamp.add(new Opportunity(
                        Id = oppId,
                        AF_OpportunityOrigin__c = 'Lead Conversion',
                        Description = sourceLead.Description,
                        AF_VehicleModel__c = sourceLead.AF_VehicleOfInterestVehicle__c,
                        AF_SelectedVehicle__c = sourceLead.AF_Vehicle__c,
                        AF_SourceOfBusiness__c = sourceLead.AF_SourceOfBusiness__c
                    ));

                    // Prefer the model tied to the specific Vehicle unit (AF_Vehicle__c) when one was
                    // picked, else fall back to the directly-selected model (AF_VehicleOfInterestVehicle__c).
                    Id vehicleDefinitionId = sourceLead.AF_Vehicle__c != null
                        ? sourceLead.AF_Vehicle__r.VehicleDefinitionId
                        : sourceLead.AF_VehicleOfInterestVehicle__c;
                    if (vehicleDefinitionId != null) {
                        vehicleDefinitionIdByOppId.put(oppId, vehicleDefinitionId);
                    }
                    if (sourceLead.AF_Vehicle__c != null) {
                        vehicleIdByOppId.put(oppId, sourceLead.AF_Vehicle__c);
                    }
                }
            }
            if (!oppsToStamp.isEmpty()) {
                update oppsToStamp;
            }

            // Same Price Book + vehicle-model line item setup the "Select Vehicle" action does on
            // an existing Opportunity (AF_VehicleExplorerController.syncOpportunityVehicleModelPricing) —
            // run here too so a Lead that already had a Vehicle/Vehicle of Interest doesn't need an
            // agent to redo that step manually right after conversion. Runs once for the whole batch
            // (syncOpportunityVehicleModelPricingBulk), not once per Opportunity — calling the
            // single-Opportunity version in a loop here is what used to blow governor limits on any
            // bulk conversion above ~25 Leads. Best-effort: a Lead's vehicle is optional, and a model
            // missing its Price Book Entry shouldn't fail the whole conversion — logged and skipped
            // instead, same as this org's other carry-forward fields.
            if (!vehicleDefinitionIdByOppId.isEmpty()) {
                try {
                    AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk(vehicleDefinitionIdByOppId, vehicleIdByOppId);
                } catch (Exception e) {
                    System.debug(LoggingLevel.WARN, 'AF_LeadConversionService: skipped vehicle pricing sync for this batch: ' + e.getMessage());
                }
            }
        }

        results.addAll(resultsInConvertOrder);
        return results;
    }

    // AF_FL_Lead_SLAEscalation registers Scheduled Path actions (15 min / 1 hour / 3 day)
    // on any lead owned by a real user. Salesforce blocks Database.convertLead() with
    // RECORD_IN_USE_BY_WORKFLOW while any such action is still pending, and each offset
    // registers independently so the block can persist for up to 3 days. Confirmed by
    // direct testing that Salesforce cancels those pending actions when the record is
    // updated so it no longer satisfies the triggering flow's entry criteria
    // (AF_IsOwnerAUser__c, formula-driven off OwnerId) — briefly reassigning to a queue
    // and back clears the lock. Database.LeadConvert.setOwnerId() restores the real
    // owner as part of the same convert call, so the lead never visibly sits on a queue.
    private static void clearPendingSlaScheduledActions(List<Lead> leads) {
        Map<String, Id> queueIdByBusinessUnit = new Map<String, Id>();
        for (Group g : [
            SELECT Id, DeveloperName
            FROM Group
            WHERE Type = 'Queue'
            AND DeveloperName IN ('AF_Q_Leads_Automobiles', 'AF_Q_Leads_PremierMotors', 'AF_Q_Leads_SportsMotors', 'AF_Q_Leads_Review')
        ]) {
            queueIdByBusinessUnit.put(g.DeveloperName, g.Id);
        }

        Map<String, Id> queueIdByBUValue = new Map<String, Id>{
            'Alfardan Automobiles' => queueIdByBusinessUnit.get('AF_Q_Leads_Automobiles'),
            'Alfardan Premier Motors' => queueIdByBusinessUnit.get('AF_Q_Leads_PremierMotors'),
            'Alfardan Sports Motors' => queueIdByBusinessUnit.get('AF_Q_Leads_SportsMotors')
        };
        Id fallbackQueueId = queueIdByBusinessUnit.get('AF_Q_Leads_Review');

        List<Lead> bounceToQueue = new List<Lead>();
        for (Lead ld : leads) {
            Id queueId = queueIdByBUValue.get(ld.AF_BusinessUnit__c);
            if (queueId == null) {
                queueId = fallbackQueueId;
            }
            if (queueId != null) {
                bounceToQueue.add(new Lead(Id = ld.Id, OwnerId = queueId));
            }
        }
        if (!bounceToQueue.isEmpty()) {
            update bounceToQueue;
        }
    }

    // LFRDN-610 #8: QID and Phone/Email are checked separately (not one combined OR query) so an
    // ambiguous case - QID points at one Account, Phone/Email points at a different one - can be
    // detected and flagged instead of silently picking whichever the database happens to return first.
    // Three independent identity checks, not one combined OR query, so an ambiguous case (e.g. QID
    // points at one Account, Other ID Number points at a different one) can be detected and flagged
    // instead of silently picking whichever the database happens to return first. QID and Other ID
    // Number are treated as strong identifiers (checked in isolation); Phone/Email are weaker and
    // checked together as a single "contact info" match.
    //
    // Bulk version of the original per-Lead findMatchingAccount: one query per identifier (QID,
    // Other ID, Phone/Email) covering ALL leads in the batch, instead of up to 3 queries per Lead.
    // That per-Lead shape is what made bulk Lead conversion exceed the 100-SOQL governor limit above
    // ~30 Leads converted in a single transaction. Ambiguous-match flagging is preserved, batched
    // into a single update instead of one per Lead.
    public static Map<Id, Account> findMatchingAccountsBulk(List<Lead> leads, Id businessAccountRTId) {
        Map<Id, Account> resultByLeadId = new Map<Id, Account>();
        if (leads == null || leads.isEmpty()) {
            return resultByLeadId;
        }

        Set<String> qids = new Set<String>();
        Set<String> otherIds = new Set<String>();
        Set<String> phones = new Set<String>();
        Set<String> emails = new Set<String>();
        for (Lead ld : leads) {
            if (!String.isBlank(ld.AF_QID__c)) {
                qids.add(ld.AF_QID__c);
            }
            if (!String.isBlank(ld.AF_OtherIdNumber__c)) {
                otherIds.add(ld.AF_OtherIdNumber__c);
            }
            phones.add(String.isBlank(ld.Phone) ? NO_PHONE : ld.Phone);
            emails.add(String.isBlank(ld.Email) ? NO_EMAIL : ld.Email);
        }

        Map<String, Account> accountByQid = new Map<String, Account>();
        if (!qids.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name, Phone, AF_QID__c FROM Account
                WHERE RecordTypeId = :businessAccountRTId AND AF_QID__c IN :qids
            ]) {
                if (!accountByQid.containsKey(acc.AF_QID__c)) {
                    accountByQid.put(acc.AF_QID__c, acc);
                }
            }
        }

        Map<String, Account> accountByOtherId = new Map<String, Account>();
        if (!otherIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Name, Phone, AF_OtherIdNumber__c FROM Account
                WHERE RecordTypeId = :businessAccountRTId AND AF_OtherIdNumber__c IN :otherIds
            ]) {
                if (!accountByOtherId.containsKey(acc.AF_OtherIdNumber__c)) {
                    accountByOtherId.put(acc.AF_OtherIdNumber__c, acc);
                }
            }
        }

        Map<String, Account> accountByPhone = new Map<String, Account>();
        Map<String, Account> accountByEmail = new Map<String, Account>();
        for (Account acc : [
            SELECT Id, Name, Phone, AF_Email__c FROM Account
            WHERE RecordTypeId = :businessAccountRTId AND (Phone IN :phones OR AF_Email__c IN :emails)
        ]) {
            if (acc.Phone != null && phones.contains(acc.Phone) && !accountByPhone.containsKey(acc.Phone)) {
                accountByPhone.put(acc.Phone, acc);
            }
            if (acc.AF_Email__c != null && emails.contains(acc.AF_Email__c) && !accountByEmail.containsKey(acc.AF_Email__c)) {
                accountByEmail.put(acc.AF_Email__c, acc);
            }
        }

        List<Account> toFlag = new List<Account>();
        Set<Id> flaggedIds = new Set<Id>();

        for (Lead ld : leads) {
            Account qidMatch = String.isBlank(ld.AF_QID__c) ? null : accountByQid.get(ld.AF_QID__c);
            Account otherIdMatch = String.isBlank(ld.AF_OtherIdNumber__c) ? null : accountByOtherId.get(ld.AF_OtherIdNumber__c);
            String phoneValue = String.isBlank(ld.Phone) ? NO_PHONE : ld.Phone;
            String emailValue = String.isBlank(ld.Email) ? NO_EMAIL : ld.Email;
            Account contactInfoMatch = accountByPhone.get(phoneValue);
            if (contactInfoMatch == null) {
                contactInfoMatch = accountByEmail.get(emailValue);
            }

            Set<Id> distinctMatchIds = new Set<Id>();
            for (Account match : new List<Account>{ qidMatch, otherIdMatch, contactInfoMatch }) {
                if (match != null) {
                    distinctMatchIds.add(match.Id);
                }
            }
            if (distinctMatchIds.size() > 1) {
                for (Id matchId : distinctMatchIds) {
                    if (!flaggedIds.contains(matchId)) {
                        flaggedIds.add(matchId);
                        toFlag.add(new Account(Id = matchId, AF_ConflictingMatch__c = true));
                    }
                }
            }

            Account resolved = qidMatch != null ? qidMatch : (otherIdMatch != null ? otherIdMatch : contactInfoMatch);
            if (resolved != null) {
                resultByLeadId.put(ld.Id, resolved);
            }
        }

        if (!toFlag.isEmpty()) {
            update toFlag;
        }

        return resultByLeadId;
    }

    // Bulk version of the original per-Lead findMatchingBrandContact: one query covering every
    // candidate Account in the batch, keyed in-memory by Account+Brand so each Lead can look up its
    // match without an extra query. Brand is filtered in Apex rather than SOQL (a handful of brand
    // values per Account) so one query serves every Lead regardless of how many distinct brands
    // appear in the batch.
    public static Map<String, Contact> findMatchingBrandContactsBulk(Set<Id> accountIds) {
        Map<String, Contact> result = new Map<String, Contact>();
        if (accountIds == null || accountIds.isEmpty()) {
            return result;
        }
        for (Contact c : [
            SELECT Id, Name, Phone, AccountId, AF_Brand__c
            FROM Contact
            WHERE AccountId IN :accountIds
            AND AF_ContactCategory__c = 'Brand Profile'
        ]) {
            result.put(contactMatchKey(c.AccountId, c.AF_Brand__c), c);
        }
        return result;
    }

    public static String contactMatchKey(Id accountId, String brand) {
        return accountId + '|' + brand;
    }

    // Mirrors AF_FL_Opp_DefaultName's naming convention ("{Account Name} - {Brand}") so
    // Opportunities created via conversion look the same as ones created by other paths.
    // Without this, Database.convertLead() defaults the Opportunity Name to the Lead's
    // own person name instead of a real deal name.
    private static String buildOpportunityName(String accountName, String brand) {
        return accountName + ' - ' + (String.isBlank(brand) ? 'Opportunity' : brand);
    }

    private static String trimName(String salutation, String firstName, String lastName) {
        String full = String.isBlank(salutation) ? '' : salutation + ' ';
        full += String.isBlank(firstName) ? '' : firstName + ' ';
        full += String.isBlank(lastName) ? 'Unknown' : lastName;
        return full.trim();
    }

    // Translates the raw Database.convertLead() failure into a message a Sales user can actually
    // act on. The raw exception text is a DML dump (error code, row index, field API names) that
    // was surfacing verbatim on the flow's error screen — this maps the handful of failure modes
    // actually seen in this org to plain language, and falls back to a generic message (never the
    // raw dump) for anything unrecognized. The raw text is still logged via System.debug for
    // troubleshooting.
    private static String friendlyConversionError(String rawMessage) {
        if (rawMessage == null) {
            return 'We couldn\'t convert this Lead due to an unexpected error. Please try again, or contact your administrator if the problem continues.';
        }
        if (rawMessage.contains('RECORD_IN_USE_BY_WORKFLOW') || rawMessage.contains('workflow')) {
            return 'This Lead has a pending automated action (SLA tracking) and can\'t be converted for a few moments. Please wait a moment and try again.';
        }
        if (rawMessage.contains('INVALID_ID_FIELD') || rawMessage.contains('owned by users')) {
            return 'We couldn\'t assign an owner for the converted Account/Contact/Opportunity. Please try again, or contact your administrator if the problem continues.';
        }
        if (rawMessage.contains('DUPLICATE_VALUE') || rawMessage.contains('duplicate value')) {
            return 'A matching record already exists and blocked this conversion. Please search for the existing Account or Contact instead of converting this Lead.';
        }
        if (rawMessage.contains('FIELD_CUSTOM_VALIDATION_EXCEPTION')) {
            return 'This Lead failed a data validation check during conversion. Please review the Lead\'s details, or contact your administrator if the problem continues.';
        }
        return 'We couldn\'t convert this Lead due to a data issue. Please try again, or contact your administrator if the problem continues.';
    }
}