public class AF_LeadConversionPreviewService {
    @InvocableMethod(label='Preview Existing Account/Contact Match' description='Read-only preview of whether AF_LeadConversionService would match an existing Account/Contact for this Lead, without creating or converting anything — used to show a confirm-before-convert screen naming the existing records so the user can Continue or Cancel. Safe to call repeatedly; the only side effect is the same AF_ConflictingMatch__c flag write AF_LeadConversionService.findMatchingAccountsBulk already performs when a QID match and a Phone/Email match disagree. A separate class because Salesforce allows only one @InvocableMethod per Apex class.')
    public static List<AF_LeadConversionService.Result> previewMatches(List<AF_LeadConversionService.Request> requests) {
        Set<Id> leadIds = new Set<Id>();
        for (AF_LeadConversionService.Request req : requests) {
            leadIds.add(req.leadId);
        }
        Map<Id, Lead> leadsById = new Map<Id, Lead>([
            SELECT Id, AF_QID__c, AF_OtherIdNumber__c, Email, Phone, AF_Brand__c
            FROM Lead
            WHERE Id IN :leadIds
        ]);
        Id businessAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();

        // Bulk-resolve every Lead's matching Account (and, for those matched, their Brand Profile
        // Contact) in a fixed handful of queries covering the whole batch — not up to 4 queries per
        // Lead, which is what previously made previewing 200 Leads at once exceed the 100-SOQL
        // governor limit.
        Map<Id, Account> matchedAccountByLeadId = AF_LeadConversionService.findMatchingAccountsBulk(leadsById.values(), businessAccountRTId);

        Set<Id> matchedAccountIds = new Set<Id>();
        for (Account acc : matchedAccountByLeadId.values()) {
            matchedAccountIds.add(acc.Id);
        }
        Map<String, Contact> contactByAccountBrandKey = AF_LeadConversionService.findMatchingBrandContactsBulk(matchedAccountIds);

        List<AF_LeadConversionService.Result> results = new List<AF_LeadConversionService.Result>();
        for (AF_LeadConversionService.Request req : requests) {
            Lead ld = leadsById.get(req.leadId);
            AF_LeadConversionService.Result res = new AF_LeadConversionService.Result();
            if (ld == null) {
                results.add(res);
                continue;
            }

            Account matchedAccount = matchedAccountByLeadId.get(ld.Id);
            if (matchedAccount != null) {
                res.accountWasMatched = true;
                res.accountId = matchedAccount.Id;
                res.accountName = matchedAccount.Name;
                res.accountPhone = matchedAccount.Phone;

                Contact matchedContact = contactByAccountBrandKey.get(AF_LeadConversionService.contactMatchKey(matchedAccount.Id, ld.AF_Brand__c));
                if (matchedContact != null) {
                    res.contactWasMatched = true;
                    res.contactId = matchedContact.Id;
                    res.contactName = matchedContact.Name;
                    res.contactPhone = matchedContact.Phone;
                }
            }
            results.add(res);
        }
        return results;
    }
}