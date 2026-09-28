@isTest
private class AF_LeadConversionSummaryControllerTest {
    @isTest
    static void testGetSummaryReturnsAllThreeRecords() {
        Id businessRT = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Id brandProfileRT = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();

        Account acc = new Account(
            RecordTypeId = businessRT,
            Name = 'Summary Test Account',
            Type = 'Prospect',
            Phone = '+97455511111',
            Website = 'https://example.com',
            Site = 'Doha'
        );
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.duplicateRuleHeader.allowSave = true;
        Database.insert(acc, dmlOpts);

        Contact con = new Contact(
            RecordTypeId = brandProfileRT,
            AccountId = acc.Id,
            FirstName = 'Summary',
            LastName = 'ContactTest',
            AF_ContactCategory__c = 'Brand Profile',
            AF_Brand__c = 'Ferrari',
            Email = 'summary.test@example.com',
            Phone = '+97455522222',
            MobilePhone = '+97455533333'
        );
        Database.insert(con, dmlOpts);

        Opportunity opp = new Opportunity(
            Name = 'Summary Test Account - Ferrari',
            AccountId = acc.Id,
            StageName = 'Consider',
            CloseDate = Date.today().addMonths(1)
        );
        insert opp;

        Test.startTest();
        AF_LeadConversionSummaryController.Summary result =
            AF_LeadConversionSummaryController.getSummary(acc.Id, con.Id, opp.Id);
        Test.stopTest();

        System.assertEquals(acc.Name, result.accountName);
        System.assertEquals('Prospect', result.accountType);
        System.assertEquals('Summary ContactTest', result.contactName);
        System.assertEquals('summary.test@example.com', result.contactEmail);
        System.assertEquals(opp.Name, result.opportunityName);
        System.assertNotEquals(null, result.opportunityCloseDate);
        System.assertNotEquals(null, result.accountOwnerName);
        System.assertNotEquals(null, result.opportunityOwnerName);
    }
}