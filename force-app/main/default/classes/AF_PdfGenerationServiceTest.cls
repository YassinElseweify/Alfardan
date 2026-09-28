@isTest
private class AF_PdfGenerationServiceTest {

    @isTest
    static void testGenerateCreatesPdfContentVersionLinkedToRecord() {
        Id businessAccountRTId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'PDF Gen Test Account', RecordTypeId = businessAccountRTId);
        insert acc;

        AF_PdfGenerationService.Request req = new AF_PdfGenerationService.Request();
        req.title = 'Test PDF Document';
        req.fileName = 'Test_Document.pdf';
        req.htmlBody = '<html><body><h1>Test Quotation</h1><p>Hello, this is a test PDF body.</p></body></html>';
        req.parentRecordId = acc.Id;

        Test.startTest();
        List<AF_PdfGenerationService.Result> results =
            AF_PdfGenerationService.generate(new List<AF_PdfGenerationService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(null, results[0].contentVersionId);
        System.assertNotEquals(null, results[0].contentDocumentId);

        ContentVersion cv = [SELECT Title, PathOnClient, VersionData, ContentDocumentId FROM ContentVersion WHERE Id = :results[0].contentVersionId];
        System.assertEquals('Test PDF Document', cv.Title);
        System.assertEquals('Test_Document.pdf', cv.PathOnClient);
        System.assertNotEquals(null, cv.VersionData);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM ContentDocumentLink WHERE ContentDocumentId = :cv.ContentDocumentId AND LinkedEntityId = :acc.Id]
        );
    }
}