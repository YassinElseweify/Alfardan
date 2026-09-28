/**
 * ALF-RS-08 (LFRDN-338) FR1/FR16: keeps Vehicle.AF_ReservationStatus__c (the current-state mirror)
 * in sync with the reservation that holds it.
 *
 * Found live: RES-00052 held a real Ferrari as "Reserved", but the vehicle's own
 * AF_ReservationStatus__c still read "Available" - nothing ever wrote to it. That field is what
 * AF_FL_Quote_CreateReservation's own vehicle picker filters on, so an already-held vehicle was
 * still selectable there (only caught afterward by AF_ReservationDoubleBookingGuard's error, not
 * prevented upfront by a clean picker). AF_VehicleExplorerController works around the same gap by
 * ignoring this field and querying AF_VehicleReservation__c live instead - that workaround stays in
 * place; this class is what makes the field itself finally trustworthy.
 *
 * A vehicle is "Reserved" the moment a reservation against it is in any of the same live states
 * AF_ReservationDoubleBookingGuard uses to block double-booking (Requested, Pending Approval,
 * Reserved) - FR1's governance starts at the request, not only once an approval clears, matching
 * how the guard already treats "live". It reverts to "Available" once no live reservation remains
 * against it (Expired, Cancelled, Converted, or the vehicle lookup was cleared/changed away).
 *
 * Vehicle Definitions (pre-order placeholders) are never touched: they are a model line, not a
 * specific unit, so this only ever runs against real Vehicle records.
 *
 * Runs without sharing (system context) rather than "as user": this is a system-of-record mirror
 * sync, not a user-facing data change, and was never meant to depend on the running user's personal
 * record access to Vehicle/Asset. Found live: every Vehicle's parent Asset is owned by the admin
 * user with no sharing rule granting Sales Rep/Manager personas edit access, so the plain "as user"
 * update here silently failed (INSUFFICIENT_ACCESS_OR_READONLY) for every real persona, rolling back
 * the entire Create Reservation transaction. A Sales Rep reserving a vehicle should never need edit
 * rights on the underlying inventory record to do so.
 */
public without sharing class AF_VehicleReservationStatusSync {

    private static final Set<String> LIVE_STATUSES = new Set<String>{ 'Requested', 'Pending Approval', 'Reserved' };
    private static final String VEHICLE_RESERVED = 'Reserved';
    private static final String VEHICLE_AVAILABLE = 'Available';

    public static void sync(List<AF_VehicleReservation__c> newRecords, Map<Id, AF_VehicleReservation__c> oldMap) {
        Set<Id> vehicleIdsTouched = new Set<Id>();

        for (AF_VehicleReservation__c resv : newRecords) {
            AF_VehicleReservation__c old = (oldMap == null) ? null : oldMap.get(resv.Id);

            if (resv.AF_Vehicle__c != null) {
                vehicleIdsTouched.add(resv.AF_Vehicle__c);
            }
            if (old != null && old.AF_Vehicle__c != null && old.AF_Vehicle__c != resv.AF_Vehicle__c) {
                vehicleIdsTouched.add(old.AF_Vehicle__c);
            }
        }

        if (vehicleIdsTouched.isEmpty()) {
            return;
        }

        Map<Id, List<AF_VehicleReservation__c>> liveByVehicle = new Map<Id, List<AF_VehicleReservation__c>>();
        for (AF_VehicleReservation__c live : [
            SELECT Id, AF_Vehicle__c
            FROM AF_VehicleReservation__c
            WHERE AF_Vehicle__c IN :vehicleIdsTouched
              AND AF_Status__c IN :LIVE_STATUSES
            WITH SECURITY_ENFORCED
        ]) {
            if (!liveByVehicle.containsKey(live.AF_Vehicle__c)) {
                liveByVehicle.put(live.AF_Vehicle__c, new List<AF_VehicleReservation__c>());
            }
            liveByVehicle.get(live.AF_Vehicle__c).add(live);
        }

        Map<Id, Vehicle> currentVehicles = new Map<Id, Vehicle>(
            [SELECT Id, AF_ReservationStatus__c FROM Vehicle WHERE Id IN :vehicleIdsTouched WITH SECURITY_ENFORCED]
        );

        List<Vehicle> vehiclesToUpdate = new List<Vehicle>();
        for (Id vehicleId : vehicleIdsTouched) {
            Vehicle v = currentVehicles.get(vehicleId);
            if (v == null) {
                continue;
            }
            String targetStatus = liveByVehicle.containsKey(vehicleId) ? VEHICLE_RESERVED : VEHICLE_AVAILABLE;
            if (v.AF_ReservationStatus__c != targetStatus) {
                vehiclesToUpdate.add(new Vehicle(Id = vehicleId, AF_ReservationStatus__c = targetStatus));
            }
        }

        if (!vehiclesToUpdate.isEmpty()) {
            update vehiclesToUpdate;
        }
    }
}