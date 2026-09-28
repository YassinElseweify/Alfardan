/**
 * ALF-RS-12 (LFRDN-342) FR6: Flow cannot be triggered directly off ContentDocumentLink (confirmed
 * via a real deploy attempt - "A flow can't be triggered by ContentDocumentLink records"), so this
 * is a plain trigger instead. Keeps AF_Handover__c.AF_TrafficFormUploaded__c /
 * AF_InsuranceFormUploaded__c in sync whenever a file tagged (via AF_DocumentController's upload
 * path, ContentVersion.AF_FileUpload__c) "Traffic Form" or "Insurance Form" is linked to a
 * Handover record - these two documents are manual-upload-only per the BRD, never
 * Salesforce-generated, so this is their only path to true.
 *
 * LFRDN-736: AF_CreditNote_CancellationLinkService.sync now refuses to submit a cancellation's
 * refund Credit Note into approval until its required Refund Evidence document is actually
 * attached - it just leaves the record Pending, un-submitted, rather than erroring. If the rep
 * attaches the file late (via the Credit Note's own afDocumentComponent), nothing else would ever
 * retry that submission, so this trigger also re-attempts it for any Credit Note the new link is
 * on, once the just-uploaded file makes it eligible.
 *
 * LFRDN-754: same retry-on-upload pattern for a deal stuck at Take the Keys because
 * AF_Opportunity_ClosedWonPaymentGate refused over a missing Payment document (e.g. Bank Transfer
 * needing its Bank LPO) - AF_FL_Handover_AutoCloseWon only re-checks the gate when the Handover
 * itself is saved again, so uploading the missing Payment document alone never used to unstick it.
 */
trigger AF_ContentDocumentLink on ContentDocumentLink (after insert) {
    AF_HandoverUploadSyncService.syncFromLinks(Trigger.new);
    AF_CreditNote_CancellationLinkService.retrySubmissionForLinkedCreditNotes(Trigger.new);
    AF_PaymentDocumentCloseRetryService.retryCloseForLinkedPayments(Trigger.new);
}