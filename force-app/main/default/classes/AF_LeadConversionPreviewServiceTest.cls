@isTest
private class AF_LeadConversionPreviewServiceTest {
    private static Id businessAccountRTId() {
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
            .get('Business_Account').getRecordTypeId();
    }

    private static Id brandProfileRTId() {
        return Schema.SObjectType.Contact.getRecordTypeInfosByDeveloperName()
            .get('AF_Brand_Profile').getRecordTypeId();
    }

    private static void insertAllowingDuplicates(SObject record) {
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.duplicateRuleHeader.allowSave = true;
        Database.insert(record, dmlOpts);
    }

    private static Lead buildBaseLead() {
        return new Lead(
            Company = '',
            AF_BusinessUnit__c = 'Alfardan Sports Motors',
            LeadSource = 'Website',
            Rating = 'Hot',
            AF_ContactValidity__c = 'Reachable',
            AF_QualificationOutcome__c = 'Qualified',
            Status = 'Follow-up'
        );
    }

    @isTest
    static void testPreviewWithNoMatchReturnsUnmatchedResult() {
        Lead ld = buildBaseLead();
        ld.FirstName = 'Preview';
        ld.LastName = 'NoMatch';
        ld.AF_QID__c = '29971100011';
        ld.Phone = '+97455530001';
        ld.AF_Brand__c = 'Ferrari';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionPreviewService.previewMatches(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        // Result.accountWasMatched/contactWasMatched are only ever explicitly set to true (on a
        // match) by previewMatches — left at their default null otherwise, never explicitly false.
        System.assertNotEquals(true, results[0].accountWasMatched, 'No existing Account should match');
        System.assertNotEquals(true, results[0].contactWasMatched, 'No existing Contact should match');
        System.assertEquals(null, results[0].accountId, 'Preview must not create anything, even for an unmatched Lead');
    }

    @isTest
    static void testPreviewWithMatchedAccountAndContactPopulatesDisplayFields() {
        Account existing = new Account(
            RecordTypeId = businessAccountRTId(),
            Name = 'Preview Matched Customer',
            AF_QID__c = '29971100022',
            Phone = '+97455530002'
        );
        insertAllowingDuplicates(existing);

        Contact existingContact = new Contact(
            RecordTypeId = brandProfileRTId(),
            AccountId = existing.Id,
            LastName = 'PreviewMatchContact',
            AF_ContactCategory__c = 'Brand Profile',
            AF_Brand__c = 'Ferrari',
            Phone = '+97455530003'
        );
        insertAllowingDuplicates(existingContact);

        Lead ld = buildBaseLead();
        ld.FirstName = 'Preview';
        ld.LastName = 'Matched';
        ld.AF_QID__c = '29971100022';
        ld.AF_Brand__c = 'Ferrari';
        ld.Phone = '+97455530004';
        insertAllowingDuplicates(ld);

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = ld.Id;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionPreviewService.previewMatches(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        AF_LeadConversionService.Result res = results[0];
        System.assertEquals(true, res.accountWasMatched);
        System.assertEquals(existing.Id, res.accountId);
        System.assertEquals(existing.Name, res.accountName);
        System.assertEquals(true, res.contactWasMatched);
        System.assertEquals(existingContact.Id, res.contactId);

        System.assertEquals(
            1,
            [SELECT COUNT() FROM Account WHERE AF_QID__c = '29971100022'],
            'Preview must not create a duplicate Account for an existing match'
        );
        Lead unconverted = [SELECT IsConverted FROM Lead WHERE Id = :ld.Id];
        System.assertEquals(false, unconverted.IsConverted, 'Preview must never actually convert the Lead');
    }

    @isTest
    static void testPreviewUnknownLeadIdIsSkippedWithBlankResult() {
        Lead ld = buildBaseLead();
        ld.FirstName = 'Preview';
        ld.LastName = 'MissingTest';
        ld.AF_QID__c = '29971100099';
        ld.Phone = '+97455530005';
        ld.AF_Brand__c = 'Ferrari';
        insertAllowingDuplicates(ld);
        Id realLeadId = ld.Id;
        delete ld;

        AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
        req.leadId = realLeadId;

        Test.startTest();
        List<AF_LeadConversionService.Result> results =
            AF_LeadConversionPreviewService.previewMatches(new List<AF_LeadConversionService.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertNotEquals(true, results[0].accountWasMatched);
    }

    // Bulk-safety check: previewing 200 Leads in one call. Before AF_LeadConversionService's match
    // logic was refactored into findMatchingAccountsBulk/findMatchingBrandContactsBulk, this class
    // called those per-Lead inside a loop (up to 4 SOQL per Lead) and would have thrown
    // System.LimitException well before reaching 200 Leads.
    @isTest
    static void testBulkPreviewOf200LeadsStaysWithinGovernorLimits() {
        List<Lead> leads = new List<Lead>();
        for (Integer i = 0; i < 200; i++) {
            Lead ld = buildBaseLead();
            ld.FirstName = 'BulkPreview';
            ld.LastName = 'LeadTest' + i;
            ld.AF_QID__c = '2998' + String.valueOf(1000000 + i);
            ld.Phone = '+9745553' + String.valueOf(10000 + i);
            ld.AF_Brand__c = 'Ferrari';
            leads.add(ld);
        }
        Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.duplicateRuleHeader.allowSave = true;
        Database.insert(leads, dmlOpts);

        List<AF_LeadConversionService.Request> requests = new List<AF_LeadConversionService.Request>();
        for (Lead ld : leads) {
            AF_LeadConversionService.Request req = new AF_LeadConversionService.Request();
            req.leadId = ld.Id;
            requests.add(req);
        }

        Test.startTest();
        List<AF_LeadConversionService.Result> results = AF_LeadConversionPreviewService.previewMatches(requests);
        Test.stopTest();

        System.assertEquals(200, results.size(), 'Expected one Result per Lead in the batch');
        for (AF_LeadConversionService.Result res : results) {
            System.assertNotEquals(true, res.accountWasMatched, 'None of these brand-new Leads should match an existing Account');
        }
        System.assertEquals(0, [SELECT COUNT() FROM Lead WHERE IsConverted = true], 'Preview must never convert any Lead, even in bulk');
    }
}