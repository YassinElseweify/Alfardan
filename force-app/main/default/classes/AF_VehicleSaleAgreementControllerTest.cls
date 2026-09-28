/**
 * Tests for AF_VehicleSaleAgreementController (LFRDN-342), the Visualforce standard-controller
 * extension that loads an AF_Handover__c and its related Account/Contact/Vehicle/Opportunity/
 * Invoice Summary fields for the printed Vehicle Sale Agreement PDF.
 */
@isTest
private class AF_VehicleSaleAgreementControllerTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Sale Agreement Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Sale Agreement Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    @isTest
    static void loadsHandoverAndItsRelatedFieldsForTheRecord() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc.Id);
        AF_Handover__c ho = new AF_Handover__c(AF_Opportunity__c = opp.Id, AF_Status__c = 'Pending');
        insert ho;

        Test.startTest();
        ApexPages.StandardController stdController = new ApexPages.StandardController(ho);
        AF_VehicleSaleAgreementController controller = new AF_VehicleSaleAgreementController(stdController);
        Test.stopTest();

        System.assertNotEquals(null, controller.handover, 'Controller must load the Handover record.');
        System.assertEquals(ho.Id, controller.handover.Id);
        System.assertEquals(opp.Id, controller.handover.AF_Opportunity__c);
    }
}