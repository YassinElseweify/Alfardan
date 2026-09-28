@isTest
private class AF_DocumentGenerationServiceTest {

    @isTest
    static void testGenerateCreatesContentVersionLinkedToRecord() {
        Id businessAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Doc Gen Test Account', RecordTypeId = businessAccountRTId);
        insert acc;

        AF_DocumentGenerationService.Request req = new AF_DocumentGenerationService.Request();
        req.title = 'Test Document';
        req.fileName = 'Test_Document.txt';
        req.body = 'Hello, this is a test document body.';
        req.parentRecordId = acc.Id;

        Test.startTest();
        List<AF_DocumentGenerationService.Result> results =
            AF_DocumentGenerationService.generate(new List<AF_DocumentGenerationService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].contentVersionId);
        System.assertNotEquals(null, results[0].contentDocumentId);

        ContentVersion cv = [SELECT Title, VersionData, ContentDocumentId FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assertEquals('Test Document', cv.Title);
        System.assertEquals('Hello, this is a test document body.', cv.VersionData.toString());

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :acc.Id]
        );
    }
}