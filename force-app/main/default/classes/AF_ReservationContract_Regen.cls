/**
 * ALF-RS-09 (LFRDN-339) FR3/AC1 - BRD verbatim: "...the reservation contract clearly reflects the
 * amount paid as a deposit and the remaining balance" and AC1 "When the payment is recorded,
 * Then... the reservation contract reflects the deposit amount." First-time contract generation
 * (AF_FL_Reservation_GenerateContract, ALF-RS-08 FR14) stays a rep-triggered Quick Action - this
 * class only handles the case a first BRD reading misses: once a contract already exists and a
 * LATER payment changes the deposit/balance numbers, nothing was re-running the generator, so the
 * customer-facing document went stale the moment a second payment was recorded.
 *
 * Called from AF_FL_Payment_RecalculateInvoiceSummary after the Invoice Summary recalc, for every
 * Vehicle Reservation tied to the Opportunity that already has a contract on file
 * (AF_ContractDocumentReference__c populated). Regeneration re-runs the exact same FR12/FR13 gates
 * as first-time generation (bypassGates=false) - if the reservation has since gone
 * Cancelled/Expired, or a Required Document got unchecked, regeneration correctly stops rather
 * than silently producing a stale or wrong document from data that's no longer valid.
 */
public with sharing class AF_ReservationContract_Regen {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    @InvocableMethod(
        label='Regenerate Reservation Contract On Payment'
        description='ALF-RS-09 FR3/AC1: regenerates the Opportunity reservation contract, if one already exists, so it reflects the latest deposit/balance after a payment is recorded.'
    )
    public static void regenerateIfContractExists(List<Request> requests) {
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

        List<AF_ReservationContractService.Request> regenRequests = new List<AF_ReservationContractService.Request>();
        for (AF_VehicleReservation__c resv : [
            SELECT Id
            FROM AF_VehicleReservation__c
            WHERE AF_Opportunity__c IN :opportunityIds
              AND AF_ContractDocumentReference__c != null
            WITH USER_MODE
        ]) {
            AF_ReservationContractService.Request req = new AF_ReservationContractService.Request();
            req.reservationId = resv.Id;
            req.bypassGates = false;
            regenRequests.add(req);
        }

        if (regenRequests.isEmpty()) {
            return;
        }

        AF_ReservationContractService.generate(regenRequests);
    }
}