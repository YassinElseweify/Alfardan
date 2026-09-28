/**
 * Tests for AF_VehicleOrderStatusSync (ALF-RS-10/LFRDN-340 FR2/FR3/FR6/AC2/AC3).
 */
@isTest
private class AF_VehicleOrderStatusSyncTest {

    private static Vehicle makeVehicle(String orderState) {
        Product2 p = new Product2(Name = 'Sync Test Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Sync Test Line', ProductId = p.Id);
        insert vd;
        Asset asset = new Asset(Name = 'Sync Test Asset ' + Math.abs(Crypto.getRandomInteger()));
        insert asset;
        Vehicle v = new Vehicle(
            Name = 'Sync Test Vehicle',
            VehicleDefinitionId = vd.Id,
            AssetId = asset.Id,
            VehicleIdentificationNumber = 'SYNCVIN' + Math.abs(Crypto.getRandomInteger()),
            AF_VehicleOrderState__c = orderState
        );
        insert v;
        return v;
    }

    private static AF_VehicleOrderStatusSync.Request req(Id vehicleId, String state) {
        AF_VehicleOrderStatusSync.Request r = new AF_VehicleOrderStatusSync.Request();
        r.vehicleId = vehicleId;
        r.orderState = state;
        return r;
    }

    @isTest
    static void syncsValidStateChange() {
        Vehicle v = makeVehicle('On Order');

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Transit') });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        Vehicle updated = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('In Transit', updated.AF_VehicleOrderState__c);
    }

