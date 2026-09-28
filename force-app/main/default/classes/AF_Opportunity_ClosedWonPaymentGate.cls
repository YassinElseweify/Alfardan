/**
 * ALF-RS-09 (LFRDN-339) FR6 - the real Closed Won gate check: every AF_Payment__c on the
 * Opportunity must be Paid/Verified (or Keyloop-synced), each must carry a real attached proof
 * document, and the sum of all payments must equal the Invoice Summary's expected total.
 *
 * BRD FR6 (verbatim): "...including attaching the receipt or deposit document... each carries an
 * attached payment proof..." - the BRD's own vocabulary throughout RS-08/RS-09/RS-11 is
 * consistently "attach"/"attached"/"upload", never "reference field". AF_ProofReference__c (a
 * text field) is kept as a human-readable label a rep can search/report on (e.g. a cheque
 * number), but the actual gate requires a real ContentDocumentLink on the Payment record - a
 * blank or populated text field alone does not satisfy "attached payment proof".
 *
 * ALF-RS-11 (LFRDN-341) FR1 added the registration and signed-delivery-note conditions: the
 * linked AF_Handover__c must have AF_TrafficFormUploaded__c = true (registration) and
 * AF_CustomerSignOff__c = 'Physically Signed' (signed delivery note). Read via the Opportunity's
 * own AF_Handover__c lookup, not new Opportunity mirror fields, since AF_HandoverComplete__c/
 * AF_DeliveryConfirmation__c are already-known unwired manual checkboxes - this deliberately
 * avoids repeating that gap for two more fields. Mirrors AF_FL_Opp_ClosedWonPaymentGate.flow's
 * Get_Handover/Handover_Conditions_Met - if this class's rule changes, that flow must be updated
 * to match, since there is no way to share logic between an Apex class and a before-save Flow.
 *
 * ALF-RS-11 FR3/FR4/FR5 (payee/NOC mismatch, Cheque copy, Bank LPO) reuse the LFRDN-342
 * AF_Document__mdt required-documents engine rather than a bespoke check: AF_DynamicObject__mdt
 * registers AF_Payment__c, and AF_DocumentCondition__mdt rows (Payment_1_ChequeAndNOC,
 * Payment_2_BankTransferAndNOC, Payment_3_Cheque, Payment_4_BankTransfer, Payment_5_NOCOnly)
 * require the correctly-named, actually-attached document per payment method / NOC state - the
 * same "attach", not "reference field", precedent as the generic proof check above.
 * AF_NOCRecorded__c drives the NOC branch (not a computed payee-mismatch) because the condition
 * grammar in AF_DocumentConditionEvaluator has no field-to-field comparison, only field=literal.
 *
 * Called from a Closed-Won-bound screen action / Quick Action flow. AF_VR_Opp_ClosedWonGate
 * remains active as a declarative backstop on Opportunity.AF_InvoiceBalance__c = 0, but a plain
 * balance-zero check cannot see per-payment status or proof attachment - this class is the
 * authoritative FR6 check and is meant to be called before the rep is allowed to set the Stage.
 */
