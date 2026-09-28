@isTest
public class AcctHierAAFAdjustmentTriggerHandlerTest {

    @testSetup 
    static void setupData() {
		//Create  child1, child2 and parent account
        List<String> accNameList = new List<String>{'MainAccount','TestParent','TestChild1', 'TestChild2'};
        List<Account> accList = new List<Account>();
        for(String accName : accNameList){
            Account acc = new Account(name=accName);
            accList.add(acc);
        }
        INSERT accList;
        //Create Product
        Product2 prod = new Product2(Name='TestProduct');
        INSERT prod;
		
        
	
	}
    
     @isTest static void test1() {
        //Fetch Account Hierarchy ForecastSet record 
        List<AdvAccountForecastSet> forecastSet = [SELECT Id, DeveloperName FROM AdvAccountForecastSet];
        List<Product2> prodLst = [SELECT Id FROM Product2];
       // System.assert(forecastSet.size() < 1 , 'Forecast Set Setting is not enabled.');
        List<Account> accList = [SELECT ID, Name FROM ACCOUNT];
        Map<String,Id> accMap = new Map<String,Id>();
        for(Account acc : accList){accMap.put(acc.Name,acc.Id);} 
       // System.assert(forecastSet.size() < 1 , 'Account creation failed.');
 		AdvAcctForecastSetPartner setPartner = new AdvAcctForecastSetPartner(Name='TestProduct',AccountId=accList.get(0).Id,AdvAccountForecastSetId=forecastSet.get(0).Id);
   		INSERT setPartner;
		//Fetch Period
		List<Period> periodList = [SELECT Id, FullyQualifiedLabel FROM Period];
       //Create ForecastFact Records and link records to set partner id.
       List<AdvAccountForecastFact> factLst = new  List<AdvAccountForecastFact>();
       AdvAccountForecastFact fact1 =makeAdvAccountForecastFact(setPartner.Id,'child1-TestProduct-1',accMap.get('MainAccount'),accMap.get('TestParent'),
                                                                 accMap.get('TestChild1'),prodLst.get(0).Id,periodList.get(0).Id,100,100
                                                               );
       factLst.add(fact1); 
     
       AdvAccountForecastFact fact2 = makeAdvAccountForecastFact( setPartner.Id,'child1-TestProduct-2',accMap.get('MainAccount'),accMap.get('TestParent'),
                                                                 accMap.get('TestChild2'),prodLst.get(0).Id,periodList.get(0).Id,100,100
                                                               );
       factLst.add(fact2); 
       INSERT factLst;
       List<AdvAccountForecastFact> insertedRec = [SELECT ID,AcctHierAAFRegionalManagerAmount__c,AcctHierAAFRegionalManagerQuantity__c,
                                                   AcctHierAAFAdjustedAmount__c,AcctHierAAFAdjustedQuantity__c,
                                                   ForecastedQuantity, ForecastedRevenue FROM AdvAccountForecastFact
                                                  WHERE AcctHierAAFChildAccount__c  =: accMap.get('TestChild2')];
         
      insertedRec.get(0).AcctHierAAFAdjustedAmount__c = 1200;
      insertedRec.get(0).AcctHierAAFAdjustedQuantity__c = 120;
      UPDATE insertedRec.get(0);
         
      insertedRec.get(0).AcctHierAAFAdjustedAmount__c = 1205;
      insertedRec.get(0).AcctHierAAFRegionalManagerAmount__c = 2000;
      UPDATE insertedRec.get(0);
      insertedRec.get(0).AcctHierAAFRegionalManagerQuantity__c = 200;
      insertedRec.get(0).AcctHierAAFAdjustedQuantity__c = 125;
      UPDATE insertedRec.get(0);
		//set values for AcctHierAAFRegionalManagerAmount__c,AcctHierAAFRegionalManagerQuantity__c,AcctHierAAFAdjustedAmount__c
		//AcctHierAAFAdjustedQuantity__c
        
   }
    
    
    private static AdvAccountForecastFact makeAdvAccountForecastFact(Id PartnerId ,String name, Id accId, Id parentId, Id childId,Id prodId,Id perId,Integer amt , Integer qty){
       return  new AdvAccountForecastFact(Name=name, AccountId=accId,AcctHierAAFParentAccount__c=parentId,
                                              AcctHierAAFChildAccount__c = childId,ProductId=prodId,PeriodId =perId,
                                          AdvAcctForecastSetPartnerId=PartnerId,
                                          ForecastedQuantity=qty,
                                          ForecastedRevenue=amt
                                         );
                                       
    }
}