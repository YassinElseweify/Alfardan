// Reproduce exactly what AF_FL_Opp_CreateQuotation does for OPP F
Id OPP='006FV00Apphsqc0YEA';
Opportunity o = [SELECT Id, Name, Pricebook2Id FROM Opportunity WHERE Id=:OPP];
Quote q = new Quote(Name='QA RS06 F repro', OpportunityId=o.Id, Pricebook2Id=o.Pricebook2Id, AF_QuoteType__c='Customer Quotation');
insert q;
System.debug('QUOTE_OK=' + q.Id);

Appraisal a = [SELECT Id, FinalAppraisalValue, AF_ApprovalStatus__c, AF_TradeInOutcome__c
               FROM Appraisal WHERE ReferenceRecordId=:OPP
               AND AF_ApprovalStatus__c='Approved' AND AF_TradeInOutcome__c='Accepted' LIMIT 1];
System.debug('APPRAISAL=' + a.Id + ' value=' + a.FinalAppraisalValue);

Product2 p = [SELECT Id FROM Product2 WHERE ProductCode='AF-TRADEIN-DEDUCT' LIMIT 1];
PricebookEntry pbe = [SELECT Id, UnitPrice, IsActive FROM PricebookEntry
                      WHERE Product2Id=:p.Id AND Pricebook2Id=:o.Pricebook2Id AND IsActive=true LIMIT 1];
System.debug('PBE=' + pbe.Id);

QuoteLineItem qli = new QuoteLineItem(
    QuoteId=q.Id, Product2Id=p.Id, PricebookEntryId=pbe.Id, Quantity=1,
    UnitPrice = a.FinalAppraisalValue * -1,
    AF_LineItemType__c='Trade-In Deduction', AF_RelatedTradeIn__c=a.Id,
    AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true);
try {
    insert qli;
    System.debug('DEDUCTION_LINE_OK=' + qli.Id);
} catch (Exception e) {
    System.debug('DEDUCTION_FAILED=' + e.getMessage());
}
