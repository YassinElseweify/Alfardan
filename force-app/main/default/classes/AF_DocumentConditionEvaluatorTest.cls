@isTest
private class AF_DocumentConditionEvaluatorTest {

    @isTest
    static void blankOrTrueAlwaysMatches() {
        AF_Handover__c ho = new AF_Handover__c(AF_Status__c = 'Pending');
        System.assertEquals(true, AF_DocumentConditionEvaluator.evaluate('true', ho));
        System.assertEquals(false, AF_DocumentConditionEvaluator.evaluate('false', ho));
        System.assertEquals(false, AF_DocumentConditionEvaluator.evaluate('', ho));
        System.assertEquals(false, AF_DocumentConditionEvaluator.evaluate(null, null));
    }

    @isTest
    static void simpleFieldEqualityMatches() {
        AF_Handover__c ho = new AF_Handover__c(AF_Status__c = 'Completed');
        System.assertEquals(true, AF_DocumentConditionEvaluator.evaluate('AF_Status__c = \'Completed\'', ho));
        System.assertEquals(false, AF_DocumentConditionEvaluator.evaluate('AF_Status__c = \'Pending\'', ho));
    }

    @isTest
    static void textFunctionEqualityMatches() {
        AF_Handover__c ho = new AF_Handover__c(AF_Status__c = 'Completed');
        System.assertEquals(true, AF_DocumentConditionEvaluator.evaluate('TEXT(AF_Status__c) = \'Completed\'', ho));
    }

    @isTest
    static void andOrNotCombineCorrectly() {
        AF_Handover__c ho = new AF_Handover__c(AF_Status__c = 'Completed', AF_ChecklistComplete__c = true);
        System.assertEquals(
            true,
            AF_DocumentConditionEvaluator.evaluate(
                'AND(AF_Status__c = \'Completed\', AF_ChecklistComplete__c = TRUE)', ho
            )
        );
        System.assertEquals(
            true,
            AF_DocumentConditionEvaluator.evaluate(
                'OR(AF_Status__c = \'Pending\', AF_ChecklistComplete__c = TRUE)', ho
            )
        );
        System.assertEquals(
            false,
            AF_DocumentConditionEvaluator.evaluate('NOT(AF_ChecklistComplete__c = TRUE)', ho)
        );
    }

    @isTest
    static void unsupportedExpressionReturnsFalse() {
        AF_Handover__c ho = new AF_Handover__c(AF_Status__c = 'Completed');
        System.assertEquals(false, AF_DocumentConditionEvaluator.evaluate('AF_Status__c > 5 garbled(', ho));
    }
}