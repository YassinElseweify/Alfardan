Id ACCT='001FV00Il8k5zHIYEY', REP='005a3001tN36pJcAQI', PB='01sa3000re0Wg8SAAS';
Id V='0vLFV0004GuzWgG2QU', M='1PqFV0002jW7LI40AN';
PricebookEntry pbe=[SELECT Id FROM PricebookEntry WHERE Product2.ProductCode='VEH-FER-ROMA' AND Pricebook2Id=:PB LIMIT 1];

Opportunity o=new Opportunity(Name='QA RS07 Discount Harness', AccountId=ACCT, OwnerId=REP, Pricebook2Id=PB,
   StageName='Select', CloseDate=Date.today().addDays(45), AF_SelectedVehicle__c=V, AF_VehicleModel__c=M);
insert o;
System.debug('RS07_OPP=' + o.Id);

// 20 quotes, each with a single 100,000 line so Subtotal = 100000 (1% = 1000)
List<String> labels = new List<String>{
 'Q01-pct-calc','Q02-tier0-1pct','Q03-bound-2.00','Q04-bound-2.01','Q05-bound-1.99',
 'Q06-tier1-2.5','Q07-tier2-4','Q08-tier3-6','Q09-tier4-10','Q10-over100',
 'Q11-negative','Q12-zerosubtotal','Q13-zerodiscount','Q14-linelevel','Q15-bulk-a',
 'Q16-bulk-b','Q17-bulk-c','Q18-approved-then-change','Q19-reject-then-revise','Q20-unrelated-save',
 'Q21-change-while-pending','Q22-bound-3.00','Q23-bound-5.00','Q24-bound-7.00','Q25-bound-100'};
List<Quote> qs=new List<Quote>();
for (String l : labels) {
  qs.add(new Quote(Name='QA RS07 '+l, OpportunityId=o.Id, Pricebook2Id=PB, AF_QuoteType__c='Customer Quotation'));
}
insert qs;
List<QuoteLineItem> lines=new List<QuoteLineItem>();
for (Integer i=0;i<qs.size();i++) {
  // Q12 deliberately gets NO line item so Subtotal stays 0
  if (labels[i]=='Q12-zerosubtotal') continue;
  lines.add(new QuoteLineItem(QuoteId=qs[i].Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100000,
     AF_LineItemType__c='Vehicle', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
}
insert lines;
for (Integer i=0;i<qs.size();i++) System.debug('RS07_'+labels[i]+'='+qs[i].Id);
