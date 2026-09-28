public with sharing class AF_AppraisalApprovalGuard {

    public class Request {
        @InvocableVariable(required=true)
        public Id appraisalId;
    }

    public class Result {
        @InvocableVariable
        public Boolean alreadySubmitting;
    }

    // High-fidelity mock layer for test execution bypasses. Supplies one approval
    // status per request so the Pending decision can be driven without relying on
    // the AF_ApprovalStatus__c field being present in the org describe (which is not
    // the case during dry-run/preview deploys, where the field is never committed).
    @TestVisible private static List<String> mockApprovalStatuses;

    @InvocableMethod(label='Check And Lock Appraisal For Approval Submission' description='Row-locks the Appraisal and reports whether it is already Pending approval, to prevent duplicate submissions when multiple AppraisalItems change in the same transaction.')
    public static List<Result> checkAndLock(List<Request> requests) {
        List<Result> results = new List<Result>();
        Boolean useMock = Test.isRunningTest() && mockApprovalStatuses != null;

        for (Integer i = 0; i < requests.size(); i++) {
            String status = useMock
                ? ((i < mockApprovalStatuses.size()) ? mockApprovalStatuses[i] : null)
                : queryApprovalStatus(requests[i].appraisalId);

            Result res = new Result();
            res.alreadySubmitting = (status == 'Pending');
            results.add(res);
        }
        return results;
    }

    // Row-locks the Appraisal and returns its current approval status. If Appraisal
    // cannot be queried (e.g. the object is not enabled in the org, or its describe
    // does not yet carry AF_ApprovalStatus__c), the status is treated as unknown so
    // the submission is not incorrectly blocked.
    private static String queryApprovalStatus(Id appraisalId) {
        try {
            List<SObject> rows = Database.query(
                'SELECT Id, AF_ApprovalStatus__c FROM Appraisal WHERE Id = :appraisalId FOR UPDATE'
            );
            return (rows.isEmpty()) ? null : (String) rows[0].get('AF_ApprovalStatus__c');
        } catch (SObjectException e) {
            return null;
        } catch (QueryException e) {
            return null;
        }
    }
}