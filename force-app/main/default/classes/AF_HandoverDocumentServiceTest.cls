/**
 * ALF-RS-12 (LFRDN-342). Covers the AF_Document__mdt required-documents engine end-to-end
 * (AF_DocumentService/AF_DocumentController/AF_DocumentGateCheck) against the real Handover
 * metadata records (AF_DynamicObject__mdt.Handover, AF_DocumentCondition__mdt.Handover_All, the 8
 * AF_Document__mdt rows) deployed alongside this feature, plus AF_HandoverDocumentService's
 * generation sequence/gates and AF_HandoverUploadSyncService's manual-upload sync.
 */
@isTest
private class AF_HandoverDocumentServiceTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Handover Doc Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Handover Doc Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static AF_Handover__c makeHandover(Id oppId) {
        AF_Handover__c ho = new AF_Handover__c(AF_Opportunity__c = oppId, AF_Status__c = 'Pending');
        insert ho;
        return ho;
    }

    @isTest
    static void requiredDocumentsEngineResolvesAllEightHandoverDocuments() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        Map<String, List<AF_Document__mdt>> required = AF_DocumentService.getRequiredDocuments(
            new List<Id>{ ho.Id }, false
        );
        Test.stopTest();

        List<AF_Document__mdt> docs = required.get(ho.Id);
        System.assertEquals(8, docs.size(), 'Expected all 8 handover documents (5 agreements + Delivery Note + Traffic/Insurance Form).');
    }

    @isTest
    static void gateCheckIsFalseUntilAllRequiredDocumentsPresent() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_DocumentGateCheck.Request req = new AF_DocumentGateCheck.Request();
        req.recordId = ho.Id;

        Test.startTest();
        List<AF_DocumentGateCheck.Result> before = AF_DocumentGateCheck.check(new List<AF_DocumentGateCheck.Request>{ req });
        Test.stopTest();

        System.assertEquals(false, before[0].allUploaded);
    }

    @isTest
    static void generateSequenceCreatesFiveAgreementsAndFlipsChecklist() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_HandoverDocumentService.Request req = new AF_HandoverDocumentService.Request();
        req.handoverId = ho.Id;

        Test.startTest();
        List<AF_HandoverDocumentService.Result> results = AF_HandoverDocumentService.generate(
            new List<AF_HandoverDocumentService.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(5, results.size(), 'FR4 automated sequence generates the 5 agreements, not the Delivery Note.');
        for (AF_HandoverDocumentService.Result r : results) {
            System.assertEquals(true, r.success, r.documentName + ' should have generated: ' + r.message);
        }

        AF_Handover__c refreshed = [
            SELECT AF_VehicleSaleAgreementComplete__c, AF_WarrantyAgreementComplete__c,
                   AF_ServiceContractAgreementComplete__c, AF_VehicleRepairDisclaimerComplete__c,
                   AF_BuyerAcknowledgementComplete__c, AF_DeliveryNoteGenerated__c, AF_ChecklistComplete__c
            FROM AF_Handover__c WHERE Id = :ho.Id
        ];
        System.assertEquals(true, refreshed.AF_VehicleSaleAgreementComplete__c);
        System.assertEquals(true, refreshed.AF_WarrantyAgreementComplete__c);
        System.assertEquals(true, refreshed.AF_ServiceContractAgreementComplete__c);
        System.assertEquals(true, refreshed.AF_VehicleRepairDisclaimerComplete__c);
        System.assertEquals(true, refreshed.AF_BuyerAcknowledgementComplete__c);
        System.assertEquals(false, refreshed.AF_DeliveryNoteGenerated__c, 'Delivery Note is never part of the automated 5-document sequence.');
        // AF_Formula_ChecklistComplete in AF_FL_Handover_UpdateChecklistGate requires all eight
        // checklist fields, not just these five agreements: the Delivery Note, Traffic Form and
        // Insurance Form are part of it too. The generate sequence deliberately stops short of
        // those, so the gate must still be closed at this point.
        System.assertEquals(false, refreshed.AF_ChecklistComplete__c,
            'The 5-document sequence alone must not flip the checklist gate - Delivery Note, Traffic Form and Insurance Form are still outstanding.');
    }

    @isTest
    static void regeneratingAnAlreadyCompleteDocumentIsSkippedUnlessBypassed() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_HandoverDocumentService.Request first = new AF_HandoverDocumentService.Request();
        first.handoverId = ho.Id;
        first.documentName = AF_HandoverDocumentService.DOC_VEHICLE_SALE_AGREEMENT;

        Test.startTest();
        AF_HandoverDocumentService.generate(new List<AF_HandoverDocumentService.Request>{ first });

        AF_HandoverDocumentService.Request second = new AF_HandoverDocumentService.Request();
        second.handoverId = ho.Id;
        second.documentName = AF_HandoverDocumentService.DOC_VEHICLE_SALE_AGREEMENT;
        List<AF_HandoverDocumentService.Result> skipped = AF_HandoverDocumentService.generate(
            new List<AF_HandoverDocumentService.Request>{ second }
        );

        AF_HandoverDocumentService.Request third = new AF_HandoverDocumentService.Request();
        third.handoverId = ho.Id;
        third.documentName = AF_HandoverDocumentService.DOC_VEHICLE_SALE_AGREEMENT;
        third.bypassGates = true;
        List<AF_HandoverDocumentService.Result> forced = AF_HandoverDocumentService.generate(
            new List<AF_HandoverDocumentService.Request>{ third }
        );
        Test.stopTest();

        System.assertEquals(false, skipped[0].success, 'Regenerating an already-complete document should be skipped by default.');
        System.assertEquals(true, forced[0].success, 'bypassGates=true should force regeneration.');
    }

    @isTest
    static void deliveryNoteIsBlockedUntilScheduleConfirmedThenSucceeds() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_HandoverDocumentService.Request req = new AF_HandoverDocumentService.Request();
        req.handoverId = ho.Id;
        req.documentName = AF_HandoverDocumentService.DOC_DELIVERY_NOTE;

        Test.startTest();
        List<AF_HandoverDocumentService.Result> blocked = AF_HandoverDocumentService.generate(
            new List<AF_HandoverDocumentService.Request>{ req }
        );
        System.assertEquals(false, blocked[0].success, 'FR7: Delivery Note requires date/time and location first.');

        update new AF_Handover__c(Id = ho.Id, AF_HandoverDate__c = System.now().addDays(1), AF_Location__c = 'Alfardan Showroom - Doha');

        AF_HandoverDocumentService.Request req2 = new AF_HandoverDocumentService.Request();
        req2.handoverId = ho.Id;
        req2.documentName = AF_HandoverDocumentService.DOC_DELIVERY_NOTE;
        List<AF_HandoverDocumentService.Result> ok = AF_HandoverDocumentService.generate(
            new List<AF_HandoverDocumentService.Request>{ req2 }
        );
        Test.stopTest();

        System.assertEquals(true, ok[0].success, 'Delivery Note should generate once the schedule is confirmed.');

        AF_Handover__c refreshed = [SELECT AF_DeliveryNoteGenerated__c FROM AF_Handover__c WHERE Id = :ho.Id];
        System.assertEquals(true, refreshed.AF_DeliveryNoteGenerated__c);
    }

    @isTest
    static void manualUploadTagsAndSyncsTrafficAndInsuranceFormFlags() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        ContentVersion trafficCv = new ContentVersion(
            Title = 'Traffic Form - Test',
            PathOnClient = 'traffic.pdf',
            VersionData = Blob.valueOf('traffic form content'),
            AF_FileUpload__c = 'Traffic Form'
        );
        ContentVersion insuranceCv = new ContentVersion(
            Title = 'Insurance Form - Test',
            PathOnClient = 'insurance.pdf',
            VersionData = Blob.valueOf('insurance form content'),
            AF_FileUpload__c = 'Insurance Form'
        );

        Test.startTest();
        insert new List<ContentVersion>{ trafficCv, insuranceCv };
        Map<Id, Id> docIdByVersionId = new Map<Id, Id>();
        for (ContentVersion cv : [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :new List<Id>{ trafficCv.Id, insuranceCv.Id }]) {
            docIdByVersionId.put(cv.Id, cv.ContentDocumentId);
        }
        AF_DocumentService.renameUploadedDocuments(ho.Id, 'Traffic Form', new List<Id>{ docIdByVersionId.get(trafficCv.Id) });
        AF_DocumentService.renameUploadedDocuments(ho.Id, 'Insurance Form', new List<Id>{ docIdByVersionId.get(insuranceCv.Id) });
        Test.stopTest();

        AF_Handover__c refreshed = [
            SELECT AF_TrafficFormUploaded__c, AF_InsuranceFormUploaded__c FROM AF_Handover__c WHERE Id = :ho.Id
        ];
        System.assertEquals(true, refreshed.AF_TrafficFormUploaded__c, 'AF_ContentDocumentLink trigger should flip this on link insert.');
        System.assertEquals(true, refreshed.AF_InsuranceFormUploaded__c);
    }

    @isTest
    static void controllerReturnsRequiredDocumentsIncludingUnmatchedUploads() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        List<AF_Document__mdt> docs = AF_DocumentController.getRequiredDocuments(ho.Id);
        Test.stopTest();

        System.assertEquals(8, docs.size());
    }
}