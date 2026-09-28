/**
 * ALF-RS-12 (LFRDN-342) - Flow-facing gate for the AF_Document__mdt required-documents engine.
 * Wraps AF_DocumentService.checkDocumentsUploaded as an @InvocableMethod so a before-save or
 * screen Flow (e.g. the AF_Handover__c checklist gate, or a future Closed Won / Sales Order gate)
 * can check "are all required documents uploaded for this record" the same way regardless of
 * which object's AF_DynamicObject__mdt row applies - mirrors how AF_ReservationContractService
 * and AF_Opportunity_ClosedWonPaymentGate return a message rather than throwing, so the Flow can
 * surface it to the rep.
 */
public with sharing class AF_DocumentGateCheck {

    public class Request {
        @InvocableVariable(required=true label='Record Id')
        public Id recordId;
    }

    public class Result {
        @InvocableVariable public Boolean allUploaded;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Check Required Documents Uploaded'
        description='ALF-RS-12: returns whether every AF_Document__mdt row required for this record (per its AF_DynamicObject__mdt/AF_DocumentCondition__mdt configuration) has a matching uploaded or generated file.'
    )
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        List<Id> recordIds = new List<Id>();
        for (Request req : requests) {
            recordIds.add(req.recordId);
        }

        Map<String, List<AF_Document__mdt>> required;
        try {
            required = AF_DocumentService.getRequiredDocuments(recordIds, false);
        } catch (Exception e) {
            for (Request req : requests) {
                Result res = new Result();
                res.allUploaded = false;
                res.message = 'Could not evaluate required documents: ' + e.getMessage();
                results.add(res);
            }
            return results;
        }

        Map<Id, Boolean> uploaded = AF_DocumentService.checkDocumentsUploaded(recordIds, required);

        for (Request req : requests) {
            Result res = new Result();
            res.allUploaded = uploaded.get(req.recordId) == true;
            res.message = res.allUploaded
                ? 'All required documents are uploaded.'
                : 'One or more required documents are missing. Upload or generate them before continuing.';
            results.add(res);
        }

        return results;
    }
}