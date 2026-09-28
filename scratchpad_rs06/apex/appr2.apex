Id F='006FV00Apphsqc0YEA', G='006FV00Apphx2l2YEA', H='006FV00Appi1Eu4YEE';
List<Appraisal> aps = new List<Appraisal>();
aps.add(new Appraisal(ReferenceRecordId=F, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='Accepted', Status='Completed'));
aps.add(new Appraisal(ReferenceRecordId=G, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='In Progress', Status='Visit Scheduled'));
aps.add(new Appraisal(ReferenceRecordId=H, Status='Visit Scheduled'));
insert aps;
for (Appraisal a : aps) System.debug('APPR=' + a.Id + '|opp=' + a.ReferenceRecordId);
