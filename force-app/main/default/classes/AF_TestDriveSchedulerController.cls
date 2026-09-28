/**
 * Backs the afTestDriveScheduler LWC step that follows Demo Vehicle selection
 * (ALF-RS-03) — real-time slot availability for a Vehicle/Date, and confirming
 * a booking. The record-page-level guard against the same conflict is
 * AF_FL_TestDrive_PreventDoubleBooking (before-save Flow); this class re-checks
 * server-side in confirmSchedule as defense in depth against a race between two
 * users booking the same slot at the same moment (the UI-side getBookedSlots
 * check alone can't catch that).
 */
public with sharing class AF_TestDriveSchedulerController {

    public class AF_SchedulerException extends Exception {}

    // Label -> time-of-day. Deliberately a fixed showroom slot list (owner
    // decision) rather than free-entry time, so slots can be checked/disabled
    // for conflicts instead of any arbitrary minute being bookable.
    private static final Map<String, Time> SLOT_TIMES = new Map<String, Time>{
        '9:00 AM' => Time.newInstance(9, 0, 0, 0),
        '9:30 AM' => Time.newInstance(9, 30, 0, 0),
        '10:00 AM' => Time.newInstance(10, 0, 0, 0),
        '10:30 AM' => Time.newInstance(10, 30, 0, 0),
        '11:00 AM' => Time.newInstance(11, 0, 0, 0),
        '11:30 AM' => Time.newInstance(11, 30, 0, 0),
        '12:00 PM' => Time.newInstance(12, 0, 0, 0),
        '12:30 PM' => Time.newInstance(12, 30, 0, 0),
        '1:00 PM' => Time.newInstance(13, 0, 0, 0),
        '1:30 PM' => Time.newInstance(13, 30, 0, 0),
        '2:00 PM' => Time.newInstance(14, 0, 0, 0),
        '2:30 PM' => Time.newInstance(14, 30, 0, 0),
        '3:00 PM' => Time.newInstance(15, 0, 0, 0),
        '3:30 PM' => Time.newInstance(15, 30, 0, 0),
        '4:00 PM' => Time.newInstance(16, 0, 0, 0),
        '4:30 PM' => Time.newInstance(16, 30, 0, 0),
        '5:00 PM' => Time.newInstance(17, 0, 0, 0)
    };

    @AuraEnabled(cacheable=true)
    public static List<String> getAllSlots() {
        List<String> ordered = new List<String>{
            '9:00 AM', '9:30 AM', '10:00 AM', '10:30 AM', '11:00 AM', '11:30 AM',
            '12:00 PM', '12:30 PM', '1:00 PM', '1:30 PM', '2:00 PM', '2:30 PM',
            '3:00 PM', '3:30 PM', '4:00 PM', '4:30 PM', '5:00 PM'
        };
        return ordered;
    }

    // Real bug fixed: Location/Showroom was a free-text field ("showroom list
    // pending" per its own description), so agents typed anything. Reuses the
    // existing Opportunity.AF_Showroom__c picklist (already the org's real
    // showroom list) as the option set — describe-based, so it stays in sync
    // automatically if showrooms are added/removed later, no duplicate list
    // to maintain. AF_TestDrive__c.AF_Location__c itself stays plain Text;
    // this only supplies the dropdown's choices.
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getShowroomOptions() {
        List<Map<String, String>> options = new List<Map<String, String>>();
        List<Schema.PicklistEntry> entries = Opportunity.AF_Showroom__c.getDescribe().getPicklistValues();
        for (Schema.PicklistEntry entry : entries) {
            if (entry.isActive()) {
                options.add(new Map<String, String>{ 'label' => entry.getLabel(), 'value' => entry.getValue() });
            }
        }
        return options;
    }

    /**
     * Slots already booked for this Vehicle on this Date, across any Test
     * Drive except testDriveId itself (the record currently being scheduled —
     * excluded so re-opening the scheduler on an already-scheduled record
     * doesn't lock out its own slot) and excluding Cancelled and Refused
     * bookings (LFRDN-623) — neither holds the slot.
     */
    @AuraEnabled(cacheable=true)
    public static List<String> getBookedSlots(Id vehicleId, Date scheduleDate, Id testDriveId) {
        try {
            if (vehicleId == null || scheduleDate == null) {
                return new List<String>();
            }
            Datetime dayStart = Datetime.newInstance(scheduleDate, Time.newInstance(0, 0, 0, 0));
            Datetime dayEnd = dayStart.addDays(1);

            List<AF_TestDrive__c> booked = [
                SELECT AF_TimeSlot__c
                FROM AF_TestDrive__c
                WHERE AF_Vehicle__c = :vehicleId
                    AND AF_TestDriveDateTime__c >= :dayStart
                    AND AF_TestDriveDateTime__c < :dayEnd
                    AND AF_Status__c NOT IN ('Cancelled', 'Refused')
                    AND Id != :testDriveId
                    AND AF_TimeSlot__c != null
                WITH USER_MODE
            ];

            List<String> slots = new List<String>();
            for (AF_TestDrive__c td : booked) {
                slots.add(td.AF_TimeSlot__c);
            }
            return slots;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking slot availability: ' + e.getMessage());
        }
    }

    /**
     * Confirms the booking: derives AF_TestDriveDateTime__c from date+slot,
     * re-validates no conflict exists (race-condition safety net beyond the
     * UI's own getBookedSlots check), sets Status to Scheduled so
     * AF_FL_Task_TestDriveConfirmationEmail can fire once the completion Task
     * is closed. AF_FL_TestDrive_PreventDoubleBooking still re-validates this
     * same conflict on the DML itself — this method's own check exists so a
     * caller gets a clear message instead of the generic Flow custom-error text.
     */
    @AuraEnabled
    public static void confirmSchedule(Id testDriveId, Id vehicleId, Date scheduleDate, String timeSlot, String location) {
        try {
            if (testDriveId == null || vehicleId == null || scheduleDate == null || String.isBlank(timeSlot)) {
                throw new AF_SchedulerException('Vehicle, date, and time slot are all required.');
            }
            if (!SLOT_TIMES.containsKey(timeSlot)) {
                throw new AF_SchedulerException('Unrecognized time slot: ' + timeSlot);
            }
            if (String.isBlank(location)) {
                throw new AF_SchedulerException('Location is required to confirm the booking.');
            }

            Datetime scheduledDateTime = Datetime.newInstance(scheduleDate, SLOT_TIMES.get(timeSlot));

            List<AF_TestDrive__c> conflicts = [
                SELECT Id
                FROM AF_TestDrive__c
                WHERE AF_Vehicle__c = :vehicleId
                    AND AF_TestDriveDateTime__c = :scheduledDateTime
                    AND AF_Status__c NOT IN ('Cancelled', 'Refused')
                    AND Id != :testDriveId
                WITH USER_MODE
                LIMIT 1
            ];
            if (!conflicts.isEmpty()) {
                throw new AF_SchedulerException('This vehicle was just booked for that slot by someone else. Please pick a different slot.');
            }

            AF_TestDrive__c td = new AF_TestDrive__c(
                Id = testDriveId,
                AF_Vehicle__c = vehicleId,
                AF_TestDriveDateTime__c = scheduledDateTime,
                AF_TimeSlot__c = timeSlot,
                AF_Location__c = location,
                AF_Status__c = 'Scheduled'
            );
            update as user td;
        } catch (AF_SchedulerException se) {
            throw new AuraHandledException(se.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error confirming booking: ' + e.getMessage());
        }
    }
}