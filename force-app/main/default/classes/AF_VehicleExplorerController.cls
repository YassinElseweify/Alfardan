/**
 * Controller for the AL Fardan Vehicle Finder (afVehicleExplorer LWC suite).
 * Serves filterable inventory vehicle data and the filter option lists/facet
 * counts/ranges that drive the finder's UI.
 *
 * Field sourcing note: Vehicle.MakeName/ModelName/ModelYear/Classification/FuelSource
 * describe as writable text/picklist fields but are, in this org, populated only by
 * the platform (empirically confirmed: even a fully-populated VehicleDefinition
 * linked via VehicleDefinitionId leaves them null on insert — presumably reserved
 * for the future Keyloop feed sync). So Make/Model/Body Type/Fuel Type here read from
 * the real writable spec-catalog fields on VehicleDefinition instead
 * (AF_Brand__c/VariantName/BodyType/FuelType), and Year is derived from the writable
 * Vehicle.ManufacturedDate. Everything else (price, color, transmission, condition,
 * inventory status, VIN/stock) is a genuine Vehicle-instance field and stays on Vehicle.
 */
public with sharing class AF_VehicleExplorerController {

    public class VehicleDataWrapper {
        @AuraEnabled public List<Vehicle> vehicles { get; set; }
        @AuraEnabled public Integer totalCount { get; set; }

        public VehicleDataWrapper() {
            this.vehicles = new List<Vehicle>();
            this.totalCount = 0;
        }
    }

    public class FacetOption {
        @AuraEnabled public String label;
        @AuraEnabled public String value;
        @AuraEnabled public Integer count;

        public FacetOption(String label, String value, Integer count) {
            this.label = label;
            this.value = value;
            this.count = count;
        }
    }

    public class DefinitionCard {
        @AuraEnabled public Id id;
        @AuraEnabled public Id productId;
        @AuraEnabled public String brand;
        @AuraEnabled public String variantName;
        @AuraEnabled public String bodyType;
        @AuraEnabled public String fuelType;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public Integer availableCount;
        @AuraEnabled public Decimal price;
    }

    public class MediaItem {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Boolean isImage;
        @AuraEnabled public String thumbnailUrl;
        @AuraEnabled public String fullUrl;
    }

    // One selectable Line/trim variant (e.g. "High Line") for the vehicle
    // model the agent just chose — surfaced by getLineOptionsForVehicleModel
    // so the picker can show a required "choose your Line" step whenever the
    // model's Product2 has any (via ProductRelatedComponent, Accessories/Parts
    // Bundle relationship, grouped so exactly one is selectable).
    public class LineOption {
        @AuraEnabled public Id productId;
        @AuraEnabled public String name;
        @AuraEnabled public String trimLevel;
        @AuraEnabled public Decimal addOnPrice;
        @AuraEnabled public Boolean isDefault;
    }

    public class FilterOptions {
        @AuraEnabled public List<FacetOption> makes { get; set; }
        @AuraEnabled public List<FacetOption> models { get; set; }
        @AuraEnabled public List<FacetOption> bodyTypes { get; set; }
        @AuraEnabled public List<FacetOption> exteriorColors { get; set; }
        @AuraEnabled public List<FacetOption> transmissions { get; set; }
        @AuraEnabled public List<FacetOption> fuelSources { get; set; }
        @AuraEnabled public List<FacetOption> conditionTypes { get; set; }
        @AuraEnabled public List<FacetOption> inventoryStatuses { get; set; }
        @AuraEnabled public List<FacetOption> locations { get; set; }
        @AuraEnabled public Decimal minPrice { get; set; }
        @AuraEnabled public Decimal maxPrice { get; set; }
        @AuraEnabled public Integer minYear { get; set; }
        @AuraEnabled public Integer maxYear { get; set; }
    }

    private static final String MAKE_FIELD = 'VehicleDefinition.AF_Brand__c';
    private static final String MODEL_FIELD = 'VehicleDefinition.VariantName';
    private static final String BODY_TYPE_FIELD = 'VehicleDefinition.BodyType';
    private static final String FUEL_FIELD = 'VehicleDefinition.FuelType';

    // Price is never read off Vehicle here (MarketPrice is a per-unit field
    // and BRD ALF-RS-05 wants one catalog price per model). Every unit's
    // price comes from its model's Product2 entry on the org's Standard
    // Price Book, resolved live via PricebookEntry (getStandardPriceByProductId)
    // rather than a synced copy field — the client gets it once per model
    // (DefinitionCard.price) and passes it down to every vehicle card in
    // that model's list, since price is constant within one model.
    private static final String BASE_QUERY_FIELDS =
        'SELECT Id, Name, ManufacturedDate, ExteriorColor, InteriorColor, GearBoxType, ConditionType, ' +
        'AF_InventoryStatus__c, AF_InventoryVehicle__c, AF_Colour__c, AF_Location__c, StockCode, ' +
        'AF_ThumbnailLink__c, VehicleIdentificationNumber, VehicleDefinition.Name, VehicleDefinition.AF_Brand__c, ' +
        'VehicleDefinition.VariantName, VehicleDefinition.BodyType, VehicleDefinition.FuelType, ' +
        'VehicleDefinition.ProductId, VehicleDefinition.Product.AF_ThumbnailLink__c, VehicleDefinition.Product.Image_URL__c ' +
        'FROM Vehicle';

    @AuraEnabled(cacheable=true)
    public static VehicleDataWrapper getVehicles(String filterJson) {
        try {
            VehicleDataWrapper wrapper = new VehicleDataWrapper();

            Map<String, Object> filters = new Map<String, Object>();
            if (String.isNotBlank(filterJson)) {
                filters = (Map<String, Object>) JSON.deserializeUntyped(filterJson);
            }

            String whereClause = buildDynamicWhereClause(filters);
            String query = BASE_QUERY_FIELDS + whereClause +
                ' WITH USER_MODE ORDER BY ManufacturedDate DESC, VehicleDefinition.AF_Brand__c ASC LIMIT 1000';

            wrapper.vehicles = Database.query(query);
            wrapper.totalCount = wrapper.vehicles.size();

            return wrapper;
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error retrieving vehicles: ' + e.getMessage());
            aex.setMessage('Error retrieving vehicles: ' + e.getMessage());
            throw aex;
        }
    }

    /**
     * Model-level cards for the Finder's first browse level: one row per
     * VehicleDefinition that has at least one available unit (In Stock + VIN
     * present), with a count of how many. Accepts the same filterJson shape as
     * getVehicles (makes/bodyTypes/fuelSources/price/year/search/etc.) so the
     * filter sidebar can narrow which MODELS show, not just which vehicles show
     * within an already-selected model. Aliases every selected field —
     * AggregateResult.get() on a raw relationship-dotted path is unreliable
     * (same gotcha already worked around in getFacetCounts below).
     */
    @AuraEnabled(cacheable=true)
    public static List<DefinitionCard> getVehicleDefinitionsWithStock(String filterJson) {
        try {
            List<DefinitionCard> cards = new List<DefinitionCard>();

            Map<String, Object> filters = new Map<String, Object>();
            if (String.isNotBlank(filterJson)) {
                filters = (Map<String, Object>) JSON.deserializeUntyped(filterJson);
            }
            // Definitions listing shows every regular vehicle unit regardless of
            // Inventory Status (In Stock, In Transit, Ordered) — a rep on the
            // Opportunity picker should see the full brand-scoped inventory by
            // default, not just In Stock units, since Inventory Status is itself
            // one of the available filters (checkbox list) rather than a forced
            // default. REMOVED 2026-09-10: this used to force
            // requireInStockWithVin=true unless demoOnly or an explicit status
            // filter was already chosen, which hid In Transit/Ordered vehicles
            // from the default view entirely.
            String whereClause = buildDynamicWhereClause(filters) + ' AND VehicleDefinitionId != null';

            String query = 'SELECT VehicleDefinitionId defId, VehicleDefinition.ProductId productId, ' +
                'VehicleDefinition.AF_Brand__c brand, VehicleDefinition.VariantName variantName, ' +
                'VehicleDefinition.BodyType bodyType, VehicleDefinition.FuelType fuelType, ' +
                'VehicleDefinition.Product.AF_ThumbnailLink__c thumbnailLink, ' +
                'VehicleDefinition.Product.Image_URL__c imageUrl, COUNT(Id) availableCount ' +
                'FROM Vehicle' + whereClause + ' WITH USER_MODE ' +
                'GROUP BY VehicleDefinitionId, VehicleDefinition.ProductId, VehicleDefinition.AF_Brand__c, VehicleDefinition.VariantName, ' +
                'VehicleDefinition.BodyType, VehicleDefinition.FuelType, ' +
                'VehicleDefinition.Product.AF_ThumbnailLink__c, VehicleDefinition.Product.Image_URL__c ' +
                'ORDER BY VehicleDefinition.AF_Brand__c ASC, VehicleDefinition.VariantName ASC';

            List<AggregateResult> results = Database.query(query);

            Set<Id> productIds = new Set<Id>();
            for (AggregateResult ar : results) {
                Id pid = (Id) ar.get('productId');
                if (pid != null) {
                    productIds.add(pid);
                }
            }
            Map<Id, Decimal> priceByProductId = getStandardPriceByProductId(productIds);

            for (AggregateResult ar : results) {
                DefinitionCard card = new DefinitionCard();
                card.id = (Id) ar.get('defId');
                card.productId = (Id) ar.get('productId');
                card.brand = (String) ar.get('brand');
                card.variantName = (String) ar.get('variantName');
                card.bodyType = (String) ar.get('bodyType');
                card.fuelType = (String) ar.get('fuelType');
                // Prefer a photo uploaded directly to the model's Files (same-origin,
                // no CSP concerns) over the catalog Image_URL__c text field.
                String thumbnailLink = (String) ar.get('thumbnailLink');
                card.imageUrl = String.isNotBlank(thumbnailLink) ? thumbnailLink : (String) ar.get('imageUrl');
                card.availableCount = (Integer) ar.get('availableCount');
                card.price = priceByProductId.get(card.productId);
                cards.add(card);
            }

            return cards;
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error retrieving vehicle models: ' + e.getMessage());
            aex.setMessage('Error retrieving vehicle models: ' + e.getMessage());
            throw aex;
        }
    }

    /**
     * The Opportunity's Brand — read by the "Select Vehicle" picker on load so
     * it can scope the model/vehicle lists to only that brand (e.g. an
     * Opportunity with Brand = Ferrari should only ever show Ferrari vehicles).
     * A plain field read, kept separate from the cacheable getVehicles/
     * getVehicleDefinitionsWithStock methods since those have no record
     * context of their own.
     */
    @AuraEnabled(cacheable=true)
    public static String getOpportunityBrand(Id opportunityId) {
        if (opportunityId == null) {
            return null;
        }
        List<Opportunity> opps = [
            SELECT AF_Brand__c
            FROM Opportunity
            WHERE Id = :opportunityId
            WITH USER_MODE
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0].AF_Brand__c;
    }

    /**
     * Same brand-scoping need as getOpportunityBrand, but for the Test Drive
     * "Select Demo Vehicle" picker — that Quick Action is hosted on
     * AF_TestDrive__c, not Opportunity, so the brand has to be read one hop
     * out via AF_Opportunity__r. Real bug fixed: the demo picker never scoped
     * by brand at all, so a Rolls-Royce Opportunity's Test Drive could select
     * a Ferrari demo unit.
     */
    @AuraEnabled(cacheable=true)
    public static String getTestDriveOpportunityBrand(Id testDriveId) {
        if (testDriveId == null) {
            return null;
        }
        List<AF_TestDrive__c> testDrives = [
            SELECT AF_Opportunity__r.AF_Brand__c
            FROM AF_TestDrive__c
            WHERE Id = :testDriveId
            WITH USER_MODE
            LIMIT 1
        ];
        return testDrives.isEmpty() ? null : testDrives[0].AF_Opportunity__r.AF_Brand__c;
    }

    public class TestDriveVehicleScope {
        @AuraEnabled public String brand;
        @AuraEnabled public Id vehicleDefinitionId;
    }

    /**
     * Same lookup as getTestDriveOpportunityBrand, but also returns the
     * Opportunity's own selected Vehicle Model (AF_VehicleModel__c) so the
     * demo picker can scope to THAT specific model instead of just the brand —
     * a rep test-driving a Ferrari Roma customer should see Roma demo units
     * first/only, not every Ferrari demo in the fleet. vehicleDefinitionId is
     * null when the Opportunity has no model selected yet, in which case the
     * picker falls back to brand-only scope (unchanged prior behavior).
     */
    @AuraEnabled(cacheable=true)
    public static TestDriveVehicleScope getTestDriveOpportunityVehicleScope(Id testDriveId) {
        TestDriveVehicleScope scope = new TestDriveVehicleScope();
        if (testDriveId == null) {
            return scope;
        }
        List<AF_TestDrive__c> testDrives = [
            SELECT AF_Opportunity__r.AF_Brand__c, AF_Opportunity__r.AF_VehicleModel__c
            FROM AF_TestDrive__c
            WHERE Id = :testDriveId
            WITH USER_MODE
            LIMIT 1
        ];
        if (!testDrives.isEmpty()) {
            scope.brand = testDrives[0].AF_Opportunity__r.AF_Brand__c;
            scope.vehicleDefinitionId = testDrives[0].AF_Opportunity__r.AF_VehicleModel__c;
        }
        return scope;
    }

    /**
     * Resolves a vehicle model's own Product2 Id given either a specific
     * in-stock Vehicle unit Id or a VehicleDefinition Id directly — used by
     * the picker to check getLineOptionsForVehicleModel BEFORE anything is
     * written, so the agent can see/confirm a Line choice while still able to
     * go back and change the vehicle with zero DML having happened yet.
     */
    @AuraEnabled(cacheable=true)
    public static Id resolveVehicleModelProductId(Id vehicleId, Id vehicleDefinitionId) {
        if (vehicleId != null) {
            List<Vehicle> vehicles = [
                SELECT VehicleDefinition.ProductId
                FROM Vehicle
                WHERE Id = :vehicleId
                WITH USER_MODE
                LIMIT 1
            ];
            return vehicles.isEmpty() ? null : vehicles[0].VehicleDefinition.ProductId;
        }
        if (vehicleDefinitionId != null) {
            List<VehicleDefinition> defs = [
                SELECT ProductId FROM VehicleDefinition WHERE Id = :vehicleDefinitionId WITH USER_MODE LIMIT 1
            ];
            return defs.isEmpty() ? null : defs[0].ProductId;
        }
        return null;
    }

    /**
     * Single atomic commit for the whole Select Vehicle flow — the Opportunity
     * fields, the base vehicle-model line item, AND (if the agent picked one)
     * the Line add-on line item are all written here together, once, only
     * when the agent finishes the picker. Nothing is written to the database
     * for any earlier step (choosing a vehicle, browsing Lines, going back) —
     * those are held in the LWC's own local state until this single call.
     * Exactly one of vehicleId/vehicleDefinitionId drives which model is
     * assigned: a specific in-stock Vehicle unit (vehicleId set) or a bare
     * model with no unit yet, i.e. "Proceed without Vehicle" (vehicleId null,
     * vehicleDefinitionId set). lineProductId is optional — omitted when the
     * model has no Line options, or the agent's model has none to choose.
     */
    @AuraEnabled
    public static void finalizeVehicleSelection(Id opportunityId, Id vehicleId, Id vehicleDefinitionId, Id lineProductId) {
        try {
            if (opportunityId == null || vehicleDefinitionId == null) {
                throw new AF_VehicleExplorerException('Both an Opportunity and a Vehicle Model are required.');
            }
            if (!Schema.sObjectType.Opportunity.fields.AF_SelectedVehicle__c.isUpdateable()) {
                throw new AF_VehicleExplorerException('Insufficient access to set the Selected Vehicle field.');
            }
            if (!Schema.sObjectType.Opportunity.fields.AF_VehicleModel__c.isUpdateable()) {
                throw new AF_VehicleExplorerException('Insufficient access to set the Vehicle Model field.');
            }

            update new Opportunity(
                Id = opportunityId,
                AF_SelectedVehicle__c = vehicleId,
                AF_VehicleModel__c = vehicleDefinitionId
            );

            syncOpportunityVehicleModelPricing(opportunityId, vehicleDefinitionId, vehicleId);

            if (lineProductId != null) {
                applyLineSelection(opportunityId, lineProductId);
            }
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error selecting vehicle: ' + e.getMessage());
            aex.setMessage('Error selecting vehicle: ' + e.getMessage());
            throw aex;
        }
    }

    /**
     * Keeps the Opportunity's Price Book and its vehicle-model line item in
     * sync with whichever model is currently assigned (AF_VehicleModel__c) —
     * called from both selectVehicleForOpportunity and proceedWithoutVehicle,
     * since either path can change which model's pricing should apply. Also
     * called from AF_LeadConversionService right after Lead Convert creates
     * the Opportunity, so a Lead that already had a Vehicle/Vehicle of
     * Interest gets the same line item + Price Book set up automatically —
     * public (not private) for that reason. Public since Apex has no
     * package-private access level.
     * Pricing always comes from the model's Product2 entry on the org's
     * Standard Price Book (BRD ALF-RS-05: "all products use the standard
     * price book but with different prices"), never Vehicle.MarketPrice.
     * CHANGED 2026-09-10: re-selecting a vehicle now deletes EVERY existing
     * OpportunityLineItem on this Opportunity (not just the prior vehicle-model
     * line) before inserting the new one — a full reset, since picking a
     * different vehicle invalidates whatever Trim/Line Variant, Accessory,
     * Package, Tint, or Customization lines were built around the old
     * selection. The rep re-adds any add-ons fresh against the new vehicle.
     */
    public static void syncOpportunityVehicleModelPricing(Id opportunityId, Id vehicleDefinitionId) {
        syncOpportunityVehicleModelPricing(opportunityId, vehicleDefinitionId, null);
    }

    /**
     * Overload that also stamps the specific in-stock Vehicle unit (if one was
     * chosen) onto the vehicle-model line item's AF_Vehicle__c. Without this,
     * the line item only ever carried the model-level Product2/PricebookEntry
     * and never the actual Vehicle/VIN — which silently broke every downstream
     * consumer that reads QuoteLineItem.AF_Vehicle__c off the copied line
     * (AF_FL_QuoteLineItem_SyncVINDisplay, AF_FL_Vehicle_SyncVINOnRestock in
     * RS-06), since AF_FL_Opp_CreateQuotation copies AF_Vehicle__c straight
     * from this OpportunityLineItem, not from Opportunity.AF_SelectedVehicle__c.
     * vehicleId is null for "Proceed without Vehicle" (model only, no specific
     * unit yet) — that case is unaffected, matching prior behavior exactly.
     */
    public static void syncOpportunityVehicleModelPricing(Id opportunityId, Id vehicleDefinitionId, Id vehicleId) {
        List<VehicleDefinition> defs = [
            SELECT ProductId
            FROM VehicleDefinition
            WHERE Id = :vehicleDefinitionId
            WITH USER_MODE
            LIMIT 1
        ];
        Id productId = defs.isEmpty() ? null : defs[0].ProductId;
        if (productId == null) {
            throw new AF_VehicleExplorerException('This vehicle model has no linked product — ask an admin to link one before it can be selected.');
        }

        // The Standard Price Book is invisible to plain SOQL in a test context
        // unless Test.getStandardPricebookId() is used — a well-known platform
        // quirk, not something specific to this org.
        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            throw new AF_VehicleExplorerException('No Standard Price Book is configured for this org.');
        }

        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :productId AND Pricebook2Id = :standardPricebookId AND IsActive = true
            WITH USER_MODE
            LIMIT 1
        ];
        if (entries.isEmpty()) {
            throw new AF_VehicleExplorerException('This vehicle model has no Standard Price Book entry yet — ask an admin to add one before it can be selected.');
        }
        PricebookEntry entry = entries[0];

        if (!Schema.sObjectType.Opportunity.fields.Pricebook2Id.isUpdateable()) {
            throw new AF_VehicleExplorerException('Insufficient access to set the Price Book field.');
        }
        update new Opportunity(Id = opportunityId, Pricebook2Id = standardPricebookId);

        List<OpportunityLineItem> existingLines = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            WITH USER_MODE
        ];
        if (!existingLines.isEmpty()) {
            delete existingLines;
        }

        insert new OpportunityLineItem(
            OpportunityId = opportunityId,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = entry.UnitPrice,
            AF_LineItemType__c = 'Vehicle',
            AF_Vehicle__c = vehicleId,
            AF_CustomerFacing__c = true,
            AF_IncludedInQuote__c = true
        );
    }

    // Relationship type used to link a vehicle model's Product2 to its
    // selectable Line/trim variants — "Parts and Accessories Bundle" (Bundle/
    // BundleComponent role), the only role Salesforce allows on a component
    // that belongs to a ProductComponentGroup (grouped min/max selection).
    // Distinct in purpose from any ungrouped physical-parts links that may
    // also use this same relationship type on the same vehicle — Lines are
    // told apart from those by living inside a ProductComponentGroup at all
    // (ProductRelatedComponent.ProductComponentGroupId != null), never by the
    // relationship type alone.
    private static final String LINE_RELATIONSHIP_TYPE_NAME = 'Parts and Accessories Bundle';

    /**
     * Returns the selectable Line/trim variants for a vehicle model's own
     * Product2, if any — empty when the model has no such group, meaning the
     * caller should skip the Line-selection step entirely and behave exactly
     * as before this feature existed. Line children are found by their
     * grouped ProductRelatedComponent rows (ProductComponentGroupId != null)
     * off the vehicle's own Product2 — never off any specific Vehicle unit —
     * since a Line is a property of the model, not one physical unit.
     */
    @AuraEnabled(cacheable=true)
    public static List<LineOption> getLineOptionsForVehicleModel(Id vehicleProductId) {
        List<LineOption> options = new List<LineOption>();
        if (vehicleProductId == null) {
            return options;
        }

        List<ProductRelatedComponent> links = [
            SELECT ChildProductId, ChildProduct.Name, ChildProduct.VehicleTrimLevel, IsDefaultComponent
            FROM ProductRelatedComponent
            WHERE ParentProductId = :vehicleProductId
            AND ProductComponentGroupId != null
            AND ProductRelationshipType.Name = :LINE_RELATIONSHIP_TYPE_NAME
            WITH USER_MODE
        ];
        if (links.isEmpty()) {
            return options;
        }

        Set<Id> lineProductIds = new Set<Id>();
        for (ProductRelatedComponent link : links) {
            lineProductIds.add(link.ChildProductId);
        }

        Id standardPricebookId = getStandardPricebookId();
        Map<Id, Decimal> priceByProductId = standardPricebookId == null
            ? new Map<Id, Decimal>()
            : getStandardPriceByProductId(lineProductIds);

        for (ProductRelatedComponent link : links) {
            LineOption opt = new LineOption();
            opt.productId = link.ChildProductId;
            opt.name = link.ChildProduct.Name;
            opt.trimLevel = link.ChildProduct.VehicleTrimLevel;
            opt.addOnPrice = priceByProductId.get(link.ChildProductId);
            opt.isDefault = link.IsDefaultComponent;
            options.add(opt);
        }
        return options;
    }

    /**
     * Adds the agent's chosen Line/trim variant as a second OpportunityLineItem
     * alongside the base vehicle model line created by
     * syncOpportunityVehicleModelPricing — the base vehicle's own Product2 is
     * always its own line; this is purely the add-on. Quantity/UnitPrice are
     * editable afterward from the Opportunity's Products related list exactly
     * like any line added via "Add Products", per the agreed design (the Line's
     * Standard Price Book entry only seeds the initial UnitPrice). Replaces any
     * previously selected Line line for this Opportunity, mirroring how
     * syncOpportunityVehicleModelPricing replaces the prior vehicle-model line
     * — an Opportunity has exactly one selected Line at a time, matching the
     * underlying ProductComponentGroup's Max=1 constraint. Called only from
     * finalizeVehicleSelection, in the same transaction as the base vehicle
     * write — never exposed on its own so a Line can never be saved without
     * its vehicle also being saved in the same commit.
     */
    private static void applyLineSelection(Id opportunityId, Id lineProductId) {
        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            throw new AF_VehicleExplorerException('No Standard Price Book is configured for this org.');
        }

        List<PricebookEntry> entries = [
            SELECT Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id = :lineProductId AND Pricebook2Id = :standardPricebookId AND IsActive = true
            WITH USER_MODE
            LIMIT 1
        ];
        if (entries.isEmpty()) {
            throw new AF_VehicleExplorerException('This Line has no Standard Price Book entry yet — ask an admin to add one before it can be selected.');
        }
        PricebookEntry entry = entries[0];

        List<OpportunityLineItem> existingLineLines = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId = :opportunityId
            AND PricebookEntry.Product2.AF_ProductCategory__c = 'Trim/Line Variant'
            WITH USER_MODE
        ];
        if (!existingLineLines.isEmpty()) {
            delete existingLineLines;
        }

        insert new OpportunityLineItem(
            OpportunityId = opportunityId,
            PricebookEntryId = entry.Id,
            Quantity = 1,
            UnitPrice = entry.UnitPrice,
            AF_LineItemType__c = 'Trim/Line Variant',
            AF_CustomerFacing__c = true,
            AF_IncludedInQuote__c = true
        );
    }

    /**
     * Bulk-safe counterpart to syncOpportunityVehicleModelPricing, for callers that must sync
     * pricing for many Opportunities in one transaction (currently only AF_LeadConversionService,
     * right after a bulk Database.convertLead()). Every SOQL/DML statement below runs once for the
     * whole batch instead of once per Opportunity — calling the single-Opportunity version in a loop
     * is exactly what made bulk Lead conversion exceed governor limits above ~25 Leads converted in
     * one transaction. A missing Product link or Price Book Entry is best-effort skipped (logged via
     * System.debug) rather than thrown — one bad model shouldn't block pricing sync for the rest of
     * the batch, matching the try/catch-and-skip the caller already wraps this in.
     */
    public static void syncOpportunityVehicleModelPricingBulk(Map<Id, Id> vehicleDefinitionIdByOppId) {
        syncOpportunityVehicleModelPricingBulk(vehicleDefinitionIdByOppId, new Map<Id, Id>());
    }

    /**
     * Overload that also stamps each Opportunity's specific in-stock Vehicle unit (if one was
     * selected on its source Lead) onto the bulk-created vehicle-model line item's AF_Vehicle__c —
     * same fix as syncOpportunityVehicleModelPricing's vehicleId overload, applied here since the
     * bulk Lead-Convert path was missed when that fix was made: it kept creating vehicle-model line
     * items with no AF_Vehicle__c at all, so a Lead that already had a specific Vehicle picked lost
     * that link on conversion, silently breaking VIN sync downstream (AF_FL_QuoteLineItem_SyncVINDisplay,
     * AF_FL_Vehicle_SyncVINOnRestock) exactly like the single-Opportunity gap did before RS-06.
     * vehicleIdByOppId entries are optional per-Opportunity — an Opportunity absent from it (Lead had
     * only a Vehicle-of-Interest model, no specific unit) is unaffected, matching prior behavior.
     */
    public static void syncOpportunityVehicleModelPricingBulk(Map<Id, Id> vehicleDefinitionIdByOppId, Map<Id, Id> vehicleIdByOppId) {
        if (vehicleDefinitionIdByOppId == null || vehicleDefinitionIdByOppId.isEmpty()) {
            return;
        }
        if (vehicleIdByOppId == null) {
            vehicleIdByOppId = new Map<Id, Id>();
        }

        Set<Id> vehicleDefinitionIds = new Set<Id>(vehicleDefinitionIdByOppId.values());
        Map<Id, Id> productIdByDefinitionId = new Map<Id, Id>();
        for (VehicleDefinition vd : [
            SELECT Id, ProductId FROM VehicleDefinition WHERE Id IN :vehicleDefinitionIds WITH USER_MODE
        ]) {
            if (vd.ProductId != null) {
                productIdByDefinitionId.put(vd.Id, vd.ProductId);
            }
        }

        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            System.debug(LoggingLevel.WARN, 'AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk: no Standard Price Book configured, skipping all.');
            return;
        }

        Set<Id> productIds = new Set<Id>(productIdByDefinitionId.values());
        Map<Id, PricebookEntry> entryByProductId = new Map<Id, PricebookEntry>();
        if (!productIds.isEmpty()) {
            for (PricebookEntry entry : [
                SELECT Id, Product2Id, UnitPrice
                FROM PricebookEntry
                WHERE Product2Id IN :productIds AND Pricebook2Id = :standardPricebookId AND IsActive = true
                WITH USER_MODE
            ]) {
                entryByProductId.put(entry.Product2Id, entry);
            }
        }

        Map<Id, PricebookEntry> entryByOppId = new Map<Id, PricebookEntry>();
        for (Id oppId : vehicleDefinitionIdByOppId.keySet()) {
            Id defId = vehicleDefinitionIdByOppId.get(oppId);
            Id productId = productIdByDefinitionId.get(defId);
            PricebookEntry entry = productId != null ? entryByProductId.get(productId) : null;
            if (entry == null) {
                System.debug(LoggingLevel.WARN, 'AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk: skipped Opportunity '
                    + oppId + ' — no linked product or Standard Price Book entry for VehicleDefinition ' + defId);
                continue;
            }
            entryByOppId.put(oppId, entry);
        }

        if (entryByOppId.isEmpty()) {
            return;
        }

        if (!Schema.sObjectType.Opportunity.fields.Pricebook2Id.isUpdateable()) {
            System.debug(LoggingLevel.WARN, 'AF_VehicleExplorerController.syncOpportunityVehicleModelPricingBulk: insufficient access to Pricebook2Id, skipping all.');
            return;
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        for (Id oppId : entryByOppId.keySet()) {
            oppsToUpdate.add(new Opportunity(Id = oppId, Pricebook2Id = standardPricebookId));
        }
        update oppsToUpdate;

        List<OpportunityLineItem> existingLines = [
            SELECT Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :entryByOppId.keySet()
            WITH USER_MODE
        ];
        if (!existingLines.isEmpty()) {
            delete existingLines;
        }

        List<OpportunityLineItem> newLines = new List<OpportunityLineItem>();
        for (Id oppId : entryByOppId.keySet()) {
            PricebookEntry entry = entryByOppId.get(oppId);
            newLines.add(new OpportunityLineItem(
                OpportunityId = oppId,
                PricebookEntryId = entry.Id,
                Quantity = 1,
                UnitPrice = entry.UnitPrice,
                AF_LineItemType__c = 'Vehicle',
                AF_Vehicle__c = vehicleIdByOppId.get(oppId),
                AF_CustomerFacing__c = true,
                AF_IncludedInQuote__c = true
            ));
        }
        insert newLines;
    }

    /**
     * Sets a Test Drive's Vehicle — the field the "Select Demo Vehicle" Quick
     * Action's picker writes to when a Sales Rep chooses which Demo Vehicle
     * unit to use for the test drive (ALF-RS-03). Deliberately independent of
     * selectVehicleForOpportunity: Test Drive selection is never inferred from
     * the Opportunity's own Selected Vehicle — the two can legitimately differ.
     */
    @AuraEnabled
    public static void selectVehicleForTestDrive(Id testDriveId, Id vehicleId) {
        try {
            if (testDriveId == null || vehicleId == null) {
                throw new AF_VehicleExplorerException('Both a Test Drive and a Vehicle are required.');
            }
            if (!Schema.sObjectType.AF_TestDrive__c.fields.AF_Vehicle__c.isUpdateable()) {
                throw new AF_VehicleExplorerException('Insufficient access to set the Vehicle field.');
            }
            if (!Schema.sObjectType.AF_TestDrive__c.fields.AF_VehicleDefinition__c.isUpdateable()) {
                throw new AF_VehicleExplorerException('Insufficient access to set the Vehicle Definition field.');
            }

            List<Vehicle> vehicles = [
                SELECT VehicleDefinitionId
                FROM Vehicle
                WHERE Id = :vehicleId
                WITH USER_MODE
                LIMIT 1
            ];
            Id vehicleDefinitionId = vehicles.isEmpty() ? null : vehicles[0].VehicleDefinitionId;

            update as user new AF_TestDrive__c(
                Id = testDriveId,
                AF_Vehicle__c = vehicleId,
                AF_VehicleDefinition__c = vehicleDefinitionId
            );
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error selecting vehicle: ' + e.getMessage());
            aex.setMessage('Error selecting vehicle: ' + e.getMessage());
            throw aex;
        }
    }

    private static final Set<String> MEDIA_IMAGE_FILE_TYPES = new Set<String>{ 'PNG', 'JPG', 'JPEG', 'GIF', 'BMP', 'SVG' };

    /**
     * Full media gallery for a Vehicle's detail view (BRD ALF-RS-05 FR#6/7):
     * every File attached to the Vehicle itself (photos, brochures), falling
     * back to the model/catalog Product2's own Files when the specific unit
     * has none yet (in-transit/ordered/demo units, per FR#7's OEM/brand-level
     * fallback requirement) — same-org Shepherd rendition URLs throughout, no
     * external CSP concerns.
     */
    @AuraEnabled(cacheable=true)
    public static List<MediaItem> getVehicleMedia(Id vehicleId) {
        try {
            if (vehicleId == null) {
                return new List<MediaItem>();
            }

            List<ContentDocumentLink> links = [
                SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.Title, ContentDocument.FileType
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :vehicleId
                WITH USER_MODE
                ORDER BY ContentDocument.CreatedDate ASC
            ];

            if (links.isEmpty()) {
                List<Vehicle> vehicles = [
                    SELECT VehicleDefinition.ProductId
                    FROM Vehicle
                    WHERE Id = :vehicleId
                    WITH USER_MODE
                    LIMIT 1
                ];
                Id modelProductId = (!vehicles.isEmpty() && vehicles[0].VehicleDefinition != null)
                    ? vehicles[0].VehicleDefinition.ProductId
                    : null;
                if (modelProductId != null) {
                    links = [
                        SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.Title, ContentDocument.FileType
                        FROM ContentDocumentLink
                        WHERE LinkedEntityId = :modelProductId
                        WITH USER_MODE
                        ORDER BY ContentDocument.CreatedDate ASC
                    ];
                }
            }

            List<MediaItem> items = new List<MediaItem>();
            for (ContentDocumentLink link : links) {
                Id versionId = link.ContentDocument.LatestPublishedVersionId;
                Boolean isImage = MEDIA_IMAGE_FILE_TYPES.contains(link.ContentDocument.FileType);

                MediaItem item = new MediaItem();
                item.title = link.ContentDocument.Title;
                item.fileType = link.ContentDocument.FileType;
                item.isImage = isImage;
                item.thumbnailUrl = isImage ? buildRenditionUrl(versionId, 'THUMB120BY160') : null;
                item.fullUrl = isImage ? buildRenditionUrl(versionId, 'THUMB720BY480') : ('/sfc/servlet.shepherd/version/download/' + versionId);
                items.add(item);
            }
            return items;
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error retrieving vehicle media: ' + e.getMessage());
            aex.setMessage('Error retrieving vehicle media: ' + e.getMessage());
            throw aex;
        }
    }

    private static String buildRenditionUrl(Id contentVersionId, String rendition) {
        return '/sfc/servlet.shepherd/version/renditionDownload?rendition=' + rendition + '&versionId=' + contentVersionId;
    }

    private static Id getLiveStandardPricebookId() {
        List<Pricebook2> standardBooks = [SELECT Id FROM Pricebook2 WHERE IsStandard = true WITH USER_MODE LIMIT 1];
        return standardBooks.isEmpty() ? null : standardBooks[0].Id;
    }

    private static Id getStandardPricebookId() {
        return Test.isRunningTest() ? Test.getStandardPricebookId() : getLiveStandardPricebookId();
    }

    // One catalog price per model (BRD ALF-RS-05: "all products use the
    // standard price book but with different prices") — read live off the
    // Standard Price Book Entry every time, not a synced copy field.
    private static Map<Id, Decimal> getStandardPriceByProductId(Set<Id> productIds) {
        Map<Id, Decimal> priceByProductId = new Map<Id, Decimal>();
        if (productIds == null || productIds.isEmpty()) {
            return priceByProductId;
        }
        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            return priceByProductId;
        }
        for (PricebookEntry entry : [
            SELECT Product2Id, UnitPrice
            FROM PricebookEntry
            WHERE Product2Id IN :productIds AND Pricebook2Id = :standardPricebookId AND IsActive = true
            WITH USER_MODE
        ]) {
            priceByProductId.put(entry.Product2Id, entry.UnitPrice);
        }
        return priceByProductId;
    }

    public class AF_VehicleExplorerException extends Exception {}

    /**
     * Full-fidelity export feed for the finder's Export button: every accessible
     * field on every inventory Vehicle (not just the columns shown in the UI),
     * ignoring the user's current filter/search/pagination state — "export
     * everything the app manages", per the export requirement. Pre-serialized to
     * JSON server-side so the client can write the response straight to a file
     * without any risk of re-serialization drift or partial data.
     */
    @AuraEnabled
    public static String getVehiclesForExport() {
        try {
            String query = buildExportQuery();
            List<Vehicle> vehicles = Database.query(query);

            Set<Id> productIds = new Set<Id>();
            for (Vehicle v : vehicles) {
                if (v.VehicleDefinition != null && v.VehicleDefinition.ProductId != null) {
                    productIds.add(v.VehicleDefinition.ProductId);
                }
            }
            Map<Id, Decimal> priceByProductId = getStandardPriceByProductId(productIds);

            List<Map<String, Object>> exportRows = new List<Map<String, Object>>();
            for (Vehicle v : vehicles) {
                Map<String, Object> row = new Map<String, Object>(v.getPopulatedFieldsAsMap());
                Id productId = (v.VehicleDefinition != null) ? v.VehicleDefinition.ProductId : null;
                row.put('StandardPrice', productId != null ? priceByProductId.get(productId) : null);
                exportRows.add(row);
            }

            return JSON.serializePretty(exportRows);
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error exporting vehicles: ' + e.getMessage());
            aex.setMessage('Error exporting vehicles: ' + e.getMessage());
            throw aex;
        }
    }

    private static String buildExportQuery() {
        Set<String> fieldNames = new Set<String>();
        for (Schema.SObjectField field : Schema.SObjectType.Vehicle.fields.getMap().values()) {
            Schema.DescribeFieldResult describe = field.getDescribe();
            if (describe.isAccessible()) {
                fieldNames.add(describe.getName());
            }
        }
        // Ensure the fields the UI relies on are present even on describes that
        // report differently across API versions.
        fieldNames.add('Id');
        fieldNames.add('VehicleDefinitionId');

        List<String> relationshipFields = new List<String>{
            'VehicleDefinition.Name', 'VehicleDefinition.AF_Brand__c', 'VehicleDefinition.VariantName',
            'VehicleDefinition.BodyType', 'VehicleDefinition.FuelType', 'VehicleDefinition.TransmissionType',
            'VehicleDefinition.ProductId', 'VehicleDefinition.Product.Name', 'VehicleDefinition.Product.Image_URL__c',
            'VehicleDefinition.Product.AF_ThumbnailLink__c'
        };

        List<String> allFields = new List<String>(fieldNames);
        allFields.addAll(relationshipFields);

        return 'SELECT ' + String.join(allFields, ', ') + ' FROM Vehicle ' +
            'WHERE AF_InventoryVehicle__c = true WITH USER_MODE ORDER BY ManufacturedDate DESC';
    }

    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptions() {
        return getFilterOptionsInternal(false, null);
    }

    // Brand-scoped variant for the Opportunity "Select Vehicle" picker — when
    // the Opportunity has a locked Brand, the filter sidebar itself (Make,
    // Model, Body Type, etc.) must only ever offer options that exist within
    // that brand, not the whole inventory (otherwise a Ferrari Opportunity's
    // sidebar would still let an agent tick "Rolls-Royce").
    @AuraEnabled(cacheable=true)
    public static FilterOptions getFilterOptionsForBrand(String brand) {
        return getFilterOptionsInternal(false, brand);
    }

    @AuraEnabled(cacheable=true)
    public static FilterOptions getDemoFilterOptions() {
        return getFilterOptionsInternal(true, null);
    }

    // Brand-scoped variant of getDemoFilterOptions, for the Test Drive demo
    // picker once it's locked to the Opportunity's brand.
    @AuraEnabled(cacheable=true)
    public static FilterOptions getDemoFilterOptionsForBrand(String brand) {
        return getFilterOptionsInternal(true, brand);
    }

    private static FilterOptions getFilterOptionsInternal(Boolean demoOnly, String brand) {
        try {
            FilterOptions options = new FilterOptions();
            String scopeCondition = getScopeCondition(demoOnly);
            if (String.isNotBlank(brand)) {
                scopeCondition += ' AND ' + MAKE_FIELD + ' = \'' + String.escapeSingleQuotes(brand) + '\'';
            }

            options.makes = getFacetCounts(MAKE_FIELD, scopeCondition);
            options.models = getFacetCounts(MODEL_FIELD, scopeCondition);
            options.bodyTypes = getFacetCounts(BODY_TYPE_FIELD, scopeCondition);
            options.fuelSources = getFacetCounts(FUEL_FIELD, scopeCondition);
            options.exteriorColors = getFacetCounts('ExteriorColor', scopeCondition);
            options.transmissions = getFacetCounts('GearBoxType', scopeCondition);
            options.conditionTypes = getFacetCounts('ConditionType', scopeCondition);
            options.inventoryStatuses = getFacetCounts('AF_InventoryStatus__c', scopeCondition);
            options.locations = getFacetCounts('AF_Location__c', scopeCondition);

            setPriceBounds(options, scopeCondition);

            AggregateResult[] dateResults = Database.query(
                'SELECT MIN(ManufacturedDate) minDate, MAX(ManufacturedDate) maxDate FROM Vehicle ' +
                'WHERE ' + scopeCondition + ' AND ManufacturedDate != null WITH USER_MODE'
            );
            Date minDate = (!dateResults.isEmpty()) ? (Date) dateResults[0].get('minDate') : null;
            Date maxDate = (!dateResults.isEmpty()) ? (Date) dateResults[0].get('maxDate') : null;
            options.minYear = minDate != null ? minDate.year() : Date.today().year();
            options.maxYear = maxDate != null ? maxDate.year() : Date.today().year();

            return options;
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error retrieving filter options: ' + e.getMessage());
            aex.setMessage('Error retrieving filter options: ' + e.getMessage());
            throw aex;
        }
    }

    /**
     * Price range for the filter sidebar's slider — resolved from the
     * Standard Price Book Entries of every model that has at least one
     * vehicle matching scopeCondition, never from Vehicle.MarketPrice.
     */
    private static void setPriceBounds(FilterOptions options, String scopeCondition) {
        options.minPrice = 0;
        options.maxPrice = 0;

        Set<Id> productIds = new Set<Id>();
        for (AggregateResult ar : Database.query(
            'SELECT VehicleDefinition.ProductId pid FROM Vehicle ' +
            'WHERE ' + scopeCondition + ' AND VehicleDefinition.ProductId != null ' +
            'WITH USER_MODE GROUP BY VehicleDefinition.ProductId'
        )) {
            productIds.add((Id) ar.get('pid'));
        }
        if (productIds.isEmpty()) {
            return;
        }

        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            return;
        }

        AggregateResult[] priceResults = [
            SELECT MIN(UnitPrice) minPrice, MAX(UnitPrice) maxPrice
            FROM PricebookEntry
            WHERE Product2Id IN :productIds AND Pricebook2Id = :standardPricebookId AND IsActive = true
            WITH USER_MODE
        ];
        if (!priceResults.isEmpty()) {
            options.minPrice = priceResults[0].get('minPrice') != null ? (Decimal) priceResults[0].get('minPrice') : 0;
            options.maxPrice = priceResults[0].get('maxPrice') != null ? (Decimal) priceResults[0].get('maxPrice') : 0;
        }
    }

    /**
     * Reservation statuses that keep a vehicle unit off the Finder — Requested/
     * Pending Approval/Reserved are all in-flight holds, and Converted means the
     * unit was actually sold. Expired and Cancelled release the unit back to the
     * pool, so those two are deliberately excluded from this set.
     */
    private static final Set<String> BLOCKING_RESERVATION_STATUSES = new Set<String>{
        'Requested', 'Pending Approval', 'Reserved', 'Converted'
    };

    // Excludes any Vehicle currently held by a non-terminal (or converted)
    // reservation. Vehicle.AF_ReservationStatus__c is NOT used for this — it is
    // never flipped back to Available when a reservation expires/cancels/converts
    // (no Flow or trigger does it), so it would leave sold/released units stuck
    // hidden or freed units stuck hidden. Reading AF_VehicleReservation__c live
    // instead is the only accurate source, since AF_Vehicle__c is the specific
    // physical unit a reservation locks (as opposed to AF_Product__c, which can
    // point at a bare model with no unit assigned yet).
    private static String getReservationExclusionCondition() {
        List<String> quotedStatuses = new List<String>();
        for (String status : BLOCKING_RESERVATION_STATUSES) {
            quotedStatuses.add('\'' + String.escapeSingleQuotes(status) + '\'');
        }
        return 'Id NOT IN (SELECT AF_Vehicle__c FROM AF_VehicleReservation__c ' +
            'WHERE AF_Vehicle__c != null AND AF_Status__c IN (' + String.join(quotedStatuses, ',') + '))';
    }

    /**
     * Vehicle.RecordTypeId condition for Demo Vehicle scope, or the standard
     * inventory-pool condition otherwise — Demo units are never inventory
     * (AF_InventoryVehicle__c is never true for them), so the two scopes need
     * genuinely different WHERE conditions, not just different flag values.
     * Both scopes also exclude vehicles held by an active reservation — a
     * reserved/sold unit should never resurface as selectable, demo pool
     * included.
     */
    private static String getScopeCondition(Boolean demoOnly) {
        String reservationExclusion = getReservationExclusionCondition();
        if (demoOnly == true) {
            Schema.RecordTypeInfo demoRecordType =
                Schema.SObjectType.Vehicle.getRecordTypeInfosByDeveloperName().get('Demo_Vehicle');
            if (demoRecordType != null) {
                return 'RecordTypeId = \'' + demoRecordType.getRecordTypeId() + '\'' +
                    ' AND ' + reservationExclusion;
            }
            return 'Id = null'; // Demo Vehicle record type not found — return nothing rather than the whole inventory.
        }
        // Regular (non-Demo) scope excludes the Demo Vehicle record type
        // explicitly, rather than requiring Regular_Vehicle — real inventory
        // units in this org are not actually assigned the Regular_Vehicle
        // record type (it exists but was never backfilled onto existing
        // data; every genuinely in-stock Vehicle has a null RecordTypeId).
        // Requiring Regular_Vehicle outright would exclude all real inventory;
        // excluding Demo_Vehicle achieves the same "no demo units" intent
        // without depending on that backfill.
        String condition = 'AF_InventoryVehicle__c = true';
        Schema.RecordTypeInfo demoRecordTypeForExclusion =
            Schema.SObjectType.Vehicle.getRecordTypeInfosByDeveloperName().get('Demo_Vehicle');
        if (demoRecordTypeForExclusion != null) {
            condition += ' AND RecordTypeId != \'' + demoRecordTypeForExclusion.getRecordTypeId() + '\'';
        }
        condition += ' AND ' + reservationExclusion;
        return condition;
    }

    // Distinct values for fieldName (a direct Vehicle field or a "Relationship.Field"
    // path) within scopeCondition, each with a record count, sorted by count desc
    // then label asc (matches the "Toyota (34)" style facet list in the sidebar).
    private static List<FacetOption> getFacetCounts(String fieldName, String scopeCondition) {
        List<FacetOption> options = new List<FacetOption>();

        // Relationship-path fields (e.g. VehicleDefinition.AF_Brand__c) must be
        // aliased — AggregateResult.get() on the raw dotted path is unreliable
        // (confirmed: throws "Invalid field ... for AggregateResult" in test context).
        String query = 'SELECT ' + fieldName + ' facetValue, COUNT(Id) recordCount FROM Vehicle ' +
            'WHERE ' + fieldName + ' != null AND ' + scopeCondition + ' ' +
            'WITH USER_MODE GROUP BY ' + fieldName;

        List<AggregateResult> results = Database.query(query);
        for (AggregateResult ar : results) {
            String value = String.valueOf(ar.get('facetValue'));
            if (String.isBlank(value)) {
                continue;
            }
            Integer count = (Integer) ar.get('recordCount');
            options.add(new FacetOption(value, value, count));
        }

        options.sort(new FacetOptionComparator());
        return options;
    }

    private class FacetOptionComparator implements Comparator<FacetOption> {
        public Integer compare(FacetOption a, FacetOption b) {
            if (a.count != b.count) {
                return b.count - a.count;
            }
            return a.label.compareTo(b.label);
        }
    }

    private static String buildDynamicWhereClause(Map<String, Object> filters) {
        List<String> conditions = new List<String>();

        conditions.add(getScopeCondition(filters.get('demoOnly') == true));

        addInStringCondition(conditions, filters, 'makes', MAKE_FIELD);
        addInStringCondition(conditions, filters, 'models', MODEL_FIELD);
        addInStringCondition(conditions, filters, 'bodyTypes', BODY_TYPE_FIELD);
        addInStringCondition(conditions, filters, 'fuelSources', FUEL_FIELD);
        addInStringCondition(conditions, filters, 'exteriorColors', 'ExteriorColor');
        addInStringCondition(conditions, filters, 'transmissions', 'GearBoxType');
        addInStringCondition(conditions, filters, 'conditionTypes', 'ConditionType');
        addInStringCondition(conditions, filters, 'inventoryStatuses', 'AF_InventoryStatus__c');
        addInStringCondition(conditions, filters, 'locations', 'AF_Location__c');

        if (filters.containsKey('brand') && filters.get('brand') != null) {
            String brand = String.escapeSingleQuotes(String.valueOf(filters.get('brand')));
            if (String.isNotBlank(brand)) {
                conditions.add(MAKE_FIELD + ' = \'' + brand + '\'');
            }
        }

        if (filters.containsKey('vehicleDefinitionId') && filters.get('vehicleDefinitionId') != null) {
            String defId = String.escapeSingleQuotes(String.valueOf(filters.get('vehicleDefinitionId')));
            if (String.isNotBlank(defId)) {
                conditions.add('VehicleDefinitionId = \'' + defId + '\'');
            }
        }

        if (filters.get('requireInStockWithVin') == true) {
            conditions.add('AF_InventoryStatus__c = \'In Stock\'');
            conditions.add('VehicleIdentificationNumber != null');
        }

        if (filters.containsKey('minYear') && filters.get('minYear') != null) {
            Integer minYear = parseYear(String.valueOf(filters.get('minYear')));
            if (minYear != null) {
                conditions.add('ManufacturedDate >= ' + minYear + '-01-01');
            }
        }
        if (filters.containsKey('maxYear') && filters.get('maxYear') != null) {
            Integer maxYear = parseYear(String.valueOf(filters.get('maxYear')));
            if (maxYear != null) {
                conditions.add('ManufacturedDate <= ' + maxYear + '-12-31');
            }
        }

        Boolean hasMinPrice = filters.containsKey('minPrice') && filters.get('minPrice') != null;
        Boolean hasMaxPrice = filters.containsKey('maxPrice') && filters.get('maxPrice') != null;
        if (hasMinPrice || hasMaxPrice) {
            Decimal minPrice = hasMinPrice ? Decimal.valueOf(String.valueOf(filters.get('minPrice'))) : null;
            Decimal maxPrice = hasMaxPrice ? Decimal.valueOf(String.valueOf(filters.get('maxPrice'))) : null;
            conditions.add(buildProductPriceRangeCondition(minPrice, maxPrice));
        }

        if (filters.containsKey('searchTerm') && filters.get('searchTerm') != null) {
            String searchTerm = String.escapeSingleQuotes(String.valueOf(filters.get('searchTerm')).trim());
            if (String.isNotBlank(searchTerm)) {
                String likeTerm = '\'%' + searchTerm + '%\'';
                conditions.add('(' + MAKE_FIELD + ' LIKE ' + likeTerm +
                    ' OR ' + MODEL_FIELD + ' LIKE ' + likeTerm +
                    ' OR StockCode LIKE ' + likeTerm +
                    ' OR VehicleIdentificationNumber LIKE ' + likeTerm +
                    ' OR Name LIKE ' + likeTerm + ')');
            }
        }

        return conditions.isEmpty() ? '' : ' WHERE ' + String.join(conditions, ' AND ');
    }

    private static Integer parseYear(String yearStr) {
        if (String.isBlank(yearStr) || !yearStr.trim().isNumeric()) {
            return null;
        }
        return Integer.valueOf(yearStr.trim());
    }

    private static void addInStringCondition(List<String> conditions, Map<String, Object> filters, String filterKey, String fieldName) {
        if (!filters.containsKey(filterKey) || filters.get(filterKey) == null) {
            return;
        }
        List<Object> rawValues = (List<Object>) filters.get(filterKey);
        if (rawValues.isEmpty()) {
            return;
        }
        List<String> escapedValues = new List<String>();
        for (Object rawValue : rawValues) {
            escapedValues.add('\'' + String.escapeSingleQuotes(String.valueOf(rawValue)) + '\'');
        }
        conditions.add(fieldName + ' IN (' + String.join(escapedValues, ',') + ')');
    }

    /**
     * A min/max price filter has to resolve against PricebookEntry.UnitPrice
     * (the model's catalog price), never Vehicle.MarketPrice — this turns
     * that range into a literal VehicleDefinition.ProductId IN (...) list,
     * embedded directly (bind variables in dynamic SOQL only resolve by name
     * within the method that calls Database.query(), not the method that
     * built the WHERE-clause string, so a bind variable here would not work).
     * Ids are platform-generated, never raw user input, so literal embedding
     * is safe — same pattern already used by getScopeCondition below.
     */
    private static String buildProductPriceRangeCondition(Decimal minPrice, Decimal maxPrice) {
        Id standardPricebookId = getStandardPricebookId();
        if (standardPricebookId == null) {
            return 'Id = null';
        }

        List<String> priceConditions = new List<String>{
            'Pricebook2Id = \'' + standardPricebookId + '\'',
            'IsActive = true'
        };
        if (minPrice != null) {
            priceConditions.add('UnitPrice >= ' + minPrice);
        }
        if (maxPrice != null) {
            priceConditions.add('UnitPrice <= ' + maxPrice);
        }

        List<String> quotedProductIds = new List<String>();
        String priceQuery = 'SELECT Product2Id FROM PricebookEntry WHERE ' + String.join(priceConditions, ' AND ') + ' WITH USER_MODE';
        for (PricebookEntry entry : (List<PricebookEntry>) Database.query(priceQuery)) {
            quotedProductIds.add('\'' + entry.Product2Id + '\'');
        }

        if (quotedProductIds.isEmpty()) {
            return 'Id = null';
        }
        return 'VehicleDefinition.ProductId IN (' + String.join(quotedProductIds, ',') + ')';
    }
}