@isTest
private class AF_AppraisalApprovalGuardTest {

    private static AF_AppraisalApprovalGuard.Request req(Id appraisalId) {
        AF_AppraisalApprovalGuard.Request r = new AF_AppraisalApprovalGuard.Request();
        r.appraisalId = appraisalId;
        return r;
    }

    @isTest
    static void appraisalNotYetPendingIsNotFlaggedAsAlreadySubmitting() {
        AF_AppraisalApprovalGuard.mockApprovalStatuses = new List<String>{ null };

        Test.startTest();
        List<AF_AppraisalApprovalGuard.Result> results =
            AF_AppraisalApprovalGuard.checkAndLock(new List<AF_AppraisalApprovalGuard.Request>{ req(null) });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].alreadySubmitting);
    }

    @isTest
    static void appraisalAlreadyPendingIsFlaggedAsAlreadySubmitting() {
        AF_AppraisalApprovalGuard.mockApprovalStatuses = new List<String>{ 'Pending' };

        Test.startTest();
        List<AF_AppraisalApprovalGuard.Result> results =
            AF_AppraisalApprovalGuard.checkAndLock(new List<AF_AppraisalApprovalGuard.Request>{ req(null) });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].alreadySubmitting);
    }

    @isTest
    static void bulkRequestsAreEachEvaluatedIndependently() {
        AF_AppraisalApprovalGuard.mockApprovalStatuses = new List<String>{ 'Approved', 'Pending' };

        Test.startTest();
        List<AF_AppraisalApprovalGuard.Result> results = AF_AppraisalApprovalGuard.checkAndLock(
            new List<AF_AppraisalApprovalGuard.Request>{ req(null), req(null) }
        );
        Test.stopTest();

        System.assertEquals(2, results.size());
        System.assertEquals(false, results[0].alreadySubmitting);
        System.assertEquals(true, results[1].alreadySubmitting);
    }

    @isTest
    static void unknownAppraisalIdIsNotFlaggedAsAlreadySubmitting() {
        // No mock supplied: forces the real queryApprovalStatus() path. A null Id
        // matches no record (or the field is unreadable), so it must not block.
        AF_AppraisalApprovalGuard.mockApprovalStatuses = null;

        Test.startTest();
        List<AF_AppraisalApprovalGuard.Result> results =
            AF_AppraisalApprovalGuard.checkAndLock(new List<AF_AppraisalApprovalGuard.Request>{ req(null) });
        Test.stopTest();

        System.assertEquals(false, results[0].alreadySubmitting);
    }
}