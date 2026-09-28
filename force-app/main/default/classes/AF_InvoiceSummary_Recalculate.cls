/**
 * ALF-RS-09 (LFRDN-339) FR2/AC1/AC2 - Flow-facing invocable wrapper for
 * AF_InvoiceSummaryService.recalculateForOpportunities. Called from
 * AF_FL_Payment_RecalculateInvoiceSummary after any Payment is saved.
 */
public with sharing class AF_InvoiceSummary_Recalculate {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    @InvocableMethod(
        label='Recalculate Invoice Summary From Payments'
        description='ALF-RS-09 FR2/AC1/AC2: recomputes the Opportunity Invoice Summary paid amount, balance, and status from its verified Payment records.'
    )
    public static void recalculate(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }
        AF_InvoiceSummaryService.recalculateForOpportunities(opportunityIds);
    }
}