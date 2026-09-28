/**
 * ALF-RS-12 (LFRDN-342) document-requirements engine. Ported from Albarari's
 * AB_BrokerDocumentController (renamed AF_, generalized off "Broker") - the Aura-enabled surface
 * afDocumentComponent calls.
 */
public without sharing class AF_DocumentController {

    @AuraEnabled(cacheable=true)
    public static List<AF_Document__mdt> getRequiredDocuments(Id recordId) {
        try {
            if (recordId == null) {
                return new List<AF_Document__mdt>();
            }

            List<AF_Document__mdt> documents = AF_DocumentService.getRequiredDocuments(
                    new List<Id>{ recordId },
                    false
                )
                .get(recordId);
            if (documents == null) {
                documents = new List<AF_Document__mdt>();
            }

            Set<String> documentNames = new Set<String>();
            for (AF_Document__mdt document : documents) {
                documentNames.add(document.AF_DocumentName__c);
            }

            List<ContentDocumentLink> uploadedDocuments = [
                SELECT ContentDocument.LatestPublishedVersion.AF_FileUpload__c,
                       ContentDocument.LatestPublishedVersion.Title,
                       ContentDocument.FileExtension
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
            ];

            for (ContentDocumentLink uploadedDocument : uploadedDocuments) {
                String tag = uploadedDocument.ContentDocument.LatestPublishedVersion.AF_FileUpload__c;
                if (String.isNotBlank(tag) && !documentNames.contains(tag)) {
                    AF_Document__mdt document = new AF_Document__mdt();
                    document.AF_DocumentName__c = tag;
                    document.AF_Required__c = true;
                    documents.add(document);
                }
            }

            return documents;
        } catch (Exception e) {
            System.debug(e);
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled
    public static Boolean isDocumentUploaded(Id recordId, String documentName) {
        try {
            List<ContentDocumentLink> links = [
                SELECT Id
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                    AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = :documentName
                LIMIT 1
            ];
            return !links.isEmpty();
        } catch (Exception e) {
            return false;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<ContentDocumentLink> getUploadedDocuments(Id recordId, String documentName) {
        try {
            if (recordId == null) {
                return new List<ContentDocumentLink>();
            }
            return AF_DocumentService.getDocuments(recordId, documentName);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Links uploaded files to the record, tags AF_FileUpload__c, and returns the current file list.
     */
    @AuraEnabled
    public static List<ContentDocumentLink> uploadDocumentsFromPortal(
        Id recordId,
        String documentName,
        List<FileUpload> files
    ) {
        try {
            List<AF_DocumentService.FilePayload> payloads = new List<AF_DocumentService.FilePayload>();
            if (files != null) {
                for (FileUpload fileRow : files) {
                    if (fileRow == null) {
                        continue;
                    }
                    AF_DocumentService.FilePayload payload = new AF_DocumentService.FilePayload();
                    payload.fileName = fileRow.fileName;
                    payload.base64Data = fileRow.base64Data;
                    payloads.add(payload);
                }
            }
            AF_DocumentService.uploadDocumentsFromBase64(recordId, documentName, payloads);
            return AF_DocumentService.getDocuments(recordId, documentName);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(String.isNotBlank(msg) ? msg : 'Error uploading documents');
        }
    }

    @AuraEnabled
    public static List<ContentDocumentLink> processDocumentUpload(
        Id recordId,
        String documentName,
        List<Id> contentDocumentIds
    ) {
        try {
            AF_DocumentService.renameUploadedDocuments(recordId, documentName, contentDocumentIds);
            return AF_DocumentService.getDocuments(recordId, documentName);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(String.isNotBlank(msg) ? msg : 'Error processing uploaded documents');
        }
    }

    @AuraEnabled
    public static void removeUploadedDocument(Id recordId, String documentName, String fileName) {
        try {
            AF_DocumentService.removeUploadedDocument(recordId, documentName, fileName);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(String.isNotBlank(msg) ? msg : 'Error removing document');
        }
    }

    @AuraEnabled
    public static void renameUploadedDocuments(Id recordId, String documentName, List<Id> contentDocumentIds) {
        try {
            AF_DocumentService.renameUploadedDocuments(recordId, documentName, contentDocumentIds);
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            String msg = e.getMessage();
            throw new AuraHandledException(String.isNotBlank(msg) ? msg : 'Error renaming uploaded documents');
        }
    }

    public class FileUpload {
        @AuraEnabled
        public String fileName { get; set; }
        @AuraEnabled
        public String base64Data { get; set; }
    }
}