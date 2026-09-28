/**
 * NOTE: this class deliberately never references the Appraisal sObject type,
 * nor inserts a real Appraisal record. Real platform constraint, reproduced
 * twice: (1) a 3-line scratch class proved `@IsTest` classes cannot even
 * declare a variable of type Appraisal ("Invalid type: Appraisal"), and (2)
 * `Schema.getGlobalDescribe().get('Appraisal')` returns null specifically
 * inside test execution context, even though both work fine in a regular
 * class and in anonymous Apex. Worked around by testing against a plain
 * Account Id instead — getAppraisalMedia's query filters ContentDocumentLink
 * by the polymorphic LinkedEntityId field only, with no join back to
 * Appraisal itself, so the method's actual logic is exercised identically
 * regardless of what object type the Id truly belongs to.
 */
@IsTest
private class AF_AppraisalMediaControllerTest {
    @IsTest
    static void testNullId() {
        Test.startTest();
        List<AF_AppraisalMediaController.MediaItem> items = AF_AppraisalMediaController.getAppraisalMedia(null);
        Test.stopTest();
        System.assertEquals(0, items.size(), 'Null appraisalId should return an empty list');
    }

    @IsTest
    static void testNoFiles() {
        Account acc = new Account(Name = 'Test Account', AF_QID__c = '11122233344');
        insert acc;

        Test.startTest();
        List<AF_AppraisalMediaController.MediaItem> items = AF_AppraisalMediaController.getAppraisalMedia(acc.Id);
        Test.stopTest();

        System.assertEquals(0, items.size(), 'No ContentDocumentLink means an empty gallery, not an error');
    }

    @IsTest
    static void testWithImageFile() {
        Account acc = new Account(Name = 'Test Account 2', AF_QID__c = '55566677788');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Trade-In Photo',
            PathOnClient = 'photo.png',
            VersionData = Blob.valueOf('test image bytes')
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<AF_AppraisalMediaController.MediaItem> items = AF_AppraisalMediaController.getAppraisalMedia(acc.Id);
        Test.stopTest();

        System.assertEquals(1, items.size(), 'One linked file should return one media item');
        System.assertEquals(true, items[0].isImage, 'A .png file should be classified as an image');
        System.assertNotEquals(null, items[0].thumbnailUrl, 'Image items should get a thumbnail rendition URL');
    }

    @IsTest
    static void testWithNonImageFile() {
        Account acc = new Account(Name = 'Test Account 3', AF_QID__c = '99988877766');
        insert acc;

        ContentVersion cv = new ContentVersion(
            Title = 'Trade-In Inspection Report',
            PathOnClient = 'report.pdf',
            VersionData = Blob.valueOf('test pdf bytes')
        );
        insert cv;

        Id contentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
        insert new ContentDocumentLink(
            ContentDocumentId = contentDocumentId,
            LinkedEntityId = acc.Id,
            ShareType = 'V'
        );

        Test.startTest();
        List<AF_AppraisalMediaController.MediaItem> items = AF_AppraisalMediaController.getAppraisalMedia(acc.Id);
        Test.stopTest();

        System.assertEquals(1, items.size(), 'One linked file should return one media item');
        System.assertEquals(false, items[0].isImage, 'A .pdf file should not be classified as an image');
        System.assertEquals(null, items[0].thumbnailUrl, 'Non-image items get no thumbnail rendition URL');
    }
}