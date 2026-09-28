/**
 * ALF-RS-08 (LFRDN-338): blocks creating or reactivating a Vehicle Reservation against a real
 * Vehicle that another live reservation already holds.
 *
 * Found via a live edge-case test: nothing in the original build stopped two reservations from
 * being created against the exact same Vehicle simultaneously. This class closes that hole. The
 * separate write-back to Vehicle.AF_ReservationStatus__c (the current-state mirror the vehicle
 * picker filters on) lives in AF_VehicleReservationStatusSync, run from the same trigger's after
 * context - "Reserved" reflects the same live states this guard blocks on (Requested onward, not
 * only once approval clears), so the two classes agree on what "held" means.
 *
 * Only checks real Vehicle records. A Vehicle Definition (pre-order placeholder) is a model line,
 * not a specific unit, so multiple reservations against the same Vehicle Definition are expected
 * and are not blocked here.
 */
public with sharing class AF_ReservationDoubleBookingGuard {

    private static final Set<String> LIVE_STATUSES = new Set<String>{ 'Requested', 'Pending Approval', 'Reserved' };

    public static void guard(List<AF_VehicleReservation__c> newRecords, Map<Id, AF_VehicleReservation__c> oldMap) {
        Set<Id> vehicleIdsToCheck = new Set<Id>();
        Map<Id, AF_VehicleReservation__c> recordsByVehicle = new Map<Id, AF_VehicleReservation__c>();

        for (AF_VehicleReservation__c resv : newRecords) {
            if (resv.AF_Vehicle__c == null || !LIVE_STATUSES.contains(resv.AF_Status__c)) {
                continue;
            }

            AF_VehicleReservation__c old = (oldMap == null) ? null : oldMap.get(resv.Id);
            Boolean vehicleChanged = old == null || old.AF_Vehicle__c != resv.AF_Vehicle__c;
            Boolean becameLive = old == null || !LIVE_STATUSES.contains(old.AF_Status__c);

            // Only worth a query when this save is what makes the record live against this
            // vehicle - a plain edit that touches neither field is not a new claim on the unit.
            if (vehicleChanged || becameLive) {
                vehicleIdsToCheck.add(resv.AF_Vehicle__c);
                recordsByVehicle.put(resv.Id, resv);
            }
        }

        if (vehicleIdsToCheck.isEmpty()) {
            return;
        }

        Map<Id, List<AF_VehicleReservation__c>> otherLiveByVehicle = new Map<Id, List<AF_VehicleReservation__c>>();
        for (AF_VehicleReservation__c existing : [
            SELECT Id, Name, AF_Vehicle__c, AF_Status__c
            FROM AF_VehicleReservation__c
            WHERE AF_Vehicle__c IN :vehicleIdsToCheck
              AND AF_Status__c IN :LIVE_STATUSES
            WITH SECURITY_ENFORCED
        ]) {
            if (!otherLiveByVehicle.containsKey(existing.AF_Vehicle__c)) {
                otherLiveByVehicle.put(existing.AF_Vehicle__c, new List<AF_VehicleReservation__c>());
            }
            otherLiveByVehicle.get(existing.AF_Vehicle__c).add(existing);
        }

        for (AF_VehicleReservation__c resv : recordsByVehicle.values()) {
            List<AF_VehicleReservation__c> others = otherLiveByVehicle.get(resv.AF_Vehicle__c);
            if (others == null) {
                continue;
            }
            for (AF_VehicleReservation__c other : others) {
                if (other.Id != resv.Id) {
                    resv.AF_Vehicle__c.addError(
                        'This vehicle is already held by reservation ' + other.Name +
                        ' (' + other.AF_Status__c + '). Choose a different vehicle or resolve the existing reservation first.'
                    );
                    break;
                }
            }
        }
    }
}