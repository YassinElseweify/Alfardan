/**
 * LFRDN-729/732 - the Opportunity's own cancellation approval (AF_AP_Opp_Cancellation) and its
 * linked refund Credit Note's approval (AF_AP_CreditNote_Cancellation) were entirely independent:
 * both auto-submitted the moment they were created, to the same approver, with no coupling at
 * all - a rejected cancellation left its refund Pending forever, and a second cancellation
 * request created a second, duplicate Pending Credit Note. Called from an after-save Flow on
 * Opportunity watching AF_CancellationApprovalStatus__c reaching Approved/Rejected.
 *
 * On Approved: submits the linked Pending Credit Note into its own approval process - it is
 * created but never submitted; see AF_FL_CreditNote_SubmitApproval's amended criteria.
 * On Rejected: rejects the linked Credit Note's own pending approval work item via Approval.process
 * (there is no "Cancelled/Withdrawn" AF_ApprovalStatus__c value, and AF_AP_CreditNote_Cancellation
 * does not allow Recall, so an Apex-driven Reject is the only way to close it out) rather than
 * leaving it Pending in the approver's queue for an approval that no longer applies.
 *
 * LFRDN-736 fix: AF_EvidenceReference__c was a free-text field with nothing behind it - typing
 * "see customer email" satisfied AF_VR_CreditNote_EvidenceRequired with no real file ever
 * attached or checked. The org already has a CreditNote row in the AF_Document__mdt
 * required-documents engine (AF_Document.CreditNote_RefundEvidence, required for every Credit
 * Note) - it just was never actually gated on. Submission to Approved is now blocked (Credit Note
 * stays Pending, not left un-actioned) until AF_DocumentService confirms a real file tagged for
 * that requirement is attached to the Credit Note.
 *
 * LFRDN-761 fix: AF_AP_CreditNote_Cancellation routes to the Credit Note owner's Manager, same as
 * every other approval process in this org - but this org's sharing is Private/BU-group-based, not
 * role-hierarchy, so a Manager outside the deal's BU had no access to the Credit Note or its
 * Opportunity (confirmed live, CN-00031/QA ShowroomManager2). shareWithApproverManager inserts the
 * same OpportunityShare/AF_CreditNote__Share (Edit/Manual) pattern as every other LFRDN-707/728/762
 * fix, right before Approval.process submits.
 *
 * LFRDN-729 QA-rejected re-fix: the On-Rejected path above only ever worked if the Credit Note had
 * already been submitted (a ProcessInstanceWorkitem existed to reject) - but per this class's own
 * design, a cancellation-reason Credit Note is normally never submitted until the Opportunity's own
 * cancellation is Approved, so on Rejected there was usually nothing to reject and the Credit Note
 * silently stayed Pending forever (confirmed live, CN-00032). AF_VR_CreditNote_NoDirectApprovalSet
 * blocks a direct field edit to close it out (Approval-process actions are the only path exempted
 * from that rule) - so a never-submitted Credit Note being rejected is now first submitted (bypassing
 * the document-readiness gate, since it's being closed out, not genuinely processed) and then
 * immediately rejected through Approval.process, the same real approval-process path the validation
 * rule expects.
 */
