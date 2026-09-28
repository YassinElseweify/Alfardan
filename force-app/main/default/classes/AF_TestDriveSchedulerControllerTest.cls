@IsTest
private class AF_TestDriveSchedulerControllerTest {

    private static Id testVehicleId() {
        Product2 prod = new Product2(Name = 'TD Test Vehicle Product', AF_ProductCategory__c = 'Vehicle Model');
        insert prod;
        VehicleDefinition vd = new VehicleDefinition(Name = 'TD Test Vehicle Definition', ProductId = prod.Id);
        insert vd;
        Asset asset = new Asset(Name = 'TD Test Asset');
        insert asset;
        Id demoVehicleRecordTypeId = Schema.SObjectType.Vehicle.getRecordTypeInfosByDeveloperName().get('Demo_Vehicle').getRecordTypeId();
        Vehicle v = new Vehicle(
            Name = 'TD Test Vehicle',
            RecordTypeId = demoVehicleRecordTypeId,
            VehicleDefinitionId = vd.Id,
            AssetId = asset.Id,
            VehicleIdentificationNumber = 'TDTESTVIN00001',
            AF_InventoryVehicle__c = false,
            AF_InventoryStatus__c = 'In Stock'
        );
        insert v;
        return v.Id;
    }

    private static Id testOpportunityId() {
        Opportunity opp = new Opportunity(
            Name = 'TD Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;
        return opp.Id;
    }

    private static AF_TestDrive__c buildBaseTestDrive(Id oppId) {
        return new AF_TestDrive__c(
            AF_Opportunity__c = oppId,
            AF_Status__c = 'Requested'
        );
    }

    @IsTest
    static void testGetAllSlotsReturnsFullOrderedList() {
        Test.startTest();
        List<String> slots = AF_TestDriveSchedulerController.getAllSlots();
        Test.stopTest();

        System.assertEquals(17, slots.size(), 'Should return all 17 fixed showroom slots');
        System.assertEquals('9:00 AM', slots[0]);
        System.assertEquals('5:00 PM', slots[slots.size() - 1]);
    }

    @IsTest
    static void testGetBookedSlotsReturnsOnlyMatchingVehicleAndDate() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        Date scheduleDate = Date.today().addDays(1);

        AF_TestDrive__c booked = buildBaseTestDrive(oppId);
        booked.AF_Vehicle__c = vehicleId;
        booked.AF_TestDriveDateTime__c = Datetime.newInstance(scheduleDate, Time.newInstance(10, 0, 0, 0));
        booked.AF_TimeSlot__c = '10:00 AM';
        booked.AF_Location__c = 'Main Showroom';
        booked.AF_Status__c = 'Scheduled';
        insert booked;

        Test.startTest();
        List<String> slots = AF_TestDriveSchedulerController.getBookedSlots(vehicleId, scheduleDate, null);
        Test.stopTest();

        System.assertEquals(1, slots.size());
        System.assertEquals('10:00 AM', slots[0]);
    }

    @IsTest
    static void testGetBookedSlotsExcludesCancelledBookings() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        Date scheduleDate = Date.today().addDays(1);

        AF_TestDrive__c cancelled = buildBaseTestDrive(oppId);
        cancelled.AF_Vehicle__c = vehicleId;
        cancelled.AF_TestDriveDateTime__c = Datetime.newInstance(scheduleDate, Time.newInstance(11, 0, 0, 0));
        cancelled.AF_TimeSlot__c = '11:00 AM';
        cancelled.AF_Location__c = 'Main Showroom';
        cancelled.AF_Status__c = 'Cancelled';
        insert cancelled;

        Test.startTest();
        List<String> slots = AF_TestDriveSchedulerController.getBookedSlots(vehicleId, scheduleDate, null);
        Test.stopTest();

