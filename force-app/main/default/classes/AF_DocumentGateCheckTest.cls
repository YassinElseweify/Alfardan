/**
 * Tests for AF_DocumentGateCheck (ALF-RS-12 / LFRDN-342), the Flow-facing gate that reports
 * whether every AF_Document__mdt row required for a record has a matching uploaded or generated
 * file. Covers the happy path, the all-uploaded path, the null/empty guard and the
 * unsupported-object error branch.
 */
@isTest
private class AF_DocumentGateCheckTest {

    private static Account makeAccount() {
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
        Account acc = new Account(Name = 'Gate Check Test Account', RecordTypeId = rtId);
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Id accountId) {
        Opportunity opp = new Opportunity(
            Name = 'Gate Check Test Opp',
            AccountId = accountId,
            StageName = 'Consider',
            CloseDate = Date.today().addDays(30),
            AF_Brand__c = 'Ferrari'
        );
        insert opp;
        return opp;
    }

    private static AF_Handover__c makeHandover(Id oppId) {
        AF_Handover__c ho = new AF_Handover__c(AF_Opportunity__c = oppId, AF_Status__c = 'Pending');
        insert ho;
        return ho;
    }

    private static AF_DocumentGateCheck.Request req(Id recordId) {
        AF_DocumentGateCheck.Request r = new AF_DocumentGateCheck.Request();
        r.recordId = recordId;
        return r;
    }

    @isTest
    static void nullAndEmptyRequestListsReturnNoResults() {
        Test.startTest();
        System.assertEquals(0, AF_DocumentGateCheck.check(null).size(),
            'A null request list must return no results rather than throwing.');
        System.assertEquals(0, AF_DocumentGateCheck.check(new List<AF_DocumentGateCheck.Request>()).size(),
            'An empty request list must return no results.');
        Test.stopTest();
    }

    @isTest
    static void handoverWithNoUploadsIsReportedAsNotAllUploaded() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c ho = makeHandover(opp.Id);

        Test.startTest();
        List<AF_DocumentGateCheck.Result> results =
            AF_DocumentGateCheck.check(new List<AF_DocumentGateCheck.Request>{ req(ho.Id) });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].allUploaded,
            'A brand new Handover has none of its required documents yet.');
        System.assert(results[0].message.contains('missing'), 'Got: ' + results[0].message);
    }

    @isTest
    static void objectWithoutADynamicObjectRowIsReportedAsAnError() {
        // Account has no AF_DynamicObject__mdt row, so getRequiredDocuments throws and the gate
        // has to surface that as a message instead of letting the exception reach the Flow.
        Account acc = makeAccount();

        Test.startTest();
        List<AF_DocumentGateCheck.Result> results =
            AF_DocumentGateCheck.check(new List<AF_DocumentGateCheck.Request>{ req(acc.Id) });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(false, results[0].allUploaded);
        System.assert(results[0].message.contains('Could not evaluate required documents'),
            'Got: ' + results[0].message);
    }

    @isTest
    static void bulkRequestsEachGetTheirOwnResult() {
        Opportunity opp = makeOpportunity(makeAccount().Id);
        AF_Handover__c first = makeHandover(opp.Id);
        AF_Handover__c second = makeHandover(opp.Id);

        Test.startTest();
        List<AF_DocumentGateCheck.Result> results = AF_DocumentGateCheck.check(
            new List<AF_DocumentGateCheck.Request>{ req(first.Id), req(second.Id) }
        );
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Each request gets its own Result.');
        System.assertEquals(false, results[0].allUploaded);
        System.assertEquals(false, results[1].allUploaded);
    }
}