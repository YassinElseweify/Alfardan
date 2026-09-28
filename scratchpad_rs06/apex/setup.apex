Id ACCT = '001FV00Il8k5zHIYEY';
Id REP  = '005a3001tN36pJcAQI';
Id PB   = '01sa3000re0Wg8SAAS';
Id V_INSTOCK   = '0vLFV0004GuzWgG2QU'; // Ferrari Roma Red, In Stock, VIN ZFF95FLA000ROMA02
Id V_INSTOCK2  = '0vLFV0004H8Whoi2QC'; // Ferrari 296 GTB Yellow, In Stock
Id V_INTRANSIT = '0vLFV0004H1l7FU2QY'; // Ferrari Roma Black, In Transit
Id V_ORDERED   = '0vLFV0004HFIINw2QP'; // Ferrari 296 GTB Blue, Ordered
Id M_ROMA = '1PqFV0002jW7LI40AN';
Id M_296  = '1PqFV0002jWBXR60AP';

Map<String,Opportunity> o = new Map<String,Opportunity>();
o.put('A', new Opportunity(Name='QA RS06 A InStock Customer',  AF_SelectedVehicle__c=V_INSTOCK,   AF_VehicleModel__c=M_ROMA));
o.put('B', new Opportunity(Name='QA RS06 B InStock Bank',      AF_SelectedVehicle__c=V_INSTOCK2,  AF_VehicleModel__c=M_296));
o.put('C', new Opportunity(Name='QA RS06 C InTransit',         AF_SelectedVehicle__c=V_INTRANSIT, AF_VehicleModel__c=M_ROMA));
o.put('D', new Opportunity(Name='QA RS06 D Ordered',           AF_SelectedVehicle__c=V_ORDERED,   AF_VehicleModel__c=M_296));
o.put('E', new Opportunity(Name='QA RS06 E ModelOnly',         AF_VehicleModel__c=M_ROMA));
o.put('F', new Opportunity(Name='QA RS06 F TradeIn Accepted',  AF_SelectedVehicle__c=V_INSTOCK,   AF_VehicleModel__c=M_ROMA));
o.put('G', new Opportunity(Name='QA RS06 G TradeIn ApprovedOnly', AF_SelectedVehicle__c=V_INSTOCK, AF_VehicleModel__c=M_ROMA));
o.put('H', new Opportunity(Name='QA RS06 H Retro TradeIn',     AF_SelectedVehicle__c=V_INSTOCK,   AF_VehicleModel__c=M_ROMA));
o.put('I', new Opportunity(Name='QA RS06 I Internal Lines',    AF_SelectedVehicle__c=V_INSTOCK,   AF_VehicleModel__c=M_ROMA));
o.put('J', new Opportunity(Name='QA RS06 J NoLines',           AF_SelectedVehicle__c=V_INSTOCK,   AF_VehicleModel__c=M_ROMA));
for (String k : o.keySet()) {
    Opportunity op = o.get(k);
    op.AccountId=ACCT; op.OwnerId=REP; op.Pricebook2Id=PB;
    op.StageName='Select'; op.CloseDate=Date.today().addDays(45);
}
insert o.values();
for (String k : o.keySet()) System.debug('OPP_'+k+'='+o.get(k).Id);
