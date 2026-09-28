/**
 * ALF-RS-12 (LFRDN-342) FR6: Flow cannot be triggered directly off ContentDocumentLink (confirmed
 * via a real deploy attempt - "A flow can't be triggered by ContentDocumentLink records"), so this
 * is a plain trigger instead. Keeps AF_Handover__c.AF_TrafficFormUploaded__c /
 * AF_InsuranceFormUploaded__c in sync whenever a file tagged (via AF_DocumentController's upload
 * path, ContentVersion.AF_FileUpload__c) "Traffic Form" or "Insurance Form" is linked to a
 * Handover record - these two documents are manual-upload-only per the BRD, never
 * Salesforce-generated, so this is their only path to true.
 */
trigger AF_ContentDocumentLink on ContentDocumentLink (after insert) {
    AF_HandoverUploadSyncService.syncFromLinks(Trigger.new);
}