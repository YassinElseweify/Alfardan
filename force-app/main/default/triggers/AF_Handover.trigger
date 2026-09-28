/**
 * LFRDN-709: AF_Handover__c was deployed Public Read/Write, so every business unit could open,
 * edit and download every other unit's customer contracts (the handover agreements) - now Private,
 * with AF_ChildRecordSharingService replacing the access Opportunity's own AF_SR_Opportunity_*
 * sharing rules used to provide implicitly. Only calls it on insert or when AF_Opportunity__c
 * actually changed, so a handover being edited for unrelated reasons doesn't re-share it every
 * save. First trigger on this object - governance here has otherwise been entirely Flow-based.
 *
 * LFRDN-711: AF_CustomerSignOff__c was a free picklist a rep could set to "Physically Signed"
 * with zero files attached to the Handover - nothing checked for a real signed document, so a
 * deal could reach Closed Won/Delivered on an unsigned handover. Blocked in before context (a
 * validation rule can't do cross-object SOQL) whenever the value is changing TO Physically
 * Signed and no ContentDocumentLink on the record is tagged as one of the 5 signed agreements
 * or the Delivery Note (the same AF_FileUpload__c document names AF_HandoverDocumentService
 * already generates/tags).
 *
 * LFRDN-722: AF_FL_Handover_GenerateDocuments used to pass bypassGates=true unconditionally, so
 * every click of the Generate Documents button re-printed and re-attached all 6 documents even
 * when nothing had changed - fixed there to bypassGates=false, so it now only fills in documents
 * genuinely missing (AF_HandoverDocumentService.isAlreadyComplete blocks the rest). That means a
 * document can never auto-regenerate just because a field it prints (e.g. AF_RepairRemarks__c)
 * changed after it was first generated - so this trigger resets the one completion flag whose
 * printed content depends on a field that changes after initial generation, letting the next
 * Generate Documents click naturally pick up just that document without a global bypass.
 */
trigger AF_Handover on AF_Handover__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            for (AF_Handover__c ho : Trigger.new) {
                AF_Handover__c old = Trigger.oldMap.get(ho.Id);
                if (ho.AF_RepairRemarks__c != old.AF_RepairRemarks__c && ho.AF_VehicleRepairDisclaimerComplete__c == true) {
                    ho.AF_VehicleRepairDisclaimerComplete__c = false;
                }
            }
        }

        Set<String> SIGNED_DOCUMENT_NAMES = new Set<String>{
            AF_HandoverDocumentService.DOC_VEHICLE_SALE_AGREEMENT,
            AF_HandoverDocumentService.DOC_WARRANTY_AGREEMENT,
            AF_HandoverDocumentService.DOC_SERVICE_CONTRACT_AGREEMENT,
            AF_HandoverDocumentService.DOC_VEHICLE_REPAIR_DISCLAIMER,
            AF_HandoverDocumentService.DOC_BUYER_ACKNOWLEDGEMENT,
            AF_HandoverDocumentService.DOC_DELIVERY_NOTE
        };

        Set<Id> handoverIdsToCheck = new Set<Id>();
        for (AF_Handover__c ho : Trigger.new) {
            AF_Handover__c old = Trigger.isUpdate ? Trigger.oldMap.get(ho.Id) : null;
            Boolean becomingSigned = ho.AF_CustomerSignOff__c == 'Physically Signed'
                && (old == null || old.AF_CustomerSignOff__c != 'Physically Signed');
            if (becomingSigned && ho.Id != null) {
                handoverIdsToCheck.add(ho.Id);
            } else if (becomingSigned && ho.Id == null) {
                // A brand-new Handover cannot possibly have an uploaded file yet.
                ho.AF_CustomerSignOff__c.addError('Customer Sign-Off cannot be set to Physically Signed until a signed handover document is attached to this Handover.');
            }
        }

        if (!handoverIdsToCheck.isEmpty()) {
            Set<Id> handoverIdsWithSignedDoc = new Set<Id>();
            for (ContentDocumentLink link : [
                SELECT LinkedEntityId, ContentDocument.LatestPublishedVersion.AF_FileUpload__c
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :handoverIdsToCheck
                  AND ContentDocument.LatestPublishedVersion.AF_FileUpload__c IN :SIGNED_DOCUMENT_NAMES
                WITH SYSTEM_MODE
            ]) {
                handoverIdsWithSignedDoc.add(link.LinkedEntityId);
            }

            for (AF_Handover__c ho : Trigger.new) {
                if (handoverIdsToCheck.contains(ho.Id) && !handoverIdsWithSignedDoc.contains(ho.Id)) {
                    ho.AF_CustomerSignOff__c.addError('Customer Sign-Off cannot be set to Physically Signed until a signed handover document is attached to this Handover.');
                }
            }
        }
    }

    if (Trigger.isAfter) {
        List<AF_Handover__c> recordsNeedingShare = new List<AF_Handover__c>();
        for (AF_Handover__c ho : Trigger.new) {
            AF_Handover__c old = Trigger.isUpdate ? Trigger.oldMap.get(ho.Id) : null;
            if (ho.AF_Opportunity__c != null && (old == null || old.AF_Opportunity__c != ho.AF_Opportunity__c)) {
                recordsNeedingShare.add(ho);
            }
        }
        if (!recordsNeedingShare.isEmpty()) {
            AF_ChildRecordSharingService.shareWithBusinessUnitAccess(recordsNeedingShare, AF_Handover__c.SObjectType);
        }
    }
}