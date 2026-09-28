public without sharing class AcctHierAAFAdjustmentTriggerHandler {

    public static void rollupAdjustments(Map<Id,AdvAccountForecastFact> oldforecastFactMap, 
    Map<Id,AdvAccountForecastFact> newForecastFactMap) {
        rollupRegionalManagerAdjustments(oldforecastFactMap,newForecastFactMap);
        rollupAccountManagerAdjustments(oldforecastFactMap,newForecastFactMap);

    }
    public static void rollupRegionalManagerAdjustments(Map<Id,AdvAccountForecastFact> oldforecastFactMap, 
                                        Map<Id,AdvAccountForecastFact> newForecastFactMap) {

        Set<Id> setpartnerIds = new Set<ID>();   
        Set<Id> changedFactRecords = new Set<ID>();  
        List<AdvAccountForecastFact> UpdatedFacts = new List<AdvAccountForecastFact>();                                                    
            for(Id recordID : newForecastFactMap.keySet()) {
                AdvAccountForecastFact newRecord = newForecastFactMap.get(recordID);
                AdvAccountForecastFact oldRecord = oldforecastFactMap.get(recordID);
                if(oldRecord.AcctHierAAFRegionalManagerAmount__c != newRecord.AcctHierAAFRegionalManagerAmount__c ||
                   oldRecord.AcctHierAAFRegionalManagerQuantity__c != newRecord.AcctHierAAFRegionalManagerQuantity__c) {
                    setpartnerIds.add(newRecord.AdvAcctForecastSetPartnerId);
                    changedFactRecords.add(newRecord.Id);
                   }
            }                 
            List<AdvAccountForecastFact> partnerForecastFacts = [ SELECT Id, AccountId,ProductId, PeriodId,Status, ForecastedQuantity, ForecastedRevenue, AcctHierAAFRegionalManagerQuantity__c, AcctHierAAFRegionalManagerAmount__c,AcctHierAAFChildAccount__c, AcctHierAAFParentAccount__c   
            FROM AdvAccountForecastFact 
            WHERE AdvAcctForecastSetPartnerId in: setpartnerIds ];

            for(Id recordID : changedFactRecords) {
                AdvAccountForecastFact newRecord = newForecastFactMap.get(recordID);
                AdvAccountForecastFact oldRecord = oldforecastFactMap.get(recordID);
                List<AdvAccountForecastFact> childFactRecords = getAllChildrenRecords(newRecord.AcctHierAAFParentAccount__c,newrecord.ProductId,newrecord.PeriodId,partnerForecastFacts);
                Double totalAdjustedQty = 0.0,totalAdjustedAmt = 0.0;
                for(AdvAccountForecastFact factRecord : childFactRecords) {
                    Double frcstQty=0.0,frcstRev=0.0;
                    if(newRecord.Id == factRecord.Id ) {
                        if(oldRecord.AcctHierAAFRegionalManagerAmount__c != newRecord.AcctHierAAFRegionalManagerAmount__c &&
                        oldRecord.AcctHierAAFRegionalManagerQuantity__c != newRecord.AcctHierAAFRegionalManagerQuantity__c) {
                            frcstRev = newRecord.AcctHierAAFRegionalManagerAmount__c;
                            frcstQty = newRecord.AcctHierAAFRegionalManagerQuantity__c;
                        }
                        else if(oldRecord.AcctHierAAFRegionalManagerAmount__c != newRecord.AcctHierAAFRegionalManagerAmount__c ) {
                            frcstRev = newRecord.AcctHierAAFRegionalManagerAmount__c;
                            frcstQty = newRecord.AcctHierAAFRegionalManagerQuantity__c !=null && newRecord.AcctHierAAFRegionalManagerQuantity__c !=0 ? newRecord.AcctHierAAFRegionalManagerQuantity__c:factRecord.ForecastedQuantity;
                        } 
                        else if(oldRecord.AcctHierAAFRegionalManagerQuantity__c != newRecord.AcctHierAAFRegionalManagerQuantity__c) {
                            frcstRev = factRecord.AcctHierAAFRegionalManagerAmount__c !=null && factRecord.AcctHierAAFRegionalManagerAmount__c != 0 ? factRecord.AcctHierAAFRegionalManagerAmount__c:factRecord.ForecastedRevenue;
                            frcstQty = newRecord.AcctHierAAFRegionalManagerQuantity__c;
                        }
                    }
                    else{
                         frcstQty =factRecord.AcctHierAAFRegionalManagerQuantity__c !=null && factRecord.AcctHierAAFRegionalManagerQuantity__c != 0 ? factRecord.AcctHierAAFRegionalManagerQuantity__c:factRecord.ForecastedQuantity;
                         frcstRev =factRecord.AcctHierAAFRegionalManagerAmount__c !=null && factRecord.AcctHierAAFRegionalManagerAmount__c != 0? factRecord.AcctHierAAFRegionalManagerAmount__c:factRecord.ForecastedRevenue;
                    }
                   
                    totalAdjustedQty +=frcstQty;
                    totalAdjustedAmt +=frcstRev;
                    
                }
                List<AdvAccountForecastFact> parentFactRecordList = getParentFactRecord(newRecord.AcctHierAAFParentAccount__c,newrecord.ProductId,newrecord.PeriodId, partnerForecastFacts);
                if(parentFactRecordList.size() > 0 ){
                    AdvAccountForecastFact parentFactRecord = parentFactRecordList.get(0);
                    parentFactRecord.AcctHierAAFRegionalManagerQuantity__c = totalAdjustedQty;
                    parentFactRecord.AcctHierAAFRegionalManagerAmount__c = totalAdjustedAmt;
                    UpdatedFacts.add(parentFactRecord);
                } 
            }
            if(! UpdatedFacts.isEmpty()) {
                update UpdatedFacts;
            }      
    }

    public static void rollupAccountManagerAdjustments(Map<Id,AdvAccountForecastFact> oldforecastFactMap, 
                Map<Id,AdvAccountForecastFact> newForecastFactMap) {

                Set<Id> setpartnerIds = new Set<ID>();   
                Set<Id> changedFactRecords = new Set<ID>();  
                List<AdvAccountForecastFact> UpdatedFacts = new List<AdvAccountForecastFact>();                                                    
                for(Id recordID : newForecastFactMap.keySet()) {
                AdvAccountForecastFact newRecord = newForecastFactMap.get(recordID);
                AdvAccountForecastFact oldRecord = oldforecastFactMap.get(recordID);
                if(oldRecord.AcctHierAAFAdjustedAmount__c != newRecord.AcctHierAAFAdjustedAmount__c ||
                oldRecord.AcctHierAAFAdjustedQuantity__c != newRecord.AcctHierAAFAdjustedQuantity__c) {
                setpartnerIds.add(newRecord.AdvAcctForecastSetPartnerId);
                changedFactRecords.add(newRecord.Id);
                }
                }                 
                List<AdvAccountForecastFact> partnerForecastFacts = [ SELECT Id, AccountId,ProductId, PeriodId,Status, ForecastedQuantity, ForecastedRevenue, AcctHierAAFAdjustedQuantity__c, AcctHierAAFAdjustedAmount__c,AcctHierAAFChildAccount__c, AcctHierAAFParentAccount__c   
                FROM AdvAccountForecastFact 
                WHERE AdvAcctForecastSetPartnerId in: setpartnerIds ];

                for(Id recordID : changedFactRecords) {
                AdvAccountForecastFact newRecord = newForecastFactMap.get(recordID);
                AdvAccountForecastFact oldRecord = oldforecastFactMap.get(recordID);
                List<AdvAccountForecastFact> childFactRecords = getAllChildrenRecords(newRecord.AcctHierAAFParentAccount__c,newrecord.ProductId,newrecord.PeriodId,partnerForecastFacts);
                Double totalAdjustedQty = 0.0,totalAdjustedAmt = 0.0;
                for(AdvAccountForecastFact factRecord : childFactRecords) {
                Double frcstQty=0.0,frcstRev=0.0;
                if(newRecord.Id == factRecord.Id ) {
                if(oldRecord.AcctHierAAFAdjustedAmount__c != newRecord.AcctHierAAFAdjustedAmount__c &&
                oldRecord.AcctHierAAFAdjustedQuantity__c != newRecord.AcctHierAAFAdjustedQuantity__c) {
                frcstRev = newRecord.AcctHierAAFAdjustedAmount__c;
                frcstQty = newRecord.AcctHierAAFAdjustedQuantity__c;
                }
                else if(oldRecord.AcctHierAAFAdjustedAmount__c != newRecord.AcctHierAAFAdjustedAmount__c ) {
                frcstRev = newRecord.AcctHierAAFAdjustedAmount__c;
                frcstQty = newRecord.AcctHierAAFAdjustedQuantity__c !=null && newRecord.AcctHierAAFAdjustedQuantity__c !=0 ? newRecord.AcctHierAAFAdjustedQuantity__c:factRecord.ForecastedQuantity;
                } 
                else if(oldRecord.AcctHierAAFAdjustedQuantity__c != newRecord.AcctHierAAFAdjustedQuantity__c) {
                frcstRev = factRecord.AcctHierAAFAdjustedAmount__c !=null && factRecord.AcctHierAAFAdjustedAmount__c != 0 ? factRecord.AcctHierAAFAdjustedAmount__c:factRecord.ForecastedRevenue;
                frcstQty = newRecord.AcctHierAAFAdjustedQuantity__c;
                }
                }
                else{
                frcstQty =factRecord.AcctHierAAFAdjustedQuantity__c !=null && factRecord.AcctHierAAFAdjustedQuantity__c != 0 ? factRecord.AcctHierAAFAdjustedQuantity__c:factRecord.ForecastedQuantity;
                frcstRev =factRecord.AcctHierAAFAdjustedAmount__c !=null && factRecord.AcctHierAAFAdjustedAmount__c != 0? factRecord.AcctHierAAFAdjustedAmount__c:factRecord.ForecastedRevenue;
                }

                totalAdjustedQty +=frcstQty;
                totalAdjustedAmt +=frcstRev;

            }
            List<AdvAccountForecastFact> parentFactRecordList = getParentFactRecord(newRecord.AcctHierAAFParentAccount__c,newrecord.ProductId,newrecord.PeriodId, partnerForecastFacts);
            if(parentFactRecordList.size() > 0 ){
                    AdvAccountForecastFact parentFactRecord = parentFactRecordList.get(0);
                    parentFactRecord.AcctHierAAFAdjustedQuantity__c = totalAdjustedQty;
                    parentFactRecord.AcctHierAAFAdjustedAmount__c = totalAdjustedAmt;
                    UpdatedFacts.add(parentFactRecord);
                } 
            }
            if(! UpdatedFacts.isEmpty()) {
            update UpdatedFacts;
            }      
    }

    private static List<AdvAccountForecastFact> getAllChildrenRecords(Id parentAccountID,ID prodID, ID PeriodID, List<AdvAccountForecastFact> factList) {
        List<AdvAccountForecastFact> childFactRecordList = new  List<AdvAccountForecastFact>();
        for(AdvAccountForecastFact factRec : factList){
            if(factRec.AcctHierAAFParentAccount__c == parentAccountID && factRec.ProductId == prodID && factRec.PeriodID == periodID){
                childFactRecordList.add(factRec);
            }
        }
        return childFactRecordList;
    }

    private static List<AdvAccountForecastFact> getParentFactRecord(Id childAccountId, ID prodID, ID PeriodID,List<AdvAccountForecastFact> factList){
        List<AdvAccountForecastFact> FactRecordList = new  List<AdvAccountForecastFact>();
        for(AdvAccountForecastFact factRec : factList){
                if(factRec.AcctHierAAFChildAccount__c == childAccountId && factRec.ProductId == prodID && factRec.PeriodID == periodID){
                    FactRecordList.add(factRec);
                }
        }
        return FactRecordList;
    }
}