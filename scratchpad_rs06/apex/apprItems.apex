List<AppraisalItem> items = new List<AppraisalItem>();
items.add(new AppraisalItem(AppraisalId='9ALFV0000jW9KpE4AV', Type='Vehicle', InitialValue=50000, CustomerAskingValue=55000,
  ConditionType='Fair', Usage=60000, IsCustomized=false, ModelYear='2022', IdentificationNumber='QARS06TRADEINF01',
  LicensePlateNumber='QA-RS06-F', AF_MakeText__c='Porsche', AF_ModelText__c='911 Carrera', AF_Source__c='Manual',
  AF_InspectionDone__c=true, AF_InspectionNotes__c='QA RS06 inspection - fair condition, no major defects'));
items.add(new AppraisalItem(AppraisalId='9ALFV0000jWDWyG4AX', Type='Vehicle', InitialValue=35000, CustomerAskingValue=38000,
  ConditionType='Fair', Usage=80000, IsCustomized=false, ModelYear='2021', IdentificationNumber='QARS06TRADEING01',
  LicensePlateNumber='QA-RS06-G', AF_MakeText__c='BMW', AF_ModelText__c='M4', AF_Source__c='Manual',
  AF_InspectionDone__c=true, AF_InspectionNotes__c='QA RS06 inspection - fair condition, no major defects'));
items.add(new AppraisalItem(AppraisalId='9ALFV0000jWHj7I4AT', Type='Vehicle', InitialValue=22000, CustomerAskingValue=25000,
  ConditionType='Fair', Usage=90000, IsCustomized=false, ModelYear='2020', IdentificationNumber='QARS06TRADEINH01',
  LicensePlateNumber='QA-RS06-H', AF_MakeText__c='Audi', AF_ModelText__c='RS5', AF_Source__c='Manual',
  AF_InspectionDone__c=true, AF_InspectionNotes__c='QA RS06 inspection - fair condition, no major defects'));
insert items;
System.debug('ITEMS=' + items.size());
