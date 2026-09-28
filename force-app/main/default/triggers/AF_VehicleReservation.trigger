/**
 * ALF-RS-08 (LFRDN-338): the only place double-booking protection and the Vehicle
 * reservation-status mirror can live. Validation rules cannot query sibling records, and the
 * object's governance is otherwise entirely Flow-based in this org - this is the first Apex
 * trigger on AF_VehicleReservation__c, added because AF_ReservationDoubleBookingGuard needs a
 * cross-record SOQL check before insert/update, and FR1/FR16's Vehicle.AF_ReservationStatus__c
 * mirror needs an after-context DML against a different object entirely - it also has to run on
 * after update, since a reservation entering or leaving a live state (Approve, Cancel, Expire)
 * happens on an existing record, not just at insert.
 *
 * 2026-09-19: removed the FR13 Required Document seeding call (AF_RequiredDocumentService) - that
 * mechanism was superseded 2026-09-16 by the AF_Document__mdt/afDocumentComponent engine (the one
 * actually gating AF_ReservationContractService today) and the old object/trigger/service/mdt were
 * fully removed as dead weight, not left in place this time.
 */
trigger AF_VehicleReservation on AF_VehicleReservation__c (before insert, before update, after insert, after update) {
    if (Trigger.isBefore) {
        AF_ReservationDoubleBookingGuard.guard(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }

    if (Trigger.isAfter) {
        AF_VehicleReservationStatusSync.sync(
            Trigger.new,
            Trigger.isUpdate ? Trigger.oldMap : null
        );
    }
}