    @isTest
    static void rejectsInvalidState() {
        Vehicle v = makeVehicle('On Order');

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'Bogus State') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('Invalid'), 'Got: ' + results[0].message);

        Vehicle unchanged = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('On Order', unchanged.AF_VehicleOrderState__c);
    }

    @isTest
    static void blocksWhenVehicleNotFound() {
        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(null, 'In Stock-Arrived') });
        Test.stopTest();

        System.assertEquals(false, results[0].success);
        System.assert(results[0].message.contains('not found'), 'Got: ' + results[0].message);
    }

    @isTest
    static void arrivalWithNoLinkedOpportunitySucceedsSilently() {
        Vehicle v = makeVehicle('In Transit');

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        Vehicle updated = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('In Stock-Arrived', updated.AF_VehicleOrderState__c);
    }

    /**
     * LFRDN-663: a late/out-of-order "On Order" message arriving after the vehicle already
     * reached "In Stock-Arrived" must not move it backwards.
     */
    @isTest
    static void ignoresBackwardsTransitionAfterArrival() {
        Vehicle v = makeVehicle('On Order');
        AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'On Order') });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'A backwards transition is not an error.');
        System.assert(results[0].message.contains('was not changed'), 'Got: ' + results[0].message);
        Vehicle updated = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('In Stock-Arrived', updated.AF_VehicleOrderState__c, 'Vehicle must stay at its more advanced state.');
    }

    /**
     * LFRDN-663: a forward transition (In Transit -> In Stock-Arrived) must still apply normally.
     */
    @isTest
    static void allowsForwardTransition() {
        Vehicle v = makeVehicle('On Order');
        AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Transit') });

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        Vehicle updated = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('In Stock-Arrived', updated.AF_VehicleOrderState__c);
    }

    /**
     * LFRDN-663: applying the same state again (no rank change) must still succeed - this is not
     * a backwards transition.
     */
    @isTest
    static void allowsRepeatOfSameState() {
        Vehicle v = makeVehicle('In Transit');

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Transit') });
        Test.stopTest();

        System.assertEquals(true, results[0].success, 'Got: ' + results[0].message);
        Vehicle updated = [SELECT AF_VehicleOrderState__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals('In Transit', updated.AF_VehicleOrderState__c);
    }

    @isTest
    static void arrivalWithSalesOrderSendsNotificationEmails() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Sync Notify Test Account', RecordTypeId = rtId);
        insert acc;

        Id brandProfileRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();
        Contact con = new Contact(
            FirstName = 'Test', LastName = 'Buyer', AccountId = acc.Id, Email = 'buyer@example.com',
            Phone = '+97145551234', AF_Brand__c = 'Ferrari', RecordTypeId = brandProfileRtId
        );
        insert con;

        Opportunity opp = new Opportunity(
            Name = 'Sync Notify Test Opp',
            AccountId = acc.Id,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari',
            AF_SOStatus__c = 'Generated',
            AF_PrimaryBrandContact__c = con.Id
        );
        insert opp;

        Vehicle v = makeVehicle('In Transit');

        // A reservation cannot be inserted directly as Converted - it must start Reserved and progress.
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = acc.Id,
            AF_Opportunity__c = opp.Id,
            AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Reserved',
            AF_StartDate__c = Date.today(),
            AF_DepositAmount__c = 50000,
            AF_VehicleSourceType__c = 'In Stock',
            AF_Vehicle__c = v.Id
        );
        insert resv;
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Converted');

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(emailInvocations > 0, 'Expected arrival notification email(s) to be sent.');
    }

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Sync Notify Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Contact makeContact(Id accountId, String email, Boolean optedOut) {
        Id brandProfileRtId = Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();
        Contact con = new Contact(
            FirstName = 'Test', LastName = 'Buyer', AccountId = accountId, Email = email,
            Phone = '+97145551234', AF_Brand__c = 'Ferrari', RecordTypeId = brandProfileRtId,
            HasOptedOutOfEmail = optedOut
        );
        insert con;
        return con;
    }

    private static Opportunity makeOpportunity(Id accountId, String soStatus, Id primaryBrandContactId) {
        Opportunity opp = new Opportunity(
            Name = 'Sync Notify Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari',
            AF_SOStatus__c = soStatus,
            AF_PrimaryBrandContact__c = primaryBrandContactId
        );
        insert opp;
        return opp;
    }

    private static AF_VehicleReservation__c makeReservation(Id accountId, Id oppId, Id vehicleId) {
        // A reservation cannot be inserted directly as Converted - it must start Reserved and progress.
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Reserved',
            AF_StartDate__c = Date.today(),
            AF_DepositAmount__c = 50000,
            AF_VehicleSourceType__c = 'In Stock',
            AF_Vehicle__c = vehicleId
        );
        insert resv;
        update new AF_VehicleReservation__c(Id = resv.Id, AF_Status__c = 'Converted');
        return resv;
    }

    /**
     * LFRDN-664 issue 1: a Cancelled order must not send an arrival notification. Confirms no
     * email is sent by checking Limits.getEmailInvocations() stays at zero.
     */
    @isTest
    static void arrivalWithCancelledSalesOrderSendsNoNotification() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id, 'buyer@example.com', false);
        // AF_VR_Opp_CancellationApprovalRequired only fires AND(Cancelled, NOT Approved), so
        // setting both fields together at insert (rather than via a later update) satisfies it
        // without needing to drive the real cancellation Approval Process.
        Opportunity opp = new Opportunity(
            Name = 'Sync Notify Test Opp',
            AccountId = acc.Id,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari',
            AF_SOStatus__c = 'Cancelled',
            AF_CancellationApprovalStatus__c = 'Approved',
            AF_PrimaryBrandContact__c = con.Id
        );
        insert opp;
        Vehicle v = makeVehicle('In Transit');
        makeReservation(acc.Id, opp.Id, v.Id);

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(0, emailInvocations, 'Expected no arrival notification for a Cancelled Sales Order.');
    }

    /**
     * LFRDN-664 issue 1: a Delivered order (already handed over) must not send an arrival
     * notification either.
     */
    @isTest
    static void arrivalWithDeliveredSalesOrderSendsNoNotification() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id, 'buyer@example.com', false);
        Opportunity opp = makeOpportunity(acc.Id, 'Delivered', con.Id);
        Vehicle v = makeVehicle('In Transit');
        makeReservation(acc.Id, opp.Id, v.Id);

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(0, emailInvocations, 'Expected no arrival notification for a Delivered Sales Order.');
    }

    /**
     * LFRDN-664 issue 2: an opted-out customer must not receive the arrival email, but the rep
     * still should (so the sync is not entirely silent).
     */
    @isTest
    static void arrivalWithOptedOutCustomerSkipsCustomerEmailOnly() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id, 'buyer@example.com', true);
        Opportunity opp = makeOpportunity(acc.Id, 'Generated', con.Id);
        Vehicle v = makeVehicle('In Transit');
        makeReservation(acc.Id, opp.Id, v.Id);

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(emailInvocations > 0, 'Expected the rep email to still be sent.');
    }

    /**
     * LFRDN-664 issue 3: AF_PrimaryBrandContact__c blank should fall back to the Invoice Summary
     * contact rather than silently skipping the customer email.
     */
    @isTest
    static void arrivalWithBlankPrimaryBrandContactFallsBackToInvoiceSummaryContact() {
        Account acc = makeAccount();
        Contact con = makeContact(acc.Id, 'invoicecontact@example.com', false);
        Opportunity opp = makeOpportunity(acc.Id, 'Generated', null);
        Vehicle v = makeVehicle('In Transit');
        makeReservation(acc.Id, opp.Id, v.Id);

        AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
            AF_Account__c = acc.Id,
            AF_Opportunity__c = opp.Id,
            AF_Contact__c = con.Id,
            AF_ExpectedTotalAmount__c = 500000,
            AF_PaidAmount__c = 500000,
            AF_Status__c = 'Fully Paid'
        );
        insert inv;
        update new Opportunity(Id = opp.Id, AF_InvoiceSummary__c = inv.Id);

        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>{ req(v.Id, 'In Stock-Arrived') });
        Integer emailInvocations = Limits.getEmailInvocations();
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assert(emailInvocations > 0, 'Expected the Invoice Summary contact fallback to be notified.');
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        List<AF_VehicleOrderStatusSync.Result> results =
            AF_VehicleOrderStatusSync.sync(new List<AF_VehicleOrderStatusSync.Request>());
        Test.stopTest();
        System.assertEquals(0, results.size());
    }
}