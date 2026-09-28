@isTest
private class AF_LeadConversionServiceTest {
    private static Id businessAccountRTId() {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
    }

    private static Id brandProfileRTId() {
        return Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();
    }

    private static void insertAllowingDuplicates(SObject record) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.duplicateRuleHeader.allowSave = true;
        Database.insert(record, dmlOpts);
    }

    private static Id testVehicleDefinitionId() {
        Product2 prod = new Product2(Name = 'Test Vehicle Product', AF_ProductCategory__c = 'Vehicle Model');
        insert prod;
        VehicleDefinition veh = new VehicleDefinition(Name = 'Test Vehicle', ProductId = prod.Id);
        insert veh;
        return veh.Id;
    }

    private static Lead buildBaseLead() {
        return new Lead(
            Company = '',
            AF_BusinessUnit__c = 'Alfardan Sports Motors',
            LeadSource = 'Website',
            AF_VehicleOfInterestVehicle__c = testVehicleDefinitionId(),
            Rating = 'Hot',
            AF_ContactValidity__c = 'Reachable',
            AF_QualificationOutcome__c = 'Qualified',
            Status = 'Follow-up'
        );
    }

    @isTest
    static void testNoMatchCreatesBusinessAccountAndBrandContact() {
        Lead ld = buildBaseLead();
        ld.FirstName = 'Yassin';
        ld.LastName = 'NoMatchTest';
        ld.AF_QID__c = '29912345678';
        ld.Email = 'nomatch.test@example.com';
        ld.Phone = '+97455512345';
        ld.AF_Brand__c = 'Ferrari';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected exactly one result for one request');
        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(false, res.accountWasMatched, 'No existing Account should have matched');
        System.assertEquals(false, res.contactWasMatched, 'No existing Contact should have matched');
        System.assertNotEquals(null, res.accountId, 'A new Account should have been created');
        System.assertNotEquals(null, res.contactId, 'A new Contact should have been created');
        System.assertNotEquals(null, res.opportunityId, 'An Opportunity should have been created on conversion');

        Account createdAccount = [SELECT Id, RecordTypeId, IsPersonAccount FROM Account WHERE Id = :res.accountId];
        System.assertEquals(businessAccountRTId(), createdAccount.RecordTypeId, 'New Account should use the Business Account record type');
        System.assertEquals(false, createdAccount.IsPersonAccount, 'New Account should not be a Person Account');

        Contact createdContact = [SELECT Id, RecordTypeId, AF_Brand__c, AF_ContactCategory__c FROM Contact WHERE Id = :res.contactId];
        System.assertEquals(brandProfileRTId(), createdContact.RecordTypeId, 'New Contact should use the Brand Profile record type');
        System.assertEquals('Ferrari', createdContact.AF_Brand__c, 'New Contact should carry the Lead brand');
        System.assertEquals('Brand Profile', createdContact.AF_ContactCategory__c, 'New Contact category should be Brand Profile');

        Lead convertedLead = [SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId, ConvertedOpportunityId FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(true, convertedLead.IsConverted, 'Lead should be marked converted');
        System.assertEquals(res.accountId, convertedLead.ConvertedAccountId, 'Converted Account should match the result');
        System.assertEquals(res.contactId, convertedLead.ConvertedContactId, 'Converted Contact should match the result');
        System.assertEquals(res.opportunityId, convertedLead.ConvertedOpportunityId, 'Converted Opportunity should match the result');
    }

    @isTest
    static void testMatchingQidLinksToExistingAccountInsteadOfDuplicating() {
        Account existing = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Existing Matched Customer',
            AF_QID__c = '29987654321'
        );
        insertAllowingDuplicates(existing);

        Lead ld = buildBaseLead();
        ld.FirstName = 'Existing';
        ld.LastName = 'MatchTest';
        ld.AF_QID__c = '29987654321';
        ld.AF_Brand__c = 'Rolls-Royce';
        ld.AF_BusinessUnit__c = 'Alfardan Automobiles';
        ld.Phone = '+97455512346';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(true, res.accountWasMatched, 'Existing Account should have matched via QID');
        System.assertEquals(existing.Id, res.accountId, 'Matched Account should be the existing one');

        System.assertEquals(1, [SELECT COUNT() FROM Account WHERE AF_QID__c = '29987654321'], 'No duplicate Account should have been created');
    }

    @isTest
    static void testExistingBrandContactIsReusedNotDuplicated() {
        Account existing = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Existing Customer With Brand Contact',
            AF_QID__c = '29955555555'
        );
        insertAllowingDuplicates(existing);

        Contact existingContact = new Contact(
            RecordTypeId = brandProfileRTId(),
            AccountId = existing.Id,
            LastName = 'MatchTest',
            AF_ContactCategory__c = 'Brand Profile',
            AF_Brand__c = 'Ferrari',
            Phone = '+97455512347'
        );
        insertAllowingDuplicates(existingContact);

        Lead ld = buildBaseLead();
        ld.FirstName = 'Repeat';
        ld.LastName = 'BrandTest';
        ld.AF_QID__c = '29955555555';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512347';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(true, res.contactWasMatched, 'Existing Contact should have matched via brand');
        System.assertEquals(existingContact.Id, res.contactId, 'Matched Contact should be the existing one');

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Contact WHERE AccountId = :existing.Id AND AF_Brand__c = 'Ferrari'],
            'No duplicate brand Contact should have been created'
        );
    }

    @isTest
    static void testMatchingOtherIdNumberLinksToExistingAccount() {
        Account existing = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Existing Customer Other Id',
            AF_OtherIdNumber__c = 'PASS-998877'
        );
        insertAllowingDuplicates(existing);

        Lead ld = buildBaseLead();
        ld.FirstName = 'OtherId';
        ld.LastName = 'MatchTest';
        ld.AF_OtherIdNumber__c = 'PASS-998877';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512348';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(true, res.accountWasMatched, 'Existing Account should have matched via Other ID Number');
        System.assertEquals(existing.Id, res.accountId, 'Matched Account should be the existing one');
    }

    @isTest
    static void testMatchingContactInfoOnlyLinksToExistingAccount() {
        Account existing = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Existing Customer Phone Only',
            Phone = '+97455512349'
        );
        insertAllowingDuplicates(existing);

        Lead ld = buildBaseLead();
        ld.FirstName = 'ContactInfo';
        ld.LastName = 'MatchTest';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512349';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(true, res.accountWasMatched, 'Existing Account should have matched via Phone');
        System.assertEquals(existing.Id, res.accountId, 'Matched Account should be the existing one');
    }

    @isTest
    static void testAmbiguousMatchFlagsBothAccountsAndPrefersQid() {
        Account qidAccount = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'QID Match Account',
            AF_QID__c = '29900011122',
            Phone = '+97455512399'
        );
        insertAllowingDuplicates(qidAccount);

        Account phoneAccount = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Phone Match Account',
            Phone = '+97455512350'
        );
        insertAllowingDuplicates(phoneAccount);

        Lead ld = buildBaseLead();
        ld.FirstName = 'Ambiguous';
        ld.LastName = 'MatchTest';
        ld.AF_QID__c = '29900011122';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512350';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(qidAccount.Id, res.accountId, 'QID match should take priority over Phone match when ambiguous');

        Map<Id, Account> flagged = new Map<Id, Account>([
            SELECT Id, AF_ConflictingMatch__c FROM Account WHERE Id IN (:qidAccount.Id, :phoneAccount.Id)
        ]);
        System.assertEquals(true, flagged.get(qidAccount.Id).AF_ConflictingMatch__c, 'QID-matched Account should be flagged as conflicting');
        System.assertEquals(true, flagged.get(phoneAccount.Id).AF_ConflictingMatch__c, 'Phone-matched Account should be flagged as conflicting');
    }

    @isTest
    static void testQueueOwnedLeadFallsBackToRunningUserAsConvertOwner() {
        Group queue = [SELECT Id FROM Group WHERE Type = 'Queue' LIMIT 1];

        Lead ld = buildBaseLead();
        ld.FirstName = 'Queue';
        ld.LastName = 'OwnedTest';
        ld.AF_QID__c = '29900099988';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512351';
        insertAllowingDuplicates(ld);
        update new Lead(Id = ld.Id, OwnerId = queue.Id);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertNotEquals(null, res.accountId, 'Queue-owned Lead should still convert successfully');
        System.assertEquals(null, res.errorMessage, 'Queue-owned Lead conversion should not error');
    }

    @isTest
    static void testConvertingAlreadyConvertedLeadReturnsFriendlyError() {
        Lead ld = buildBaseLead();
        ld.FirstName = 'Already';
        ld.LastName = 'ConvertedTest';
        ld.AF_QID__c = '29900055544';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512352';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        // First conversion succeeds, converting the Lead for real.
        AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one Result even on failure');
        AF_LeadConversionService.Result res = results[0];
        System.assertNotEquals(null, res.errorMessage, 'Re-converting an already-converted Lead should surface a friendly error');
        System.assertEquals(null, res.accountId, 'No accountId should be populated on the error result');
    }

    // Bulk-safety check: 200 brand-new Leads converted in a single transaction. Before
    // AF_LeadConversionService was refactored to bulk-resolve Accounts/Contacts (one match query set
    // for the whole batch, one insert for all new Accounts, one insert for all new Contacts, one bulk
    // pricing-sync call) instead of doing all of that per-Lead inside the loop, this would have thrown
    // System.LimitException (too many SOQL queries / DML statements) well before reaching 200 Leads.
    @isTest
    static void testBulkConversionOf200NewLeadsStaysWithinGovernorLimits() {
        Id vehicleDefId = testVehicleDefinitionId();

        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            leads.add(new Lead(
                Company = '',
                AF_BusinessUnit__c = 'Alfardan Sports Motors',
                LeadSource = 'Website',
                AF_VehicleOfInterestVehicle__c = vehicleDefId,
                Rating = 'Hot',
                AF_ContactValidity__c = 'Reachable',
                AF_QualificationOutcome__c = 'Qualified',
                Status = 'Follow-up',
                FirstName = 'Bulk',
                LastName = 'LeadTest' + i,
                AF_QID__c = '2999' + String.valueOf(1000000 + i),
                Email = 'bulklead' + i + '@example.com',
                Phone = '+9745551' + String.valueOf(10000 + i),
                AF_Brand__c = 'Ferrari'
            ));
        }
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.duplicateRuleHeader.allowSave = true;
        Database.insert(leads, dmlOpts);

        List<AF_LeadConversionService.Request> requests = new List<AF_LeadConversionService.Request>();
        for (Lead ld : leads) {
            AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
            req.leadId = ld.Id;
            requests.add(req);
        }

        Test.startTest();
        List<AF_LeadConversionService.Result> results = AF_LeadConversionService.convertLeads(requests);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Expected one Result per Lead in the batch');
        for (AF_LeadConversionService.Result res : results) {
            System.assertEquals(false, res.accountWasMatched, 'No existing Accounts should have matched any of these new Leads');
            System.assertNotEquals(null, res.accountId, 'Every Lead should have gotten a new Account');
            System.assertNotEquals(null, res.contactId, 'Every Lead should have gotten a new Brand Profile Contact');
            System.assertEquals(null, res.errorMessage, 'No Lead in this batch should have failed conversion');
        }
        System.assertEquals(
            200,
            [SELECT COUNT() FROM Account WHERE RecordTypeId = :businessAccountRTId() AND Name LIKE 'Bulk %'],
            'Should have created exactly 200 new Accounts, one per Lead, with no cross-contamination between requests'
        );
        System.assertEquals(200, [SELECT COUNT() FROM Lead WHERE IsConverted = true], 'All 200 Leads should be converted');
    }

    // A single bulk request mixing already-matching Leads (via QID and via existing Brand Profile
    // Contact) with brand-new Leads, to prove the batch-wide match maps resolve each Lead to the
    // correct Account/Contact independently rather than cross-matching between requests — a case the
    // single-request tests above never exercise, since they each send exactly one Request.
    @isTest
    static void testBulkConversionMixOfMatchedAndNewRecordsResolvesIndependently() {
        Id vehicleDefId = testVehicleDefinitionId();
        List<AF_LeadConversionService.Request> requests = new List<AF_LeadConversionService.Request>();
        Map<Id, Id> expectedAccountIdByLeadId = new Map<Id, Id>();

        // Three Leads that should match existing Accounts via QID.
        List<Id> qidMatchedAccountIds = new List<Id>();
        for (Integer i = 0; i < 3; i++) {
            Account existing = new Account(
                RecordTypeId = businessAccountRTId(),
                Name = 'Bulk Mix QID Account ' + i,
                AF_QID__c = '29988' + String.valueOf(300000 + i)
            );
            insertAllowingDuplicates(existing);
            qidMatchedAccountIds.add(existing.Id);

            Lead ld = new Lead(
                Company = '', AF_BusinessUnit__c = 'Alfardan Sports Motors', LeadSource = 'Website',
                AF_VehicleOfInterestVehicle__c = vehicleDefId, Rating = 'Hot',
                AF_ContactValidity__c = 'Reachable', AF_QualificationOutcome__c = 'Qualified', Status = 'Follow-up',
                FirstName = 'Mix', LastName = 'QidMatch' + i, AF_QID__c = '29988' + String.valueOf(300000 + i),
                Phone = '+97455520' + i, AF_Brand__c = 'Ferrari'
            );
            insertAllowingDuplicates(ld);
            expectedAccountIdByLeadId.put(ld.Id, existing.Id);
            AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
            req.leadId = ld.Id;
            requests.add(req);
        }

        // Three brand-new Leads with no matching Account at all.
        List<Id> newLeadIds = new List<Id>();
        for (Integer i = 0; i < 3; i++) {
            Lead ld = new Lead(
                Company = '', AF_BusinessUnit__c = 'Alfardan Sports Motors', LeadSource = 'Website',
                AF_VehicleOfInterestVehicle__c = vehicleDefId, Rating = 'Hot',
                AF_ContactValidity__c = 'Reachable', AF_QualificationOutcome__c = 'Qualified', Status = 'Follow-up',
                FirstName = 'Mix', LastName = 'NewAccount' + i, AF_QID__c = '29989' + String.valueOf(400000 + i),
                Phone = '+97455521' + i, AF_Brand__c = 'Ferrari'
            );
            insertAllowingDuplicates(ld);
            newLeadIds.add(ld.Id);
            AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
            req.leadId = ld.Id;
            requests.add(req);
        }

        Test.startTest();
        List<AF_LeadConversionService.Result> results = AF_LeadConversionService.convertLeads(requests);
        Test.stopTest();

        System.assertEquals(6, results.size(), 'Expected one Result per Request');
        for (Integer i = 0; i < 3; i++) {
            System.assertEquals(true, results[i].accountWasMatched, 'QID-matched Leads should resolve to their existing Account');
            System.assertEquals(qidMatchedAccountIds[i], results[i].accountId, 'Each QID-matched Lead must resolve to its OWN existing Account, not another request\'s');
        }
        Set<Id> newAccountIds = new Set<Id>();
        for (Integer i = 3; i < 6; i++) {
            System.assertEquals(false, results[i].accountWasMatched, 'Brand-new Leads should not match any existing Account');
            System.assertNotEquals(null, results[i].accountId);
            System.assert(!newAccountIds.contains(results[i].accountId), 'Each brand-new Lead should get its own distinct new Account, not share one');
            newAccountIds.add(results[i].accountId);
        }
    }

    @isTest
    static void testUnknownLeadIdIsSkippedWithBlankResult() {
        Lead ld = buildBaseLead();
        ld.FirstName = 'Skip';
        ld.LastName = 'MissingTest';
        ld.AF_QID__c = '29900033311';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455512353';
        insertAllowingDuplicates(ld);
        Id realLeadId = ld.Id;
        delete ld;

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = realLeadId;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionService.convertLeads(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Expected one Result even for a Lead that no longer exists');
        System.assertEquals(null, results[0].accountId, 'No Account should be created for a missing Lead');
    }
}