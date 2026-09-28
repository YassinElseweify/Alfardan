trigger AdvancedAccountForecastFactTrigger on AdvAccountForecastFact (before update) {
    if(Trigger.isBefore && Trigger.isUpdate){
        AcctHierAAFAdjustmentTriggerHandler.rollupAdjustments(Trigger.oldMap, Trigger.newMap);
    }
}