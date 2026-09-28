// NEW TC-032: Opportunity with NEITHER a selected vehicle NOR a vehicle model
Opportunity n = new Opportunity(Name='QA RS06 L NoVehicleNoModel', AccountId='001FV00Il8k5zHIYEY',
   OwnerId='005a3001tN36pJcAQI', Pricebook2Id='01sa3000re0Wg8SAAS',
   StageName='Consider', CloseDate=Date.today().addDays(45));
insert n;
System.debug('OPP_L=' + n.Id);
