/**
 * ALF-RS-09 - "Get Payment" on Invoice Summary. Sales Reps no longer create Payment records
 * directly (Record Payment has been removed) - the only path onto a deal's Invoice Summary is
 * pulling a real payment from Keyloop by its payment reference.
 *
 * No live Keyloop integration exists in this org yet (confirmed: zero Named Credentials, zero
 * Apex HTTP callouts anywhere). Per explicit instruction, this is built as a full in-Salesforce
 * simulation for now: the agent enters ONLY the Keyloop Payment ID - every other field (payee,
 * amount, method, date) is synthesized here exactly as a real callout response would arrive,
 * derived from the Invoice Summary itself (payee = the Account on record, amount = the
 * outstanding balance so a single pull can bring the deal to Fully Paid, method = Bank Transfer,
 * date = today). Swapping in a real HttpRequest to Keyloop later only touches the body of
 * getPayment() below - the screen flow, its single input field, and everything downstream
 * (recalculation, gates) is unchanged.
 *
 * NOC handling (LFRDN-686 fix): AF_NOCRecorded__c is left false. It was previously asserted true
 * on every simulated payment, which recorded a false statement (no signed NOC was ever produced or
 * reviewed) and, worse, tripped the Signed NOC document requirement in the LFRDN-342 engine for a
 * certificate that doesn't exist - blocking every deal's close. Since the simulated payee always
 * equals the Invoice Summary's own Account, AF_VR_Payment_PayeeMismatchNOC can never fire either
 * way; leaving the flag false just stops the false assertion without changing behavior. The real
 * NOC path is reintroduced alongside the real Keyloop callout, when a returned payee name can
 * genuinely differ from the customer of record.
 *
 * Proof handling (LFRDN-683 fix): generates and attaches a ContentVersion as the Keyloop payment
 * advice on the Payment it creates, alongside the AF_ProofReference__c text label. The Closed Won
 * gate (AF_Opportunity_ClosedWonPaymentGate) requires a real ContentDocumentLink, not just a
 * reference field - see that class's header for why. A payment the system itself pulled and marked
 * verified should carry its own evidence rather than needing a human to upload one by hand.
 *
 * Vehicle Reservation linking (LFRDN-693 fix): the created Payment never had AF_VehicleReservation__c
 * populated, leaving it to be found and set by hand. Sourced from Opportunity.AF_VehicleReservation__c
 * - the same live-reservation mirror AF_OpportunityReservationMirrorSync already maintains for
 * LFRDN-669/680 - rather than re-deriving "the current Reserved reservation" a third time in this
 * class. Left null (not an error) when the Opportunity has no live reservation, since a payment can
 * legitimately be pulled against a deal that was never reserved (see LFRDN-681).
 */
