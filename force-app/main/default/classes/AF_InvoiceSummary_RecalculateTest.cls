/**
 * Tests for AF_InvoiceSummary_Recalculate (ALF-RS-09 FR2/AC1/AC2).
 */
@isTest
private class AF_InvoiceSummary_RecalculateTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Invoice Recalc Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunityWithInvoice(Id accountId, Decimal expectedTotal) {
        Opportunity opp = new Opportunity(
            Name = 'Invoice Recalc Test Opp',
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
            AF_PaidAmount__c = 0,
            AF_Balance__c = expectedTotal,
            AF_Status__c = 'Unpaid'
        );
        insert inv;
        update new Opportunity(Id = opp.Id, AF_InvoiceSummary__c = inv.Id, AF_InvoiceBalance__c = expectedTotal);
        return [SELECT Id, AF_InvoiceSummary__c FROM Opportunity WHERE Id = :opp.Id];
    }

    private static void insertPayment(Id accountId, Id oppId, Decimal amount, String status, String integrationStatus) {
        insert new AF_Payment__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_Amount__c = amount,
            AF_SFPaymentReference__c = 'TESTPAY-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AF_PaymentMethod__c = 'Bank Transfer',
            AF_ProofReference__c = 'PROOF-001',
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = status,
            AF_IntegrationStatus__c = integrationStatus
        );
    }

    private static AF_InvoiceSummary_Recalculate.Request req(Id opportunityId) {
        AF_InvoiceSummary_Recalculate.Request r = new AF_InvoiceSummary_Recalculate.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    @isTest
    static void partialPaymentSetsPartiallyPaid() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insertPayment(acc.Id, opp.Id, 100000, 'Paid / Verified', null);

        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_InvoiceSummary__c inv = [
            SELECT AF_PaidAmount__c, AF_Balance__c, AF_Status__c FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id
        ];
        System.assertEquals(100000, inv.AF_PaidAmount__c);
        System.assertEquals(400000, inv.AF_Balance__c);
        System.assertEquals('Partially Paid', inv.AF_Status__c);

        Opportunity reloaded = [SELECT AF_InvoiceBalance__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(400000, reloaded.AF_InvoiceBalance__c);
    }

    @isTest
    static void fullPaymentSetsFullyPaid() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', null);

        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_InvoiceSummary__c inv = [
            SELECT AF_PaidAmount__c, AF_Balance__c, AF_Status__c FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id
        ];
        System.assertEquals(500000, inv.AF_PaidAmount__c);
        System.assertEquals(0, inv.AF_Balance__c);
        System.assertEquals('Fully Paid', inv.AF_Status__c);
    }

    @isTest
    static void unverifiedPaymentDoesNotCount() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insertPayment(acc.Id, opp.Id, 500000, 'Pending', null);

        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_InvoiceSummary__c inv = [
            SELECT AF_PaidAmount__c, AF_Status__c FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id
        ];
        System.assertEquals(0, inv.AF_PaidAmount__c);
        System.assertEquals('Unpaid', inv.AF_Status__c);
    }

    @isTest
    static void keyloopSyncedPaymentCountsWithoutManualVerification() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insertPayment(acc.Id, opp.Id, 500000, null, 'Synced');

        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_InvoiceSummary__c inv = [
            SELECT AF_PaidAmount__c, AF_Status__c FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id
        ];
        System.assertEquals(500000, inv.AF_PaidAmount__c);
        System.assertEquals('Fully Paid', inv.AF_Status__c);
    }

    @isTest
    static void noOpWhenOpportunityHasNoInvoiceSummary() {
        Account acc = makeAccount();
        Opportunity opp = new Opportunity(
            Name = 'No Invoice Opp', AccountId = acc.Id, StageName = 'Consider',
            CloseDate = Date.today().addDays(30), AF_Brand__c = 'Ferrari'
        );
        insert opp;

        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM AF_InvoiceSummary__c]);
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        AF_InvoiceSummary_Recalculate.recalculate(new List<AF_InvoiceSummary_Recalculate.Request>());
        Test.stopTest();
    }
}