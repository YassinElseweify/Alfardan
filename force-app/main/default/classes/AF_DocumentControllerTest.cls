/**
 * Tests for AF_DocumentController (ALF-RS-12 / LFRDN-342), the Aura-enabled surface the
 * afDocumentComponent LWC calls. AF_HandoverDocumentServiceTest already covers getRequiredDocuments
 * and the rename path via AF_Handover__c fixtures with a real AF_DynamicObject__mdt/
 * AF_Document__mdt configuration; this class drives the remaining controller methods
 * (isDocumentUploaded, getUploadedDocuments, uploadDocumentsFromPortal, removeUploadedDocument)
 * against that same configuration.
 */
@isTest
private class AF_DocumentControllerTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Document Controller Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Document Controller Test Opp',
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

    private static Id uploadVersion(String title, String pathOnClient, String documentTag) {
        ContentVersion cv = new ContentVersion(
            Title = title,
            PathOnClient = pathOnClient,
            VersionData = Blob.valueOf(title),
            AF_FileUpload__c = documentTag
        );
        insert cv;
        return [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    private static void linkToHandover(Id recordId, Id contentDocumentId) {
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = recordId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    @isTest
    static void getRequiredDocumentsWithNullRecordIdReturnsEmptyList() {
        Test.startTest();
        List<AF_Document__mdt> docs = AF_DocumentController.getRequiredDocuments(null);
        Test.stopTest();

        System.assertEquals(0, docs.size(), 'A null record Id must return an empty list, not throw.');
    }

    @isTest
    static void isDocumentUploadedIsFalseBeforeUploadAndTrueAfter() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        System.assertEquals(false, AF_DocumentController.isDocumentUploaded(ho.Id, 'Traffic Form'),
            'Nothing has been uploaded yet.');

        ContentVersion cv = new ContentVersion(
            Title = 'Traffic Form - Controller Test',
            PathOnClient = 'traffic.pdf',
            VersionData = Blob.valueOf('traffic form content'),
            AF_FileUpload__c = 'Traffic Form'
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = ho.Id,
            ShareType = 'V'
        );

        Test.startTest();
        Boolean uploaded = AF_DocumentController.isDocumentUploaded(ho.Id, 'Traffic Form');
        Test.stopTest();

        System.assertEquals(true, uploaded, 'AF_DocumentController must see the linked, tagged file.');
    }

    @isTest
    static void isDocumentUploadedReturnsFalseInsteadOfThrowingOnError() {
        Test.startTest();
        // documentName left null: the underlying query still runs, this only proves the method's
        // catch-and-return-false contract instead of letting a query exception surface.
        Boolean uploaded = AF_DocumentController.isDocumentUploaded(null, null);
        Test.stopTest();

        System.assertEquals(false, uploaded);
    }

    @isTest
    static void getUploadedDocumentsWithNullRecordIdReturnsEmptyList() {
        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.getUploadedDocuments(null, 'Traffic Form');
        Test.stopTest();

        System.assertEquals(0, links.size());
    }

    @isTest
    static void getUploadedDocumentsReturnsLinksMatchingTheTag() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        ContentVersion cv = new ContentVersion(
            Title = 'Insurance Form - Controller Test',
            PathOnClient = 'insurance.pdf',
            VersionData = Blob.valueOf('insurance form content'),
            AF_FileUpload__c = 'Insurance Form'
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = ho.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.getUploadedDocuments(ho.Id, 'Insurance Form');
        Test.stopTest();

        System.assertEquals(1, links.size());
    }

    @isTest
    static void uploadDocumentsFromPortalLinksAndTagsANewFile() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_DocumentController.FileUpload file = new AF_DocumentController.FileUpload();
        file.fileName = 'traffic-portal.pdf';
        file.base64Data = EncodingUtil.base64Encode(Blob.valueOf('portal traffic content'));

        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.uploadDocumentsFromPortal(
            ho.Id, 'Traffic Form', new List<AF_DocumentController.FileUpload>{ file }
        );
        Test.stopTest();

        System.assertEquals(1, links.size(), 'The uploaded file must come back tagged and linked.');
        AF_Handover__c refreshed = [SELECT AF_TrafficFormUploaded__c FROM AF_Handover__c WHERE Id = :ho.Id];
        System.assertEquals(true, refreshed.AF_TrafficFormUploaded__c);
    }

    @isTest
    static void uploadDocumentsFromPortalIgnoresNullEntriesInTheFileList() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        AF_DocumentController.FileUpload file = new AF_DocumentController.FileUpload();
        file.fileName = 'insurance-portal.pdf';
        file.base64Data = EncodingUtil.base64Encode(Blob.valueOf('portal insurance content'));

        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.uploadDocumentsFromPortal(
            ho.Id, 'Insurance Form', new List<AF_DocumentController.FileUpload>{ null, file }
        );
        Test.stopTest();

        System.assertEquals(1, links.size(), 'A null entry in the list must be skipped, not throw.');
    }

    @isTest
    static void removeUploadedDocumentDeletesTheMatchingLink() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        // Traffic Form is a required document type, so removeUploadedDocument refuses to delete
        // the only file of that type ("upload a replacement first") - two LINKED files need to
        // exist for a plain removal to succeed, and removeUploadedDocument only looks at files
        // already linked to the record (ContentDocumentLink), not just any ContentVersion.
        linkToHandover(ho.Id, uploadVersion('Traffic Form To Remove', 'traffic-remove.pdf', 'Traffic Form'));
        linkToHandover(ho.Id, uploadVersion('Traffic Form Kept', 'traffic-keep.pdf', 'Traffic Form'));

        Test.startTest();
        AF_DocumentController.removeUploadedDocument(ho.Id, 'Traffic Form', 'Traffic Form To Remove');
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :ho.Id AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = 'Traffic Form'
        ], 'Only the named file should be removed, the second one of the same type must remain.');
    }

    @isTest
    static void removeUploadedDocumentRefusesToDeleteTheOnlyRequiredFile() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        linkToHandover(ho.Id, uploadVersion('Only Traffic Form', 'traffic-only.pdf', 'Traffic Form'));

        Test.startTest();
        try {
            AF_DocumentController.removeUploadedDocument(ho.Id, 'Traffic Form', 'Only Traffic Form');
            System.assert(false, 'Removing the only file of a required document type must be refused.');
        } catch (AuraHandledException e) {
            // Expected - AF_DocumentService.removeUploadedDocument's required-type guard fired.
        }
        Test.stopTest();

        System.assertEquals(1, [
            SELECT COUNT() FROM ContentDocumentLink
            WHERE LinkedEntityId = :ho.Id AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = 'Traffic Form'
        ]);
    }

    @isTest
    static void getRequiredDocumentsIncludesUploadsTaggedOutsideTheRequiredSet() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        // A file tagged with something that is NOT one of the configured required documents still
        // has to appear in the list, so the LWC shows what the rep actually uploaded.
        linkToHandover(ho.Id, uploadVersion('Ad Hoc Evidence', 'adhoc.pdf', 'Totally Unlisted Document'));

        Test.startTest();
        List<AF_Document__mdt> docs = AF_DocumentController.getRequiredDocuments(ho.Id);
        Test.stopTest();

        Boolean foundAdHoc = false;
        for (AF_Document__mdt doc : docs) {
            if (doc.AF_DocumentName__c == 'Totally Unlisted Document') {
                foundAdHoc = true;
                System.assertEquals(true, doc.AF_Required__c);
            }
        }
        System.assertEquals(true, foundAdHoc,
            'An upload tagged outside the configured set must still be surfaced.');
    }

    @isTest
    static void uploadDocumentsFromPortalSurfacesServiceErrors() {
        AF_DocumentController.FileUpload file = new AF_DocumentController.FileUpload();
        file.fileName = 'orphan.pdf';
        file.base64Data = EncodingUtil.base64Encode(Blob.valueOf('orphan'));

        Test.startTest();
        try {
            // Null record Id makes AF_DocumentService throw; the controller must re-surface it.
            AF_DocumentController.uploadDocumentsFromPortal(
                null, 'Traffic Form', new List<AF_DocumentController.FileUpload>{ file }
            );
            System.assert(false, 'A null record Id must be surfaced as an error.');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void processDocumentUploadSurfacesServiceErrors() {
        Test.startTest();
        try {
            AF_DocumentController.processDocumentUpload(null, 'Traffic Form', new List<Id>{ null });
            System.assert(false, 'A null record Id must be surfaced as an error.');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void renameUploadedDocumentsSurfacesServiceErrors() {
        Test.startTest();
        try {
            AF_DocumentController.renameUploadedDocuments(null, 'Traffic Form', new List<Id>{ null });
            System.assert(false, 'A null record Id must be surfaced as an error.');
        } catch (AuraHandledException e) {
            // expected
        }
        try {
            AF_DocumentController.renameUploadedDocuments(null, '', new List<Id>{ null });
            System.assert(false, 'A blank document type must be surfaced as an error.');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void getRequiredDocumentsSurfacesServiceErrors() {
        // Account has no AF_DynamicObject__mdt row, so the service throws and the controller
        // converts it into an AuraHandledException for the LWC.
        Account acc = makeAccount();

        Test.startTest();
        try {
            AF_DocumentController.getRequiredDocuments(acc.Id);
            System.assert(false, 'An unsupported object must be surfaced as an error.');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void processDocumentUploadTagsAndReturnsTheFileList() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Id contentDocumentId = uploadVersion('Traffic Form Processed', 'traffic-processed.pdf', 'Traffic Form');

        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.processDocumentUpload(
            ho.Id, 'Traffic Form', new List<Id>{ contentDocumentId }
        );
        Test.stopTest();

        System.assertEquals(1, links.size(), 'The processed upload must come back linked and tagged.');
    }

    @isTest
    static void processDocumentUploadWithNoContentDocumentIdsReturnsEmptyList() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        List<ContentDocumentLink> links = AF_DocumentController.processDocumentUpload(
            ho.Id, 'Traffic Form', new List<Id>()
        );
        Test.stopTest();

        System.assertEquals(0, links.size(), 'Nothing was uploaded, so nothing comes back.');
    }

    @isTest
    static void removeUploadedDocumentRejectsMissingArguments() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        try {
            AF_DocumentController.removeUploadedDocument(null, 'Traffic Form', 'Some File');
            System.assert(false, 'A null record Id must be rejected.');
        } catch (AuraHandledException e) {
            // expected
        }
        try {
            AF_DocumentController.removeUploadedDocument(ho.Id, '', 'Some File');
            System.assert(false, 'A blank document type must be rejected.');
        } catch (AuraHandledException e) {
            // expected
        }
        try {
            AF_DocumentController.removeUploadedDocument(ho.Id, 'Traffic Form', '');
            System.assert(false, 'A blank file name must be rejected.');
        } catch (AuraHandledException e) {
            // expected
        }
        Test.stopTest();
    }

    @isTest
    static void removeUploadedDocumentReportsWhenNothingMatches() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        // Two linked files so the required-type guard passes, then ask for a name that is not there.
        linkToHandover(ho.Id, uploadVersion('Traffic Form A', 'a.pdf', 'Traffic Form'));
        linkToHandover(ho.Id, uploadVersion('Traffic Form B', 'b.pdf', 'Traffic Form'));

        Test.startTest();
        try {
            AF_DocumentController.removeUploadedDocument(ho.Id, 'Traffic Form', 'Not A Real File');
            System.assert(false, 'Removing a file that does not exist must be reported.');
        } catch (AuraHandledException e) {
            // expected - 'No matching file was found to remove.'
        }
        Test.stopTest();
    }

    @isTest
    static void renameUploadedDocumentsIgnoresNullAndEmptyIdLists() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        // Both are no-ops rather than errors, so the Flow/LWC can call them unconditionally.
        AF_DocumentController.renameUploadedDocuments(ho.Id, 'Traffic Form', null);
        AF_DocumentController.renameUploadedDocuments(ho.Id, 'Traffic Form', new List<Id>());
        AF_DocumentController.renameUploadedDocuments(ho.Id, 'Traffic Form', new List<Id>{ null });
        Test.stopTest();

        System.assertEquals(0, [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :ho.Id]);
    }

    @isTest
    static void renameUploadedDocumentsControllerDelegatesToTheService() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        // AF_ContentDocumentLink is an "after insert" trigger that reads AF_FileUpload__c off the
        // version at the moment the link is inserted (AF_HandoverUploadSyncService.syncFromLinks),
        // so the version has to already carry the tag - AF_DocumentController.renameUploadedDocuments
        // only relabels its Title, it does not retroactively re-fire that insert-time sync.
        ContentVersion cv = new ContentVersion(
            Title = 'Insurance Form Upload',
            PathOnClient = 'insurance-upload.pdf',
            VersionData = Blob.valueOf('insurance content'),
            AF_FileUpload__c = 'Insurance Form'
        );
        insert cv;
        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        Test.startTest();
        AF_DocumentController.renameUploadedDocuments(ho.Id, 'Insurance Form', new List<Id>{ contentDocumentId });
        Test.stopTest();

        AF_Handover__c refreshed = [SELECT AF_InsuranceFormUploaded__c FROM AF_Handover__c WHERE Id = :ho.Id];
        System.assertEquals(true, refreshed.AF_InsuranceFormUploaded__c);

        ContentVersion renamed = [SELECT Title FROM ContentVersion WHERE Id = :cv.Id];
        System.assert(renamed.Title.startsWith('Insurance Form'),
            'renameUploadedDocuments must relabel the Title to the document type. Got: ' + renamed.Title);
    }
}