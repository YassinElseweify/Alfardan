Id ACCT='001FV00Il8k5zHIYEY', REP='005a3001tN36pJcAQI', PB='01sa3000re0Wg8SAAS';
Id V_ROMA='0vLFV0004GuzWgG2QU',  M_ROMA='1PqFV0002jW7LI40AN';
Id V_296='0vLFV0004H8Whoi2QC',   M_296='1PqFV0002jWBXR60AP';
Id V_PHANB='0vLFV0004HgMeeq2QC', M_PHAN='1PqFV0002jWO7sC0AT';
Id V_CULLG='0vLFV0004HttpnI2QQ', M_CULL='1PqFV0002jWSK1E0AX';
Id V_SF90='0vLFV0004HSpTWO2Q3',  M_SF90='1PqFV0002jWJvjA0AT';
Id V_PURO='0vLFV0004HM3sxA2QR',  M_PURO='1PqFV0002jWFja80AD';
Id V_CULLS='0vLFV0004Hn8FE42QM';
Id V_PHANW='0vLFV0004HZb45c2QB';

Map<String,Opportunity> o = new Map<String,Opportunity>();
o.put('01', new Opportunity(Name='DEMO RS06 01 - In Stock (Customer Quote)', AF_SelectedVehicle__c=V_ROMA,  AF_VehicleModel__c=M_ROMA));
o.put('02', new Opportunity(Name='DEMO RS06 02 - In Stock (Bank Quote)',     AF_SelectedVehicle__c=V_296,   AF_VehicleModel__c=M_296));
o.put('03', new Opportunity(Name='DEMO RS06 03 - In Transit (VIN test)',     AF_SelectedVehicle__c=V_PHANB, AF_VehicleModel__c=M_PHAN));
o.put('04', new Opportunity(Name='DEMO RS06 04 - Ordered (VIN test)',        AF_SelectedVehicle__c=V_CULLG, AF_VehicleModel__c=M_CULL));
o.put('05', new Opportunity(Name='DEMO RS06 05 - Model only, no vehicle',                                   AF_VehicleModel__c=M_ROMA));
o.put('06', new Opportunity(Name='DEMO RS06 06 - Trade-In APPROVED and ACCEPTED', AF_SelectedVehicle__c=V_SF90, AF_VehicleModel__c=M_SF90));
o.put('07', new Opportunity(Name='DEMO RS06 07 - Trade-In not yet accepted',  AF_SelectedVehicle__c=V_PURO,  AF_VehicleModel__c=M_PURO));
o.put('08', new Opportunity(Name='DEMO RS06 08 - Internal cost lines',        AF_SelectedVehicle__c=V_CULLS, AF_VehicleModel__c=M_CULL));
o.put('09', new Opportunity(Name='DEMO RS06 09 - No line items',              AF_SelectedVehicle__c=V_PHANW, AF_VehicleModel__c=M_PHAN));
o.put('10', new Opportunity(Name='DEMO RS06 10 - No vehicle and no model'));
o.put('11', new Opportunity(Name='DEMO RS06 11 - Retro trade-in',             AF_SelectedVehicle__c=V_ROMA,  AF_VehicleModel__c=M_ROMA));
for (String k : o.keySet()) {
    Opportunity op=o.get(k);
    op.AccountId=ACCT; op.OwnerId=REP; op.Pricebook2Id=PB;
    op.StageName='Select'; op.CloseDate=Date.today().addDays(60);
}
// 10 has no vehicle/model, which a validation rule forbids from Explore onward
o.get('10').StageName='Consider';
insert o.values();

Id P_ROMA='01uFV001A94Y0qiYIC', P_296='01uFV001A94cCzkYIE', P_PHAN='01uFV001A94onQqYII',
   P_CULL='01uFV001A94szZsYII', P_SF90='01uFV001A94kbHoYII', P_PURO='01uFV001A94gP8mYIE',
   P_ACC='01uFV001A94xBiuYIE', P_PKG='01uFV001A955a0yYIA', P_TINT='01uFV001A959mA0YII',
   P_PDI='01uFV001A95DyJ2YIK', P_INT='01uFV001A95MMb6YIG';

