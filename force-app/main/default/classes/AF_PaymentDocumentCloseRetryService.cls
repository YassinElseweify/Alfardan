/**
 * LFRDN-754: AF_FL_Handover_AutoCloseWon only runs when the Handover itself is saved, so a deal
 * stuck at Take the Keys because AF_Opportunity_ClosedWonPaymentGate refused (e.g. a Bank Transfer
 * Payment missing its Bank LPO) stayed stuck even after the rep uploaded the missing document -
 * nothing else in the org re-checked the gate. Mirrors AF_ContentDocumentLink's existing pattern
 * (AF_CreditNote_CancellationLinkService.retrySubmissionForLinkedCreditNotes) of retrying a
 * previously-blocked action once the file that was missing shows up.
 */
public without sharing class AF_PaymentDocumentCloseRetryService {

    public static void retryCloseForLinkedPayments(List<ContentDocumentLink> links) {
        Set<Id> linkedEntityIds = new Set<Id>();
        for (ContentDocumentLink link : links) {
            linkedEntityIds.add(link.LinkedEntityId);
        }

        Map<Id, Id> opportunityIdByPaymentId = new Map<Id, Id>();
        for (AF_Payment__c payment : [
            SELECT Id, AF_Opportunity__c
            FROM AF_Payment__c
            WHERE Id IN :linkedEntityIds
            AND AF_Opportunity__c != null
        ]) {
            opportunityIdByPaymentId.put(payment.Id, payment.AF_Opportunity__c);
        }
        if (opportunityIdByPaymentId.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> stuckOpportunities = new Map<Id, Opportunity>([
            SELECT Id, StageName, AF_Handover__r.AF_Status__c
            FROM Opportunity
            WHERE Id IN :opportunityIdByPaymentId.values()
            AND StageName = 'Take the Keys'
            AND AF_Handover__r.AF_Status__c = 'Completed'
        ]);
        if (stuckOpportunities.isEmpty()) {
            return;
        }

        List<AF_Opportunity_ClosedWonPaymentGate.Request> gateRequests = new List<AF_Opportunity_ClosedWonPaymentGate.Request>();
        for (Id oppId : stuckOpportunities.keySet()) {
            AF_Opportunity_ClosedWonPaymentGate.Request req = new AF_Opportunity_ClosedWonPaymentGate.Request();
            req.opportunityId = oppId;
            gateRequests.add(req);
        }

        List<AF_Opportunity_ClosedWonPaymentGate.Result> gateResults = AF_Opportunity_ClosedWonPaymentGate.check(gateRequests);

        List<Opportunity> opportunitiesToClose = new List<Opportunity>();
        Integer idx = 0;
        for (Id oppId : stuckOpportunities.keySet()) {
            AF_Opportunity_ClosedWonPaymentGate.Result res = gateResults[idx++];
            if (res.allowed == true) {
                opportunitiesToClose.add(new Opportunity(
                    Id = oppId,
                    StageName = 'Closed Won',
                    CloseDate = Date.today()
                ));
            }
        }

        if (!opportunitiesToClose.isEmpty()) {
            update opportunitiesToClose;
        }
    }
}