// TC-016: approve step 1 on the Tier 3 quote, then REJECT at step 2.
Id QUOTE='0Q0FV004Bx7N72S0IS';
ProcessInstanceWorkitem wi=[SELECT Id FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId=:QUOTE AND ProcessInstance.Status='Pending' LIMIT 1];
wi.ActorId=UserInfo.getUserId(); update wi;
Approval.ProcessWorkitemRequest a=new Approval.ProcessWorkitemRequest();
a.setWorkitemId(wi.Id); a.setAction('Approve'); a.setComments('QA RS07 - step 1 approved');
System.debug('STEP1=' + Approval.process(a).getInstanceStatus());

ProcessInstanceWorkitem wi2=[SELECT Id FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId=:QUOTE AND ProcessInstance.Status='Pending' LIMIT 1];
wi2.ActorId=UserInfo.getUserId(); update wi2;
Approval.ProcessWorkitemRequest r=new Approval.ProcessWorkitemRequest();
r.setWorkitemId(wi2.Id); r.setAction('Reject'); r.setComments('QA RS07 - REJECTED at step 2, discount too high');
System.debug('STEP2_REJECT=' + Approval.process(r).getInstanceStatus());

Quote q=[SELECT AF_DiscountTier__c, AF_DiscountApprovalStatus__c FROM Quote WHERE Id=:QUOTE];
System.debug('FINAL tier=' + q.AF_DiscountTier__c + ' status=' + q.AF_DiscountApprovalStatus__c);
System.debug('REMAINING_WORKITEMS=' + [SELECT COUNT() FROM ProcessInstanceWorkitem WHERE ProcessInstance.TargetObjectId=:QUOTE AND ProcessInstance.Status='Pending']);
