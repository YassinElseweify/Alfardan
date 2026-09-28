Id OPP='006FV00AqRuCIjsYUG', PB='01sa3000re0Wg8SAAS';
PricebookEntry pbe=[SELECT Id FROM PricebookEntry WHERE Product2.ProductCode='VEH-FER-ROMA' AND Pricebook2Id=:PB LIMIT 1];
List<String> labels=new List<String>{
  'H1-tier1-approve','H2-tier4-escalate','H3-tier3-reject',
  'H4-bulk-1','H5-bulk-2','H6-bulk-3','H7-selfapprove','H8-tierfield-tamper'};
List<Quote> qs=new List<Quote>();
for (String l : labels)
  qs.add(new Quote(Name='QA RS07 '+l, OpportunityId=OPP, Pricebook2Id=PB, AF_QuoteType__c='Customer Quotation'));
insert qs;
List<QuoteLineItem> lines=new List<QuoteLineItem>();
for (Quote q : qs)
  lines.add(new QuoteLineItem(QuoteId=q.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100000,
     AF_LineItemType__c='Vehicle', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
insert lines;
for (Integer i=0;i<qs.size();i++) System.debug('RS07_'+labels[i]+'='+qs[i].Id);
