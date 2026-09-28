Id F='006FV00Apphsqc0YEA', G='006FV00Apphx2l2YEA', H='006FV00Appi1Eu4YEE';
List<Appraisal> aps = new List<Appraisal>();
// F: fully Approved + Accepted -> deduction expected at quote creation
aps.add(new Appraisal(ReferenceRecordId=F, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='Accepted', FinalAppraisalValue=50000, Status='Completed'));
// G: Approved but outcome NOT Accepted -> no deduction, must not break quoting
aps.add(new Appraisal(ReferenceRecordId=G, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='In Progress', FinalAppraisalValue=35000, Status='Visit Scheduled'));
// H: pending -> will be approved+accepted AFTER the quote exists (retro path)
aps.add(new Appraisal(ReferenceRecordId=H, FinalAppraisalValue=22000, Status='Visit Scheduled'));
insert aps;
for (Appraisal a : aps) System.debug('APPR=' + a.Id + ' opp=' + a.ReferenceRecordId);
