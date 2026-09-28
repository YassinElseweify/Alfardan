Id A='006FV00ApphXrsqYEC', B='006FV00Apphc41sYEA', C='006FV00ApphgGAuYEM', D='006FV00ApphkSJwYEM',
   E='006FV00ApphoeSyYEI', F='006FV00Apphsqc0YEA', G='006FV00Apphx2l2YEA', H='006FV00Appi1Eu4YEE',
   I='006FV00Appi5R36YEE';
Id PBE_ROMA='01uFV001A94Y0qiYIC', PBE_296='01uFV001A94cCzkYIE', PBE_ACC='01uFV001A94xBiuYIE',
   PBE_PKG='01uFV001A955a0yYIA', PBE_TINT='01uFV001A959mA0YII', PBE_INT='01uFV001A95MMb6YIG',
   PBE_PDI='01uFV001A95DyJ2YIK';
Id V_INSTOCK='0vLFV0004GuzWgG2QU', V_INSTOCK2='0vLFV0004H8Whoi2QC',
   V_INTRANSIT='0vLFV0004H1l7FU2QY', V_ORDERED='0vLFV0004HFIINw2QP';
Id M_ROMA='1PqFV0002jW7LI40AN', M_296='1PqFV0002jWBXR60AP';

List<OpportunityLineItem> L = new List<OpportunityLineItem>();
// A: full composition (Vehicle, Accessory, Paint Job, Tint, Customization)
L.add(new OpportunityLineItem(OpportunityId=A, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle',      AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=A, PricebookEntryId=PBE_ACC,  Quantity=2, UnitPrice=850,    AF_LineItemType__c='Accessory',    AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=A, PricebookEntryId=PBE_PKG,  Quantity=1, UnitPrice=3200,   AF_LineItemType__c='Package',      AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=A, PricebookEntryId=PBE_TINT, Quantity=1, UnitPrice=1200,   AF_LineItemType__c='Tint',         AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=A, PricebookEntryId=PBE_PDI,  Quantity=1, UnitPrice=350,    AF_LineItemType__c='Customization', AF_CustomizationDescription__c='QA RS06 custom stitching', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
// B: mirror of A but 296 GTB (for Bank Quotation comparison)
L.add(new OpportunityLineItem(OpportunityId=B, PricebookEntryId=PBE_296,  Quantity=1, UnitPrice=369300, AF_LineItemType__c='Vehicle',      AF_Vehicle__c=V_INSTOCK2, AF_VehicleDefinition__c=M_296, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=B, PricebookEntryId=PBE_ACC,  Quantity=2, UnitPrice=850,    AF_LineItemType__c='Accessory',    AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=B, PricebookEntryId=PBE_PKG,  Quantity=1, UnitPrice=3200,   AF_LineItemType__c='Package',      AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=B, PricebookEntryId=PBE_TINT, Quantity=1, UnitPrice=1200,   AF_LineItemType__c='Tint',         AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=B, PricebookEntryId=PBE_PDI,  Quantity=1, UnitPrice=350,    AF_LineItemType__c='Customization', AF_CustomizationDescription__c='QA RS06 custom stitching', AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
// C / D / E: vehicle line only
L.add(new OpportunityLineItem(OpportunityId=C, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INTRANSIT, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=D, PricebookEntryId=PBE_296,  Quantity=1, UnitPrice=369300, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_ORDERED,   AF_VehicleDefinition__c=M_296,  AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=E, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
// F / G / H: vehicle line (trade-in scenarios)
L.add(new OpportunityLineItem(OpportunityId=F, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=G, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=H, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle', AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true, AF_IncludedInQuote__c=true));
// I: internal / non-customer-facing lines
L.add(new OpportunityLineItem(OpportunityId=I, PricebookEntryId=PBE_ROMA, Quantity=1, UnitPrice=247308, AF_LineItemType__c='Vehicle',              AF_Vehicle__c=V_INSTOCK, AF_VehicleDefinition__c=M_ROMA, AF_CustomerFacing__c=true,  AF_IncludedInQuote__c=true));
L.add(new OpportunityLineItem(OpportunityId=I, PricebookEntryId=PBE_INT,  Quantity=1, UnitPrice=1500,   AF_LineItemType__c='Internal Requisition', AF_RequiresInternalRequisition__c=true, AF_CustomerFacing__c=false, AF_IncludedInQuote__c=false));
L.add(new OpportunityLineItem(OpportunityId=I, PricebookEntryId=PBE_PDI,  Quantity=1, UnitPrice=350,    AF_LineItemType__c='Provider Service',     AF_ProviderSource__c='Alfardan Internal', AF_CustomerFacing__c=false, AF_IncludedInQuote__c=false));
insert L;
System.debug('LINES_INSERTED=' + L.size());
