/**
 * Tests for AF_KeyloopGetPayment (ALF-RS-09 - "Get Payment" on Invoice Summary).
 *
 * The class simulates the Keyloop response in-org rather than calling out (see its header), so
 * these tests drive it exactly as the screen flow does: an Invoice Summary Id plus a Keyloop
 * payment reference, and assert on the AF_Payment__c it synthesizes and the recalculation that
 * follows. Every guard clause gets its own case so a regression in one cannot hide behind
 * another, and a bulk case proves the invocable stays correct for more than one request.
 */
@isTest
private class AF_KeyloopGetPaymentTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Keyloop Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Keyloop Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    /**
     * Builds the Invoice Summary the way the reservation-approval path leaves it, and links it
     * back onto the Opportunity so the recalculation at the end of getPayment() has something to
     * write to.
     */
    private static AF_InvoiceSummary__c makeInvoice(
        Id accountId,
        Id opportunityId,
        Decimal expectedTotal,
        Decimal paidAmount,
        String status
    ) {
        AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = opportunityId,
            AF_ExpectedTotalAmount__c = expectedTotal,
            AF_PaidAmount__c = paidAmount,
            AF_Balance__c = expectedTotal == null ? null : expectedTotal - paidAmount,
            AF_Status__c = status
        );
        insert inv;
        update new Opportunity(Id = opportunityId, AF_InvoiceSummary__c = inv.Id);
        return inv;
    }

    private static AF_KeyloopGetPayment.Request req(Id invoiceSummaryId, String reference) {
        AF_KeyloopGetPayment.Request r = new AF_KeyloopGetPayment.Request();
        r.invoiceSummaryId = invoiceSummaryId;
        r.keyloopPaymentReference = reference;
        return r;
    }

    @isTest
    static void pullsOutstandingBalanceAsASingleVerifiedPayment() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 0, 'Unpaid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1001') });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        System.assertNotEquals(null, results[0].paymentId);
        System.assertEquals(false, results[0].nocGenerated,
            'The simulated payee always matches the Account, so no NOC is expected.');

        AF_Payment__c pay = [
            SELECT AF_Amount__c, AF_PaymentMethod__c, AF_PaymentDate__c, AF_PayeeName__c,
                   AF_KeyloopPaymentReference__c, AF_ExternalMatchingReference__c,
                   AF_Status__c, AF_IntegrationStatus__c, AF_NOCRecorded__c,
                   AF_InvoiceSummary__c, AF_Opportunity__c, AF_Account__c
            FROM AF_Payment__c WHERE AF_InvoiceSummary__c = :inv.Id
        ];
        // Amount is the whole outstanding balance so one pull can settle the deal.
        System.assertEquals(500000, pay.AF_Amount__c);
        System.assertEquals('Bank Transfer', pay.AF_PaymentMethod__c);
        System.assertEquals(Date.today(), pay.AF_PaymentDate__c);
        System.assertEquals('Keyloop Test Account', pay.AF_PayeeName__c);
        System.assertEquals('KL-1001', pay.AF_KeyloopPaymentReference__c);
        System.assertEquals('KL-1001', pay.AF_ExternalMatchingReference__c);
        System.assertEquals('Paid / Verified', pay.AF_Status__c);
        System.assertEquals('Synced', pay.AF_IntegrationStatus__c);
        System.assertEquals(true, pay.AF_NOCRecorded__c);
        System.assertEquals(opp.Id, pay.AF_Opportunity__c);
        System.assertEquals(acc.Id, pay.AF_Account__c);
    }

    @isTest
    static void pullingTheOutstandingBalanceTakesTheInvoiceToFullyPaid() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 0, 'Unpaid');

        Test.startTest();
        AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1002') });
        Test.stopTest();

        AF_InvoiceSummary__c reloaded = [
            SELECT AF_PaidAmount__c, AF_Balance__c, AF_Status__c
            FROM AF_InvoiceSummary__c WHERE Id = :inv.Id
        ];
        System.assertEquals(500000, reloaded.AF_PaidAmount__c);
        System.assertEquals(0, reloaded.AF_Balance__c);
        System.assertEquals('Fully Paid', reloaded.AF_Status__c,
            'Pulling the full outstanding balance must settle the Invoice Summary.');
    }

    @isTest
    static void partiallyPaidInvoicePullsOnlyTheRemainingBalance() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 200000, 'Partially Paid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1003') });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        AF_Payment__c pay = [
            SELECT AF_Amount__c FROM AF_Payment__c WHERE AF_KeyloopPaymentReference__c = 'KL-1003'
        ];
        System.assertEquals(300000, pay.AF_Amount__c,
            'Only the outstanding 300,000 should be pulled, not the full expected total.');
    }

    @isTest
    static void blankPaymentReferenceIsRejected() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 0, 'Unpaid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, '   ') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Keyloop Payment ID is required'), 'Got: ' + results[0].message);
        System.assertEquals(0, [SELECT COUNT() FROM AF_Payment__c WHERE AF_InvoiceSummary__c = :inv.Id]);
    }

    @isTest
    static void unknownInvoiceSummaryIsReportedNotThrown() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 0, 'Unpaid');
        Id deletedId = inv.Id;
        delete inv;

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(deletedId, 'KL-1004') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('not found'), 'Got: ' + results[0].message);
    }

    @isTest
    static void alreadyFullyPaidInvoiceIsRefused() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 500000, 'Fully Paid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1005') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('already Fully Paid'), 'Got: ' + results[0].message);
        System.assertEquals(0, [SELECT COUNT() FROM AF_Payment__c WHERE AF_InvoiceSummary__c = :inv.Id]);
    }

    @isTest
    static void invoiceWithoutAnExpectedTotalIsRefused() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, null, 0, 'Unpaid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1006') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('no Expected Total'), 'Got: ' + results[0].message);
    }

    @isTest
    static void invoiceWithNothingOutstandingIsRefused() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        // Not flagged Fully Paid, but nothing is actually left to pull - the balance guard, not
        // the status guard, is what has to catch this.
        AF_InvoiceSummary__c inv = makeInvoice(acc.Id, opp.Id, 500000, 500000, 'Partially Paid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results =
            AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>{ req(inv.Id, 'KL-1007') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('No outstanding balance'), 'Got: ' + results[0].message);
    }

    @isTest
    static void emptyAndNullRequestListsReturnNoResults() {
        Test.startTest();
        System.assertEquals(0, AF_KeyloopGetPayment.getPayment(new List<AF_KeyloopGetPayment.Request>()).size());
        System.assertEquals(0, AF_KeyloopGetPayment.getPayment(null).size());
        Test.stopTest();
    }

    @isTest
    static void bulkRequestsAreEachResolvedIndependently() {
        Account acc = makeAccount();

        Opportunity oppA = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c invA = makeInvoice(acc.Id, oppA.Id, 500000, 0, 'Unpaid');
        Opportunity oppB = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c invB = makeInvoice(acc.Id, oppB.Id, 250000, 50000, 'Partially Paid');
        Opportunity oppC = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c invC = makeInvoice(acc.Id, oppC.Id, 100000, 100000, 'Fully Paid');

        Test.startTest();
        List<AF_KeyloopGetPayment.Result> results = AF_KeyloopGetPayment.getPayment(
            new List<AF_KeyloopGetPayment.Request>{
                req(invA.Id, 'KL-2001'),
                req(invB.Id, 'KL-2002'),
                req(invC.Id, 'KL-2003')
            }
        );
        Test.stopTest();

        System.assertEquals(3, results.size());
        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        System.assertEquals(true, results[1].success, 'Got: ' + results[1].message);
        System.assertEquals(false, results[2].success, 'The Fully Paid invoice must still be refused in a bulk call.');

        // Two payments inserted in one DML, each against its own Invoice Summary.
        System.assertEquals(2, [SELECT COUNT() FROM AF_Payment__c WHERE AF_KeyloopPaymentReference__c LIKE 'KL-200%']);
        System.assertEquals(500000,
            [SELECT AF_Amount__c FROM AF_Payment__c WHERE AF_KeyloopPaymentReference__c = 'KL-2001'].AF_Amount__c);
        System.assertEquals(200000,
            [SELECT AF_Amount__c FROM AF_Payment__c WHERE AF_KeyloopPaymentReference__c = 'KL-2002'].AF_Amount__c);
    }

    @isTest
    static void everyPulledPaymentGetsItsOwnSalesforceReference() {
        Account acc = makeAccount();
        Opportunity oppA = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c invA = makeInvoice(acc.Id, oppA.Id, 500000, 0, 'Unpaid');
        Opportunity oppB = makeOpportunity(acc.Id);
        AF_InvoiceSummary__c invB = makeInvoice(acc.Id, oppB.Id, 400000, 0, 'Unpaid');

        Test.startTest();
        AF_KeyloopGetPayment.getPayment(
            new List<AF_KeyloopGetPayment.Request>{ req(invA.Id, 'KL-3001'), req(invB.Id, 'KL-3002') }
        );
        Test.stopTest();

        Set<String> references = new Set<String>();
        for (AF_Payment__c pay : [
            SELECT AF_SFPaymentReference__c, AF_ProofReference__c
            FROM AF_Payment__c WHERE AF_KeyloopPaymentReference__c LIKE 'KL-300%'
        ]) {
            System.assertNotEquals(null, pay.AF_SFPaymentReference__c);
            System.assert(pay.AF_ProofReference__c.startsWith('Keyloop payment '),
                'Got: ' + pay.AF_ProofReference__c);
            references.add(pay.AF_SFPaymentReference__c);
        }
        System.assertEquals(2, references.size(), 'Each payment needs its own SF reference.');
    }
}