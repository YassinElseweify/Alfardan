/**
 * ALF-RS-09 (LFRDN-339) FR1/FR3 - Flow-facing invocable wrapper for
 * AF_InvoiceSummaryService.ensureForApprovedReservations. Called from AF_FL_Reservation_Approved.
 */
public with sharing class AF_InvoiceSummary_EnsureOnResv {

    public class Request {
        @InvocableVariable(required=true label='Reservation Id')
        public Id reservationId;
    }

    @InvocableMethod(
        label='Ensure Invoice Summary For Approved Reservation'
        description='ALF-RS-09 FR1/FR3: creates the Opportunity Invoice Summary (if none exists yet) when a Vehicle Reservation is approved, seeded from the reservation quote/vehicle price total.'
    )
    public static void ensure(List<Request> requests) {
        if (requests == null || requests.isEmpty()) {
            return;
        }
        Set<Id> reservationIds = new Set<Id>();
        for (Request req : requests) {
            if (req.reservationId != null) {
                reservationIds.add(req.reservationId);
            }
        }
        AF_InvoiceSummaryService.ensureForApprovedReservations(reservationIds);
    }
}