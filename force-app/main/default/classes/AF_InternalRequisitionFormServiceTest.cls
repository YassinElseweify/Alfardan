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

        String html = AF_InternalRequisitionFormService.buildBody(opp, new List<OpportunityLineItem>{ flagged }, '00000123');

        System.assert(html.contains('Fit tinted windows'), 'Body should include the job specification text for a flagged line item');
        System.assert(html.contains('IRF Body Test Opportunity'), 'Body should reference the Opportunity name');
        System.assert(html.contains('00000123'), 'Body should print the quote number passed in');

        String emptyHtml = AF_InternalRequisitionFormService.buildBody(opp, new List<OpportunityLineItem>(), null);
        System.assert(emptyHtml.contains('No accessory/PDI line items were flagged'), 'Body should show a fallback message when no line items are flagged');
        System.assert(!emptyHtml.contains('null'), 'LFRDN-742: a missing vehicle/quote must never print the literal string "null"');
    }

    @isTest
    static void testBuildBodyEscapesAngleBracketsAndPreservesArabicText() {
        Opportunity opp = new Opportunity(
            Name = 'IRF Escaping Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        OpportunityLineItem flagged = new OpportunityLineItem();
        flagged.AF_CustomizationDescription__c = 'Roof Rails & Cross-Bars — M Sport <front + rear> "OEM" / فحص ما قبل التسليم';
        flagged.Quantity = 1;

        String html = AF_InternalRequisitionFormService.buildBody(opp, new List<OpportunityLineItem>{ flagged }, null);

        System.assert(
            html.contains('&lt;front') && html.contains('rear&gt;'),
            'LFRDN-745: angle-bracket text must be HTML-escaped so it is not parsed as a tag and silently dropped'
        );
        System.assert(!html.contains('<front'), 'The raw unescaped angle-bracket text must not appear in the body');
        System.assert(
            !html.contains('فحص'),
            'LFRDN-745: Arabic must be pre-shaped, since the PDF renderer joins raw Arabic letters in reversed order'
        );
        // فحص ما قبل التسليم, shaped and in visual (right-to-left) order after the left-to-right text
        String visualArabic = String.fromCharArray(new List<Integer>{
            65250, 65268, 65248, 65204, 65176, 65247, 65165, 32, 65246, 65170, 65239, 32, 65166, 65251, 32, 65210, 65188, 65235
        });
        System.assert(html.contains('&quot;OEM&quot; / ' + visualArabic), 'LFRDN-745: Arabic run must be shaped and reversed for display');
        System.assert(html.contains('Arial Unicode MS'), 'LFRDN-745: the body font must support Arabic glyphs');
    }

    @isTest
    static void testFormatForPdfArabicParagraphIsRightAlignedAndWrapped() {
        String arabic = 'تركيب زجاج أمامي ولا يوجد تظليل على الزجاج الأمامي يرجى المراجعة قبل التسليم للعميل';
        String html = AF_InternalRequisitionFormService.formatForPdf(arabic);
        System.assert(html.startsWith('<div style="text-align:right;">'), 'An Arabic paragraph must be right-aligned');
        System.assert(html.contains('<br/>'), 'Long Arabic text must be broken into lines before rendering');
        System.assert(html.contains(String.fromCharArray(new List<Integer>{ 65275 })), 'Lam-alef in "ولا" must use the isolated ligature');
        System.assertEquals('Plain &lt;text&gt;', AF_InternalRequisitionFormService.formatForPdf('Plain <text>'), 'Text without Arabic is only escaped');
    }

    @isTest
    static void testBuildBodyReflectsPendingVsApprovedStatus() {
        Opportunity pendingOpp = new Opportunity(
            Name = 'IRF Pending Status Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AF_RequisitionStatus__c = 'Pending Approval'
        );
        Opportunity approvedOpp = new Opportunity(
            Name = 'IRF Approved Status Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AF_RequisitionStatus__c = 'Approved'
        );
        insert new List<Opportunity>{ pendingOpp, approvedOpp };

        String pendingHtml = AF_InternalRequisitionFormService.buildBody(pendingOpp, new List<OpportunityLineItem>(), null);
        System.assert(
            pendingHtml.contains('>Pending Approval<'),
            'LFRDN-746: the form must show a Pending Approval status pill when generated before approval, ' +
            'so the Sales Manager can see the vehicle and jobs before approving instead of approving blind'
        );

        String approvedHtml = AF_InternalRequisitionFormService.buildBody(approvedOpp, new List<OpportunityLineItem>(), null);
        System.assert(approvedHtml.contains('>Approved<'), 'The form must still show Approved once the requisition is approved');
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

    @isTest
    static void testRegenerateAddsVersionInsteadOfDuplicateDocument() {
        Opportunity opp = new Opportunity(
            Name = 'IRF Regenerate Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        AF_InternalRequisitionFormService.Request req = new AF_InternalRequisitionFormService.Request();
        req.opportunityId = opp.Id;

        Test.startTest();
        AF_InternalRequisitionFormService.Result firstResult =
            AF_InternalRequisitionFormService.generate(new List<AF_InternalRequisitionFormService.Request>{ req })[0];
        AF_InternalRequisitionFormService.Result secondResult =
            AF_InternalRequisitionFormService.generate(new List<AF_InternalRequisitionFormService.Request>{ req })[0];
        Test.stopTest();

        System.assertEquals(
            firstResult.contentDocumentId,
            secondResult.contentDocumentId,
            'LFRDN-744: re-requesting after a post-approval change must add a version to the same ' +
            'ContentDocument, not create a second file - the reported bug showed two files both titled ' +
            'the same and both stamped Approved with no way to tell which was current'
        );
        System.assertNotEquals(firstResult.contentVersionId, secondResult.contentVersionId, 'Each generation should still produce its own ContentVersion');

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :opp.Id AND ContentDocument.Title = 'Internal Requisition Form - IRF Regenerate Test Opportunity']
        );
        System.assertEquals(2, [SELECT COUNT() FROM ContentVersion WHERE ContentDocumentId = :firstResult.contentDocumentId]);
    }
}