public without sharing class AF_CreditNote_CancellationLinkService {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;

        @InvocableVariable(required=true label='Cancellation Approved')
        public Boolean cancellationApproved;
    }

    @InvocableMethod(
        label='Sync Credit Note to Cancellation Outcome'
        description='LFRDN-729/732: submits the linked refund Credit Note on cancellation approval, or rejects its pending approval on cancellation rejection.'
    )
    public static void sync(List<Request> requests) {
        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }
        if (opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, AF_CreditNote__c> pendingCreditNoteByOpportunity = new Map<Id, AF_CreditNote__c>();
        for (AF_CreditNote__c cn : [
            SELECT Id, AF_Opportunity__c, AF_ApprovalStatus__c
            FROM AF_CreditNote__c
            WHERE AF_Opportunity__c IN :opportunityIds
              AND AF_ApprovalStatus__c = 'Pending'
              AND AF_Reason__c = 'Cancellation'
            WITH SYSTEM_MODE
        ]) {
            pendingCreditNoteByOpportunity.put(cn.AF_Opportunity__c, cn);
        }
        if (pendingCreditNoteByOpportunity.isEmpty()) {
            return;
        }

        List<AF_CreditNote__c> toSubmit = new List<AF_CreditNote__c>();
        List<Id> toReject = new List<Id>();
        for (Request req : requests) {
            AF_CreditNote__c cn = pendingCreditNoteByOpportunity.get(req.opportunityId);
            if (cn == null) {
                continue;
            }
            if (req.cancellationApproved == true) {
                toSubmit.add(cn);
            } else {
                toReject.add(cn.Id);
            }
        }

        if (!toSubmit.isEmpty()) {
            List<Id> toSubmitIds = new List<Id>();
            for (AF_CreditNote__c cn : toSubmit) {
                toSubmitIds.add(cn.Id);
            }
            submitIfDocumentsReady(toSubmitIds);
        }

        if (!toReject.isEmpty()) {
            Map<Id, Id> workItemIdByCreditNoteId = new Map<Id, Id>();
            for (ProcessInstanceWorkitem wi : [
                SELECT Id, ProcessInstance.TargetObjectId
                FROM ProcessInstanceWorkitem
                WHERE ProcessInstance.TargetObjectId IN :toReject
                WITH SYSTEM_MODE
            ]) {
                workItemIdByCreditNoteId.put(wi.ProcessInstance.TargetObjectId, wi.Id);
            }

            // LFRDN-729 QA-rejected re-fix: the common case is that this Credit Note was never
            // submitted at all (LFRDN-729's own earlier fix restricts submission to Approved
            // cancellations only), so there is no ProcessInstanceWorkitem to reject - the old
            // code silently did nothing for exactly this case, leaving finance looking at a live
            // Pending refund for a cancellation that was refused. AF_VR_CreditNote_NoDirectApprovalSet
            // blocks a direct field edit to AF_FinanceStatus__c/AF_ApprovalStatus__c outside the
            // real Approval Process, so a never-submitted Credit Note is first submitted (bypassing
            // the document-readiness gate, since it is being closed out, not genuinely processed),
            // then immediately rejected through Approval.process - the only path this validation
            // rule exempts.
            List<Id> toSubmitThenReject = new List<Id>();
            for (Id cnId : toReject) {
                if (!workItemIdByCreditNoteId.containsKey(cnId)) {
                    toSubmitThenReject.add(cnId);
                }
            }
            if (!toSubmitThenReject.isEmpty()) {
                for (Id cnId : toSubmitThenReject) {
                    Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
                    submitRequest.setObjectId(cnId);
                    submitRequest.setProcessDefinitionNameOrId('AF_AP_CreditNote_Cancellation');
                    Approval.ProcessResult submitResult = Approval.process(submitRequest, false);
                    if (submitResult.isSuccess() && !submitResult.getNewWorkitemIds().isEmpty()) {
                        workItemIdByCreditNoteId.put(cnId, submitResult.getNewWorkitemIds()[0]);
                    }
                }
            }

            for (Id cnId : toReject) {
                Id workItemId = workItemIdByCreditNoteId.get(cnId);
                if (workItemId == null) {
                    continue;
                }
                Approval.ProcessWorkitemRequest rejectRequest = new Approval.ProcessWorkitemRequest();
                rejectRequest.setWorkitemId(workItemId);
                rejectRequest.setAction('Reject');
                rejectRequest.setComments('Automatically rejected: the linked Opportunity cancellation request was rejected.');
                Approval.process(rejectRequest, false);
            }
        }
    }

    /**
     * LFRDN-736: called from the ContentDocumentLink trigger whenever a file is newly attached.
     * If any of the linked records is a Credit Note that is Pending, tagged Cancellation, and not
     * yet submitted (no ProcessInstance exists for it), retries submission now that a document may
     * have made it eligible - this is what lets a rep who attaches the evidence file late actually
     * get their refund moving, instead of it silently sitting Pending forever.
     */
    public static void retrySubmissionForLinkedCreditNotes(List<ContentDocumentLink> links) {
        Set<Id> linkedRecordIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            if (link.LinkedEntityId != null && link.LinkedEntityId.getSObjectType() == AF_CreditNote__c.SObjectType) {
                linkedRecordIds.add(link.LinkedEntityId);
            }
        }
        if (linkedRecordIds.isEmpty()) {
            return;
        }

        Set<Id> alreadySubmitted = new Set<Id>();
        for (ProcessInstance pi : [
            SELECT TargetObjectId FROM ProcessInstance WHERE TargetObjectId IN :linkedRecordIds WITH SYSTEM_MODE
        ]) {
            alreadySubmitted.add(pi.TargetObjectId);
        }

        List<Id> candidateIds = new List<Id>();
        for (AF_CreditNote__c cn : [
            SELECT Id
            FROM AF_CreditNote__c
            WHERE Id IN :linkedRecordIds
              AND AF_ApprovalStatus__c = 'Pending'
              AND AF_Reason__c = 'Cancellation'
            WITH SYSTEM_MODE
        ]) {
            if (!alreadySubmitted.contains(cn.Id)) {
                candidateIds.add(cn.Id);
            }
        }
        if (!candidateIds.isEmpty()) {
            submitIfDocumentsReady(candidateIds);
        }
    }

    private static void submitIfDocumentsReady(List<Id> creditNoteIds) {
        Map<String, List<AF_Document__mdt>> required = AF_DocumentService.getRequiredDocuments(creditNoteIds, false);
        Map<Id, Boolean> uploaded = AF_DocumentService.checkDocumentsUploaded(creditNoteIds, required);

        List<Id> readyIds = new List<Id>();
        for (Id cnId : creditNoteIds) {
            if (uploaded.get(cnId) == true) {
                readyIds.add(cnId);
            }
        }
        if (readyIds.isEmpty()) {
            return;
        }

        shareWithApproverManager(readyIds);

        List<AF_CreditNote__c> submittedTouch = new List<AF_CreditNote__c>();
        for (Id cnId : readyIds) {
            Approval.ProcessSubmitRequest submitRequest = new Approval.ProcessSubmitRequest();
            submitRequest.setObjectId(cnId);
            submitRequest.setProcessDefinitionNameOrId('AF_AP_CreditNote_Cancellation');
            Approval.ProcessResult submitResult = Approval.process(submitRequest, false);
            if (submitResult.isSuccess()) {
                submittedTouch.add(new AF_CreditNote__c(Id = cnId, AF_ApprovalSubmittedAt__c = System.now()));
            }
        }
        if (!submittedTouch.isEmpty()) {
            // LFRDN-736: AF_ApprovalStatus__c is already Pending from creation and Approval.process
            // itself never changes it, so this is the only field write AF_FL_CreditNote_ApprovalRequested
            // can actually react to that is unique to a genuine submission - see that flow's own
            // description for the full timing story.
            update submittedTouch;
        }
    }

    private static void shareWithApproverManager(List<Id> creditNoteIds) {
        Map<Id, AF_CreditNote__c> creditNoteById = new Map<Id, AF_CreditNote__c>([
            SELECT Id, OwnerId, AF_Opportunity__c
            FROM AF_CreditNote__c
            WHERE Id IN :creditNoteIds
            WITH SYSTEM_MODE
        ]);

        Set<Id> ownerIds = new Set<Id>();
        for (AF_CreditNote__c cn : creditNoteById.values()) {
            if (cn.OwnerId != null) {
                ownerIds.add(cn.OwnerId);
            }
        }
        Map<Id, Id> managerIdByOwnerId = new Map<Id, Id>();
        for (User u : [SELECT Id, ManagerId FROM User WHERE Id IN :ownerIds WITH SYSTEM_MODE]) {
            if (u.ManagerId != null) {
                managerIdByOwnerId.put(u.Id, u.ManagerId);
            }
        }

        List<SObject> sharesToInsert = new List<SObject>();
        for (AF_CreditNote__c cn : creditNoteById.values()) {
            Id managerId = managerIdByOwnerId.get(cn.OwnerId);
            if (managerId == null) {
                continue;
            }

            SObject cnShare = Schema.getGlobalDescribe().get('AF_CreditNote__Share').newSObject();
            cnShare.put('ParentId', cn.Id);
            cnShare.put('UserOrGroupId', managerId);
            cnShare.put('AccessLevel', 'Edit');
            cnShare.put('RowCause', 'Manual');
            sharesToInsert.add(cnShare);

            if (cn.AF_Opportunity__c != null) {
                sharesToInsert.add(new OpportunityShare(
                    OpportunityId = cn.AF_Opportunity__c,
                    UserOrGroupId = managerId,
                    OpportunityAccessLevel = 'Edit',
                    RowCause = Schema.OpportunityShare.RowCause.Manual
                ));
            }
        }

        if (!sharesToInsert.isEmpty()) {
            Database.insert(sharesToInsert, false);
        }
    }
}