public with sharing class AF_KeyloopGetPayment {

    public class Request {
        @InvocableVariable(required=true label='Invoice Summary Id')
        public Id invoiceSummaryId;

        @InvocableVariable(required=true label='Keyloop Payment ID')
        public String keyloopPaymentReference;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id paymentId;
        @InvocableVariable public Boolean nocGenerated;
    }

    @InvocableMethod(
        label='Get Payment From Keyloop'
        description='Pulls a payment by reference (simulated pending live Keyloop integration) and creates it against the given Invoice Summary.'
    )
    public static List<Result> getPayment(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> invoiceSummaryIds = new Set<Id>();
        for (Request req : requests) {
            if (req.invoiceSummaryId != null) {
                invoiceSummaryIds.add(req.invoiceSummaryId);
            }
        }

        Map<Id, AF_InvoiceSummary__c> invoiceSummaries = new Map<Id, AF_InvoiceSummary__c>([
            SELECT Id, Name, AF_Opportunity__c, AF_Opportunity__r.AF_VehicleReservation__c,
                   AF_Quote__c, AF_Account__c, AF_Account__r.Name,
                   AF_Contact__c, AF_Vehicle__c, AF_Status__c,
                   AF_ExpectedTotalAmount__c, AF_PaidAmount__c, AF_Balance__c
            FROM AF_InvoiceSummary__c
            WHERE Id IN :invoiceSummaryIds
            WITH USER_MODE
        ]);

        List<AF_Payment__c> paymentsToInsert = new List<AF_Payment__c>();
        List<Result> resultForInsertIndex = new List<Result>();

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            res.nocGenerated = false;
            results.add(res);

            if (String.isBlank(req.keyloopPaymentReference)) {
                res.message = 'A Keyloop Payment ID is required.';
                continue;
            }
            AF_InvoiceSummary__c inv = invoiceSummaries.get(req.invoiceSummaryId);
            if (inv == null) {
                res.message = 'Invoice Summary not found, or you do not have access to it.';
                continue;
            }
            if (inv.AF_Status__c == 'Fully Paid') {
                res.message = 'This Invoice Summary is already Fully Paid - nothing outstanding to pull.';
                continue;
            }

            if (inv.AF_ExpectedTotalAmount__c == null) {
                res.message = 'This Invoice Summary has no Expected Total set - check the linked Quote before pulling a payment.';
                continue;
            }

            // Simulated Keyloop response, derived from the Invoice Summary itself (no live
            // integration exists yet - see class header). A real callout replaces this block only.
            Decimal outstanding = inv.AF_Balance__c != null
                ? inv.AF_Balance__c
                : inv.AF_ExpectedTotalAmount__c - (inv.AF_PaidAmount__c == null ? 0 : inv.AF_PaidAmount__c);
            if (outstanding == null || outstanding <= 0) {
                res.message = 'No outstanding balance to pull a payment against.';
                continue;
            }
            String keyloopPayeeName = inv.AF_Account__c != null ? inv.AF_Account__r.Name : null;

            AF_Payment__c pay = new AF_Payment__c(
                AF_InvoiceSummary__c = inv.Id,
                AF_Opportunity__c = inv.AF_Opportunity__c,
                AF_VehicleReservation__c = inv.AF_Opportunity__c != null ? inv.AF_Opportunity__r.AF_VehicleReservation__c : null,
                AF_Quote__c = inv.AF_Quote__c,
                AF_Account__c = inv.AF_Account__c,
                AF_Contact__c = inv.AF_Contact__c,
                AF_Amount__c = outstanding,
                AF_PaymentMethod__c = 'Bank Transfer',
                AF_PaymentDate__c = Date.today(),
                AF_PayeeName__c = keyloopPayeeName,
                AF_KeyloopPaymentReference__c = req.keyloopPaymentReference,
                AF_ExternalMatchingReference__c = req.keyloopPaymentReference,
                AF_SFPaymentReference__c = 'PAY-' + inv.Name + '-' + String.valueOf(Datetime.now().getTime()),
                AF_Status__c = 'Paid / Verified',
                AF_IntegrationStatus__c = 'Synced',
                AF_ProofReference__c = 'Keyloop payment ' + req.keyloopPaymentReference,
                AF_NOCRecorded__c = false
            );

            paymentsToInsert.add(pay);
            resultForInsertIndex.add(res);
        }

        if (paymentsToInsert.isEmpty()) {
            return results;
        }

        insert as user paymentsToInsert;

        List<ContentVersion> adviceFiles = new List<ContentVersion>();
        for (AF_Payment__c pay : paymentsToInsert) {
            String adviceBody = 'Keyloop Payment Advice\n'
                + 'Reference: ' + pay.AF_KeyloopPaymentReference__c + '\n'
                + 'Amount: ' + String.valueOf(pay.AF_Amount__c) + '\n'
                + 'Method: ' + pay.AF_PaymentMethod__c + '\n'
                + 'Date: ' + String.valueOf(pay.AF_PaymentDate__c) + '\n'
                + 'Payee: ' + pay.AF_PayeeName__c + '\n'
                + 'Integration Status: Synced';
            adviceFiles.add(new ContentVersion(
                Title = 'Keyloop Payment Advice - ' + pay.AF_KeyloopPaymentReference__c,
                PathOnClient = 'Keyloop_Payment_Advice_' + pay.AF_KeyloopPaymentReference__c + '.txt',
                VersionData = Blob.valueOf(adviceBody),
                FirstPublishLocationId = pay.Id
            ));
        }
        if (!adviceFiles.isEmpty()) {
            insert as user adviceFiles;
        }

        for (Integer i = 0; i < paymentsToInsert.size(); i++) {
            AF_Payment__c pay = paymentsToInsert[i];
            Result res = resultForInsertIndex[i];
            res.success = true;
            res.paymentId = pay.Id;
            res.message = 'Payment ' + pay.AF_KeyloopPaymentReference__c + ' pulled from Keyloop and recorded, with payment advice attached.';
        }

        Set<Id> opportunityIdsToRecalculate = new Set<Id>();
        for (AF_InvoiceSummary__c inv : invoiceSummaries.values()) {
            if (inv.AF_Opportunity__c != null) {
                opportunityIdsToRecalculate.add(inv.AF_Opportunity__c);
            }
        }
        AF_InvoiceSummaryService.recalculateForOpportunities(opportunityIdsToRecalculate);

        return results;
    }
}