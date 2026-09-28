/**
 * Tests for AF_ReservationDoubleBookingGuard / the AF_VehicleReservation trigger.
 */
@isTest
private class AF_ReservationDoubleBookingGuardTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'DoubleBooking Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'DoubleBooking Test Opp', AccountId = accountId, StageName = 'Consider',
            CloseDate = Date.today().addDays(30), AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static Integer vehicleCounter = 0;

    private static Vehicle makeVehicle() {
        vehicleCounter++;
        Product2 p = new Product2(Name = 'DoubleBooking Product ' + vehicleCounter, IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'DoubleBooking Line ' + vehicleCounter, ProductId = p.Id);
        insert vd;
        Asset asset = new Asset(Name = 'DoubleBooking Test Asset ' + vehicleCounter);
        insert asset;
        Vehicle v = new Vehicle(
            Name = 'DoubleBooking Test Vehicle ' + vehicleCounter,
            VehicleDefinitionId = vd.Id,
            AssetId = asset.Id,
            VehicleIdentificationNumber = 'TESTVIN' + vehicleCounter + Math.abs(Crypto.getRandomInteger())
        );
        insert v;
        return v;
    }

    @isTest
    static void secondLiveReservationOnSameVehicleIsBlocked() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v = makeVehicle();

        insert new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
        );

        Test.startTest();
        Boolean threw = false;
        try {
            insert new AF_VehicleReservation__c(
                AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
                AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
                AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
            );
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('already held'), 'Unexpected error: ' + e.getMessage());
        }
        Test.stopTest();

        System.assertEquals(true, threw, 'A second live reservation on the same vehicle must be blocked.');
    }

    @isTest
    static void secondReservationAllowedOnceFirstIsTerminal() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v = makeVehicle();

        AF_VehicleReservation__c first = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
        );
        insert first;
        update new AF_VehicleReservation__c(Id = first.Id, AF_Status__c = 'Cancelled');

        Test.startTest();
        Boolean threw = false;
        try {
            insert new AF_VehicleReservation__c(
                AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
                AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
                AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
            );
        } catch (DmlException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'A vehicle whose only reservation is Cancelled should be free to reserve again.');
    }

    @isTest
    static void editingAReservationWithoutChangingVehicleOrStatusIsUnaffected() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v = makeVehicle();

        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
        );
        insert resv;

        Test.startTest();
        // Re-saving the same record with the same vehicle/status must not trip over itself.
        update new AF_VehicleReservation__c(Id = resv.Id, AF_RequiredDocumentsComplete__c = true);
        Test.stopTest();

        AF_VehicleReservation__c after = [SELECT AF_RequiredDocumentsComplete__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id];
        System.assertEquals(true, after.AF_RequiredDocumentsComplete__c);
    }

    @isTest
    static void vehicleDefinitionReservationsAreNeverBlocked() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Product2 p = new Product2(Name = 'DoubleBooking VD Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'DoubleBooking VD Line', ProductId = p.Id);
        insert vd;

        insert new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_VehicleDefinition__c = vd.Id, AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
        );

        Test.startTest();
        Boolean threw = false;
        try {
            insert new AF_VehicleReservation__c(
                AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
                AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
                AF_VehicleDefinition__c = vd.Id, AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
            );
        } catch (DmlException e) {
            threw = true;
        }
        Test.stopTest();

        System.assertEquals(false, threw, 'Multiple reservations against the same Vehicle Definition (a model line, not a unit) must be allowed.');
    }

    @isTest
    static void rejectedReservationResetsToRequested() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Product2 p = new Product2(Name = 'Rejected Test Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Rejected Test Line', ProductId = p.Id);
        insert vd;

        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(), AF_DepositAmount__c = 1000,
            AF_VehiclePriceTotal__c = 500000, AF_VehicleDefinition__c = vd.Id, AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
        );
        insert resv;

        Test.startTest();
        update new AF_VehicleReservation__c(Id = resv.Id, AF_ApprovalStatus__c = 'Rejected');
        Test.stopTest();

        AF_VehicleReservation__c after = [SELECT AF_Status__c, AF_ApprovalStatus__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id];
        System.assertEquals('Requested', after.AF_Status__c, 'A rejected reservation must reset to Requested so the rep can fix and resubmit.');
        System.assertEquals('Rejected', after.AF_ApprovalStatus__c);
    }

    @isTest
    static void rejectedTerminalReservationIsNotReopened() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Product2 p = new Product2(Name = 'Rejected Terminal Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Rejected Terminal Line', ProductId = p.Id);
        insert vd;

        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(), AF_DepositAmount__c = 1000,
            AF_VehiclePriceTotal__c = 500000, AF_VehicleDefinition__c = vd.Id, AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
        );
        insert resv;
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Cancelled');

        Test.startTest();
        // A cancelled reservation getting its approval field rejected in some data-fix scenario
        // must not be dragged back to life.
        update new AF_VehicleReservation__c(Id = resv.Id, AF_ApprovalStatus__c = 'Rejected');
        Test.stopTest();

        AF_VehicleReservation__c after = [SELECT AF_Status__c FROM AF_VehicleReservation__c WHERE Id = :resv.Id];
        System.assertEquals('Cancelled', after.AF_Status__c, 'A terminal reservation must never be reset to Requested.');
    }

    /**
     * ALF-RS-08 FR1/FR16: AF_VehicleReservationStatusSync must flip the Vehicle's own mirror field
     * to Reserved the moment a reservation against it goes live - found live as a real defect
     * (RES-00052 was Reserved against a real vehicle whose AF_ReservationStatus__c still read
     * Available), which is exactly what AF_FL_Quote_CreateReservation's picker filters on.
     */
    @isTest
    static void vehicleMirrorFlipsToReservedWhenReservationGoesLive() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v = makeVehicle();

        Test.startTest();
        insert new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
        );
        Test.stopTest();

        Vehicle after = [SELECT AF_ReservationStatus__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('Reserved', after.AF_ReservationStatus__c,
            'The vehicle mirror must flip to Reserved once a live reservation exists against it.');
    }

    /**
     * ALF-RS-08 FR16: once the only live reservation against a vehicle is cancelled, the mirror
     * must revert to Available so the vehicle picker sees it as selectable again.
     */
    @isTest
    static void vehicleMirrorRevertsToAvailableWhenReservationIsCancelled() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v = makeVehicle();

        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v.Id, AF_VehicleSourceType__c = 'In Stock'
        );
        insert resv;

        Vehicle whileLive = [SELECT AF_ReservationStatus__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('Reserved', whileLive.AF_ReservationStatus__c);

        Test.startTest();
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Cancelled');
        Test.stopTest();

        Vehicle after = [SELECT AF_ReservationStatus__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('Available', after.AF_ReservationStatus__c,
            'A vehicle with no remaining live reservation must revert to Available.');
    }

    /**
     * Moving a reservation from one vehicle to another must free the old vehicle and hold the new
     * one - both writes happen in the same trigger execution.
     */
    @isTest
    static void vehicleMirrorMovesWithReservationWhenVehicleIsSwapped() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        Vehicle v1 = makeVehicle();
        Vehicle v2 = makeVehicle();

        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id, AF_Opportunity__c = opp.Id, AF_ContractType__c = '3-Day (No Deposit)',
            AF_Status__c = 'Requested', AF_StartDate__c = Date.today(),
            AF_Vehicle__c = v1.Id, AF_VehicleSourceType__c = 'In Stock'
        );
        insert resv;

        Test.startTest();
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Vehicle__c = v2.Id);
        Test.stopTest();

        Map<Id, Vehicle> after = new Map<Id, Vehicle>(
            [SELECT Id, AF_ReservationStatus__c FROM Vehicle WHERE Id IN (:v1.Id, :v2.Id)]
        );
        System.assertEquals('Available', after.get(v1.Id).AF_ReservationStatus__c, 'The old vehicle must be freed.');
        System.assertEquals('Reserved', after.get(v2.Id).AF_ReservationStatus__c, 'The new vehicle must be held.');
    }
}