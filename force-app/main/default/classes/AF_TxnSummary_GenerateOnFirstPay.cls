/**
 * ALF-RS-09 (LFRDN-339) FR5 - Flow-facing trigger for the Sales Transaction Summary: generates it
 * the moment an Opportunity has its first verified Payment and none exists yet for that
 * Opportunity. Called from AF_FL_Payment_RecalculateInvoiceSummary right after the Invoice
 * Summary recalc, so it always runs against up-to-date paid/balance figures.
 *
 * The LLD (06-quotation-reservation-payment-sales-order, process step 5) describes this document
 * generating "in parallel with the Sales Order" at the same payment-confirmation moment - Sales
 * Order generation itself is LFRDN-340 (ALF-RS-10) scope, not built here. When RS-10 is built, its
 * SO-generation trigger should key off the same "first verified payment" event this class already
 * detects, so the two remain co-triggered without being code-coupled.
 */
public with sharing class AF_TxnSummary_GenerateOnFirstPay {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    @InvocableMethod(
        label='Generate Transaction Summary On First Payment'
        description='ALF-RS-09 FR5: generates the Sales Transaction Summary the moment an Opportunity has its first verified payment, if one has not already been generated.'
    )
    public static void generateIfFirstPayment(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }
        if (opportunityIds.isEmpty()) {
            return;
        }

        List<Id> toGenerate = new List<Id>();
        for (Opportunity opp : [
            SELECT Id, AF_TransactionSummaryDocumentReference__c, AF_InvoiceSummary__c,
                   AF_InvoiceSummary__r.AF_PaidAmount__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
              AND AF_TransactionSummaryDocumentReference__c = null
              AND AF_InvoiceSummary__c != null
              AND AF_InvoiceSummary__r.AF_PaidAmount__c > 0
            WITH USER_MODE
        ]) {
            toGenerate.add(opp.Id);
        }

        if (toGenerate.isEmpty()) {
            return;
        }

        List<AF_TransactionSummaryService.Request> reqs = new List<AF_TransactionSummaryService.Request>();
        for (Id oppId : toGenerate) {
            AF_TransactionSummaryService.Request req = new AF_TransactionSummaryService.Request();
            req.opportunityId = oppId;
            reqs.add(req);
        }
        AF_TransactionSummaryService.generate(reqs);
    }
}