List<OpportunityLineItem> L = new List<OpportunityLineItem>();
for (String k : new List<String>{'01','02'}) {
  Id opp=o.get(k).Id;
  Id veh = (k=='01') ? V_ROMA : V_296;
  Id mod = (k=='01') ? M_ROMA : M_296;
  Id pbe = (k=='01') ? P_ROMA : P_296;
  Decimal price = (k=='01') ? 247308 : 369300;
  L.add(new OpportunityLineItem(OpportunityId=opp, PricebookEntryId=pbe, Quantity=1, UnitPrice=price, AF_LineItemType__c='Vehicle', AF_Vehicle__c=veh, AF_VehicleDefinition__c=mod, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
  L.add(new OpportunityLineItem(OpportunityId=opp, PricebookEntryId=P_ACC,  Quantity=2, UnitPrice=850,  AF_LineItemType__c='Accessory', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
  L.add(new OpportunityLineItem(OpportunityId=opp, PricebookEntryId=P_PKG,  Quantity=1, UnitPrice=3200, AF_LineItemType__c='Package',   AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
  L.add(new OpportunityLineItem(OpportunityId=opp, PricebookEntryId=P_TINT, Quantity=1, UnitPrice=1200, AF_LineItemType__c='Tint',      AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
  L.add(new OpportunityLineItem(OpportunityId=opp, PricebookEntryId=P_PDI,  Quantity=1, UnitPrice=350,  AF_LineItemType__c='Customization', AF_CustomizationDescription__c='Demo custom stitching', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
}
L.add(new OpportunityLineItem(OpportunityId=o.get('03').Id, PricebookEntryId=P_PHAN, Quantity=1, UnitPrice=545000, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_PHANB, AF_VehicleDefinition__c=M_PHAN, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('04').Id, PricebookEntryId=P_CULL, Quantity=1, UnitPrice=405000, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_CULLG, AF_VehicleDefinition__c=M_CULL, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('05').Id, PricebookEntryId=P_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('06').Id, PricebookEntryId=P_SF90, Quantity=1, UnitPrice=625000, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_SF90, AF_VehicleDefinition__c=M_SF90, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('07').Id, PricebookEntryId=P_PURO, Quantity=1, UnitPrice=398350, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_PURO, AF_VehicleDefinition__c=M_PURO, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('11').Id, PricebookEntryId=P_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_ROMA, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('08').Id, PricebookEntryId=P_CULL, Quantity=1, UnitPrice=405000, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_CULLS, AF_VehicleDefinition__c=M_CULL, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=o.get('08').Id, PricebookEntryId=P_INT,  Quantity=1, UnitPrice=1500, AF_LineItemType__c='Internal Requisition', AF_RequiresInternalRequisition__c=true, AF_CustomerFacing__c=false, AF_IncludedInQuote__c=false));
L.add(new OpportunityLineItem(OpportunityId=o.get('08').Id, PricebookEntryId=P_PDI,  Quantity=1, UnitPrice=350,  AF_LineItemType__c='Provider Service', AF_ProviderSource__c='Alfardan Internal', AF_CustomerFacing__c=false, AF_IncludedInQuote__c=false));
insert L;

List<Appraisal> aps = new List<Appraisal>{
  new Appraisal(ReferenceRecordId=o.get('06').Id, PurposeType='Trade-In', UsageType='Automotive', AF_Account__c=ACCT, AF_InitiatingSalesRep__c=REP, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='Accepted',    Status='Completed'),
  new Appraisal(ReferenceRecordId=o.get('07').Id, PurposeType='Trade-In', UsageType='Automotive', AF_Account__c=ACCT, AF_InitiatingSalesRep__c=REP, AF_ApprovalStatus__c='Approved', AF_TradeInOutcome__c='In Progress', Status='Visit Scheduled'),
  new Appraisal(ReferenceRecordId=o.get('11').Id, PurposeType='Trade-In', UsageType='Automotive', AF_Account__c=ACCT, AF_InitiatingSalesRep__c=REP, Status='Visit Scheduled')};
insert aps;
List<AppraisalItem> items=new List<AppraisalItem>();
List<Decimal> vals=new List<Decimal>{60000, 45000, 30000};
List<String> makes=new List<String>{'Porsche','BMW','Audi'};
for (Integer i=0;i<aps.size();i++) {
  items.add(new AppraisalItem(AppraisalId=aps[i].Id, Type='Vehicle', InitialValue=vals[i], CustomerAskingValue=vals[i]+3000,
    ConditionType='Fair', Usage=70000, IsCustomized=false, ModelYear='2022', AF_InspectionDone__c=true,
    AF_InspectionNotes__c='Demo inspection - fair condition', IdentificationNumber='DEMORS06TRADE'+i,
    LicensePlateNumber='DEMO-'+i, AF_MakeText__c=makes[i], AF_ModelText__c='Demo Model', AF_Source__c='Manual'));
}
insert items;
for (String k : new List<String>{'01','02','03','04','05','06','07','08','09','10','11'})
    System.debug('DEMO_'+k+'='+o.get(k).Id);
