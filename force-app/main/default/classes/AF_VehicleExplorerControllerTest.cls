@IsTest
private class AF_VehicleExplorerControllerTest {

    @TestSetup
    static void setupData() {
        Product2 model = new Product2(
            Name = 'AFVF Test Model',
            AF_ProductCategory__c = 'Vehicle Model',
            Image_URL__c = 'https://example.com/afvf-test.png'
        );
        insert model;

        // Price is read live off the Standard Price Book Entry (BRD
        // ALF-RS-05), never a synced field, so every test needs a real one.
        insert new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = model.Id,
            UnitPrice = 95000,
            IsActive = true
        );

        VehicleDefinition vd = new VehicleDefinition(
            Name = 'AFVF Test Definition',
            ProductId = model.Id,
            AF_Brand__c = 'Ferrari',
            VariantName = 'Roma',
            BodyType = 'Coupe',
            FuelType = 'Gasoline'
        );
        insert vd;

        List<Asset> assets = new List<Asset>{
            new Asset(Name = 'AFVF Test Asset 1'),
            new Asset(Name = 'AFVF Test Asset 2')
        };
        insert assets;

        List<Vehicle> vehicles = new List<Vehicle>{
            new Vehicle(
                Name = 'AFVF Test Vehicle 1',
                VehicleDefinitionId = vd.Id,
                AssetId = assets[0].Id,
                VehicleIdentificationNumber = 'AFVFTESTVIN00001',
                StockCode = 'AFVF-STK-001',
                ManufacturedDate = Date.newInstance(2024, 3, 1),
                GearBoxType = 'Automatic',
                ExteriorColor = 'Black',
                InteriorColor = 'Beige',
                ConditionType = 'New',
                MarketPrice = 95000,
                AF_InventoryVehicle__c = true,
                AF_InventoryStatus__c = 'In Stock'
            ),
            new Vehicle(
                Name = 'AFVF Test Vehicle 2',
                VehicleDefinitionId = vd.Id,
                AssetId = assets[1].Id,
                VehicleIdentificationNumber = 'AFVFTESTVIN00002',
                StockCode = 'AFVF-STK-002',
                ManufacturedDate = Date.newInstance(2020, 6, 15),
                GearBoxType = 'Manual',
                ExteriorColor = 'White',
                InteriorColor = 'Black',
                ConditionType = 'Running',
                MarketPrice = 65000,
                AF_InventoryVehicle__c = true,
                AF_InventoryStatus__c = 'In Transit'
            )
        };
        insert vehicles;
    }

    @IsTest
    static void testGetVehiclesNoFilters() {
        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result = AF_VehicleExplorerController.getVehicles(null);
        Test.stopTest();

        System.assertNotEquals(null, result, 'Wrapper should not be null');
        System.assert(result.totalCount >= 2, 'Should return at least the two seeded vehicles');
    }

    @IsTest
    static void testGetVehiclesWithFilters() {
        Map<String, Object> filters = new Map<String, Object>{
            'transmissions' => new List<String>{ 'Automatic' },
            'exteriorColors' => new List<String>{ 'Black' },
            'conditionTypes' => new List<String>{ 'New' },
            'inventoryStatuses' => new List<String>{ 'In Stock' },
            'makes' => new List<String>{ 'Ferrari' },
            'models' => new List<String>{ 'Roma' },
            'bodyTypes' => new List<String>{ 'Coupe' },
            'fuelSources' => new List<String>{ 'Gasoline' },
            'minPrice' => 50000,
            'maxPrice' => 100000,
            'minYear' => '2023',
            'maxYear' => '2026',
            'searchTerm' => 'AFVF'
        };

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result =
            AF_VehicleExplorerController.getVehicles(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Only the 2024 automatic vehicle should match this filter combo');
        System.assertEquals('AFVF Test Vehicle 1', result.vehicles[0].Name, 'Should match the 2024 vehicle, not the 2020 one');
    }

    @IsTest
    static void testGetVehiclesYearRangeExcludesOlderVehicle() {
        Map<String, Object> filters = new Map<String, Object>{ 'minYear' => '2023', 'maxYear' => '2026' };

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result =
            AF_VehicleExplorerController.getVehicles(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Year range should exclude the 2020 vehicle');
    }

    @IsTest
    static void testGetVehiclesPriceRangeExcludesModelOutsideRange() {
        Map<String, Object> filters = new Map<String, Object>{ 'minPrice' => 200000, 'maxPrice' => 300000 };

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result =
            AF_VehicleExplorerController.getVehicles(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(0, result.totalCount, 'The seeded model is priced at 95000 — a 200000-300000 range should exclude it entirely');
    }

    @IsTest
    static void testGetVehiclesSearchTermOnly() {
        Map<String, Object> filters = new Map<String, Object>{ 'searchTerm' => 'AFVF-STK-002' };

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result =
            AF_VehicleExplorerController.getVehicles(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Search term should narrow to a single stock code match');
    }

    @IsTest
    static void testGetFilterOptions() {
        Test.startTest();
        AF_VehicleExplorerController.FilterOptions options = AF_VehicleExplorerController.getFilterOptions();
        Test.stopTest();

        System.assertNotEquals(null, options, 'Filter options should not be null');
        System.assertNotEquals(null, options.transmissions, 'Transmission facets should be populated');
        System.assert(options.maxPrice >= options.minPrice, 'Max price should be at least min price');
        System.assertEquals(95000, options.minPrice, 'Price bounds should come from the Standard Price Book Entry');
        System.assertEquals(95000, options.maxPrice, 'Both seeded vehicles share the same model/product, so min and max are equal');
        System.assertEquals(2020, options.minYear, 'Min year should derive from the older seeded vehicle');
        System.assertEquals(2024, options.maxYear, 'Max year should derive from the newer seeded vehicle');

        Boolean foundFerrari = false;
        for (AF_VehicleExplorerController.FacetOption opt : options.makes) {
            if (opt.value == 'Ferrari') {
                foundFerrari = true;
                System.assertEquals(2, opt.count, 'Both seeded vehicles share the same VehicleDefinition/brand');
            }
        }
        System.assert(foundFerrari, 'Ferrari make facet should be present');
    }

    @IsTest
    static void testGetVehiclesForExport() {
        Test.startTest();
        String exportJson = AF_VehicleExplorerController.getVehiclesForExport();
        Test.stopTest();

        System.assertNotEquals(null, exportJson, 'Export JSON should not be null');
        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(exportJson);
        System.assertEquals(2, parsed.size(), 'Export should include both seeded vehicles regardless of UI filter state');

        Map<String, Object> firstRecord = (Map<String, Object>) parsed[0];
        System.assert(firstRecord.containsKey('MarketPrice'), 'Export should include full record fields, not just UI columns');
        System.assert(firstRecord.containsKey('VehicleIdentificationNumber'), 'Export should include full record fields, not just UI columns');
    }

    @IsTest
    static void testGetVehiclesForExportEmptyWhenNoInventoryVehicles() {
        List<Vehicle> vehicles = [SELECT Id, AF_InventoryVehicle__c FROM Vehicle];
        for (Vehicle v : vehicles) {
            v.AF_InventoryVehicle__c = false;
        }
        update vehicles;

        Test.startTest();
        String exportJson = AF_VehicleExplorerController.getVehiclesForExport();
        Test.stopTest();

        List<Object> parsed = (List<Object>) JSON.deserializeUntyped(exportJson);
        System.assertEquals(0, parsed.size(), 'Export should return an empty array, not an error, when there is nothing to export');
    }

    @IsTest
    static void testGetVehicleDefinitionsWithStock() {
        Test.startTest();
        List<AF_VehicleExplorerController.DefinitionCard> cards = AF_VehicleExplorerController.getVehicleDefinitionsWithStock(null);
        Test.stopTest();

        System.assertEquals(1, cards.size(), 'Every regular unit (In Stock and In Transit) belongs to the same definition, so exactly one card should surface');
        System.assertEquals('Ferrari', cards[0].brand);
        System.assertEquals('Roma', cards[0].variantName);
        System.assertEquals(2, cards[0].availableCount, 'Both vehicle 1 (In Stock) and vehicle 2 (In Transit) should count — the definitions list no longer defaults to In Stock only');
        System.assertEquals(95000, cards[0].price, 'Card price should come from the model\'s Standard Price Book Entry, not Vehicle.MarketPrice');
    }

    @IsTest
    static void testGetVehicleDefinitionsWithStockAppliesFilters() {
        Map<String, Object> filters = new Map<String, Object>{ 'makes' => new List<String>{ 'Rolls-Royce' } };

        Test.startTest();
        List<AF_VehicleExplorerController.DefinitionCard> cards =
            AF_VehicleExplorerController.getVehicleDefinitionsWithStock(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(0, cards.size(), 'Filtering to a make with no matching definitions should return no cards, not an error');
    }

    @IsTest
    static void testGetVehiclesScopedToDefinitionRequiringInStockWithVin() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        Map<String, Object> filters = new Map<String, Object>{
            'vehicleDefinitionId' => vd.Id,
            'requireInStockWithVin' => true
        };

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result =
            AF_VehicleExplorerController.getVehicles(JSON.serialize(filters));
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'Scoped to this model + In Stock + VIN should return only vehicle 1');
        System.assertEquals('AFVF Test Vehicle 1', result.vehicles[0].Name);
    }

    // A vehicle held by a Reserved reservation must not surface in the Finder at all —
    // neither in getVehicles nor in the model-level stock count.
    @IsTest
    static void testGetVehiclesExcludesUnitWithActiveReservation() {
        Vehicle v1 = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];
        insert buildReservation(v1.Id, 'Reserved');

        Test.startTest();
        AF_VehicleExplorerController.VehicleDataWrapper result = AF_VehicleExplorerController.getVehicles(null);
        Test.stopTest();

        System.assertEquals(1, result.totalCount, 'The Reserved vehicle should be excluded, leaving only Vehicle 2');
        System.assertEquals('AFVF Test Vehicle 2', result.vehicles[0].Name);
    }

    // Requested, Pending Approval, and Converted are all equally blocking — only
    // Expired/Cancelled should ever release a unit back to the Finder.
    @IsTest
    static void testGetVehiclesExcludesUnitForEveryBlockingReservationStatus() {
        Vehicle v1 = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];

        for (String status : new List<String>{ 'Requested', 'Pending Approval', 'Reserved', 'Converted' }) {
            System.Savepoint sp = Database.setSavepoint();
            insertReservation(v1.Id, status);

            AF_VehicleExplorerController.VehicleDataWrapper result = AF_VehicleExplorerController.getVehicles(null);
            System.assertEquals(1, result.totalCount, 'Status ' + status + ' should block the vehicle from the Finder');
            System.assertEquals('AFVF Test Vehicle 2', result.vehicles[0].Name);

            Database.rollback(sp);
        }
    }

    // Expired and Cancelled reservations must NOT hide the vehicle — it's back in the pool.
    @IsTest
    static void testGetVehiclesIncludesUnitForNonBlockingReservationStatus() {
        Vehicle v1 = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];

        for (String status : new List<String>{ 'Expired', 'Cancelled' }) {
            System.Savepoint sp = Database.setSavepoint();
            insertReservation(v1.Id, status);

            AF_VehicleExplorerController.VehicleDataWrapper result = AF_VehicleExplorerController.getVehicles(null);
            System.assertEquals(2, result.totalCount, 'Status ' + status + ' should NOT block the vehicle from the Finder');

            Database.rollback(sp);
        }
    }

    // The model-level stock count (getVehicleDefinitionsWithStock) must reflect the same
    // reservation-aware exclusion as getVehicles, since it feeds the same Finder.
    @IsTest
    static void testGetVehicleDefinitionsWithStockExcludesReservedUnit() {
        Vehicle v1 = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];
        insert buildReservation(v1.Id, 'Reserved');

        Test.startTest();
        List<AF_VehicleExplorerController.DefinitionCard> cards = AF_VehicleExplorerController.getVehicleDefinitionsWithStock(null);
        Test.stopTest();

        System.assertEquals(1, cards.size(), 'The definition still has one available unit left');
        System.assertEquals(1, cards[0].availableCount, 'Only Vehicle 2 should count — Vehicle 1 is under an active reservation');
    }

    /**
     * AF_VR_Reservation_NoSkipOnInsert blocks creating a reservation directly as Expired,
     * Converted or Cancelled, so those statuses have to be reached by updating a reservation
     * that started in its real initial status.
     */
    private static AF_VehicleReservation__c insertReservation(Id vehicleId, String status) {
        AF_VehicleReservation__c resv = buildReservation(vehicleId, status);
        if (status == 'Expired' || status == 'Converted' || status == 'Cancelled') {
            resv.AF_Status__c = 'Requested';
            insert resv;
            resv.AF_Status__c = status;
            update resv;
        } else {
            insert resv;
        }
        return resv;
    }

    private static AF_VehicleReservation__c buildReservation(Id vehicleId, String status) {
        Account acc = new Account(Name = 'AFVF Reservation Test Account', AF_QID__c = '28812345678');
        insert acc;
        Opportunity opp = new Opportunity(
            Name = 'AFVF Reservation Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        return new AF_VehicleReservation__c(
            AF_Account__c = acc.Id,
            AF_Opportunity__c = opp.Id,
            AF_Vehicle__c = vehicleId,
            AF_ContractType__c = '3-Day (No Deposit)',
            AF_StartDate__c = Date.today(),
            AF_Status__c = status
        );
    }

    @IsTest
    static void testSelectVehicleForOpportunity() {
        Vehicle v = [SELECT Id, VehicleDefinitionId FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = stdPbId
        );
        insert opp;

        Test.startTest();
        AF_VehicleExplorerController.finalizeVehicleSelection(opp.Id, v.Id, v.VehicleDefinitionId, null);
        Test.stopTest();

        Opportunity refreshed = [SELECT AF_SelectedVehicle__c, AF_VehicleModel__c, Pricebook2Id FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(v.Id, refreshed.AF_SelectedVehicle__c, 'Selecting a vehicle should set the Opportunity\'s Selected Vehicle lookup');

        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        System.assertEquals(vd.Id, refreshed.AF_VehicleModel__c, 'Selecting a vehicle should also set the Opportunity\'s Vehicle Model lookup to that vehicle\'s VehicleDefinition');
        System.assertEquals(stdPbId, refreshed.Pricebook2Id, 'Selecting a vehicle should set the Standard Price Book on the Opportunity');

        List<OpportunityLineItem> lineItems = [SELECT PricebookEntry.Product2Id, UnitPrice, Quantity, AF_Vehicle__c FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(1, lineItems.size(), 'Selecting a vehicle should create exactly one line item for the vehicle model');
        System.assertEquals(model.Id, lineItems[0].PricebookEntry.Product2Id, 'Line item should reference the model\'s Product2');
        System.assertEquals(v.Id, lineItems[0].AF_Vehicle__c, 'Line item should reference the specific selected Vehicle unit, not just the model - RS-06\'s VIN sync (AF_FL_QuoteLineItem_SyncVINDisplay) reads this field once the line is copied onto a Quote');
    }

    // Re-selecting a vehicle (finalizeVehicleSelection / syncOpportunityVehicleModelPricing)
    // deletes ALL existing OpportunityLineItems, not just the prior vehicle-model line —
    // an unrelated Accessory line added independently should not survive a vehicle change.
    @IsTest
    static void testSelectVehicleForOpportunityDeletesAllExistingLines() {
        Vehicle v = [SELECT Id, VehicleDefinitionId FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];
        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Opportunity - Full Wipe',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = stdPbId
        );
        insert opp;

        Product2 accessory = new Product2(Name = 'AFVF Test Accessory', AF_ProductCategory__c = 'Accessory', IsActive = true);
        insert accessory;
        PricebookEntry accessoryEntry = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = accessory.Id, UnitPrice = 500, IsActive = true
        );
        insert accessoryEntry;
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = accessoryEntry.Id,
            Quantity = 1,
            UnitPrice = 500,
            AF_LineItemType__c = 'Accessory',
            AF_CustomerFacing__c = true,
            AF_IncludedInQuote__c = true
        );

        Test.startTest();
        AF_VehicleExplorerController.finalizeVehicleSelection(opp.Id, v.Id, v.VehicleDefinitionId, null);
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [SELECT AF_LineItemType__c FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(1, lineItems.size(), 'Re-selecting a vehicle should wipe the pre-existing Accessory line, leaving only the new vehicle-model line');
        System.assertEquals('Vehicle', lineItems[0].AF_LineItemType__c);
    }

    @IsTest
    static void testSyncOpportunityVehicleModelPricingTwoArgOverloadLeavesVehicleBlank() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Opportunity - Two-Arg Overload',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Test.startTest();
        AF_VehicleExplorerController.syncOpportunityVehicleModelPricing(opp.Id, vd.Id);
        Test.stopTest();

        List<OpportunityLineItem> lineItems = [SELECT PricebookEntry.Product2Id, AF_Vehicle__c FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(1, lineItems.size(), 'The two-arg overload should still create the model line item');
        System.assertEquals(model.Id, lineItems[0].PricebookEntry.Product2Id);
        System.assertEquals(null, lineItems[0].AF_Vehicle__c, 'The two-arg overload has no vehicleId parameter to pass, so AF_Vehicle__c should stay blank');
    }

    @IsTest
    static void testResolveVehicleModelProductIdByVehicleAndByDefinition() {
        Vehicle v = [SELECT Id, VehicleDefinitionId FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        Test.startTest();
        Id byVehicle = AF_VehicleExplorerController.resolveVehicleModelProductId(v.Id, null);
        Id byDefinition = AF_VehicleExplorerController.resolveVehicleModelProductId(null, v.VehicleDefinitionId);
        Id byNeither = AF_VehicleExplorerController.resolveVehicleModelProductId(null, null);
        Test.stopTest();

        System.assertEquals(model.Id, byVehicle, 'Resolving by a specific Vehicle should return its model Product2');
        System.assertEquals(model.Id, byDefinition, 'Resolving by a VehicleDefinition directly should return the same model Product2');
        System.assertEquals(null, byNeither, 'Resolving with neither Id given should return null, not throw');
    }

    @IsTest
    static void testGetLineOptionsForVehicleModelEmptyWhenNoGroup() {
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        Test.startTest();
        List<AF_VehicleExplorerController.LineOption> options = AF_VehicleExplorerController.getLineOptionsForVehicleModel(model.Id);
        Test.stopTest();

        System.assertEquals(0, options.size(), 'A model with no ProductComponentGroup-linked Lines should return an empty list, not throw');
    }

    @IsTest
    static void testProceedWithoutVehicle() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];
        Vehicle v = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];

        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Opportunity - Proceed Without Vehicle',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = stdPbId,
            AF_SelectedVehicle__c = v.Id
        );
        insert opp;

        Test.startTest();
        AF_VehicleExplorerController.finalizeVehicleSelection(opp.Id, null, vd.Id, null);
        Test.stopTest();

        Opportunity refreshed = [SELECT AF_SelectedVehicle__c, AF_VehicleModel__c, Pricebook2Id FROM Opportunity WHERE Id = :opp.Id];
        System.assertEquals(vd.Id, refreshed.AF_VehicleModel__c, 'Proceeding without a vehicle should still set the Vehicle Model lookup');
        System.assertEquals(null, refreshed.AF_SelectedVehicle__c, 'Proceeding without a vehicle should clear any previously selected specific Vehicle');
        System.assertEquals(stdPbId, refreshed.Pricebook2Id, 'Should still set the Standard Price Book on the Opportunity');

        List<OpportunityLineItem> lineItems = [SELECT PricebookEntry.Product2Id, AF_Vehicle__c FROM OpportunityLineItem WHERE OpportunityId = :opp.Id];
        System.assertEquals(1, lineItems.size(), 'Should still create the model line item even without a specific vehicle unit');
        System.assertEquals(model.Id, lineItems[0].PricebookEntry.Product2Id);
        System.assertEquals(null, lineItems[0].AF_Vehicle__c, 'No specific Vehicle unit was chosen, so the line item should have no AF_Vehicle__c');
    }

    @IsTest
    static void testSelectVehicleForOpportunityThrowsWithoutStandardPriceBookEntry() {
        // A separate model with no Standard Price Book Entry at all — the
        // shared 'AFVF Test Model' from @TestSetup always has one now.
        Product2 modelWithNoPricing = new Product2(Name = 'AFVF No-Price Model', AF_ProductCategory__c = 'Vehicle Model');
        insert modelWithNoPricing;
        VehicleDefinition vdWithNoPricing = new VehicleDefinition(
            Name = 'AFVF No-Price Definition',
            ProductId = modelWithNoPricing.Id,
            AF_Brand__c = 'Ferrari',
            VariantName = 'Testarossa'
        );
        insert vdWithNoPricing;
        Asset asset = new Asset(Name = 'AFVF No-Price Asset');
        insert asset;
        Vehicle v = new Vehicle(
            Name = 'AFVF No-Price Vehicle',
            VehicleDefinitionId = vdWithNoPricing.Id,
            AssetId = asset.Id,
            VehicleIdentificationNumber = 'AFVFNOPRICEVIN001',
            AF_InventoryVehicle__c = true,
            AF_InventoryStatus__c = 'In Stock'
        );
        insert v;

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Opportunity - No PBE',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Boolean threw = false;
        Test.startTest();
        try {
            AF_VehicleExplorerController.finalizeVehicleSelection(opp.Id, v.Id, vdWithNoPricing.Id, null);
        } catch (AuraHandledException e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'Selecting a vehicle whose model has no Standard Price Book Entry should fail loudly, not silently skip pricing');
    }

    @IsTest
    static void testGetVehicleMediaReturnsVehiclesOwnFile() {
        Vehicle v = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 1' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'AFVF Vehicle Photo',
            PathOnClient = 'afvf-vehicle-photo.png',
            VersionData = Blob.valueOf('fake image bytes'),
            ContentLocation = 'S'
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = v.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<AF_VehicleExplorerController.MediaItem> media = AF_VehicleExplorerController.getVehicleMedia(v.Id);
        Test.stopTest();

        System.assertEquals(1, media.size(), 'Should return the one File linked directly to the vehicle');
        System.assertEquals(true, media[0].isImage);
        System.assert(media[0].thumbnailUrl.contains('renditionDownload'));
    }

    @IsTest
    static void testGetVehicleMediaFallsBackToModelFile() {
        Vehicle v = [SELECT Id FROM Vehicle WHERE Name = 'AFVF Test Vehicle 2' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'AFVF Model Brochure',
            PathOnClient = 'afvf-model-brochure.pdf',
            VersionData = Blob.valueOf('fake pdf bytes'),
            ContentLocation = 'S'
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];
        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = model.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<AF_VehicleExplorerController.MediaItem> media = AF_VehicleExplorerController.getVehicleMedia(v.Id);
        Test.stopTest();

        System.assertEquals(1, media.size(), 'Vehicle has no Files of its own, should fall back to the model/catalog Files');
        System.assertEquals(false, media[0].isImage);
        System.assert(media[0].fullUrl.contains('/sfc/servlet.shepherd/version/download/'));
    }

    @IsTest
    static void testGetVehicleMediaNullIdReturnsEmpty() {
        Test.startTest();
        List<AF_VehicleExplorerController.MediaItem> media = AF_VehicleExplorerController.getVehicleMedia(null);
        Test.stopTest();

        System.assertEquals(0, media.size());
    }

    // Bulk-safety check for syncOpportunityVehicleModelPricingBulk, added when
    // AF_LeadConversionService was refactored to call it once per conversion batch instead of
    // looping the single-Opportunity version once per Opportunity. 200 Opportunities in one call
    // must not exceed governor limits (one query/DML statement per object type, not per Opportunity).
    @IsTest
    static void testSyncOpportunityVehicleModelPricingBulkHandles200Opportunities() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVF Test Model' LIMIT 1];

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opps.add(new Opportunity(
                Name = 'AFVF Bulk Pricing Opp ' + i,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30)
            ));
        }
        insert opps;

        Map<Id, Id> vehicleDefinitionIdByOppId = new Map<Id, Id>();
        for (Opportunity opp : opps) {
            vehicleDefinitionIdByOppId.put(opp.Id, vd.Id);
        }

        Test.startTest();
        AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk(vehicleDefinitionIdByOppId);
        Test.stopTest();

        List<Opportunity> refreshed = [SELECT Id, Pricebook2Id FROM Opportunity WHERE Id IN :vehicleDefinitionIdByOppId.keySet()];
        for (Opportunity opp : refreshed) {
            System.assertEquals(Test.getStandardPricebookId(), opp.Pricebook2Id, 'Every Opportunity in the batch should get the Standard Price Book');
        }

        Map<Id, Integer> lineItemCountByOppId = new Map<Id, Integer>();
        for (OpportunityLineItem li : [
            SELECT OpportunityId, PricebookEntry.Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :vehicleDefinitionIdByOppId.keySet()
        ]) {
            System.assertEquals(model.Id, li.PricebookEntry.Product2Id, 'Line item should reference the model\'s Product2');
            Integer count = lineItemCountByOppId.containsKey(li.OpportunityId) ? lineItemCountByOppId.get(li.OpportunityId) : 0;
            lineItemCountByOppId.put(li.OpportunityId, count + 1);
        }
        System.assertEquals(200, lineItemCountByOppId.size(), 'Every one of the 200 Opportunities should get exactly one line item');
        for (Integer count : lineItemCountByOppId.values()) {
            System.assertEquals(1, count, 'Each Opportunity should get exactly one vehicle-model line item, not duplicates');
        }
    }

    // getTestDriveOpportunityVehicleScope should return both the Opportunity's Brand AND its
    // selected Vehicle Model, so the demo picker can scope to that specific model, not just brand.
    @IsTest
    static void testGetTestDriveOpportunityVehicleScopeReturnsBrandAndModel() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];

        Opportunity opp = new Opportunity(
            Name = 'AFVF Test Drive Scope Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari',
            AF_VehicleModel__c = vd.Id
        );
        insert opp;

        AF_TestDrive__c td = new AF_TestDrive__c(
            AF_Opportunity__c = opp.Id,
            AF_Status__c = 'Requested'
        );
        insert td;

        Test.startTest();
        AF_VehicleExplorerController.TestDriveVehicleScope scope =
            AF_VehicleExplorerController.getTestDriveOpportunityVehicleScope(td.Id);
        Test.stopTest();

        System.assertEquals('Ferrari', scope.brand, 'Should resolve the brand off the Test Drive\'s Opportunity');
        System.assertEquals(vd.Id, scope.vehicleDefinitionId, 'Should resolve the Opportunity\'s own selected Vehicle Model');
    }

    @IsTest
    static void testGetTestDriveOpportunityVehicleScopeNullTestDriveIdReturnsEmptyScope() {
        Test.startTest();
        AF_VehicleExplorerController.TestDriveVehicleScope scope =
            AF_VehicleExplorerController.getTestDriveOpportunityVehicleScope(null);
        Test.stopTest();

        System.assertEquals(null, scope.brand);
        System.assertEquals(null, scope.vehicleDefinitionId);
    }

    // The vehicleIdByOppId overload should stamp AF_Vehicle__c on the bulk-created line item,
    // mirroring the single-Opportunity vehicleId overload's fix — this is what
    // AF_FL_QuoteLineItem_SyncVINDisplay / AF_FL_Vehicle_SyncVINOnRestock read downstream, so a
    // Lead converted with a specific Vehicle unit already selected must carry that link forward.
    @IsTest
    static void testSyncOpportunityVehicleModelPricingBulkStampsSelectedVehicle() {
        VehicleDefinition vd = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];
        Vehicle selectedVehicle = [SELECT Id FROM Vehicle WHERE VehicleIdentificationNumber = 'AFVFTESTVIN00001' LIMIT 1];

        Opportunity oppWithVehicle = new Opportunity(Name = 'AFVF Bulk Vehicle Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        Opportunity oppWithoutVehicle = new Opportunity(Name = 'AFVF Bulk Model-Only Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert new List<Opportunity>{ oppWithVehicle, oppWithoutVehicle };

        Map<Id, Id> vehicleDefinitionIdByOppId = new Map<Id, Id>{
            oppWithVehicle.Id => vd.Id,
            oppWithoutVehicle.Id => vd.Id
        };
        Map<Id, Id> vehicleIdByOppId = new Map<Id, Id>{
            oppWithVehicle.Id => selectedVehicle.Id
        };

        Test.startTest();
        AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk(vehicleDefinitionIdByOppId, vehicleIdByOppId);
        Test.stopTest();

        OpportunityLineItem lineWithVehicle = [SELECT AF_Vehicle__c FROM OpportunityLineItem WHERE OpportunityId = :oppWithVehicle.Id LIMIT 1];
        System.assertEquals(selectedVehicle.Id, lineWithVehicle.AF_Vehicle__c, 'The line item should carry the specific Vehicle unit selected on the source Lead');

        OpportunityLineItem lineWithoutVehicle = [SELECT AF_Vehicle__c FROM OpportunityLineItem WHERE OpportunityId = :oppWithoutVehicle.Id LIMIT 1];
        System.assertEquals(null, lineWithoutVehicle.AF_Vehicle__c, 'An Opportunity absent from vehicleIdByOppId (model-only Lead) should be unaffected');
    }

    // A model with no Standard Price Book Entry should be skipped (logged, not thrown) without
    // affecting the rest of the batch — the bulk method's best-effort contract.
    @IsTest
    static void testSyncOpportunityVehicleModelPricingBulkSkipsModelWithNoPricebookEntry() {
        VehicleDefinition vdWithPricing = [SELECT Id FROM VehicleDefinition WHERE Name = 'AFVF Test Definition' LIMIT 1];

        Product2 modelWithNoPricing = new Product2(Name = 'AFVF Bulk No-Price Model', AF_ProductCategory__c = 'Vehicle Model');
        insert modelWithNoPricing;
        VehicleDefinition vdWithNoPricing = new VehicleDefinition(
            Name = 'AFVF Bulk No-Price Definition',
            ProductId = modelWithNoPricing.Id,
            AF_Brand__c = 'Ferrari',
            VariantName = 'Testarossa'
        );
        insert vdWithNoPricing;

        Opportunity oppWithPricing = new Opportunity(Name = 'AFVF Bulk Priced Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        Opportunity oppWithoutPricing = new Opportunity(Name = 'AFVF Bulk Unpriced Opp', StageName = 'Prospecting', CloseDate = Date.today().addDays(30));
        insert new List<Opportunity>{ oppWithPricing, oppWithoutPricing };

        Map<Id, Id> vehicleDefinitionIdByOppId = new Map<Id, Id>{
            oppWithPricing.Id => vdWithPricing.Id,
            oppWithoutPricing.Id => vdWithNoPricing.Id
        };

        Test.startTest();
        AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk(vehicleDefinitionIdByOppId);
        Test.stopTest();

        System.assertEquals(
            1,
            [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppWithPricing.Id],
            'The Opportunity whose model has pricing should still get its line item'
        );
        System.assertEquals(
            0,
            [SELECT COUNT() FROM OpportunityLineItem WHERE OpportunityId = :oppWithoutPricing.Id],
            'The Opportunity whose model has no Price Book Entry should be skipped, not error out or block the batch'
        );
    }
}