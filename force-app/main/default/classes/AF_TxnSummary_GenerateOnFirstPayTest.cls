/**
 * Tests for AF_TxnSummary_GenerateOnFirstPay (ALF-RS-09 FR5).
 */
@isTest
private class AF_TxnSummary_GenerateOnFirstPayTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Txn First Payment Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunityWithInvoice(Id accountId, Decimal paidAmount) {
        Opportunity opp = new Opportunity(
            Name = 'Txn First Payment Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;

        AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = opp.Id,
            AF_ExpectedTotalAmount__c = 500000,
            AF_PaidAmount__c = paidAmount,
            AF_Balance__c = 500000 - paidAmount,
            AF_Status__c = paidAmount > 0 ? 'Partially Paid' : 'Unpaid'
        );
        insert inv;
        update new Opportunity(Id = opp.Id, AF_InvoiceSummary__c = inv.Id);
        return [SELECT Id, AF_TransactionSummaryDocumentReference__c FROM Opportunity WHERE Id = :opp.Id];
    }

    private static AF_TxnSummary_GenerateOnFirstPay.Request req(Id opportunityId) {
        AF_TxnSummary_GenerateOnFirstPay.Request r = new AF_TxnSummary_GenerateOnFirstPay.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    @isTest
    static void generatesWhenPaidAmountPositiveAndNoDocumentYet() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 100000);
        insert new AF_Payment__c(
            AF_Account__c = acc.Id,
            AF_Opportunity__c = opp.Id,
            AF_Amount__c = 100000,
            AF_SFPaymentReference__c = 'TESTPAY-FIRST-1',
            AF_PaymentMethod__c = 'Bank Transfer',
            AF_ProofReference__c = 'PROOF-1',
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = 'Paid / Verified'
        );

        Test.startTest();
        AF_TxnSummary_GenerateOnFirstPay.generateIfFirstPayment(
            new List<AF_TxnSummary_GenerateOnFirstPay.Request>{ req(opp.Id) }
        );
        Test.stopTest();

        Opportunity reloaded = [SELECT AF_TransactionSummaryDocumentReference__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, reloaded.AF_TransactionSummaryDocumentReference__c,
            'A document should be generated on first positive paid amount.');
    }

    @isTest
    static void doesNotGenerateWhenPaidAmountStillZero() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 0);

        Test.startTest();
        AF_TxnSummary_GenerateOnFirstPay.generateIfFirstPayment(
            new List<AF_TxnSummary_GenerateOnFirstPay.Request>{ req(opp.Id) }
        );
        Test.stopTest();

        Opportunity reloaded = [SELECT AF_TransactionSummaryDocumentReference__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(null, reloaded.AF_TransactionSummaryDocumentReference__c);
    }

    @isTest
    static void doesNotDuplicateWhenDocumentAlreadyGenerated() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 100000);
        update new Opportunity(Id = opp.Id, AF_TransactionSummaryDocumentReference__c = '069000000000000AAA');

        Test.startTest();
        AF_TxnSummary_GenerateOnFirstPay.generateIfFirstPayment(
            new List<AF_TxnSummary_GenerateOnFirstPay.Request>{ req(opp.Id) }
        );
        Test.stopTest();

        Opportunity reloaded = [SELECT AF_TransactionSummaryDocumentReference__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('069000000000000AAA', reloaded.AF_TransactionSummaryDocumentReference__c,
            'Existing reference should not be overwritten.');
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        AF_TxnSummary_GenerateOnFirstPay.generateIfFirstPayment(
            new List<AF_TxnSummary_GenerateOnFirstPay.Request>()
        );
        Test.stopTest();
    }
}