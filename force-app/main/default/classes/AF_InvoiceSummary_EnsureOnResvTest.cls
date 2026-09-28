/**
 * Tests for AF_InvoiceSummary_EnsureOnResv (ALF-RS-09 FR1/FR3).
 */
@isTest
private class AF_InvoiceSummary_EnsureOnResvTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Invoice Summary Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Invoice Summary Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static VehicleDefinition makeVehicleDefinition() {
        Product2 p = new Product2(Name = 'Invoice Test Model Line Product', IsActive = true, AF_ProductCategory__c = 'Vehicle Model');
        insert p;
        VehicleDefinition vd = new VehicleDefinition(Name = 'Invoice Test Model Line', ProductId = p.Id);
        insert vd;
        return vd;
    }

    private static AF_VehicleReservation__c makeReservation(Id accountId, Id oppId, Id vdId, Decimal priceTotal) {
        AF_VehicleReservation__c resv = new AF_VehicleReservation__c(
            AF_Account__c = accountId,
            AF_Opportunity__c = oppId,
            AF_ContractType__c = '7-Day (Deposit)',
            AF_Status__c = 'Reserved',
            AF_StartDate__c = Date.today(),
            AF_DepositAmount__c = 100000,
            AF_RequiredDocumentsComplete__c = true,
            AF_VehiclePriceTotal__c = priceTotal,
            AF_VehicleDefinition__c = vdId,
            AF_VehicleSourceType__c = 'Pre-Order (Placeholder)'
        );
        insert resv;
        return resv;
    }

    @isTest
    static void createsInvoiceSummaryWhenNoneExists() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, vd.Id, 500000);

        AF_InvoiceSummary_EnsureOnResv.Request req = new AF_InvoiceSummary_EnsureOnResv.Request();
        req.reservationId = resv.Id;

        Test.startTest();
        AF_InvoiceSummary_EnsureOnResv.ensure(new List<AF_InvoiceSummary_EnsureOnResv.Request>{ req });
        Test.stopTest();

        Opportunity reloaded = [SELECT AF_InvoiceSummary__c, AF_InvoiceBalance__c FROM Opportunity WHERE Id = :opp.Id];
        System.assertNotEquals(null, reloaded.AF_InvoiceSummary__c, 'Invoice Summary should have been created.');
        System.assertEquals(500000, reloaded.AF_InvoiceBalance__c);

        AF_InvoiceSummary__c inv = [
            SELECT AF_ExpectedTotalAmount__c, AF_PaidAmount__c, AF_Balance__c, AF_Status__c, AF_LegalInvoice__c
            FROM AF_InvoiceSummary__c WHERE Id = :reloaded.AF_InvoiceSummary__c
        ];
        System.assertEquals(500000, inv.AF_ExpectedTotalAmount__c);
        System.assertEquals(0, inv.AF_PaidAmount__c);
        System.assertEquals(500000, inv.AF_Balance__c);
        System.assertEquals('Unpaid', inv.AF_Status__c);
        System.assertEquals(false, inv.AF_LegalInvoice__c);
    }

    @isTest
    static void doesNotDuplicateWhenInvoiceSummaryAlreadyExists() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        VehicleDefinition vd = makeVehicleDefinition();
        AF_VehicleReservation__c resv = makeReservation(acc.Id, opp.Id, vd.Id, 500000);

        // The reservation above is created in an approved status, so in orgs where the
        // AF_FL_Reservation_Approved record-triggered flow is active it has already produced the
        // Invoice Summary for this Opportunity. Reuse that one when it exists instead of
        // inserting a second one here, so this test asserts the guard in ensure() rather than
        // the presence or absence of that flow.
        List<AF_InvoiceSummary__c> alreadyThere = [
            SELECT Id FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id LIMIT 1
        ];
        AF_InvoiceSummary__c existing;
        if (alreadyThere.isEmpty()) {
            existing = new AF_InvoiceSummary__c(
                AF_Account__c = acc.Id,
                AF_Opportunity__c = opp.Id,
                AF_ExpectedTotalAmount__c = 500000,
                AF_PaidAmount__c = 0,
                AF_Balance__c = 500000,
                AF_Status__c = 'Unpaid'
            );
            insert existing;
        } else {
            existing = alreadyThere[0];
        }
        update new Opportunity(Id = opp.Id, AF_InvoiceSummary__c = existing.Id);

        AF_InvoiceSummary_EnsureOnResv.Request req = new AF_InvoiceSummary_EnsureOnResv.Request();
        req.reservationId = resv.Id;

        Test.startTest();
        AF_InvoiceSummary_EnsureOnResv.ensure(new List<AF_InvoiceSummary_EnsureOnResv.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = :opp.Id],
            'A second Invoice Summary should never be created for the same Opportunity.');
    }

    @isTest
    static void handlesEmptyInput() {
        Test.startTest();
        AF_InvoiceSummary_EnsureOnResv.ensure(new List<AF_InvoiceSummary_EnsureOnResv.Request>());
        Test.stopTest();
        System.assertEquals(0, [SELECT COUNT() FROM AF_InvoiceSummary__c]);
    }
}