@isTest
private class AF_InternalRequisitionFormServiceTest {

    @isTest
    static void testGenerateCreatesPdfListingFlaggedLineItems() {
        Id stdPbId = Test.getStandardPricebookId();

        Opportunity opp = new Opportunity(
            Name = 'IRF Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            Pricebook2Id = stdPbId,
            AF_RequisitionCompletionDate__c = Date.today().addDays(7)
        );
        insert opp;

        Product2 accessory = new Product2(Name = 'IRF Test Accessory', AF_ProductCategory__c = 'Accessory', IsActive = true);
        Product2 unflagged = new Product2(Name = 'IRF Test Vehicle Model', AF_ProductCategory__c = 'Vehicle Model', IsActive = true);
        insert new List<Product2>{ accessory, unflagged };

        PricebookEntry accessoryEntry = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = accessory.Id, UnitPrice = 500, IsActive = true
        );
        PricebookEntry unflaggedEntry = new PricebookEntry(
            Pricebook2Id = stdPbId, Product2Id = unflagged.Id, UnitPrice = 250000, IsActive = true
        );
        insert new List<PricebookEntry>{ accessoryEntry, unflaggedEntry };

        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = accessoryEntry.Id,
            Quantity = 2,
            UnitPrice = 500,
            AF_RequiresInternalRequisition__c = true,
            AF_CustomizationDescription__c = 'Fit tinted windows'
        );
        insert new OpportunityLineItem(
            OpportunityId = opp.Id,
            PricebookEntryId = unflaggedEntry.Id,
            Quantity = 1,
            UnitPrice = 250000,
            AF_RequiresInternalRequisition__c = false
        );

        AF_InternalRequisitionFormService.Request req = new AF_InternalRequisitionFormService.Request();
        req.opportunityId = opp.Id;

        Test.startTest();
        List<AF_InternalRequisitionFormService.Result> results =
            AF_InternalRequisitionFormService.generate(new List<AF_InternalRequisitionFormService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].contentVersionId);
        System.assertNotEquals(null, results[0].contentDocumentId);

        ContentVersion cv = [SELECT Title, PathOnClient, VersionData, ContentSize, FileType, ContentDocumentId FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assertEquals('Internal Requisition Form - IRF Test Opportunity', cv.Title);
        System.assert(cv.PathOnClient.endsWith('.pdf'), 'File should be generated as a PDF, not plain text');
        System.assertEquals('PDF', cv.FileType, 'Blob.toPdf() output should be stored as a real PDF file type');
        System.assert(cv.ContentSize > 0, 'PDF should have rendered content');

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :opp.Id]
        );
    }

    @isTest
    static void testBuildBodyListsOnlyFlaggedLineItemsWithJobSpecs() {
        Opportunity opp = new Opportunity(
            Name = 'IRF Body Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        OpportunityLineItem flagged = new OpportunityLineItem();
        flagged.AF_CustomizationDescription__c = 'Fit tinted windows';
        flagged.Quantity = 2;

        String html = AF_InternalRequisitionFormService.buildBody(opp, new List<OpportunityLineItem>{ flagged });

        System.assert(html.contains('Fit tinted windows'), 'Body should include the job specification text for a flagged line item');
        System.assert(html.contains('IRF Body Test Opportunity'), 'Body should reference the Opportunity name');

        String emptyHtml = AF_InternalRequisitionFormService.buildBody(opp, new List<OpportunityLineItem>());
        System.assert(emptyHtml.contains('No accessory/PDI line items were flagged'), 'Body should show a fallback message when no line items are flagged');
    }

    @isTest
    static void testGenerateHandlesOpportunityWithNoFlaggedLineItems() {
        Opportunity opp = new Opportunity(
            Name = 'IRF Test Opportunity - No Flags',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        AF_InternalRequisitionFormService.Request req = new AF_InternalRequisitionFormService.Request();
        req.opportunityId = opp.Id;

        Test.startTest();
        List<AF_InternalRequisitionFormService.Result> results =
            AF_InternalRequisitionFormService.generate(new List<AF_InternalRequisitionFormService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].contentVersionId);

        ContentVersion cv = [SELECT FileType, ContentSize FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assertEquals('PDF', cv.FileType);
        System.assert(cv.ContentSize > 0);
    }
}