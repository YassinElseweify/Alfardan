/**
 * ALF-RS-12 (LFRDN-342) document-requirements engine. Ported from Albarari's AB_DocumentService
 * (same method shapes and naming, renamed AF_) so both orgs' required-document-checklist
 * infrastructure stays interchangeable. Reusable across any object with an AF_DynamicObject__mdt
 * row - not specific to AF_Handover__c.
 */
public without sharing class AF_DocumentService {

    /**
     * @description Retrieve required documents for a list of records of the same sObject type.
     * @param recordIds List of sObject Ids to check for required documents.
     * @param includeParentDocs Whether to key the result by "parentId-recordId" for documents that have AF_ParentId__c set.
     * @return Map of record Id (or "parentId-recordId" key) to list of required documents.
     */
    public static Map<String, List<AF_Document__mdt>> getRequiredDocuments(List<Id> recordIds, Boolean includeParentDocs) {
        if (recordIds == null || recordIds.isEmpty()) {
            throw new IllegalArgumentException('Record Ids cannot be null or empty.');
        }

        try {
            Id firstId = recordIds[0];
            if (firstId == null) {
                return new Map<String, List<AF_Document__mdt>>();
            }
            String type = firstId.getSObjectType().getDescribe().getName();

            List<AF_DynamicObject__mdt> dynamicRows = [
                SELECT Id, AF_ObjectAPIName__c, AF_FieldSet__c, AF_FieldToCheck__c
                FROM AF_DynamicObject__mdt
                WHERE AF_ObjectAPIName__c = :type
                LIMIT 1
            ];
            if (dynamicRows.isEmpty()) {
                throw new IllegalArgumentException(
                    'No AF_DynamicObject__mdt row for object type ' + type + '. Add metadata or fix AF_ObjectAPIName__c.'
                );
            }
            AF_DynamicObject__mdt dynamicObject = dynamicRows[0];

            // Stable order: first condition that evaluates true wins.
            List<AF_DocumentCondition__mdt> documentConditions = [
                SELECT Id, AF_Conditions__c, AF_DynamicObject__c
                FROM AF_DocumentCondition__mdt
                WHERE AF_DynamicObject__c = :dynamicObject.Id
                ORDER BY DeveloperName ASC
            ];

            Set<String> adjustedFieldSet = adjustFieldSet(type, dynamicObject.AF_FieldSet__c);
            String soql = 'SELECT Id';
            for (String f : adjustedFieldSet) { soql += ',' + f; }
            soql += ' FROM ' + type + ' WHERE Id IN :recordIds';
            List<SObject> records = Database.query(soql);

            Map<Id, Id> objectToCondition = new Map<Id, Id>();
            Set<Id> satisfiedConditionIds = checkConditions(records, documentConditions, objectToCondition);

            List<AF_Document__mdt> allDocuments = [
                SELECT Id, AF_DocumentName__c, AF_Required__c, AF_ParentId__c, AF_DocumentCondition__c
                FROM AF_Document__mdt
                WHERE AF_DocumentCondition__c IN :satisfiedConditionIds
            ];
            Map<String, List<AF_Document__mdt>> requiredDocs = new Map<String, List<AF_Document__mdt>>();
            for (SObject rec : records) {
                for (AF_Document__mdt doc : allDocuments) {
                    if (doc.AF_DocumentCondition__c == objectToCondition.get(rec.Id)) {
                        handleDocumentMap(requiredDocs, doc, includeParentDocs, rec);
                    }
                }
                if (!objectToCondition.containsKey(rec.Id)) {
                    requiredDocs.put(rec.Id, new List<AF_Document__mdt>());
                }
            }
            return requiredDocs;
        } catch (Exception e) {
            System.debug('Error in getRequiredDocuments: ' + e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Checks if all required documents are uploaded for each record.
     * @param recordIds List of record Ids to check (must be in the same order as documents' keys imply, one per recordId).
     * @param documents Map of required documents keyed by recordId (or "parentId-recordId").
     * @return Map of record Id to boolean indicating if all required documents are uploaded.
     */
    public static Map<Id, Boolean> checkDocumentsUploaded(List<Id> recordIds, Map<String, List<AF_Document__mdt>> documents) {
        Map<Id, Boolean> result = new Map<Id, Boolean>();
        Map<Id, Set<String>> recordToUploadedNames = getUploadedDocuments(documents);

        for (Id recId : recordIds) {
            List<AF_Document__mdt> docs = documents.get(String.valueOf(recId));
            if (docs == null) {
                // Fall back to matching by "parentId-recordId" keys.
                for (String key : documents.keySet()) {
                    if (getParentIdFromKey(key) == recId) {
                        docs = documents.get(key);
                        break;
                    }
                }
            }
            Set<String> uploadedNames = recordToUploadedNames.get(recId);
            Boolean allUploaded = true;
            if (docs != null) {
                for (AF_Document__mdt doc : docs) {
                    if (doc.AF_Required__c && (uploadedNames == null || !uploadedNames.contains(doc.AF_DocumentName__c))) {
                        allUploaded = false;
                        break;
                    }
                }
            }
            result.put(recId, allUploaded);
        }

        return result;
    }

    /**
     * @description Convenience single-record wrapper for checkDocumentsUploaded, used by the Flow-facing invocable.
     */
    public static Boolean areRequiredDocumentsUploaded(Id recordId) {
        if (recordId == null) {
            return false;
        }
        Map<String, List<AF_Document__mdt>> required = getRequiredDocuments(new List<Id>{ recordId }, false);
        Map<Id, Boolean> result = checkDocumentsUploaded(new List<Id>{ recordId }, required);
        return result.get(recordId) == true;
    }

    /**
     * LFRDN-703: names the specific required documents still missing for a single record - the
     * same "required but not yet uploaded" check areRequiredDocumentsUploaded/
     * checkDocumentsUploaded already make, but returning names instead of a Boolean so a blocked
     * gate (e.g. AF_ReservationContractService's FR13 check) can tell the rep exactly what to
     * attach, matching how afDocumentComponent's own "Missing" badge is computed per document.
     */
    public static List<String> getMissingDocumentNames(Id recordId) {
        if (recordId == null) {
            return new List<String>();
        }
        Map<String, List<AF_Document__mdt>> required = getRequiredDocuments(new List<Id>{ recordId }, false);
        List<AF_Document__mdt> docs = required.get(String.valueOf(recordId));
        if (docs == null) {
            return new List<String>();
        }
        Map<Id, Set<String>> recordToUploadedNames = getUploadedDocuments(required);
        Set<String> uploadedNames = recordToUploadedNames.get(recordId);

        List<String> missing = new List<String>();
        for (AF_Document__mdt doc : docs) {
            if (doc.AF_Required__c && (uploadedNames == null || !uploadedNames.contains(doc.AF_DocumentName__c))) {
                missing.add(doc.AF_DocumentName__c);
            }
        }
        return missing;
    }

    /**
     * @description Remove an uploaded document by record, document type (AF_FileUpload__c), and display name from the UI (e.g. Title.pdf).
     */
    public static void removeUploadedDocument(Id recordId, String documentName, String fileName) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(documentName)) {
            throw new AuraHandledException('Document type is required.');
        }
        if (String.isBlank(fileName)) {
            throw new AuraHandledException('File name is required.');
        }

        String fullLabel = fileName.trim();
        String baseTitle = fullLabel.contains('.') ? fullLabel.substringBeforeLast('.') : fullLabel;

        Boolean documentTypeIsRequired = isDocumentTypeRequired(recordId, documentName);

        List<ContentDocumentLink> allForType = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
                AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = :documentName
        ];
        if (documentTypeIsRequired && allForType.size() <= 1) {
            throw new AuraHandledException('Cannot remove the only file for this document type. Upload a replacement first.');
        }

        List<ContentDocumentLink> links = [
            SELECT Id, ContentDocumentId, ContentDocument.LatestPublishedVersion.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId
                AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = :documentName
                AND (ContentDocument.LatestPublishedVersion.Title = :fullLabel
                    OR ContentDocument.LatestPublishedVersion.Title = :baseTitle)
        ];

        if (links.isEmpty()) {
            throw new AuraHandledException('No matching file was found to remove.');
        }

        Set<Id> docIdsToDelete = new Set<Id>();
        for (ContentDocumentLink l : links) {
            docIdsToDelete.add(l.ContentDocumentId);
        }

        List<ContentDocument> docsToDelete = [
            SELECT Id
            FROM ContentDocument
            WHERE Id IN :docIdsToDelete
        ];

        if (docsToDelete.isEmpty()) {
            return;
        }

        delete docsToDelete;
    }

    /**
     * @description Returns true when the document type is currently required for this record.
     */
    private static Boolean isDocumentTypeRequired(Id recordId, String documentName) {
        try {
            Map<String, List<AF_Document__mdt>> requiredMap = getRequiredDocuments(new List<Id>{ recordId }, false);
            String recordKey = String.valueOf(recordId);
            List<AF_Document__mdt> requiredDocs = requiredMap != null ? requiredMap.get(recordKey) : null;
            if (requiredDocs == null || requiredDocs.isEmpty()) {
                return false;
            }
            for (AF_Document__mdt doc : requiredDocs) {
                if (doc != null && doc.AF_DocumentName__c == documentName) {
                    return doc.AF_Required__c == true;
                }
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }

    /**
     * @description Renames newly uploaded files to the metadata document name and tags AF_FileUpload__c.
     */
    public static void renameUploadedDocuments(Id recordId, String documentName, List<Id> contentDocumentIds) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(documentName)) {
            throw new AuraHandledException('Document type is required.');
        }
        if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
            return;
        }

        Set<Id> targetDocumentIds = new Set<Id>();
        for (Id docId : contentDocumentIds) {
            if (docId != null) {
                targetDocumentIds.add(docId);
            }
        }
        if (targetDocumentIds.isEmpty()) {
            return;
        }

        Set<Id> linkedDocumentIds = new Set<Id>();
        for (ContentDocumentLink linkRow : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId AND ContentDocumentId IN :targetDocumentIds
        ]) {
            linkedDocumentIds.add(linkRow.ContentDocumentId);
        }

        List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
        for (Id docId : targetDocumentIds) {
            if (!linkedDocumentIds.contains(docId)) {
                linksToInsert.add(
                    new ContentDocumentLink(
                        ContentDocumentId = docId,
                        LinkedEntityId = recordId,
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    )
                );
            }
        }
        if (!linksToInsert.isEmpty()) {
            insert linksToInsert;
            for (ContentDocumentLink linkRow : linksToInsert) {
                linkedDocumentIds.add(linkRow.ContentDocumentId);
            }
        }

        if (linkedDocumentIds.isEmpty()) {
            return;
        }

        List<ContentVersion> latestVersions = [
            SELECT Id, Title, AF_FileUpload__c, ContentDocumentId
            FROM ContentVersion
            WHERE IsLatest = true AND ContentDocumentId IN :linkedDocumentIds
            ORDER BY ContentDocumentId ASC
        ];

        if (latestVersions.isEmpty()) {
            return;
        }

        Set<String> usedTitles = new Set<String>();
        for (ContentDocumentLink existingLink : [
            SELECT ContentDocument.LatestPublishedVersion.Title
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId AND ContentDocumentId NOT IN :linkedDocumentIds
        ]) {
            usedTitles.add(existingLink.ContentDocument.LatestPublishedVersion.Title);
        }

        for (ContentVersion versionRow : latestVersions) {
            String nextTitle = generateUniqueTitle(documentName, usedTitles);
            versionRow.Title = nextTitle;
            versionRow.AF_FileUpload__c = documentName;
            usedTitles.add(nextTitle);
        }

        update latestVersions;

        // LFRDN-697: the ContentDocumentLink insert above fires AF_ContentDocumentLink's
        // after-insert trigger (AF_HandoverUploadSyncService.syncFromLinks) before
        // ContentVersion.AF_FileUpload__c is set by the update just above, so that first run always
        // sees a blank tag and skips. Re-running the sync here, now that the tag is set, is what
        // actually ticks AF_Handover__c.AF_TrafficFormUploaded__c / AF_InsuranceFormUploaded__c.
        AF_HandoverUploadSyncService.syncFromLinks([
            SELECT Id, LinkedEntityId, ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId AND ContentDocumentId IN :linkedDocumentIds
        ]);
    }

    private static String generateUniqueTitle(String baseTitle, Set<String> usedTitles) {
        if (!usedTitles.contains(baseTitle)) {
            return baseTitle;
        }
        Integer suffix = 2;
        String candidate = baseTitle + ' (' + suffix + ')';
        while (usedTitles.contains(candidate)) {
            suffix++;
            candidate = baseTitle + ' (' + suffix + ')';
        }
        return candidate;
    }

    /**
     * @description Retrieve all uploaded documents for a set of records.
     */
    private static Map<Id, Set<String>> getUploadedDocuments(Map<String, List<AF_Document__mdt>> documents) {
        Set<Id> recordIds = new Set<Id>();
        for (String key : documents.keySet()) {
            recordIds.add(getParentIdFromKey(key));
        }

        List<ContentDocumentLink> uploadedDocs = [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersion.Title, ContentDocument.LatestPublishedVersion.AF_FileUpload__c
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
        ];

        Map<Id, Set<String>> recordToName = new Map<Id, Set<String>>();
        for (ContentDocumentLink link : uploadedDocs) {
            if (!recordToName.containsKey(link.LinkedEntityId)) {
                recordToName.put(link.LinkedEntityId, new Set<String>());
            }
            String tag = link.ContentDocument.LatestPublishedVersion.AF_FileUpload__c;
            recordToName.get(link.LinkedEntityId).add(String.isNotBlank(tag) ? tag : link.ContentDocument.LatestPublishedVersion.Title);
        }

        return recordToName;
    }

    /**
     * @description Adjusts field set for querying records (expands RecordTypeId to RecordType.Name for text comparisons).
     */
    private static Set<String> adjustFieldSet(String type, String fieldSetName) {
        if (String.isBlank(fieldSetName)) {
            throw new IllegalArgumentException(
                'AF_DynamicObject__mdt.AF_FieldSet__c is blank for object ' + type + '. Set it to a valid Field Set API name.'
            );
        }
        Schema.SObjectType sObjType = Schema.getGlobalDescribe().get(type);
        if (sObjType == null) {
            throw new IllegalArgumentException('Unknown sObject type: ' + type);
        }
        Schema.DescribeSObjectResult describe = sObjType.getDescribe();
        Map<String, Schema.FieldSet> fieldSetMap = describe.fieldSets.getMap();
        Schema.FieldSet fs = fieldSetMap.get(fieldSetName);
        if (fs == null) {
            throw new IllegalArgumentException(
                'Field set "' +
                    fieldSetName +
                    '" does not exist on ' +
                    type +
                    '. Fix AF_DynamicObject__mdt.AF_FieldSet__c. Available field sets: ' +
                    String.join(new List<String>(fieldSetMap.keySet()), ', ')
            );
        }
        Set<String> fields = new Set<String>();

        for (Schema.FieldSetMember f : fs.getFields()) {
            if (f.getFieldPath().contains('RecordTypeId')) {
                fields.add(f.getFieldPath().replace('RecordTypeId', 'RecordType.Name'));
            } else {
                fields.add(f.getFieldPath());
            }
        }

        return fields;
    }

    /**
     * @description Evaluates AF_Conditions__c per record. The first matching condition (DeveloperName order) wins; its documents are shown.
     */
    private static Set<Id> checkConditions(List<SObject> records, List<AF_DocumentCondition__mdt> conditions, Map<Id, Id> objectToCondition) {
        Set<Id> satisfiedConditionIds = new Set<Id>();

        for (SObject rec : records) {
            for (AF_DocumentCondition__mdt cond : conditions) {
                Boolean isSatisfied = String.isBlank(cond.AF_Conditions__c)
                    ? true
                    : AF_DocumentConditionEvaluator.evaluate(cond.AF_Conditions__c, rec);
                if (isSatisfied == true) {
                    satisfiedConditionIds.add(cond.Id);
                    objectToCondition.put(rec.Id, cond.Id);
                    break;
                }
            }
        }

        return satisfiedConditionIds;
    }

    /**
     * @description Handles adding documents to map based on parent-child logic.
     */
    private static void handleDocumentMap(Map<String, List<AF_Document__mdt>> docMap, AF_Document__mdt doc, Boolean includeParentDocs, SObject rec) {
        if (doc.AF_ParentId__c != null && includeParentDocs) {
            String key = rec.get(doc.AF_ParentId__c) + '-' + rec.Id;
            if (!docMap.containsKey(key)) docMap.put(key, new List<AF_Document__mdt>());
            docMap.get(key).add(doc);
        } else {
            if (!docMap.containsKey(rec.Id)) docMap.put(rec.Id, new List<AF_Document__mdt>());
            docMap.get(rec.Id).add(doc);
        }
    }

    private static Id getParentIdFromKey(String key) {
        if (key.contains('-')) key = key.substringBefore('-');
        return (Id) key;
    }

    public class FilePayload {
        public String fileName;
        public String base64Data;
    }

    /**
     * @description Portal-safe upload: creates ContentVersion in Apex and links/tags on the record.
     */
    public static List<Id> uploadDocumentsFromBase64(
        Id recordId,
        String documentName,
        List<FilePayload> files
    ) {
        if (recordId == null) {
            throw new AuraHandledException('Record Id is required.');
        }
        if (String.isBlank(documentName)) {
            throw new AuraHandledException('Document type is required.');
        }
        if (files == null || files.isEmpty()) {
            throw new AuraHandledException('Select at least one file to upload.');
        }

        List<ContentVersion> versions = new List<ContentVersion>();
        for (FilePayload fileRow : files) {
            if (fileRow == null || String.isBlank(fileRow.base64Data) || String.isBlank(fileRow.fileName)) {
                continue;
            }
            ContentVersion cv = new ContentVersion();
            cv.Title = sanitizeUploadTitle(fileRow.fileName);
            cv.PathOnClient = fileRow.fileName;
            cv.VersionData = EncodingUtil.base64Decode(stripBase64Prefix(fileRow.base64Data));
            cv.AF_FileUpload__c = documentName;
            versions.add(cv);
        }

        if (versions.isEmpty()) {
            throw new AuraHandledException('No valid file data was received.');
        }

        insert versions;

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion versionRow : versions) {
            versionIds.add(versionRow.Id);
        }

        List<Id> contentDocumentIds = new List<Id>();
        for (ContentVersion insertedVersion : [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :versionIds
        ]) {
            if (insertedVersion.ContentDocumentId != null) {
                contentDocumentIds.add(insertedVersion.ContentDocumentId);
            }
        }

        if (contentDocumentIds.isEmpty()) {
            throw new AuraHandledException('Files were uploaded but could not be linked to the record.');
        }

        renameUploadedDocuments(recordId, documentName, contentDocumentIds);
        return contentDocumentIds;
    }

    private static String stripBase64Prefix(String base64Data) {
        if (String.isBlank(base64Data)) {
            return base64Data;
        }
        Integer commaIndex = base64Data.indexOf(',');
        return commaIndex > -1 ? base64Data.substring(commaIndex + 1) : base64Data;
    }

    private static String sanitizeUploadTitle(String fileName) {
        String title = String.isBlank(fileName) ? 'File' : fileName.trim();
        if (title.contains('.')) {
            title = title.substringBeforeLast('.');
        }
        if (title.length() > 255) {
            title = title.substring(0, 255);
        }
        return title;
    }

    public static List<ContentDocumentLink> getDocuments(Id recordId, String documentName) {
        return [
            SELECT ContentDocument.LatestPublishedVersion.AF_FileUpload__c,
                   ContentDocument.LatestPublishedVersion.Title,
                   ContentDocument.FileExtension
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :recordId AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c = :documentName
        ];
    }
}