        System.assertEquals(0, slots.size(), 'A Cancelled booking should not block its slot');
    }

    @IsTest
    static void testGetBookedSlotsExcludesTheRecordBeingRescheduledItself() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        Date scheduleDate = Date.today().addDays(1);

        AF_TestDrive__c existing = buildBaseTestDrive(oppId);
        existing.AF_Vehicle__c = vehicleId;
        existing.AF_TestDriveDateTime__c = Datetime.newInstance(scheduleDate, Time.newInstance(9, 0, 0, 0));
        existing.AF_TimeSlot__c = '9:00 AM';
        existing.AF_Location__c = 'Main Showroom';
        existing.AF_Status__c = 'Scheduled';
        insert existing;

        Test.startTest();
        List<String> slots = AF_TestDriveSchedulerController.getBookedSlots(vehicleId, scheduleDate, existing.Id);
        Test.stopTest();

        System.assertEquals(0, slots.size(), 'Re-opening the scheduler on its own already-scheduled record should not lock out its own slot');
    }

    @IsTest
    static void testGetBookedSlotsNullVehicleOrDateReturnsEmpty() {
        Test.startTest();
        List<String> slots = AF_TestDriveSchedulerController.getBookedSlots(null, Date.today(), null);
        Test.stopTest();

        System.assertEquals(0, slots.size());
    }

    @IsTest
    static void testConfirmScheduleSuccessfullyBooksSlot() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        AF_TestDrive__c td = buildBaseTestDrive(oppId);
        insert td;

        Date scheduleDate = Date.today().addDays(2);

        Test.startTest();
        AF_TestDriveSchedulerController.confirmSchedule(td.Id, vehicleId, scheduleDate, '2:00 PM', 'Main Showroom');
        Test.stopTest();

        AF_TestDrive__c refreshed = [
            SELECT AF_Status__c, AF_TimeSlot__c, AF_Location__c, AF_TestDriveDateTime__c, AF_Vehicle__c
            FROM AF_TestDrive__c WHERE Id = :td.Id
        ];
        System.assertEquals('Scheduled', refreshed.AF_Status__c);
        System.assertEquals('2:00 PM', refreshed.AF_TimeSlot__c);
        System.assertEquals('Main Showroom', refreshed.AF_Location__c);
        System.assertEquals(vehicleId, refreshed.AF_Vehicle__c);
        System.assertEquals(
            Datetime.newInstance(scheduleDate, Time.newInstance(14, 0, 0, 0)),
            refreshed.AF_TestDriveDateTime__c
        );
    }

    @IsTest
    static void testConfirmScheduleThrowsWhenSlotAlreadyBookedByAnotherRecord() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        Date scheduleDate = Date.today().addDays(2);

        AF_TestDrive__c existing = buildBaseTestDrive(oppId);
        existing.AF_Vehicle__c = vehicleId;
        existing.AF_TestDriveDateTime__c = Datetime.newInstance(scheduleDate, Time.newInstance(15, 0, 0, 0));
        existing.AF_TimeSlot__c = '3:00 PM';
        existing.AF_Location__c = 'Main Showroom';
        existing.AF_Status__c = 'Scheduled';
        insert existing;

        AF_TestDrive__c newTd = buildBaseTestDrive(oppId);
        insert newTd;

        Boolean threw = false;
        Test.startTest();
        try {
            AF_TestDriveSchedulerController.confirmSchedule(newTd.Id, vehicleId, scheduleDate, '3:00 PM', 'Main Showroom');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Booking a slot already taken by another Test Drive should fail with a clear error');
    }

    @IsTest
    static void testConfirmScheduleThrowsWithMissingRequiredFields() {
        Boolean threw = false;
        Test.startTest();
        try {
            AF_TestDriveSchedulerController.confirmSchedule(null, null, null, null, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Missing vehicle/date/time slot should fail with a clear validation error');
    }

    @IsTest
    static void testConfirmScheduleThrowsWithUnrecognizedTimeSlot() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        AF_TestDrive__c td = buildBaseTestDrive(oppId);
        insert td;

        Boolean threw = false;
        Test.startTest();
        try {
            AF_TestDriveSchedulerController.confirmSchedule(td.Id, vehicleId, Date.today().addDays(2), '11:45 PM', 'Main Showroom');
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'A time slot outside the fixed list should be rejected');
    }

    @IsTest
    static void testConfirmScheduleThrowsWithoutLocation() {
        Id vehicleId = testVehicleId();
        Id oppId = testOpportunityId();
        AF_TestDrive__c td = buildBaseTestDrive(oppId);
        insert td;

        Boolean threw = false;
        Test.startTest();
        try {
            AF_TestDriveSchedulerController.confirmSchedule(td.Id, vehicleId, Date.today().addDays(2), '4:00 PM', null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Confirming without a location should fail with a clear validation error');
    }
}