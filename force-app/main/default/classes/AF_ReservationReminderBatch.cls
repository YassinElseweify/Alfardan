/**
 * ALF-RS-08 (LFRDN-338) FR5 / FR15 - reservation expiry reminders on a configurable cadence.
 *
 * AF_FL_Reservation_ExpiryAutomation's scheduled path could only ever fire one "1 day before
 * expiry" reminder; its own description flags that as a known simplification, because recurring
 * reminders need a scheduled job. This batch is that job.
 *
 * Cadence is read from AF_ReservationReminderCadence__mdt, one row per contract type, so the
 * business can retune reminders without a deployment (FR15). For each active reservation the
 * batch works out whether today falls inside the reminder window and whether enough days have
 * passed since the last reminder, then emails the assigned Sales Representative and posts a
 * custom notification - the same dual-channel pattern the approval flows use.
 *
 * Schedule nightly:
 *   System.schedule('AF Reservation Reminders', '0 0 6 * * ?', new AF_ReservationReminderBatch());
 */
public with sharing class AF_ReservationReminderBatch implements Database.Batchable<SObject>, Database.Stateful, Schedulable {

    private static final Set<String> LIVE_STATUSES = new Set<String>{ 'Requested', 'Pending Approval', 'Reserved' };
    private static final String NOTIFICATION_TYPE = 'AF_NT_Alfardan_Alert';

    @TestVisible private Integer remindersSent = 0;

    public void execute(SchedulableContext sc) {
        Database.executeBatch(this, 50);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        // VIP / Extended reservations deliberately carry no expiry date, so they fall out here -
        // consistent with AF_FL_Reservation_SetExpiryDate leaving that case open-ended.
        Date today = Date.today();
        return Database.getQueryLocator([
            SELECT Id, Name, AF_Status__c, AF_ContractType__c, AF_ExpiryDate__c,
                   AF_LastReminderSentDate__c, AF_ReminderCount__c,
                   AF_Account__r.Name, AF_Contact__r.Name,
                   AF_Vehicle__r.Name, AF_VehicleDefinition__r.Name,
                   OwnerId, Owner.Name, Owner.Email
            FROM AF_VehicleReservation__c
            WHERE AF_ExpiryDate__c != NULL
              AND AF_ExpiryDate__c >= :today
              AND AF_Status__c IN :LIVE_STATUSES
            ORDER BY AF_ExpiryDate__c ASC
        ]);
    }

    public void execute(Database.BatchableContext bc, List<AF_VehicleReservation__c> scope) {
        Map<String, AF_ReservationReminderCadence__mdt> cadenceByType = loadCadences();
        if (cadenceByType.isEmpty()) {
            return;
        }

        Date today = Date.today();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<AF_VehicleReservation__c> toUpdate = new List<AF_VehicleReservation__c>();
        Set<String> notifyRecipients = new Set<String>();
        List<AF_VehicleReservation__c> toNotify = new List<AF_VehicleReservation__c>();

        for (AF_VehicleReservation__c resv : scope) {
            AF_ReservationReminderCadence__mdt cadence = cadenceByType.get(resv.AF_ContractType__c);
            if (cadence == null) {
                continue;
            }
            if (!isDue(resv, cadence, today)) {
                continue;
            }

            if (String.isNotBlank(resv.Owner.Email)) {
                emails.add(buildEmail(resv, today));
            }
            toNotify.add(resv);
            notifyRecipients.add(String.valueOf(resv.OwnerId));

            toUpdate.add(new AF_VehicleReservation__c(
                Id = resv.Id,
                AF_LastReminderSentDate__c = today,
                AF_ReminderCount__c = (resv.AF_ReminderCount__c == null ? 0 : resv.AF_ReminderCount__c) + 1
            ));
            remindersSent++;
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
        sendNotifications(toNotify);
        if (!toUpdate.isEmpty()) {
            Database.update(toUpdate, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'AF_ReservationReminderBatch sent ' + remindersSent + ' reminder(s).');
    }

    /**
     * True when today sits inside the reminder window and the configured interval has elapsed
     * since the last reminder. Sending is idempotent per day: a re-run on the same date is a
     * no-op, so operating the job twice never double-mails a rep.
     */
    @TestVisible
    private static Boolean isDue(AF_VehicleReservation__c resv, AF_ReservationReminderCadence__mdt cadence, Date today) {
        if (resv.AF_ExpiryDate__c == null) {
            return false;
        }
        Integer daysToExpiry = today.daysBetween(resv.AF_ExpiryDate__c);
        if (daysToExpiry < 0) {
            return false;
        }

        Integer windowStart = cadence.AF_DaysBeforeExpiry__c == null
            ? 1
            : Integer.valueOf(cadence.AF_DaysBeforeExpiry__c);
        if (daysToExpiry > windowStart) {
            return false;
        }

        if (resv.AF_LastReminderSentDate__c == null) {
            return true;
        }
        if (resv.AF_LastReminderSentDate__c >= today) {
            return false;
        }
        if (cadence.AF_RepeatDaily__c != true) {
            return false;
        }

        Integer interval = cadence.AF_ReminderIntervalDays__c == null
            ? 1
            : Integer.valueOf(cadence.AF_ReminderIntervalDays__c);
        if (interval < 1) {
            interval = 1;
        }
        return resv.AF_LastReminderSentDate__c.daysBetween(today) >= interval;
    }

    @TestVisible
    private static Map<String, AF_ReservationReminderCadence__mdt> loadCadences() {
        Map<String, AF_ReservationReminderCadence__mdt> byType =
            new Map<String, AF_ReservationReminderCadence__mdt>();
        for (AF_ReservationReminderCadence__mdt c : [
            SELECT AF_ContractType__c, AF_DaysBeforeExpiry__c, AF_RepeatDaily__c,
                   AF_ReminderIntervalDays__c, AF_Active__c
            FROM AF_ReservationReminderCadence__mdt
            WHERE AF_Active__c = true
        ]) {
            byType.put(c.AF_ContractType__c, c);
        }
        return byType;
    }

    @TestVisible
    private static Messaging.SingleEmailMessage buildEmail(AF_VehicleReservation__c resv, Date today) {
        Integer daysLeft = today.daysBetween(resv.AF_ExpiryDate__c);
        String vehicle = resv.AF_Vehicle__r != null && resv.AF_Vehicle__r.Name != null
            ? resv.AF_Vehicle__r.Name
            : (resv.AF_VehicleDefinition__r != null ? resv.AF_VehicleDefinition__r.Name : 'the reserved vehicle');
        String customer = resv.AF_Contact__r != null && resv.AF_Contact__r.Name != null
            ? resv.AF_Contact__r.Name
            : (resv.AF_Account__r != null ? resv.AF_Account__r.Name : 'the customer');

        String whenText = daysLeft == 0
            ? 'today'
            : (daysLeft == 1 ? 'tomorrow' : 'in ' + daysLeft + ' days');

        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ resv.Owner.Email });
        mail.setSubject('Reservation ' + resv.Name + ' expires ' + whenText);
        mail.setSaveAsActivity(false);
        mail.setHtmlBody(
            '<p>Hi ' + escape(resv.Owner.Name) + ',</p>' +
            '<p>Vehicle reservation <b>' + escape(resv.Name) + '</b> for <b>' + escape(customer) +
            '</b> (' + escape(vehicle) + ') expires <b>' + whenText + '</b> on ' +
            DateTime.newInstance(resv.AF_ExpiryDate__c, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy') + '.</p>' +
            '<p>If the customer is proceeding, convert the reservation to a Sales Order before it lapses. ' +
            'If more time is needed, raise an extension - extensions require manager approval.</p>' +
            '<p>On expiry the reservation is closed automatically and the vehicle is released back to stock.</p>'
        );
        return mail;
    }

    private static void sendNotifications(List<AF_VehicleReservation__c> reservations) {
        if (reservations.isEmpty()) {
            return;
        }
        List<CustomNotificationType> types = [
            SELECT Id FROM CustomNotificationType WHERE DeveloperName = :NOTIFICATION_TYPE LIMIT 1
        ];
        if (types.isEmpty()) {
            return;
        }
        Id typeId = types[0].Id;

        for (AF_VehicleReservation__c resv : reservations) {
            try {
                Messaging.CustomNotification n = new Messaging.CustomNotification();
                n.setNotificationTypeId(typeId);
                n.setTargetId(resv.Id);
                n.setTitle('Reservation expiring: ' + resv.Name);
                n.setBody('Reservation ' + resv.Name + ' expires on ' +
                    DateTime.newInstance(resv.AF_ExpiryDate__c, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy') + '.');
                n.send(new Set<String>{ String.valueOf(resv.OwnerId) });
            } catch (Exception e) {
                // A notification failure must never lose the email or the reminder stamp.
                System.debug(LoggingLevel.WARN, 'Reservation reminder notification failed: ' + e.getMessage());
            }
        }
    }

    private static String escape(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}