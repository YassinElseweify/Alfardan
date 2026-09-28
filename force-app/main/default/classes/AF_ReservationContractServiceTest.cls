/**
 * Tests for AF_ReservationContractService (ALF-RS-08 FR12 / FR13 / FR14).
 *
 * Covers each gate independently, the happy path for both the deposit and no-deposit contract
 * tiers, and the pre-order placeholder case where the reservation carries a Vehicle Definition
 * rather than a VIN.
 */
@isTest
private class AF_ReservationContractServiceTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Reservation Contract Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Reservation Contract Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static AF_VehicleReservation__c makeReservation(
        Id accountId, Id oppId, String contractType, Decimal deposit, Boolean docsComplete
    ) {
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_ContractType__c = contractType,
            AF_Status__c = 'Reserved',
            AF_StartDate__c = Date.today(),
            AF_DepositAmount__c = deposit,
            AF_VehiclePriceTotal__c = 500000,
            AF_VehicleDefinition__c = null
        );
        return resv;
        // Note: docsComplete is unused - FR13 is now driven by the LFRDN-342 document-requirements
        // engine (AF_DocumentService / AF_Document__mdt), resolved from real uploaded files tagged
        // against the reservation. Call linkAllRequiredDocuments() after insert instead.
    }

    /** ALF-RS-08 FR13, ported onto the LFRDN-342 engine: attaches a real ContentVersion/
     *  ContentDocumentLink, tagged AF_FileUpload__c, for every document AF_DocumentService says is
     *  required for this reservation's contract type / trade-in combination. */
    private static void linkAllRequiredDocuments(Id reservationId) {
        Map<String, List<AF_Document__mdt>> requiredByRecord = AF_DocumentService.getRequiredDocuments(
            new List<Id>{ reservationId }, false
        );
        List<AF_Document__mdt> required = requiredByRecord.get(String.valueOf(reservationId));
        if (required == null) {
            return;
        }
        for (AF_Document__mdt doc : required) {
            ContentVersion cv = new ContentVersion(
                Title = doc.AF_DocumentName__c + '-' + reservationId,
                PathOnClient = doc.AF_DocumentName__c + '.pdf',
                VersionData = Blob.valueOf(doc.AF_DocumentName__c),
                AF_FileUpload__c = doc.AF_DocumentName__c
            );
            insert cv;
            Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            insert new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = reservationId,
                ShareType = 'V'
            );
        }
    }

    /** A reservation must reference stock (AF_VR_VehicleRequired), so give every fixture one.
     *  VehicleDefinition requires a Product, so build that first. */
    private static VehicleDefinition makeVehicleDefinition() {
        Product2 p = new Product2(Name = 'Test Model Line Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Test Model Line', ProductId = p.Id);
        insert vd;
        return vd;
    }

    private static AF_Payment__c makeVerifiedPayment(Id accountId, Id reservationId, Decimal amount) {
        AF_Payment__c pay = new AF_Payment__c(
            AF_Account__c = accountId,
            AF_VehicleReservation__c = reservationId,
            AF_Amount__c = amount,
            AF_SFPaymentReference__c = 'TESTPAY-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AF_PaymentMethod__c = 'Bank Transfer',
            AF_ProofReference__c = 'PROOF-001',
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = 'Paid / Verified'
        );
        insert pay;
        return pay;
    }

    private static AF_ReservationContractService.Request req(Id reservationId) {
        AF_ReservationContractService.Request r = new AF_ReservationContractService.Request();
        r.reservationId = reservationId;
        r.bypassGates = false;
        return r;
    }

    @isTest
    static void blocksWhenRequiredDocumentsIncomplete() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, false);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        makeVerifiedPayment(acc.Id, resv.Id, 100000);

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'FR13 gate should block generation.');
        System.assert(results[0].message.contains('Required Documents'), 'Expected the FR13 message, got: ' + results[0].message);
        System.assertEquals(null, results[0].contentDocumentId);
    }

    @isTest
    static void blocksWhenNoVerifiedPayment() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        linkAllRequiredDocuments(resv.Id);

        // A payment exists but is still Pending - the gate must stay shut.
        insert new AF_Payment__c(
            AF_Account__c = acc.Id,
            AF_VehicleReservation__c = resv.Id,
            AF_Amount__c = 100000,
            AF_SFPaymentReference__c = 'TESTPAY-PENDING',
            AF_PaymentMethod__c = 'Cash',
            AF_PaymentDate__c = Date.today(),
            AF_Status__c = 'Pending'
        );

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'FR12 gate should block on an unverified payment.');
        System.assert(results[0].message.contains('Paid / Verified'), 'Expected the FR12 message, got: ' + results[0].message);
    }

    @isTest
    static void generatesContractWhenGatesPass() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        linkAllRequiredDocuments(resv.Id);
        makeVerifiedPayment(acc.Id, resv.Id, 100000);

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Expected generation to succeed, got: ' + results[0].message);
        System.assertNotEquals(null, results[0].contentDocumentId);

        ContentVersion cv = [
            SELECT Title, VersionData FROM ContentVersion WHERE Id = :results[0].contentVersionId
        ];
        String body = cv.VersionData.toString();

        // FR14 requires each of these on the document.
        System.assert(body.contains('VEHICLE RESERVATION CONTRACT'), 'Missing title');
        System.assert(body.contains('CUSTOMER DETAILS'), 'Missing customer details');
        System.assert(body.contains('VEHICLE DETAILS'), 'Missing vehicle details');
        System.assert(body.contains('Deposit Paid'), 'Missing deposit amount');
        System.assert(body.contains('Remaining Balance'), 'Missing remaining balance');
        System.assert(body.contains('RESERVATION PERIOD'), 'Missing reservation dates');
        System.assert(body.contains('SIGNATURES'), 'Missing signature block');
        System.assert(body.contains('pre-order placeholder'), 'Pre-order vehicle should be labelled as a placeholder');

        // The reservation must be stamped so the UI can show a contract exists.
        AF_VehicleReservation__c reloaded = [
            SELECT AF_ContractDocumentReference__c, AF_ContractGeneratedDate__c
            FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        System.assertNotEquals(null, reloaded.AF_ContractDocumentReference__c);
        System.assertNotEquals(null, reloaded.AF_ContractGeneratedDate__c);
    }

    /**
     * ALF-RS-08 FR12, reconciled against the 07-opportunity-quote-reservation-handover-flow LLD:
     * a payment confirmed by the Keyloop/MuleSoft sync (AF_IntegrationStatus__c = Synced) must
     * clear the gate exactly like a cashier-verified payment does - AF_Status__c is never touched
     * on this path, since the confirmation came back through the integration, not a human.
     */
    @isTest
    static void keyloopSyncedPaymentClearsGateWithoutManualVerification() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        linkAllRequiredDocuments(resv.Id);

        insert new AF_Payment__c(
            AF_Account__c = acc.Id,
            AF_VehicleReservation__c = resv.Id,
            AF_Amount__c = 100000,
            AF_SFPaymentReference__c = 'TESTPAY-KEYLOOP',
            AF_PaymentMethod__c = 'Bank Transfer',
            AF_ProofReference__c = 'BANK-LPO-001',
            AF_PaymentDate__c = Date.today(),
            AF_IntegrationStatus__c = 'Synced',
            AF_IntegrationReceivedDate__c = System.now()
            // AF_Status__c deliberately left at its Pending default - no human ever verified this one.
        );

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Keyloop sync alone should clear FR12. Got: ' + results[0].message);
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assert(cv.VersionData.toString().contains('Keyloop synced'),
            'Contract should attribute verification to the Keyloop sync, not a cashier.');
    }

    /**
     * ALF-RS-08 FR12 (amount): a verified payment existing is not enough - its total must cover
     * the required deposit. A $30,000 verified payment against a $100,000 required deposit must
     * still block generation, naming both figures in the message.
     */
    @isTest
    static void blocksWhenVerifiedPaymentIsLessThanRequiredDeposit() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        linkAllRequiredDocuments(resv.Id);
        makeVerifiedPayment(acc.Id, resv.Id, 30000);

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success, 'A partial verified payment must not clear FR12.');
        System.assert(results[0].message.contains('30,000') && results[0].message.contains('100,000'),
            'Expected the message to name both the verified total and the required deposit. Got: ' + results[0].message);
    }

    /**
     * ALF-RS-08 FR12 (amount) combined with FR11 (Trade-In as deposit): when the agreed Trade-In
     * value makes up part of the deposit, the verified cash/card payment total is legitimately
     * allowed to be less than AF_DepositAmount__c - the amount check must not fire in that case.
     */
    @isTest
    static void tradeInAsDepositExemptFromPaymentAmountCheck() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        resv.AF_TradeInAsDeposit__c = true;
        insert resv;
        linkAllRequiredDocuments(resv.Id);
        // Only a fraction of the $100,000 deposit is covered by an actual verified cash payment -
        // the rest is the agreed Trade-In value, which is not a Payment record.
        makeVerifiedPayment(acc.Id, resv.Id, 20000);

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'Trade-In-as-deposit reservations must be exempt from the payment-amount check. Got: ' + results[0].message);
    }

    @isTest
    static void noDepositContractSkipsPaymentGate() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        // 3-Day (No Deposit) has no deposit to verify, so FR12 must not apply.
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '3-Day (No Deposit)', 0, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;
        linkAllRequiredDocuments(resv.Id);

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success,
            'A no-deposit reservation should not be blocked by the payment gate. Got: ' + results[0].message);
        ContentVersion cv = [SELECT VersionData FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assert(cv.VersionData.toString().contains('No deposit required'),
            'No-deposit contract should say so in the payment line.');
    }

    @isTest
    static void blocksCancelledReservation() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '3-Day (No Deposit)', 0, true);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        // AF_VR_Reservation_NoSkipOnInsert only fires on insert, so the reservation has to
        // start in its real initial status and then be moved to Cancelled the way it would be.
        insert resv;
        resv.AF_Status__c = 'Cancelled';
        update resv;

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ req(resv.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('cancelled'), 'Got: ' + results[0].message);
    }

    @isTest
    static void bypassGatesGeneratesAnyway() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();

        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, '7-Day (Deposit)', 100000, false);
        resv.AF_VehicleDefinition__c = vd.Id;
        resv.AF_VehicleSourceType__c = 'Pre-Order (Placeholder)';
        insert resv;

        AF_ReservationContractService.Request r = req(resv.Id);
        r.bypassGates = true;

        Test.startTest();
        List<AF_ReservationContractService.Result> results =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ r });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Bypass should skip both gates. Got: ' + results[0].message);
    }

    @isTest
    static void handlesMissingReservationAndEmptyInput() {
        Test.startTest();
        List<AF_ReservationContractService.Result> empty =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>());
        AF_ReservationContractService.Request bogus = new AF_ReservationContractService.Request();
        bogus.reservationId = null;
        List<AF_ReservationContractService.Result> missing =
            AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ bogus });
        Test.stopTest();

        System.assertEquals(0, empty.size(), 'Empty input should return no results.');
        System.assertEquals(false, missing[0].success);
        System.assert(missing[0].message.contains('not found'), 'Got: ' + missing[0].message);
    }
}