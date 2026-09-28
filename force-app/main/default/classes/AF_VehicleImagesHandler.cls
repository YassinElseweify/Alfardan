/**
 * Populates AF_ThumbnailLink__c from the first image File uploaded to the
 * Files related list of either a Vehicle (the physical unit) or a Product2
 * (the vehicle model/catalog entry, used by the Vehicle Finder's model
 * cards), so both levels of the finder can show a real photo without anyone
 * typing a URL. Mirrors AL Barrari's PropertyImagesHandler pattern
 * (same-org Shepherd rendition URL — no external CSP trusted site needed).
 */
public with sharing class AF_VehicleImagesHandler {

    private static final String VEHICLE_KEY_PREFIX = '0vL';
    private static final String PRODUCT2_KEY_PREFIX = '01t';
    private static final Set<String> IMAGE_FILE_TYPES = new Set<String>{ 'PNG', 'JPG', 'JPEG', 'GIF', 'BMP', 'SVG' };

    public static void handleAfterInsert(List<ContentDocumentLink> newLinks) {
        processImages(newLinks);
    }

    public static void handleAfterDelete(List<ContentDocumentLink> oldLinks) {
        processImages(oldLinks);
    }

    private static void processImages(List<ContentDocumentLink> links) {
        Set<Id> vehicleIds = new Set<Id>();
        Set<Id> productIds = new Set<Id>();

        for (ContentDocumentLink link : links) {
            String entityId = String.valueOf(link.LinkedEntityId);
            if (entityId.startsWith(VEHICLE_KEY_PREFIX)) {
                vehicleIds.add(link.LinkedEntityId);
            } else if (entityId.startsWith(PRODUCT2_KEY_PREFIX)) {
                productIds.add(link.LinkedEntityId);
            }
        }

        if (!vehicleIds.isEmpty()) {
            processThumbnails(vehicleIds, 'Vehicle');
        }
        if (!productIds.isEmpty()) {
            processThumbnails(productIds, 'Product2');
        }
    }

    @TestVisible
    private static void processThumbnails(Set<Id> recordIds, String objectApiName) {
        if (recordIds.isEmpty()) {
            return;
        }
        if (!Schema.getGlobalDescribe().get(objectApiName).getDescribe().fields.getMap()
            .get('AF_ThumbnailLink__c').getDescribe().isUpdateable()) {
            return;
        }

        List<ContentDocumentLink> allLinks = [
            SELECT LinkedEntityId, ContentDocument.LatestPublishedVersionId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
            AND ContentDocument.FileType IN :IMAGE_FILE_TYPES
            WITH USER_MODE
            ORDER BY SystemModstamp ASC
        ];

        Map<Id, Id> recordToFirstVersionId = new Map<Id, Id>();
        for (ContentDocumentLink link : allLinks) {
            if (!recordToFirstVersionId.containsKey(link.LinkedEntityId)) {
                recordToFirstVersionId.put(link.LinkedEntityId, link.ContentDocument.LatestPublishedVersionId);
            }
        }

        List<SObject> recordsToUpdate = new List<SObject>();
        for (Id recordId : recordIds) {
            Id versionId = recordToFirstVersionId.get(recordId);
            SObject record = Schema.getGlobalDescribe().get(objectApiName).newSObject(recordId);
            record.put('AF_ThumbnailLink__c', versionId != null ? buildShepherdRenditionUrl(versionId) : null);
            recordsToUpdate.add(record);
        }

        Database.update(recordsToUpdate, false);
    }

    private static String buildShepherdRenditionUrl(Id contentVersionId) {
        return '/sfc/servlet.shepherd/version/renditionDownload?rendition=THUMB720BY480&versionId=' + contentVersionId;
    }
}