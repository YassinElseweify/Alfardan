Id ACCT='001FV00Il8k5zHIYEY', REP='005a3001tN36pJcAQI', MGR='005a3001tN3B1SeAQK', PB='01sa3000re0Wg8SAAS';
Id V_ROMA='0vLFV0004GuzWgG2QU', M_ROMA='1PqFV0002jW7LI40AN';

// --- TEST HARNESS HIERARCHY (disclosed to the user) ---
// As found: Sales Rep -> "Alfardan Salesforce" (integration account) -> no manager.
// Nobody can log in as that account, so no approval was actionable at all.
// Set Rep -> Sales Manager so Tier 1 can be approved by a real persona,
// and leave Sales Manager with NO manager so Tier 2+ still hits the real
// MANAGER_NOT_DEFINED wall. The defect is unchanged; it just moves one seat along.
update new List<User>{
  new User(Id=REP, ManagerId=MGR),
  new User(Id=MGR, ManagerId=null)
};

Opportunity o = new Opportunity(Name='DEMO RS07 Discount Harness', AccountId=ACCT, OwnerId=REP,
  Pricebook2Id=PB, StageName='Select', CloseDate=Date.today().addDays(60),
  AF_SelectedVehicle__c=V_ROMA, AF_VehicleModel__c=M_ROMA);
insert o;
System.debug('RS07_DEMO_OPP=' + o.Id);

List<String> labels = new List<String>{
 '01 - Tier 0 self-authorised (enter 1000)',
 '02 - Boundary exactly 2 percent (enter 2000)',
 '03 - Boundary 2.01 percent (enter 2010)',
 '04 - Tier 1 approve end to end (enter 2500)',
 '05 - Tier 2 escalation wall (enter 4000)',
 '06 - Tier 4 CEO level (enter 10000)',
 '07 - Rejection path (enter 2600)',
 '08 - Bulk inbox A (enter 2200)',
 '09 - Bulk inbox B (enter 2300)',
 '10 - Bulk inbox C (enter 2400)',
 '11 - Negative discount (enter -5000)',
 '12 - Over 100 percent fail-safe (enter 150000)',
 '13 - Line-level bypass (discount the LINE by 20000)',
 '14 - Does the discount change the price (enter 10000)'};

List<Quote> qs = new List<Quote>();
for (String l : labels) {
  qs.add(new Quote(Name='DEMO RS07 ' + l, OpportunityId=o.Id, Pricebook2Id=PB,
      AF_QuoteType__c='Customer Quotation', OwnerId=REP));
}
insert qs;

PricebookEntry pbe=[SELECT Id FROM PricebookEntry WHERE Product2.ProductCode='VEH-FER-ROMA' AND Pricebook2Id=:PB LIMIT 1];
List<QuoteLineItem> lines = new List<QuoteLineItem>();
for (Quote q : qs) {
  lines.add(new QuoteLineItem(QuoteId=q.Id, PricebookEntryId=pbe.Id, Quantity=1, UnitPrice=100000,
      AF_LineItemType__c='Vehicle', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
}
insert lines;

for (Integer i=0;i<qs.size();i++) System.debug('RS07Q_' + labels[i].substring(0,2) + '=' + qs[i].Id);
System.debug('HIERARCHY: Rep -> Sales Manager -> (none)');
