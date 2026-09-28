// Walk the Tier 4 approval to completion. Reassigns each pending work item to the
// running admin (test-harness only, because the intermediate approvers' UI logins
// aren't available), then approves, so we can prove the chain traverses all 4 steps.
Id QUOTE='0Q0FV004Bx7IutQ0IS';
for (Integer i=0; i<5; i++) {
    List<ProcessInstanceWorkitem> wis = [SELECT Id, ActorId FROM ProcessInstanceWorkitem
        WHERE ProcessInstance.TargetObjectId=:QUOTE AND ProcessInstance.Status='Pending'];
    if (wis.isEmpty()) { System.debug('NO_MORE_WORKITEMS at iteration ' + i); break; }
    ProcessInstanceWorkitem wi = wis[0];
    wi.ActorId = UserInfo.getUserId();
    update wi;
    Approval.ProcessWorkitemRequest req = new Approval.ProcessWorkitemRequest();
    req.setWorkitemId(wi.Id);
    req.setAction('Approve');
    req.setComments('QA RS07 - walking escalation step ' + (i+2));
    try {
        Approval.ProcessResult r = Approval.process(req);
        System.debug('STEP' + (i+2) + '_APPROVED instanceStatus=' + r.getInstanceStatus());
    } catch (Exception e) {
        System.debug('STEP' + (i+2) + '_FAILED=' + e.getMessage());
        break;
    }
}
Quote q=[SELECT AF_DiscountTier__c, AF_DiscountApprovalStatus__c FROM Quote WHERE Id=:QUOTE];
System.debug('FINAL_QUOTE tier=' + q.AF_DiscountTier__c + ' status=' + q.AF_DiscountApprovalStatus__c);
