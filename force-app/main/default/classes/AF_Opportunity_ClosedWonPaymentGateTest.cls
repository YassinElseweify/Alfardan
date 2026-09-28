/**
 * Tests for AF_Opportunity_ClosedWonPaymentGate (ALF-RS-09 FR6).
 */
@isTest
private class AF_Opportunity_ClosedWonPaymentGateTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Closed Won Gate Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    /** LFRDN-341 FR1: the gate also requires the linked Handover's registration (Traffic Form)
     *  and signed delivery note (Customer Sign-Off) conditions - true by default so existing
     *  payment/proof/sum scenarios aren't blocked by an unrelated condition; withHandoverOk=false
     *  exercises the new check itself. */
    private static Opportunity makeOpportunityWithInvoice(Id accountId, Decimal expectedTotal) {
        return makeOpportunityWithInvoice(accountId, expectedTotal, true);
    }

    private static Opportunity makeOpportunityWithInvoice(Id accountId, Decimal expectedTotal, Boolean withHandoverOk) {
        Opportunity opp = new Opportunity(
            Name = 'Closed Won Gate Test Opp',
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

        if (withHandoverOk) {
            AF_Handover__c handover = new AF_Handover__c(
                AF_Opportunity__c = opp.Id,
                AF_Account__c = accountId,
                AF_Status__c = 'Completed',
                AF_TrafficFormUploaded__c = true,
                AF_CustomerSignOff__c = 'Physically Signed'
            );
            insert handover;
            opp.AF_Handover__c = handover.Id;
            update opp;
        }

        return opp;
    }

    /** LFRDN-341 FR4/FR5 reuse the LFRDN-342 AF_Document__mdt engine, which requires a Bank LPO /
     *  Cheque Copy document per AF_PaymentMethod__c - defaults to Cash (no document requirement)
     *  so existing generic-proof scenarios aren't blocked by an unrelated new condition. */
    private static Id insertPayment(Id accountId, Id oppId, Decimal amount, String status, String proof) {
        return insertPayment(accountId, oppId, amount, status, proof, 'Cash');
    }

    private static Id insertPayment(Id accountId, Id oppId, Decimal amount, String status, String proof, String paymentMethod) {
        AF_Payment__c pay = new AF_Payment__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_Amount__c = amount,
            AF_SFPaymentReference__c = 'TESTPAY-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AF_PaymentMethod__c = paymentMethod,
            AF_ProofReference__c = proof,
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = status
        );
        insert pay;
        return pay.Id;
    }

    /** Tags the attached ContentVersion with AF_FileUpload__c so AF_DocumentService recognizes it
     *  as satisfying a specific AF_Document__mdt requirement (e.g. "Bank LPO", "Cheque Copy"). */
    private static void attachTaggedDocument(Id paymentId, String documentName) {
        ContentVersion cv = new ContentVersion(
            Title = documentName + '-' + paymentId,
            PathOnClient = documentName + '.pdf',
            VersionData = Blob.valueOf(documentName),
            AF_FileUpload__c = documentName
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = paymentId,
            ShareType = 'V'
        );
    }

    /** BRD FR6 requires a real attached/uploaded proof document, not just the AF_ProofReference__c
     *  text label - attaches a genuine ContentVersion/ContentDocumentLink to the given Payment. */
    private static void attachProofFile(Id paymentId) {
        ContentVersion cv = new ContentVersion(
            Title = 'Proof-' + paymentId,
            PathOnClient = 'proof.pdf',
            VersionData = Blob.valueOf('proof of payment')
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = paymentId,
            ShareType = 'V'
        );
    }

    /** Cash + Keyloop-synced: neither AF_VR_ProofRequiredWhenVerified (checks AF_Status__c only)
     *  nor AF_VR_Payment_ProofRequired (checks Cheque/Bank Transfer only) block a proof-less Cash
     *  payment, so this is the only way to legally insert a verified payment with no attached file -
     *  needed to exercise the gate's own proof check independently of those two VRs. */
    private static void insertKeyloopSyncedPaymentWithNoProof(Id accountId, Id oppId, Decimal amount) {
        insert new AF_Payment__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_Amount__c = amount,
            AF_SFPaymentReference__c = 'TESTPAY-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AF_PaymentMethod__c = 'Cash',
            AF_PaymentDate__c = Date.today(),
            AF_IntegrationStatus__c = 'Synced'
        );
    }

    private static AF_Opportunity_ClosedWonPaymentGate.Request req(Id opportunityId) {
        AF_Opportunity_ClosedWonPaymentGate.Request r = new AF_Opportunity_ClosedWonPaymentGate.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    @isTest
    static void allowsWhenAllPaymentsVerifiedWithProofAndSumMatches() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        attachProofFile(insertPayment(acc.Id, opp.Id, 300000, 'Paid / Verified', 'PROOF-1'));
        attachProofFile(insertPayment(acc.Id, opp.Id, 200000, 'Paid / Verified', 'PROOF-2'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].allowed, 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenAnyPaymentNotVerified() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        attachProofFile(insertPayment(acc.Id, opp.Id, 300000, 'Paid / Verified', 'PROOF-1'));
        attachProofFile(insertPayment(acc.Id, opp.Id, 200000, 'Pending', 'PROOF-2'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('Paid / Verified'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenAnyPaymentMissingProof() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        insertPayment(acc.Id, opp.Id, 300000, 'Paid / Verified', 'PROOF-1');
        insertKeyloopSyncedPaymentWithNoProof(acc.Id, opp.Id, 200000);

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('proof'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenSumDoesNotMatchExpectedTotal() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        attachProofFile(insertPayment(acc.Id, opp.Id, 300000, 'Paid / Verified', 'PROOF-1'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('does not equal'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenNoInvoiceSummaryExists() {
        Account acc = makeAccount();
        Opportunity opp = new Opportunity(
            Name = 'No Invoice Opp', AccountId = acc.Id, StageName = 'Consider',
            CloseDate = Date.today().addDays(30), AF_Brand__c = 'Ferrari'
        );
        insert opp;

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('No Invoice Summary'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenHandoverConditionsNotMet() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000, false);
        attachProofFile(insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('Registration'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenChequePaymentMissingChequeCopy() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        attachProofFile(insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1', 'Cheque'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('Required Documents'), 'Got: ' + results[0].message);
    }

    @isTest
    static void allowsChequePaymentWithChequeCopyUploaded() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        Id payId = insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1', 'Cheque');
        attachProofFile(payId);
        attachTaggedDocument(payId, 'Cheque Copy');

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].allowed, 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenBankTransferPaymentMissingBankLPO() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        attachProofFile(insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1', 'Bank Transfer'));

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('Required Documents'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenPayeeMismatchMissingSignedNOC() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        Id payId = insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1', 'Cash');
        attachProofFile(payId);
        update new AF_Payment__c(Id = payId, AF_PayeeName__c = 'Someone Else', AF_NOCRecorded__c = true);

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('Required Documents'), 'Got: ' + results[0].message);
    }

    @isTest
    static void allowsPayeeMismatchWithSignedNOCUploaded() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);
        Id payId = insertPayment(acc.Id, opp.Id, 500000, 'Paid / Verified', 'PROOF-1', 'Cash');
        attachProofFile(payId);
        update new AF_Payment__c(Id = payId, AF_PayeeName__c = 'Someone Else', AF_NOCRecorded__c = true);
        attachTaggedDocument(payId, 'Signed NOC');

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].allowed, 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenNoPaymentsExist() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunityWithInvoice(acc.Id, 500000);

        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].allowed);
        System.assert(results[0].message.contains('No Payment records'), 'Got: ' + results[0].message);
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        List<AF_Opportunity_ClosedWonPaymentGate.Result> results =
            AF_Opportunity_ClosedWonPaymentGate.check(new List<AF_Opportunity_ClosedWonPaymentGate.Request>());
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}