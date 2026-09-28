/**
 * Tests for AF_ReservationContract_Regen (ALF-RS-09 FR3/AC1).
 */
@isTest
private class AF_ReservationContract_RegenTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Contract Regen Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Contract Regen Test Opp', AccountId = accountId, StageName = 'Consider',
            CloseDate = Date.today().addDays(30), AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static VehicleDefinition makeVehicleDefinition() {
        Product2 p = new Product2(Name = 'Contract Regen Model Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Contract Regen Model Line', ProductId = p.Id);
        insert vd;
        return vd;
    }

    /** FR13 is now driven by the LFRDN-342 document-requirements engine (AF_DocumentService /
     *  AF_Document__mdt), resolved from real uploaded files tagged against the reservation - not
     *  AF_RequiredDocument__c child rows. When docsComplete is true, attach a real ContentVersion/
     *  ContentDocumentLink, tagged AF_FileUpload__c, for every document AF_DocumentService says is
     *  required for this reservation's contract type / trade-in combination. */
    private static AF_VehicleReservation__c makeReservation(Id accountId, Id oppId, Id vdId, Decimal deposit, Boolean docsComplete) {
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = accountId, AF_Opportunity__c = oppId, AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Reserved', AF_StartDate__c = Date.today(), AF_DepositAmount__c = deposit,
            AF_VehiclePriceTotal__c = 500000,
            AF_VehicleDefinition__c = vdId, AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
        );
        insert resv;

        if (docsComplete) {
            linkAllRequiredDocuments(resv.Id);
        }
        return resv;
    }

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

    private static Id insertVerifiedPayment(Id accountId, Id oppId, Id resvId, Decimal amount) {
        AF_Payment__c pay = new AF_Payment__c(
            AF_Account__c = accountId, AF_Opportunity__c = oppId, AF_VehicleReservation__c = resvId,
            AF_Amount__c = amount, AF_SFPaymentReference__c = 'TESTPAY-' + String.valueOf(Math.abs(Crypto.getRandomInteger())),
            AF_PaymentMethod__c = 'Bank Transfer', AF_ProofReference__c = 'PROOF-' + amount,
            AF_PaymentDate__c = Date.today(), AF_Status__c = 'Paid / Verified'
        );
        insert pay;
        return pay.Id;
    }

    private static AF_ReservationContract_Regen.Request req(Id opportunityId) {
        AF_ReservationContract_Regen.Request r = new AF_ReservationContract_Regen.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    @isTest
    static void regeneratesWithUpdatedNumbersWhenContractAlreadyExists() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, vd.Id, 100000, true);
        insertVerifiedPayment(acc.Id, opp.Id, resv.Id, 100000);

        // First-time generation (mirrors the rep clicking the Quick Action).
        AF_ReservationContractService.Request initialReq = new AF_ReservationContractService.Request();
        initialReq.reservationId = resv.Id;
        AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ initialReq });

        AF_VehicleReservation__c afterFirstGen = [
            SELECT AF_ContractDocumentReference__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        System.assertNotEquals(null, afterFirstGen.AF_ContractDocumentReference__c, 'Contract should exist after first generation.');
        Id firstDocId = afterFirstGen.AF_ContractDocumentReference__c;

        // A second payment lands - the contract should refresh to reflect the new total.
        insertVerifiedPayment(acc.Id, opp.Id, resv.Id, 400000);

        Test.startTest();
        AF_ReservationContract_Regen.regenerateIfContractExists(new List<AF_ReservationContract_Regen.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_VehicleReservation__c afterRegen = [
            SELECT AF_ContractDocumentReference__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        System.assertNotEquals(firstDocId, afterRegen.AF_ContractDocumentReference__c,
            'Regeneration should produce a new document reflecting the updated deposit total.');

        ContentVersion cv = [
            SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :afterRegen.AF_ContractDocumentReference__c
        ];
        String body = cv.VersionData.toString();
        System.assert(body.contains('Deposit Paid'), 'Contract should still show a Deposit Paid line. Body: ' + body);
        System.assert(body.contains('500') && body.contains('000'),
            'Regenerated contract should reflect the combined 500000 deposit total (locale-formatted). Body: ' + body);
    }

    @isTest
    static void doesNothingWhenNoContractExistsYet() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, vd.Id, 100000, true);
        insertVerifiedPayment(acc.Id, opp.Id, resv.Id, 100000);

        Test.startTest();
        AF_ReservationContract_Regen.regenerateIfContractExists(new List<AF_ReservationContract_Regen.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_VehicleReservation__c reloaded = [
            SELECT AF_ContractDocumentReference__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        System.assertEquals(null, reloaded.AF_ContractDocumentReference__c,
            'No contract should be generated - first-time generation stays a manual rep action.');
    }

    @isTest
    static void regenerationRespectsGatesAndStopsOnCancelledReservation() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, vd.Id, 100000, true);
        insertVerifiedPayment(acc.Id, opp.Id, resv.Id, 100000);

        AF_ReservationContractService.Request initialReq = new AF_ReservationContractService.Request();
        initialReq.reservationId = resv.Id;
        AF_ReservationContractService.generate(new List<AF_ReservationContractService.Request>{ initialReq });

        AF_VehicleReservation__c afterFirstGen = [
            SELECT AF_ContractDocumentReference__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        Id firstDocId = afterFirstGen.AF_ContractDocumentReference__c;

        // Reservation gets cancelled after the contract already exists.
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Cancelled');
        insertVerifiedPayment(acc.Id, opp.Id, resv.Id, 50000);

        Test.startTest();
        AF_ReservationContract_Regen.regenerateIfContractExists(new List<AF_ReservationContract_Regen.Request>{ req(opp.Id) });
        Test.stopTest();

        AF_VehicleReservation__c afterAttempt = [
            SELECT AF_ContractDocumentReference__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id
        ];
        System.assertEquals(firstDocId, afterAttempt.AF_ContractDocumentReference__c,
            'Regeneration must not silently succeed on a Cancelled reservation - the FR12/FR13 gates should stop it.');
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        AF_ReservationContract_Regen.regenerateIfContractExists(new List<AF_ReservationContract_Regen.Request>());
        Test.stopTest();
    }

    /** Guardrail: AF_VehicleReservation__c.AF_RequiredDocumentsComplete__c is still queried by
     *  AF_ReservationContractService's SOQL (unused now that FR13 is driven by
     *  AF_DocumentService.areRequiredDocumentsUploaded()), so a Sales Rep with FLS on it muted
     *  would fail the query outright rather than just silently block generation - still worth
     *  guarding against a WITH USER_MODE query failing loudly for that persona. */
    @isTest
    static void salesRepCanReadRequiredDocumentsCompleteField() {
        // Looked up by Alias, not Username: a sandbox refresh rewrites the username suffix per
        // org (.qa.dev / .qa.ci / .qa.qa), so a hardcoded Username only resolves in one of them.
        // The persona is also seeded per-org and is inactive in some sandboxes, so when it is not
        // available this asserts nothing rather than failing - the FLS it guards is enforced by
        // the permission set metadata in this package, which deploys regardless.
        List<User> salesReps = [
            SELECT Id FROM User
            WHERE Alias = 'jstev' AND IsActive = true
            LIMIT 1
        ];
        if (salesReps.isEmpty()) {
            return;
        }
        User salesRep = salesReps[0];
        System.runAs(salesRep) {
            Boolean canRead = Schema.SObjectType.AF_VehicleReservation__c.fields.AF_RequiredDocumentsComplete__c.isAccessible();
            System.assertEquals(true, canRead,
                'Sales Rep must be able to read AF_RequiredDocumentsComplete__c - AF_ReservationContractService\'s ' +
                'gate-check SOQL still selects this field, and a muted field would fail that query for every ' +
                'Sales Rep instead of erroring visibly.');
        }
    }
}