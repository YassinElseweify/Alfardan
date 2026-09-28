/**
 * ALF-RS-04 FR3: read-only media gallery for an AppraisalItem's uploaded 360-degree
 * photos, mirroring AF_VehicleExplorerController.getVehicleMedia's shape/rendition
 * approach so the LWC can share the same display pattern already proven on the
 * Vehicle record page. Deliberately its own small class rather than an addition
 * to AF_VehicleExplorerController — a trade-in has no catalog Product2 to fall
 * back to, so there is no shared fallback logic worth reusing beyond the plain
 * ContentDocumentLink query and rendition URL helper. Moved from Appraisal to
 * AppraisalItem 2026-09-09 (per-vehicle photos, one gallery per trade-in item
 * rather than one shared gallery for a multi-vehicle Appraisal) — parameter
 * renamed generically since ContentDocumentLink.LinkedEntityId works the same
 * for either object, only the caller (afAppraisalMediaGallery's recordId) changes.
 */
public with sharing class AF_AppraisalMediaController {
    private static final Set<String> MEDIA_IMAGE_FILE_TYPES = new Set<String>{ 'PNG', 'JPG', 'JPEG', 'GIF', 'BMP', 'SVG' };

    @AuraEnabled(cacheable=true)
    public static List<MediaItem> getAppraisalMedia(Id recordId) {
        try {
            if (recordId == null) {
                return new List<MediaItem>();
            }

            List<ContentDocumentLink> links = [
                SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.Title, ContentDocument.FileType
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                WITH USER_MODE
                ORDER BY ContentDocument.CreatedDate ASC
            ];

            List<MediaItem> items = new List<MediaItem>();
            for (ContentDocumentLink link : links) {
                Id versionId = link.ContentDocument.LatestPublishedVersionId;
                Boolean isImage = MEDIA_IMAGE_FILE_TYPES.contains(link.ContentDocument.FileType);

                MediaItem item = new MediaItem();
                item.title = link.ContentDocument.Title;
                item.fileType = link.ContentDocument.FileType;
                item.isImage = isImage;
                item.thumbnailUrl = isImage ? buildRenditionUrl(versionId, 'THUMB120BY160') : null;
                item.fullUrl = isImage ? buildRenditionUrl(versionId, 'THUMB720BY480') : ('/sfc/servlet.shepherd/version/download/' + versionId);
                items.add(item);
            }
            return items;
        } catch (Exception e) {
            AuraHandledException aex = new AuraHandledException('Error retrieving appraisal media: ' + e.getMessage());
            aex.setMessage('Error retrieving appraisal media: ' + e.getMessage());
            throw aex;
        }
    }

    private static String buildRenditionUrl(Id contentVersionId, String rendition) {
        return '/sfc/servlet.shepherd/version/renditionDownload?rendition=' + rendition + '&versionId=' + contentVersionId;
    }

    public class MediaItem {
        @AuraEnabled public String title;
        @AuraEnabled public String fileType;
        @AuraEnabled public Boolean isImage;
        @AuraEnabled public String thumbnailUrl;
        @AuraEnabled public String fullUrl;
    }
}