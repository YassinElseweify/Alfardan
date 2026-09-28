// Faithful reproduction of AF_FL_Opp_CreateQuotation's trade-in branch on a NON-STANDARD pricebook
Id OPP='006FV00ApfE3pmGYER'; // QA RS06 K NonStdPricebook MGR
Opportunity o=[SELECT Id, Name, Pricebook2Id, Pricebook2.Name FROM Opportunity WHERE Id=:OPP];
System.debug('OPP_PRICEBOOK=' + o.Pricebook2.Name + ' (' + o.Pricebook2Id + ')');

Quote q=new Quote(Name='QA RS06 K repro', OpportunityId=o.Id, Pricebook2Id=o.Pricebook2Id, AF_QuoteType__c='Customer Quotation');
insert q;
System.debug('QUOTE_CREATED=' + q.Id);

Appraisal a=[SELECT Id, FinalAppraisalValue FROM Appraisal WHERE ReferenceRecordId=:OPP
             AND AF_ApprovalStatus__c='Approved' AND AF_TradeInOutcome__c='Accepted' LIMIT 1];
Product2 p=[SELECT Id FROM Product2 WHERE ProductCode='AF-TRADEIN-DEDUCT' LIMIT 1];
System.debug('TRADEIN_PRODUCT=' + p.Id);

// This is the flow's Get_TradeIn_PricebookEntry lookup
List<PricebookEntry> pbes=[SELECT Id FROM PricebookEntry
     WHERE Product2Id=:p.Id AND Pricebook2Id=:o.Pricebook2Id AND IsActive=true];
System.debug('TRADEIN_PBE_FOUND_ON_THIS_PRICEBOOK=' + pbes.size());

if (pbes.isEmpty()) {
    System.debug('RESULT=NO_PRICEBOOKENTRY - flow would pass a null PricebookEntryId');
    try {
        insert new QuoteLineItem(QuoteId=q.Id, Product2Id=p.Id, PricebookEntryId=null, Quantity=1,
            UnitPrice=a.FinalAppraisalValue*-1, AF_LineItemType__c='Trade-In Deduction',
            AF_RelatedTradeIn__c=a.Id, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true);
        System.debug('UNEXPECTED_SUCCESS');
    } catch (Exception e) { System.debug('DEDUCTION_FAILS_WITH=' + e.getMessage()); }
}
delete q;
System.debug('CLEANED_UP');
