// Prove the Tier 4 chain resolves through all four DoA levels.
// Reassignment to the running admin is only so the harness can action each step;
// the ActorId captured BEFORE each reassignment is the real routing evidence.
Id QUOTE='0Q0FV004C28x1ky0IA';
for (Integer step=1; step<=5; step++) {
    List<ProcessInstanceWorkitem> wis = [SELECT Id, ActorId, Actor.Name FROM ProcessInstanceWorkitem
        WHERE ProcessInstance.TargetObjectId=:QUOTE AND ProcessInstance.Status='Pending'];
    if (wis.isEmpty()) { System.debug('CHAIN COMPLETE after ' + (step-1) + ' steps'); break; }
    ProcessInstanceWorkitem wi = wis[0];
    System.debug('STEP ' + step + ' ROUTED TO -> ' + wi.Actor.Name);
    wi.ActorId = UserInfo.getUserId();
    update wi;
    Approval.ProcessWorkitemRequest r = new Approval.ProcessWorkitemRequest();
    r.setWorkitemId(wi.Id); r.setAction('Approve'); r.setComments('chain verification step ' + step);
    try { System.debug('   approved -> instance now: ' + Approval.process(r).getInstanceStatus()); }
    catch (Exception e) { System.debug('   FAILED: ' + e.getMessage()); break; }
}
Quote q=[SELECT AF_DiscountTier__c, AF_DiscountApprovalStatus__c FROM Quote WHERE Id=:QUOTE];
System.debug('FINAL: tier=' + q.AF_DiscountTier__c + ' status=' + q.AF_DiscountApprovalStatus__c);
