/**
 * LFRDN-669: keeps Opportunity.AF_VehicleReservation__c in sync with the reservation that
 * currently holds the Opportunity's selected vehicle.
 *
 * Found live: AF_SalesOrderService.findBlocker() and AF_VR_Opp_SOGenerationGate both read the
 * mirror field Opportunity.AF_VehicleReservation__c to decide whether a live Reserved reservation
 * exists - but nothing in the build ever wrote to it. AF_InvoiceSummaryService.ensureForApprovedReservations
 * mirrors AF_InvoiceSummary__c onto the Opportunity, but only once per Opportunity's lifetime (it
 * is duplicate-guarded against an existing Invoice Summary), so it is the wrong place to also
 * maintain a mirror that can legitimately need to change more than once (e.g. a rejected-and-resubmitted
 * reservation, or an extension replacing an earlier reservation).
 *
 * Matches the same "live" definition AF_ReservationDoubleBookingGuard and AF_VehicleReservationStatusSync
 * already use: the mirror is set the moment a reservation reaches Reserved, and cleared back to
 * blank once no Reserved reservation remains for that Opportunity (Expired, Cancelled, Converted,
 * or Requested/Pending Approval - none of those hold the vehicle for Sales Order purposes, which
 * only accepts Reserved per LFRDN-661).
 *
 * Runs "as user" via the same trigger context as AF_VehicleReservationStatusSync, on
 * AF_VehicleReservation__c after insert/update - the mirror lives on the parent (Opportunity), so
 * this needs an after-context DML against a different object, same reasoning as the vehicle sync.
 */
public with sharing class AF_OpportunityReservationMirrorSync {

    private static final String STATUS_RESERVED = 'Reserved';

    public static void sync(List<AF_VehicleReservation__c> newRecords, Map<Id, AF_VehicleReservation__c> oldMap) {
        Set<Id> opportunityIdsTouched = new Set<Id>();

        for (AF_VehicleReservation__c resv : newRecords) {
            AF_VehicleReservation__c old = (oldMap == null) ? null : oldMap.get(resv.Id);

            if (resv.AF_Opportunity__c != null) {
                opportunityIdsTouched.add(resv.AF_Opportunity__c);
            }
            if (old != null && old.AF_Opportunity__c != null && old.AF_Opportunity__c != resv.AF_Opportunity__c) {
                opportunityIdsTouched.add(old.AF_Opportunity__c);
            }
        }

        if (opportunityIdsTouched.isEmpty()) {
            return;
        }

        Map<Id, AF_VehicleReservation__c> reservedByOpportunity = new Map<Id, AF_VehicleReservation__c>();
        for (AF_VehicleReservation__c live : [
            SELECT Id, AF_Opportunity__c
            FROM AF_VehicleReservation__c
            WHERE AF_Opportunity__c IN :opportunityIdsTouched
              AND AF_Status__c = :STATUS_RESERVED
            WITH USER_MODE
        ]) {
            // If more than one Reserved reservation somehow exists on the same Opportunity, keep
            // whichever the query returns first rather than erroring - this mirror is read by the
            // Sales Order gate, which separately validates the reservation's vehicle matches the
            // Opportunity's selected vehicle, so a stale/ambiguous mirror is caught there.
            if (!reservedByOpportunity.containsKey(live.AF_Opportunity__c)) {
                reservedByOpportunity.put(live.AF_Opportunity__c, live);
            }
        }

        Map<Id, Opportunity> currentOpportunities = new Map<Id, Opportunity>(
            [SELECT Id, AF_VehicleReservation__c FROM Opportunity WHERE Id IN :opportunityIdsTouched WITH USER_MODE]
        );

        List<Opportunity> oppUpdates = new List<Opportunity>();
        for (Id oppId : opportunityIdsTouched) {
            Opportunity opp = currentOpportunities.get(oppId);
            if (opp == null) {
                continue;
            }
            Id targetReservationId = reservedByOpportunity.containsKey(oppId) ? reservedByOpportunity.get(oppId).Id : null;
            if (opp.AF_VehicleReservation__c != targetReservationId) {
                oppUpdates.add(new Opportunity(Id = oppId, AF_VehicleReservation__c = targetReservationId));
            }
        }

        if (!oppUpdates.isEmpty()) {
            update as user oppUpdates;
        }
    }
}