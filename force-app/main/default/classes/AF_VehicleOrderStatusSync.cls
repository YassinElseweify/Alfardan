/**
 * ALF-RS-10 (LFRDN-340) FR2 / FR3 / FR6 / AC2 / AC3 - Keyloop vehicle order status sync (stub).
 *
 * No live Keyloop/MuleSoft integration exists yet for vehicle order status (unlike Payments and
 * Reservations, which already carry AF_KeyloopPaymentReference__c / AF_KeyloopReservationReference__c
 * and an AF_IntegrationStatus__c field wired to real sync flows). This class is the Salesforce-side
 * entry point a future inbound integration user/Platform Event would call - for now it is invoked
 * manually (data-fix / Ordering-Planning-Admin Quick Action) to set Vehicle.AF_VehicleOrderState__c,
 * the field whose three values (On Order / In Transit / In Stock-Arrived) match the BRD's FR3
 * wording exactly.
 *
 * On a transition INTO "In Stock-Arrived" (AC3), notifies the customer and the owning Sales
 * Representative on the linked Opportunity, if a Sales Order has already been generated for it -
 * "the customer receives a progress notification" only makes sense once there is an order to
 * progress. A vehicle with no linked Opportunity/Sales Order simply updates silently; that is a
 * normal stock-arrival with no customer waiting on it yet.
 *
 * LFRDN-672: AF_VehicleOrderState__c (this field, matching FR3's wording exactly) and
 * AF_InventoryStatus__c (what AF_SalesOrderService/AF_VR_Opp_SOGenerationGate actually read, and
 * what the Vehicle page already showed) were two disconnected fields - nothing kept them in sync,
 * so a vehicle synced here as In Stock-Arrived never unblocked Sales Order generation, which
 * checks the other field entirely. AF_VehicleOrderState__c is the authoritative Keyloop-mastered
 * field going forward; this sync now also writes the equivalent AF_InventoryStatus__c value in
 * the same transaction, so the gate keeps working unchanged and both fields agree.
 */
