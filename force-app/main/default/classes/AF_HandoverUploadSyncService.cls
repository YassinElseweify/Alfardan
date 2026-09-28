/**
 * ALF-RS-12 (LFRDN-342) FR6 - see AF_ContentDocumentLink.trigger for why this is a plain trigger
 * handler rather than a Flow. Bulk-safe: handles the whole Trigger.new list in one pass.
 */
public without sharing class AF_HandoverUploadSyncService {

    private static final String DOC_TRAFFIC_FORM = 'Traffic Form';
    private static final String DOC_INSURANCE_FORM = 'Insurance Form';

    public static void syncFromLinks(List<ContentDocumentLink> links) {
        Set<Id> handoverIds = new Set<Id>();
        Set<Id> contentDocumentIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == AF_Handover__c.SObjectType) {
                handoverIds.add(link.LinkedEntityId);
                contentDocumentIds.add(link.ContentDocumentId);
            }
        }
        if (handoverIds.isEmpty()) {
            return;
        }

        Map<Id, ContentVersion> latestVersionByDocId = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, AF_FileUpload__c
            FROM ContentVersion
            WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = true
        ]) {
            latestVersionByDocId.put(cv.ContentDocumentId, cv);
        }

        Set<Id> trafficFormHandoverIds = new Set<Id>();
        Set<Id> insuranceFormHandoverIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (!handoverIds.contains(link.LinkedEntityId)) {
                continue;
            }
            ContentVersion cv = latestVersionByDocId.get(link.ContentDocumentId);
            if (cv == null || String.isBlank(cv.AF_FileUpload__c)) {
                continue;
            }
            if (cv.AF_FileUpload__c == DOC_TRAFFIC_FORM) {
                trafficFormHandoverIds.add(link.LinkedEntityId);
            } else if (cv.AF_FileUpload__c == DOC_INSURANCE_FORM) {
                insuranceFormHandoverIds.add(link.LinkedEntityId);
            }
        }

        if (trafficFormHandoverIds.isEmpty() && insuranceFormHandoverIds.isEmpty()) {
            return;
        }

        Map<Id, AF_Handover__c> updates = new Map<Id, AF_Handover__c>();
        for (Id hoId : trafficFormHandoverIds) {
            updates.put(hoId, new AF_Handover__c(Id = hoId, AF_TrafficFormUploaded__c = true));
        }
        for (Id hoId : insuranceFormHandoverIds) {
            if (updates.containsKey(hoId)) {
                updates.get(hoId).AF_InsuranceFormUploaded__c = true;
            } else {
                updates.put(hoId, new AF_Handover__c(Id = hoId, AF_InsuranceFormUploaded__c = true));
            }
        }

        // System mode: this write only ever sets the checklist flag the upload itself just
        // satisfied. LFRDN-701 intentionally mutes rep Edit on these flags to stop manual ticking;
        // that FLS must not also block the automation that is the sole legitimate way to set them.
        Database.update(updates.values(), AccessLevel.SYSTEM_MODE);
    }
}