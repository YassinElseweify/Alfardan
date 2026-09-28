public with sharing class AF_DocumentGenerationService {

    public class Request {
        @InvocableVariable(required=true)
        public String title;
        @InvocableVariable(required=true)
        public String fileName;
        @InvocableVariable(required=true)
        public String body;
        @InvocableVariable(required=true)
        public Id parentRecordId;
    }

    public class Result {
        @InvocableVariable
        public Id contentDocumentId;
        @InvocableVariable
        public Id contentVersionId;
    }

    @InvocableMethod(label='Generate Text Document' description='Creates a ContentVersion from plain text and links it to the given record. Exists because Flow cannot Base64-encode text for a Blob field (VersionData) declaratively.')
    public static List<Result> generate(List<Request> requests) {
        List<ContentVersion> versions = new List<ContentVersion>();
        for (Request req : requests) {
            ContentVersion cv = new ContentVersion();
            cv.Title = req.title;
            cv.PathOnClient = req.fileName;
            cv.VersionData = Blob.valueOf(req.body);
            cv.FirstPublishLocationId = req.parentRecordId;
            versions.add(cv);
        }
        insert versions;

        List<Id> versionIds = new List<Id>();
        for (ContentVersion cv : versions) {
            versionIds.add(cv.Id);
        }
        Map<Id, ContentVersion> withDocIds = new Map<Id, ContentVersion>(
            [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds]
        );

        List<Result> results = new List<Result>();
        for (ContentVersion cv : versions) {
            Result res = new Result();
            res.contentVersionId = cv.Id;
            res.contentDocumentId = withDocIds.get(cv.Id).ContentDocumentId;
            results.add(res);
        }
        return results;
    }
}