public with sharing class AF_VehicleOrderStatusSync {

    private static final Set<String> VALID_STATES = new Set<String>{ 'On Order', 'In Transit', 'In Stock-Arrived' };
    private static final String STATE_IN_STOCK = 'In Stock-Arrived';

    // LFRDN-672: maps the authoritative AF_VehicleOrderState__c value onto the equivalent
    // AF_InventoryStatus__c value the Sales Order gate and existing UI already read.
    private static final Map<String, String> ORDER_STATE_TO_INVENTORY_STATUS = new Map<String, String>{
        'On Order' => 'Ordered', 'In Transit' => 'In Transit', 'In Stock-Arrived' => 'In Stock'
    };

    /**
     * LFRDN-663: order state is meant to move forward only. A late/out-of-order message (normal
     * for an async integration) must not push a vehicle backwards - e.g. a delayed "On Order"
     * arriving after "In Stock-Arrived" was already applied. Whether a genuine backwards move
     * (e.g. a showroom transfer) should ever be possible is an open business question per the
     * ticket; until that is decided, every backwards transition is rejected rather than silently
     * allowed, since a silent regression is worse than a rejected update the integration can retry
     * or a human can apply deliberately.
     */
    private static final Map<String, Integer> STATE_RANK = new Map<String, Integer>{
        'On Order' => 0, 'In Transit' => 1, 'In Stock-Arrived' => 2
    };

    public class Request {
        @InvocableVariable(required=true label='Vehicle Id')
        public Id vehicleId;

        @InvocableVariable(required=true label='Vehicle Order State')
        public String orderState;

        @InvocableVariable(label='Brand Sub-Status')
        public String brandSubStatus;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
    }

    @InvocableMethod(
        label='Sync Vehicle Order Status'
        description='ALF-RS-10 FR2/FR3: updates Vehicle.AF_VehicleOrderState__c to reflect the Keyloop-synced order status, and notifies on arrival (FR6/AC3).'
    )
    public static List<Result> sync(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> vehicleIds = new Set<Id>();
        for (Request req : requests) {
            if (req.vehicleId != null) {
                vehicleIds.add(req.vehicleId);
            }
        }

        Map<Id, Vehicle> vehiclesBefore = new Map<Id, Vehicle>([
            SELECT Id, Name, AF_VehicleOrderState__c
            FROM Vehicle
            WHERE Id IN :vehicleIds
            WITH USER_MODE
        ]);

        List<Vehicle> toUpdate = new List<Vehicle>();
        List<Id> arrivedVehicleIds = new List<Id>();

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            results.add(res);

            Vehicle before = vehiclesBefore.get(req.vehicleId);
            if (before == null) {
                res.message = 'Vehicle not found, or you do not have access to it.';
                continue;
            }
            if (!VALID_STATES.contains(req.orderState)) {
                res.message = 'Invalid Vehicle Order State "' + req.orderState + '" - must be On Order, In Transit, or In Stock-Arrived.';
                continue;
            }

            Integer currentRank = STATE_RANK.get(before.AF_VehicleOrderState__c);
            Integer incomingRank = STATE_RANK.get(req.orderState);
            if (currentRank != null && incomingRank < currentRank) {
                // Not an error - a late/out-of-order message is expected from an async integration.
                // The vehicle is left at its current (more advanced) state.
                res.success = true;
                res.message = 'Vehicle Order State was not changed: "' + req.orderState + '" is earlier than the vehicle\'s current state "' +
                    before.AF_VehicleOrderState__c + '". A backwards transition was ignored (LFRDN-663).';
                continue;
            }

            Vehicle upd = new Vehicle(
                Id = req.vehicleId,
                AF_VehicleOrderState__c = req.orderState,
                AF_InventoryStatus__c = ORDER_STATE_TO_INVENTORY_STATUS.get(req.orderState)
            );
            if (String.isNotBlank(req.brandSubStatus)) {
                upd.AF_BrandSubStatus__c = req.brandSubStatus;
            }
            toUpdate.add(upd);

            if (req.orderState == STATE_IN_STOCK && before.AF_VehicleOrderState__c != STATE_IN_STOCK) {
                arrivedVehicleIds.add(req.vehicleId);
            }

            res.success = true;
            res.message = 'Vehicle order status synced to ' + req.orderState + '.';
        }

        if (!toUpdate.isEmpty()) {
            update as user toUpdate;
        }
        if (!arrivedVehicleIds.isEmpty()) {
            notifyOnArrival(arrivedVehicleIds);
        }

        return results;
    }

    private static final Set<String> LIVE_ORDER_SO_STATUSES = new Set<String>{
        'Generated', 'Sent to Customer', 'Signed'
    };

    /**
     * FR6/AC3: "the customer receives a progress notification and the sales order is updated" -
     * only meaningful once a Sales Order already exists for the Opportunity holding the vehicle.
     * LFRDN-664: notifies only Opportunities with a live order (Generated/Sent to Customer/Signed)
     * - an inclusion list rather than the old "!= Not Generated" exclusion, so Cancelled and
     * Delivered orders (already handed over, nothing new to report) are correctly excluded, and any
     * future AF_SOStatus__c value fails safe by not notifying rather than notifying. Checks the
     * Contact's consent before emailing them, and falls back to the Invoice Summary contact when
     * AF_PrimaryBrandContact__c is blank - surfacing in the rep email when no contactable customer
     * could be found at all, so the gap is visible rather than a silent success.
     */
    private static void notifyOnArrival(List<Id> vehicleIds) {
        List<AF_VehicleReservation__c> reservations = [
            SELECT Id, AF_Vehicle__c,
                   AF_Opportunity__c, AF_Opportunity__r.Name, AF_Opportunity__r.AF_SOStatus__c,
                   AF_Opportunity__r.Account.Name,
                   AF_Opportunity__r.AF_PrimaryBrandContact__c,
                   AF_Opportunity__r.AF_PrimaryBrandContact__r.Name,
                   AF_Opportunity__r.AF_PrimaryBrandContact__r.Email,
                   AF_Opportunity__r.AF_PrimaryBrandContact__r.HasOptedOutOfEmail,
                   AF_Opportunity__r.AF_InvoiceSummary__r.AF_Contact__c,
                   AF_Opportunity__r.AF_InvoiceSummary__r.AF_Contact__r.Name,
                   AF_Opportunity__r.AF_InvoiceSummary__r.AF_Contact__r.Email,
                   AF_Opportunity__r.AF_InvoiceSummary__r.AF_Contact__r.HasOptedOutOfEmail,
                   AF_Opportunity__r.Owner.Name, AF_Opportunity__r.Owner.Email,
                   AF_Vehicle__r.Name
            FROM AF_VehicleReservation__c
            WHERE AF_Vehicle__c IN :vehicleIds
              AND AF_Opportunity__c != null
              AND AF_Opportunity__r.AF_SOStatus__c IN :LIVE_ORDER_SO_STATUSES
            WITH USER_MODE
        ];
        if (reservations.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (AF_VehicleReservation__c resv : reservations) {
            Opportunity opp = resv.AF_Opportunity__r;

            Contact customer = resolveCustomerContact(opp);
            Boolean customerNotified = false;
            if (customer != null && String.isNotBlank(customer.Email) && customer.HasOptedOutOfEmail != true) {
                emails.add(buildCustomerEmail(customer, resv.AF_Vehicle__r.Name, opp.Owner.Name));
                customerNotified = true;
            }

            if (String.isNotBlank(opp.Owner.Email)) {
                emails.add(buildRepEmail(opp, resv.AF_Vehicle__r.Name, customerNotified, customer != null));
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails, false);
        }
    }

    /**
     * LFRDN-664 issue 3: AF_PrimaryBrandContact__c is blank on a freshly created Opportunity.
     * Falls back to the Invoice Summary contact - the same fallback AF_SalesOrderService already
     * uses when building the Sales Order document.
     */
    private static Contact resolveCustomerContact(Opportunity opp) {
        if (opp.AF_PrimaryBrandContact__c != null) {
            return opp.AF_PrimaryBrandContact__r;
        }
        if (opp.AF_InvoiceSummary__r != null && opp.AF_InvoiceSummary__r.AF_Contact__c != null) {
            return opp.AF_InvoiceSummary__r.AF_Contact__r;
        }
        return null;
    }

    private static Messaging.SingleEmailMessage buildRepEmail(Opportunity opp, String vehicleName, Boolean customerNotified, Boolean customerFound) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new List<String>{ opp.Owner.Email });
        mail.setSubject('Vehicle arrived: ' + vehicleName + ' (' + opp.Name + ')');
        mail.setSaveAsActivity(false);

        String customerStatusLine;
        if (customerNotified) {
            customerStatusLine = 'The customer has been notified.';
        } else if (customerFound) {
            customerStatusLine = 'The customer was <b>not</b> notified (opted out of email communications).';
        } else {
            customerStatusLine = 'The customer was <b>not</b> notified - no contactable customer (Primary Brand Contact or Invoice Summary contact) with an email address could be found. Please follow up manually.';
        }

        mail.setHtmlBody(
            '<p>Hi ' + escape(opp.Owner.Name) + ',</p>' +
            '<p>The vehicle for <b>' + escape(opp.Name) + '</b> (' + escape(vehicleName) + ') is now ' +
            '<b>In Stock-Arrived</b>. ' + customerStatusLine + ' Please coordinate handover next steps.</p>'
        );
        return mail;
    }

    private static Messaging.SingleEmailMessage buildCustomerEmail(Contact customer, String vehicleName, String repName) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setTargetObjectId(customer.Id);
        mail.setSubject('Your vehicle has arrived');
        mail.setSaveAsActivity(false);
        mail.setHtmlBody(
            '<p>Dear ' + escape(customer.Name) + ',</p>' +
            '<p>Good news - your vehicle (' + escape(vehicleName) + ') has arrived and is now in stock. ' +
            'Your Sales Representative, ' + escape(repName) + ', will be in touch shortly to arrange the next steps.</p>'
        );
        return mail;
    }

    private static String escape(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}