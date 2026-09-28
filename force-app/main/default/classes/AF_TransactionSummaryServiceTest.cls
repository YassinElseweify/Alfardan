/**
 * Tests for AF_TransactionSummaryService (ALF-RS-09 FR5).
 */
@isTest
private class AF_TransactionSummaryServiceTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Transaction Summary Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunityWithInvoice(Id accountId, Decimal expectedTotal) {
        Opportunity opp = new Opportunity(
            Name = 'Transaction Summary Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;

        AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = opp.Id,
            AF_ExpectedTotalAmount__c = expectedTotal,
            AF_PaidAmount__c = 100000,
            AF_Balance__c = expectedTotal - 100000,
            AF_Status__c = 'Partially Paid'
        );
        insert inv;
        update new Opportunity(Id = opp.Id, AF_InvoiceSummary__c = inv.Id);
        return [SELECT Id FROM Opportunity WHERE Id = :opp.Id];
    }

    private static AF_TransactionSummaryService.Request req(Id opportunityId) {
        AF_TransactionSummaryService.Request r = new AF_TransactionSummaryService.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    @isTest
    static void generatesDocumentWhenPaymentsExist() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insert new AF_Payment__c(
            AF_Account__c = acc.Id,
            AF_Opportunity__c = opp.Id,
            AF_Amount__c = 100000,
            AF_SFPaymentReference__c = 'TESTPAY-TXN-1',
            AF_PaymentMethod__c = 'Bank Transfer',
            AF_ProofReference__c = 'PROOF-1',
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = 'Paid / Verified'
        );

        Test.startTest();
        List<AF_TransactionSummaryService.Result> results =
            AF_TransactionSummaryService.generate(new List<AF_TransactionSummaryService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        System.assertNotEquals(null, results[0].contentDocumentId);

        Opportunity reloaded = [SELECT AF_TransactionSummaryDocumentReference__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, reloaded.AF_TransactionSummaryDocumentReference__c);
    }

    @isTest
    static void blocksWhenNoInvoiceSummary() {
        Account acc = makeAccount();
        Opportunity opp = new Opportunity(
            Name = 'No Invoice Txn Opp', AccountId = acc.Id, StageName = 'Consider',
            CloseDate = Date.today().addDays(30), AF_Brand__c = 'Ferrari'
        );
        insert opp;

        Test.startTest();
        List<AF_TransactionSummaryService.Result> results =
            AF_TransactionSummaryService.generate(new List<AF_TransactionSummaryService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No Invoice Summary'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenNoPayments() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);

        Test.startTest();
        List<AF_TransactionSummaryService.Result> results =
            AF_TransactionSummaryService.generate(new List<AF_TransactionSummaryService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No Payment records'), 'Got: ' + results[0].message);
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        List<AF_TransactionSummaryService.Result> results =
            AF_TransactionSummaryService.generate(new List<AF_TransactionSummaryService.Request>());
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}