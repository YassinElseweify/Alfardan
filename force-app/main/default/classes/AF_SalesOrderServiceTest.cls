/**
 * Tests for AF_SalesOrderService (ALF-RS-10/LFRDN-340 FR1/FR5/AC1).
 *
 * Gates mirror AF_VR_Opp_SOGenerationGate: the Invoice Summary must be Fully Paid (LFRDN-660,
 * confirmed by the business 2026-09-21), a vehicle must be selected and In Stock, and a Reserved
 * Vehicle Reservation must exist on the Opportunity covering that same vehicle (LFRDN-661,
 * confirmed by the business 2026-09-21).
 */
@isTest
private class AF_SalesOrderServiceTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Sales Order Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Sales Order Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    /**
     * The Invoice Summary is read via the Opportunity's own AF_InvoiceSummary__c lookup, which
     * does not populate itself - it must be set back onto the Opportunity explicitly, same as a
     * real Invoice Summary creation flow would.
     */
    private static void makeInvoice(Id accountId, Id oppId, Decimal expectedTotal, Decimal paidAmount) {
        AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_ExpectedTotalAmount__c = expectedTotal,
            AF_PaidAmount__c = paidAmount,
            AF_Balance__c = expectedTotal - paidAmount,
            AF_Status__c = paidAmount >= expectedTotal ? 'Fully Paid' : (paidAmount > 0 ? 'Partially Paid' : 'Unpaid')
        );
        insert inv;
        update new Opportunity(Id = oppId, AF_InvoiceSummary__c = inv.Id);
    }

    private static Vehicle makeVehicle(String inventoryStatus) {
        Product2 p = new Product2(Name = 'SO Test Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'SO Test Line', ProductId = p.Id);
        insert vd;
        Asset asset = new Asset(Name = 'SO Test Asset ' + Math.abs(Crypto.getRandomInteger()));
        insert asset;
        Vehicle v = new Vehicle(
            Name = 'SO Test Vehicle',
            VehicleDefinitionId = vd.Id,
            AssetId = asset.Id,
            VehicleIdentificationNumber = 'SOTESTVIN' + Math.abs(Crypto.getRandomInteger()),
            AF_InventoryStatus__c = inventoryStatus
        );
        insert v;
        return v;
    }

    private static AF_VehicleReservation__c makeReservation(Id accountId, Id oppId, Id vehicleId, String status) {
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = status,
            AF_StartDate__c = Date.today(),
            AF_DepositAmount__c = 50000,
            AF_VehicleSourceType__c = 'In Stock',
            AF_Vehicle__c = vehicleId
        );
        insert resv;
        return resv;
    }

    private static AF_SalesOrderService.Request req(Id opportunityId) {
        AF_SalesOrderService.Request r = new AF_SalesOrderService.Request();
        r.opportunityId = opportunityId;
        return r;
    }

    /**
     * The one fully-satisfied path: fully paid, vehicle In Stock, Reserved reservation covering
     * that same vehicle.
     */
    @isTest
    static void generatesSalesOrderWhenFullyPaidVehicleInStockAndReserved() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Stock');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        System.assertNotEquals(null, results[0].contentDocumentId);

        Opportunity updated = [SELECT AF_SOStatus__c, AF_SODocumentReference__c, AF_SOGeneratedDate__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals('Generated', updated.AF_SOStatus__c);
        System.assertNotEquals(null, updated.AF_SODocumentReference__c);
        System.assertNotEquals(null, updated.AF_SOGeneratedDate__c);
    }

    @isTest
    static void blocksWhenNoInvoiceSummaryExists() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('fully paid'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenOnlyDepositPaid() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        // Deliberately below the expected total - LFRDN-660: a deposit is no longer sufficient.
        makeInvoice(acc.Id, opp.Id, 500000, 50000);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('fully paid'), 'Got: ' + results[0].message);
        System.assert(results[0].message.contains('50,000'), 'Got: ' + results[0].message);
        System.assert(results[0].message.contains('450,000'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenPaidAmountIsZero() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 0);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('fully paid'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenNoVehicleSelected() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        // No AF_SelectedVehicle__c at all - LFRDN-661.

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('no vehicle is selected'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenSelectedVehicleOnOrder() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('Ordered');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('In Stock'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenSelectedVehicleInTransit() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Transit');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('In Stock'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenNoReservationExists() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Stock');
        // No Vehicle Reservation at all - LFRDN-661.
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('reservation'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenReservationExpired() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Stock');
        // A reservation cannot be inserted directly as Expired - it must start Reserved and progress.
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Expired');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('reservation'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenReservationCoversDifferentVehicle() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle selectedVehicle = makeVehicle('In Stock');
        Vehicle reservedVehicle = makeVehicle('In Stock');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, reservedVehicle.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = selectedVehicle.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('reservation'), 'Got: ' + results[0].message);
    }

    @isTest
    static void blocksWhenSalesOrderAlreadyGenerated() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Stock');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id, AF_SOStatus__c = 'Generated');

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('already exists'), 'Got: ' + results[0].message);
    }

    @isTest
    static void convertsLinkedReservationOnSuccess() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        makeInvoice(acc.Id, opp.Id, 500000, 500000);
        Vehicle v = makeVehicle('In Stock');
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, v.Id, 'Reserved');
        update new Opportunity(Id = opp.Id, AF_SelectedVehicle__c = v.Id, AF_VehicleReservation__c = resv.Id);

        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(opp.Id) });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        AF_VehicleReservation__c resvAfter = [SELECT AF_Status__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id];
        System.assertEquals('Converted', resvAfter.AF_Status__c);
    }

    @isTest
    static void blocksWhenOpportunityNotFound() {
        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>{ req(null) });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('not found'), 'Got: ' + results[0].message);
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        List<AF_SalesOrderService.Result> results =
            AF_SalesOrderService.generate(new List<AF_SalesOrderService.Request>());
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}