public with sharing class AF_Opportunity_ClosedWonPaymentGate {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable public Boolean allowed;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Check Closed Won Payment Gate'
        description='ALF-RS-09 FR6: every Payment on the Opportunity must be Paid/Verified with proof attached, and their sum must equal the Invoice Summary expected total.'
    )
    public static List<Result> check(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }

        Map<Id, AF_InvoiceSummary__c> invoicesByOpportunity = new Map<Id, AF_InvoiceSummary__c>();
        for (AF_InvoiceSummary__c inv : [
            SELECT Id, AF_Opportunity__c, AF_ExpectedTotalAmount__c
            FROM AF_InvoiceSummary__c
            WHERE AF_Opportunity__c IN :opportunityIds
            WITH USER_MODE
        ]) {
            invoicesByOpportunity.put(inv.AF_Opportunity__c, inv);
        }

        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>([
            SELECT Id, AF_Handover__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ]);

        // LFRDN-709/LFRDN-696-pattern: AF_Handover__c is now Private OWD, shared only to the
        // record's own business-unit/showroom group. Whether the Traffic Form is uploaded and the
        // customer signed off is a gate-check fact the running user needs answered to know if THEY
        // may close THIS deal - not document content the rep is personally choosing to view - so
        // the record-access decision made by the main Opportunity query above (WITH USER_MODE) is
        // what actually gates this check; requiring separate Handover sharing on top of that would
        // make every real rep without a direct BU-group grant unable to close their own deals.
        Set<Id> handoverIds = new Set<Id>();
        for (Opportunity opp : opportunitiesById.values()) {
            if (opp.AF_Handover__c != null) {
                handoverIds.add(opp.AF_Handover__c);
            }
        }
        Map<Id, AF_Handover__c> handoversById = new Map<Id, AF_Handover__c>();
        if (!handoverIds.isEmpty()) {
            for (AF_Handover__c ho : [
                SELECT Id, AF_TrafficFormUploaded__c, AF_CustomerSignOff__c
                FROM AF_Handover__c
                WHERE Id IN :handoverIds
                WITH SYSTEM_MODE
            ]) {
                handoversById.put(ho.Id, ho);
            }
        }

        Map<Id, List<AF_Payment__c>> paymentsByOpportunity = new Map<Id, List<AF_Payment__c>>();
        Map<Id, AF_Payment__c> paymentsById = new Map<Id, AF_Payment__c>();
        for (AF_Payment__c pay : [
            SELECT Id, AF_Amount__c, AF_Status__c, AF_IntegrationStatus__c, AF_ProofReference__c,
                   AF_Opportunity__c
            FROM AF_Payment__c
            WHERE AF_Opportunity__c IN :opportunityIds
            WITH USER_MODE
        ]) {
            if (!paymentsByOpportunity.containsKey(pay.AF_Opportunity__c)) {
                paymentsByOpportunity.put(pay.AF_Opportunity__c, new List<AF_Payment__c>());
            }
            paymentsByOpportunity.get(pay.AF_Opportunity__c).add(pay);
            paymentsById.put(pay.Id, pay);
        }

        Set<Id> paymentIdsWithFile = new Set<Id>();
        if (!paymentsById.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :paymentsById.keySet()
                WITH USER_MODE
            ]) {
                paymentIdsWithFile.add(cdl.LinkedEntityId);
            }
        }

        for (Request req : requests) {
            Result res = new Result();
            res.allowed = false;
            results.add(res);

            AF_InvoiceSummary__c inv = invoicesByOpportunity.get(req.opportunityId);
            if (inv == null) {
                res.message = 'No Invoice Summary exists on this Opportunity yet.';
                continue;
            }

            Opportunity opp = opportunitiesById.get(req.opportunityId);
            AF_Handover__c ho = opp != null && opp.AF_Handover__c != null ? handoversById.get(opp.AF_Handover__c) : null;
            Boolean handoverOk = ho != null
                && ho.AF_TrafficFormUploaded__c == true
                && ho.AF_CustomerSignOff__c == 'Physically Signed';
            if (!handoverOk) {
                res.message = 'Registration (Traffic Form) and signed delivery note (Customer Sign-Off) must be complete on the linked Handover.';
                continue;
            }

            List<AF_Payment__c> payments = paymentsByOpportunity.get(req.opportunityId);
            if (payments == null || payments.isEmpty()) {
                res.message = 'No Payment records exist on this Opportunity.';
                continue;
            }

            Decimal sum = 0;
            Boolean allVerified = true;
            Boolean allHaveProof = true;
            Boolean allDocumentsComplete = true;
            for (AF_Payment__c pay : payments) {
                Boolean verified = pay.AF_Status__c == AF_InvoiceSummaryService.STATUS_PAID
                    || pay.AF_IntegrationStatus__c == AF_InvoiceSummaryService.INTEGRATION_SYNCED;
                if (!verified) {
                    allVerified = false;
                }
                if (!paymentIdsWithFile.contains(pay.Id)) {
                    allHaveProof = false;
                }
                if (!AF_DocumentService.areRequiredDocumentsUploaded(pay.Id)) {
                    allDocumentsComplete = false;
                }
                sum += (pay.AF_Amount__c == null ? 0 : pay.AF_Amount__c);
            }

            Decimal expected = inv.AF_ExpectedTotalAmount__c == null ? 0 : inv.AF_ExpectedTotalAmount__c;

            if (!allVerified) {
                res.message = 'Not every Payment record is marked Paid / Verified (or Keyloop-synced).';
            } else if (!allHaveProof) {
                res.message = 'Not every Payment record has a proof/receipt document attached (upload the file under Files).';
            } else if (!allDocumentsComplete) {
                res.message = 'Not every Payment has its required documents (Cheque Copy / Bank LPO / Signed NOC) uploaded - check the Required Documents checklist on the Payment.';
            } else if (sum != expected) {
                res.message = 'Sum of Payments (' + sum.setScale(2) + ') does not equal the Invoice expected total (' + expected.setScale(2) + ').';
            } else {
                res.allowed = true;
                res.message = 'All payments verified with proof; sum matches the invoice total.';
            }
        }

        return results;
    }
}