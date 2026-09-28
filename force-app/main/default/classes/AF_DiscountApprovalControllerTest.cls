/**
 * Covers AF_DiscountApprovalController (LFRDN-645 / LFRDN-646).
 *
 * The approval process AF_AP_Quote_DiscountTiers routes via the manager hierarchy,
 * which is not reliably populated in this org (LFRDN-647), so these tests do not
 * attempt to drive a real multi-step approval to completion. They exercise the
 * controller's own logic: the empty case, the guard on an unsupported action, and
 * per-row failure isolation when a work item id cannot be actioned.
 */
@IsTest
private class AF_DiscountApprovalControllerTest {

    private static Integer qidSeq = 0;

    private static User buildUser(String alias, Id managerId) {
        User u = new User(
            Alias = alias,
            Email = alias + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = alias,
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'GMT',
            Username = 'af.' + alias + '.' + DateTime.now().getTime() + Math.round(Math.random() * 100000) + '@example.com.lfrdn645',
            ManagerId = managerId
        );
        insert u;
        return u;
    }

    /**
     * getPendingApprovals queries WITH USER_MODE, so an approver without FLS on the
     * discount fields gets "No such column 'AF_DiscountAmount__c'" rather than an empty
     * result. Granting the sets a real approver holds keeps the test honest.
     */
    private static void grantQuoteAccess(List<User> users) {
        List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [
            SELECT Id FROM PermissionSet
            WHERE Name IN ('AF_PS_Quote_FullAccess', 'AF_PS_Opportunity_FullAccess', 'AF_PS_Account_FullAccess')
        ]) {
            for (User u : users) {
                grants.add(new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps.Id));
            }
        }
        insert grants;
    }

    private static Quote buildQuote() {
        qidSeq++;
        Account acc = new Account(Name = 'Approval Test Account', AF_QID__c = '9998887' + String.valueOf(7000 + qidSeq));
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Approval Test Opp',
            AccountId = acc.Id,
            StageName = 'Qualification',
            CloseDate = Date.today().addDays(30)
        );
        insert opp;

        Quote q = new Quote(
            Name = 'Approval Test Quote',
            OpportunityId = opp.Id,
            Pricebook2Id = Test.getStandardPricebookId(),
            AF_QuoteType__c = 'Customer Quotation'
        );
        insert q;
        return q;
    }

    @IsTest
    static void returnsEmptyWhenNothingPending() {
        Test.startTest();
        List<AF_DiscountApprovalController.PendingApproval> rows =
            AF_DiscountApprovalController.getPendingApprovals();
        Test.stopTest();

        System.assertEquals(0, rows.size(), 'A user with no assigned work items should see an empty queue');
    }

    /**
     * AF_AP_Quote_DiscountTiers resolves its first approver from the record owner's
     * Manager (useApproverFieldOfRecordOwner). The submitting user therefore needs a
     * Manager, or the submit fails and no work item is ever created — which is exactly
     * the production defect in LFRDN-647. The test builds that hierarchy explicitly so
     * the approver here is the running user, letting getPendingApprovals return a real
     * row and the bulk approve path act on it.
     */
    @IsTest
    static void pendingApprovalCarriesDiscountFiguresAndApproves() {
        // The tier-2 Quote below needs a second approval step, which resolves from the
        // first approver's own Manager - so the chain needs a head, or the approve call
        // fails with MANAGER_NOT_DEFINED (the production gap tracked as LFRDN-647).
        User seniorApprover = new User(
            Alias = 'afsnr',
            Email = 'af.senior@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'SeniorApprover',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'GMT',
            Username = 'af.senior.' + DateTime.now().getTime() + '@example.com.lfrdn645'
        );
        insert seniorApprover;

        User approver = new User(
            Alias = 'afappr',
            Email = 'af.approver@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Approver',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'GMT',
            Username = 'af.approver.' + DateTime.now().getTime() + '@example.com.lfrdn645',
            ManagerId = seniorApprover.Id
        );
        insert approver;

        User submitter = new User(
            Alias = 'afsubm',
            Email = 'af.submitter@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Submitter',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = UserInfo.getProfileId(),
            TimeZoneSidKey = 'GMT',
            Username = 'af.submitter.' + DateTime.now().getTime() + '@example.com.lfrdn645',
            ManagerId = approver.Id
        );
        insert submitter;

        // getPendingApprovals queries WITH USER_MODE, so a user without FLS on the
        // discount fields gets "No such column 'AF_DiscountAmount__c'" rather than an
        // empty result. Granting the same permission sets a real approver holds keeps
        // the test honest instead of weakening the query's security.
        List<PermissionSetAssignment> grants = new List<PermissionSetAssignment>();
        for (PermissionSet ps : [
            SELECT Id FROM PermissionSet
            WHERE Name IN ('AF_PS_Quote_FullAccess', 'AF_PS_Opportunity_FullAccess', 'AF_PS_Account_FullAccess')
        ]) {
            grants.add(new PermissionSetAssignment(AssigneeId = approver.Id, PermissionSetId = ps.Id));
            grants.add(new PermissionSetAssignment(AssigneeId = submitter.Id, PermissionSetId = ps.Id));
        }
        insert grants;

        Quote q;
        System.runAs(submitter) {
            q = buildQuote();
            q.OwnerId = submitter.Id;
            q.AF_DiscountAmount__c = 5000;
            q.AF_DiscountApprovalStatus__c = 'Pending';
            q.AF_DiscountTier__c = 2;
            update q;

            Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
            req.setObjectId(q.Id);
            req.setSubmitterId(submitter.Id);
            Approval.process(req, false);
        }

        Test.startTest();
        List<AF_DiscountApprovalController.PendingApproval> rows;
        List<AF_DiscountApprovalController.ApprovalResult> results;
        System.runAs(approver) {
            rows = AF_DiscountApprovalController.getPendingApprovals();

            List<Id> workItemIds = new List<Id>();
            for (AF_DiscountApprovalController.PendingApproval row : rows) {
                workItemIds.add(row.workItemId);
            }
            results = AF_DiscountApprovalController.processApprovals(workItemIds, 'Approve', 'bulk approved');
        }
        Test.stopTest();

        System.assertEquals(1, rows.size(), 'The approver should see exactly the one submitted Quote');
        System.assertEquals(q.Id, rows[0].recordId, 'The row must be the submitted Quote');
        System.assertEquals(5000, rows[0].amount, 'The discount figure must reach the approver (LFRDN-646)');
        System.assertEquals('Discount Approval', rows[0].approvalType, 'The row must name its approval type');
        System.assertNotEquals(null, rows[0].detail, 'The percent/tier detail must reach the approver (LFRDN-646)');

        System.assertEquals(1, results.size(), 'One work item in means one result out');
        System.assertEquals(true, results[0].success, 'The bulk approval should succeed: ' + results[0].message);
    }

    /**
     * Guards the keying of the work-item map. An earlier version keyed by Quote Id, so two
     * work items on the same Quote assigned to one approver collapsed into a single row and
     * a bulk approve silently left the other pending.
     */
    @IsTest
    static void everyAssignedWorkItemGetsItsOwnRow() {
        User approver = buildUser('afmulti', null);
        User submitter = buildUser('afmsub', approver.Id);
        grantQuoteAccess(new List<User>{ approver, submitter });

        List<Quote> quotes = new List<Quote>();
        System.runAs(submitter) {
            for (Integer i = 0; i < 2; i++) {
                Quote q = buildQuote();
                q.OwnerId = submitter.Id;
                q.AF_DiscountAmount__c = 1000 * (i + 1);
                q.AF_DiscountApprovalStatus__c = 'Pending';
                q.AF_DiscountTier__c = 1;
                update q;
                quotes.add(q);

                Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                req.setObjectId(q.Id);
                req.setSubmitterId(submitter.Id);
                Approval.process(req, false);
            }
        }

        Test.startTest();
        List<AF_DiscountApprovalController.PendingApproval> rows;
        System.runAs(approver) {
            rows = AF_DiscountApprovalController.getPendingApprovals();
        }
        Test.stopTest();

        System.assertEquals(2, rows.size(), 'Each pending work item must surface as its own row');

        Set<Id> workItemIds = new Set<Id>();
        for (AF_DiscountApprovalController.PendingApproval row : rows) {
            workItemIds.add(row.workItemId);
        }
        System.assertEquals(2, workItemIds.size(), 'Rows must carry distinct work item ids, not a shared one');
    }

    @IsTest
    static void emptyInputReturnsEmptyResults() {
        Test.startTest();
        List<AF_DiscountApprovalController.ApprovalResult> results =
            AF_DiscountApprovalController.processApprovals(new List<Id>(), 'Approve', null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'No work item ids means no results and no exception');
    }

    @IsTest
    static void nullInputReturnsEmptyResults() {
        Test.startTest();
        List<AF_DiscountApprovalController.ApprovalResult> results =
            AF_DiscountApprovalController.processApprovals(null, 'Approve', null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'A null list must be tolerated rather than dereferenced');
    }

    @IsTest
    static void rejectsUnsupportedAction() {
        Quote q = buildQuote();

        Test.startTest();
        Boolean threw = false;
        try {
            AF_DiscountApprovalController.processApprovals(new List<Id>{ q.Id }, 'Escalate', null);
        } catch (Exception e) {
            threw = true;
        }
        Test.stopTest();

        System.assert(threw, 'An action other than Approve/Reject should be refused');
    }

    @IsTest
    static void failureOnOneItemIsReportedNotThrown() {
        Quote q = buildQuote();

        // A Quote id is not a valid work item id, so Approval.process fails for this row.
        // The point of the assertion is that the failure is captured per row.
        Test.startTest();
        List<AF_DiscountApprovalController.ApprovalResult> results =
            AF_DiscountApprovalController.processApprovals(new List<Id>{ q.Id }, 'Approve', 'bulk test');
        Test.stopTest();

        System.assertEquals(1, results.size(), 'One id in means one result row out');
        System.assertEquals(false, results[0].success, 'An invalid work item id cannot succeed');
        System.assert(String.isNotBlank(results[0].message), 'A failed row must carry a message for the approver');
    }
}