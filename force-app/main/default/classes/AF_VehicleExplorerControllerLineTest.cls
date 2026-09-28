/**
 * Line/trim-selection tests for AF_VehicleExplorerController, split out from
 * AF_VehicleExplorerControllerTest because these need @IsTest(SeeAllData=true)
 * to see the org's pre-existing ProductRelationshipType reference data (e.g.
 * "Parts and Accessories Bundle") — there is no supported way to insert new
 * ProductRelationshipType records from Apex, and a class with a @TestSetup
 * method cannot contain any SeeAllData=true test methods, which
 * AF_VehicleExplorerControllerTest already has.
 */
@IsTest
private class AF_VehicleExplorerControllerLineTest {

    // A fresh Bundle-type model with one grouped Line child. Product2.Type
    // and ConfigureDuringSale are create-only, so both must be set correctly
    // on the very first insert — see alfardan-vehicle-line-selection-feature
    // memory for why (Salesforce won't let either be fixed after the fact).
    private static Product2 createLineTestVehicleModel() {
        Product2 vehicle = new Product2(
            Name = 'AFVFLine Test Vehicle',
            AF_ProductCategory__c = 'Vehicle Model',
            Type = 'Bundle',
            ConfigureDuringSale = 'Allowed'
        );
        insert vehicle;
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = vehicle.Id,
            UnitPrice = 120000,
            IsActive = true
        );

        Product2 line = new Product2(
            Name = 'AFVFLine Test Line - High',
            AF_ProductCategory__c = 'Trim/Line Variant',
            VehicleTrimLevel = 'High Line'
        );
        insert line;
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = line.Id,
            UnitPrice = 5000,
            IsActive = true
        );

        ProductComponentGroup lineGroup = new ProductComponentGroup(
            Name = 'AFVFLine Selection',
            ParentProductId = vehicle.Id,
            MinBundleComponents = 1,
            MaxBundleComponents = 1
        );
        insert lineGroup;

        ProductRelationshipType bundleType = [
            SELECT Id FROM ProductRelationshipType WHERE MainProductRoleCat = 'Bundle' LIMIT 1
        ];
        insert new ProductRelatedComponent(
            ParentProductId = vehicle.Id,
            ChildProductId = line.Id,
            ProductRelationshipTypeId = bundleType.Id,
            ProductComponentGroupId = lineGroup.Id,
            Quantity = 1,
            IsComponentRequired = false,
            IsDefaultComponent = true,
            IsQuantityEditable = false
        );

        return vehicle;
    }

    @IsTest(SeeAllData=true)
    static void testGetLineOptionsForVehicleModelReturnsGroupedLines() {
        Product2 vehicle = createLineTestVehicleModel();

        Test.startTest();
        List<AF_VehicleExplorerController.LineOption> options = AF_VehicleExplorerController.getLineOptionsForVehicleModel(vehicle.Id);
        Test.stopTest();

        System.assertEquals(1, options.size(), 'Should return exactly the one grouped Line child linked to this vehicle');
        System.assertEquals('AFVFLine Test Line - High', options[0].name);
        System.assertEquals('High Line', options[0].trimLevel);
        System.assertEquals(5000, options[0].addOnPrice);
    }

    @IsTest(SeeAllData=true)
    static void testFinalizeVehicleSelectionWithLineCreatesBothLineItems() {
        Product2 vehicle = createLineTestVehicleModel();
        VehicleDefinition vd = new VehicleDefinition(
            Name = 'AFVFLine Test Definition',
            ProductId = vehicle.Id,
            AF_Brand__c = 'Ferrari',
            VariantName = 'Line Test'
        );
        insert vd;

        List<AF_VehicleExplorerController.LineOption> options = AF_VehicleExplorerController.getLineOptionsForVehicleModel(vehicle.Id);
        Id lineProductId = options[0].productId;

        Opportunity opp = new Opportunity(
            Name = 'AFVFLine Test Opportunity - With Line',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        AF_VehicleExplorerController.finalizeVehicleSelection(opp.Id, null, vd.Id, lineProductId);
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [
            SELECT PricebookEntry.Product2.AF_ProductCategory__c, UnitPrice
            FROM OpportunityLineItem
            WHERE OpportunityId = :opp.Id
        ];
        System.assertEquals(2, lineItems.size(), 'Selecting a vehicle with a Line should create exactly two line items: the vehicle and the Line');

        Set<String> categories = new Set<String>();
        for (OpportunityLineItem oli : lineItems) {
            categories.add(oli.PricebookEntry.Product2.AF_ProductCategory__c);
        }
        System.assert(categories.contains('Vehicle Model'), 'Should include the base vehicle model line item');
        System.assert(categories.contains('Trim/Line Variant'), 'Should include the selected Line line item');
    }
}