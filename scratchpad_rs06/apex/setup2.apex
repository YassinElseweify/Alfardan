Id ACCT='001FV00Il8k5zHIYEY', MGR='005a3001tN3B1SeAQK';
Id PB_STD='01sa3000re0Wg8SAAS', PB_ALT='01sa3000re0jGZYAA2'; // Dream Cars and EV
Id V_INSTOCK='0vLFV0004GuzWgG2QU', M_ROMA='1PqFV0002jW7LI40AN';
Product2 roma=[SELECT Id FROM Product2 WHERE ProductCode='VEH-FER-ROMA' LIMIT 1];

// ensure the Roma has a PricebookEntry on the NON-standard pricebook
List<PricebookEntry> existing=[SELECT Id FROM PricebookEntry WHERE Product2Id=:roma.Id AND Pricebook2Id=:PB_ALT];
PricebookEntry altPbe;
if (existing.isEmpty()) {
    altPbe = new PricebookEntry(Product2Id=roma.Id, Pricebook2Id=PB_ALT, UnitPrice=250000, IsActive=true, UseStandardPrice=false);
    insert altPbe;
} else { altPbe = existing[0]; }
System.debug('ALT_PBE=' + altPbe.Id);

// F2: Sales Manager owned, STANDARD pricebook, trade-in happy path (TC-019)
Opportunity f2 = new Opportunity(Name='QA RS06 F2 TradeIn Accepted MGR', AccountId=ACCT, OwnerId=MGR,
    Pricebook2Id=PB_STD, StageName='Select', CloseDate=Date.today().addDays(45),
    AF_SelectedVehicle__c=V_INSTOCK, AF_VehicleModel__c=M_ROMA);
// K: Sales Manager owned, NON-STANDARD pricebook, trade-in (TC-024)
Opportunity k = new Opportunity(Name='QA RS06 K NonStdPricebook MGR', AccountId=ACCT, OwnerId=MGR,
    Pricebook2Id=PB_ALT, StageName='Select', CloseDate=Date.today().addDays(45),
    AF_SelectedVehicle__c=V_INSTOCK, AF_VehicleModel__c=M_ROMA);
insert new List<Opportunity>{f2, k};
System.debug('OPP_F2=' + f2.Id);
System.debug('OPP_K=' + k.Id);

PricebookEntry stdPbe=[SELECT Id FROM PricebookEntry WHERE Product2Id=:roma.Id AND Pricebook2Id=:PB_STD LIMIT 1];
insert new List<OpportunityLineItem>{
  new OpportunityLineItem(OpportunityId=f2.Id, PricebookEntryId=stdPbe.Id, Quantity=1, UnitPrice=247308,
      AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA,
      AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true),
  new OpportunityLineItem(OpportunityId=k.Id, PricebookEntryId=altPbe.Id, Quantity=1, UnitPrice=250000,
      AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA,
      AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true)
};

List<Appraisal> aps = new List<Appraisal>{
  new Appraisal(ReferenceRecordId=f2.Id, PurposeType='Trade-In', UsageType='Automotive', AF_Account__c=ACCT,
      AF_InitiatingSalesRep__c=MGR, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='Accepted', Status='Completed'),
  new Appraisal(ReferenceRecordId=k.Id, PurposeType='Trade-In', UsageType='Automotive', AF_Account__c=ACCT,
      AF_InitiatingSalesRep__c=MGR, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='Accepted', Status='Completed')};
insert aps;
List<AppraisalItem> items = new List<AppraisalItem>();
for (Appraisal a : aps) {
  items.add(new AppraisalItem(AppraisalId=a.Id, Type='Vehicle', InitialValue=40000, CustomerAskingValue=42000,
     ConditionType='Fair', Usage=70000, IsCustomized=false, AF_InspectionDone__c=true,
     AF_InspectionNotes__c='QA RS06 inspection ok', ModelYear='2022',
     IdentificationNumber='QARS06MGR'+String.valueOf(items.size()), LicensePlateNumber='QA-MGR-'+String.valueOf(items.size()),
     AF_MakeText__c='Porsche', AF_ModelText__c='Cayenne', AF_Source__c='Manual'));
}
insert items;
for (Appraisal a : aps) System.debug('MGR_APPR=' + a.Id + '|' + a.ReferenceRecordId);
