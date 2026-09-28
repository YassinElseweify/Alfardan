@IsTest
private class AF_VehicleImagesHandlerTest {

    @TestSetup
    static void setupData() {
        Product2 model = new Product2(Name = 'AFVIH Test Model', AF_ProductCategory__c = 'Vehicle Model');
        insert model;

        VehicleDefinition vd = new VehicleDefinition(Name = 'AFVIH Test Definition', ProductId = model.Id);
        insert vd;

        Asset a = new Asset(Name = 'AFVIH Test Asset');
        insert a;

        Vehicle v = new Vehicle(
            Name = 'AFVIH Test Vehicle',
            VehicleDefinitionId = vd.Id,
            AssetId = a.Id,
            VehicleIdentificationNumber = 'AFVIHTESTVIN0001',
            AF_InventoryVehicle__c = true
        );
        insert v;
    }

    @IsTest
    static void testUploadingImageSetsThumbnail() {
        Vehicle v = [SELECT Id FROM Vehicle WHERE Name = 'AFVIH Test Vehicle' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Test Photo',
            PathOnClient = 'test-photo.png',
            VersionData = Blob.valueOf('fake image bytes'),
            ContentLocation = 'S'
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = v.Id,
            ShareType = 'V'
        );
        Test.stopTest();

        Vehicle refreshed = [SELECT AF_ThumbnailLink__c FROM Vehicle WHERE Id = :v.Id];
        System.assertNotEquals(null, refreshed.AF_ThumbnailLink__c, 'Thumbnail link should be set after an image File is linked');
        System.assert(refreshed.AF_ThumbnailLink__c.contains('renditionDownload'), 'Link should be a Shepherd rendition URL');
    }

    @IsTest
    static void testDeletingLastImageClearsThumbnail() {
        Vehicle v = [SELECT Id FROM Vehicle WHERE Name = 'AFVIH Test Vehicle' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Test Photo 2',
            PathOnClient = 'test-photo-2.png',
            VersionData = Blob.valueOf('fake image bytes 2'),
            ContentLocation = 'S'
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = v.Id,
            ShareType = 'V'
        );
        insert link;

        Test.startTest();
        delete link;
        Test.stopTest();

        Vehicle refreshed = [SELECT AF_ThumbnailLink__c FROM Vehicle WHERE Id = :v.Id];
        System.assertEquals(null, refreshed.AF_ThumbnailLink__c, 'Thumbnail link should clear once the only image File is unlinked');
    }

    @IsTest
    static void testUploadingImageSetsProductThumbnail() {
        Product2 model = [SELECT Id FROM Product2 WHERE Name = 'AFVIH Test Model' LIMIT 1];

        ContentVersion cv = new ContentVersion(
            Title = 'Test Model Photo',
            PathOnClient = 'test-model-photo.png',
            VersionData = Blob.valueOf('fake image bytes'),
            ContentLocation = 'S'
        );
        insert cv;
        ContentVersion insertedCv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id];

        Test.startTest();
        insert new ContentDocumentLink(
            ContentDocumentId = insertedCv.ContentDocumentId,
            LinkedEntityId = model.Id,
            ShareType = 'V'
        );
        Test.stopTest();

        Product2 refreshed = [SELECT AF_ThumbnailLink__c FROM Product2 WHERE Id = :model.Id];
        System.assertNotEquals(null, refreshed.AF_ThumbnailLink__c, 'Thumbnail link should be set on the model/catalog Product2 too, not just Vehicle');
        System.assert(refreshed.AF_ThumbnailLink__c.contains('renditionDownload'), 'Link should be a Shepherd rendition URL');
    }
}