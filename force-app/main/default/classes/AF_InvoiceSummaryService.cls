/**
 * ALF-RS-09 (LFRDN-339) - Invoice Summary lifecycle shared logic.
 *
 * AF_InvoiceSummary__c (DEC-012 of the 06-quotation-reservation-payment-sales-order LLD) tracks
 * totals/balance/gate on the Opportunity - it is never the legal invoice (Keyloop creates that).
 *
 * A Salesforce Apex class may declare at most one @InvocableMethod, so the three Flow-facing entry
 * points that use this shared logic each live in their own thin class:
 *   - AF_InvoiceSummary_EnsureForReservation (FR1/FR3, called from AF_FL_Reservation_Approved)
 *   - AF_InvoiceSummary_Recalculate (FR2/AC1/AC2, called from AF_FL_Payment_RecalculateInvoiceSummary)
 *   - AF_Opportunity_ClosedWonPaymentGate (FR6, the authoritative Closed Won payment check)
 *
 * LFRDN-680 follow-on: found live that ensureForApprovedReservations, run "as user" from
 * AF_FL_Reservation_Approved (FR1/FR3), throws INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY the
 * moment a Manager approves a reservation - inserting an Invoice Summary that cross-references the
 * Opportunity fails because the approving Manager has no read/edit access to that Opportunity.
 * Same root cause and fix as AF_VehicleReservationStatusSync and AF_OpportunityReservationMirrorSync:
 * this is a system-of-record write, not something the triggering user needs personal access to, so
 * the whole class now runs without sharing rather than per-statement "as user"/WITH USER_MODE.
 */
public without sharing class AF_InvoiceSummaryService {

    public static final String STATUS_PAID = 'Paid / Verified';
    public static final String INTEGRATION_SYNCED = 'Synced';

    public static final String INV_UNPAID = 'Unpaid';
    public static final String INV_PARTIAL = 'Partially Paid';
    public static final String INV_FULL = 'Fully Paid';

    /**
     * FR1/FR3 - creates the Opportunity's AF_InvoiceSummary__c the moment a reservation is
     * approved, if one does not already exist, seeded from the reservation's own Quote/vehicle-
     * price total (DEC-012's "expected (quote) total"). Matches the BRD's "reservation deposits
     * are tracked against an initial Invoice record" line - the record exists before any payment
     * does.
     *
     * The duplicate-guard queries AF_InvoiceSummary__c directly by its own AF_Opportunity__c
     * lookup (the real, authoritative relationship) rather than trusting
     * Opportunity.AF_InvoiceSummary__c (a denormalized mirror field kept in sync by this same
     * method's own second DML statement below). Reading the mirror instead of the source would let
     * a partial-DML failure - insert succeeds, the follow-up Opportunity update doesn't - silently
     * produce a second Invoice Summary on the next reservation approval, since the guard would see
     * a still-null mirror and never know one already exists.
     */
    public static void ensureForApprovedReservations(Set<Id> reservationIds) {
        if (reservationIds == null || reservationIds.isEmpty()) {
            return;
        }

        Map<Id, AF_VehicleReservation__c> reservations = new Map<Id, AF_VehicleReservation__c>(
            [
                SELECT Id, AF_Opportunity__c, AF_Account__c, AF_Contact__c, AF_Vehicle__c,
                       AF_Quote__c, AF_Quote__r.GrandTotal, AF_VehiclePriceTotal__c
                FROM AF_VehicleReservation__c
                WHERE Id IN :reservationIds AND AF_Opportunity__c != null
            ]
        );

        Set<Id> opportunityIds = new Set<Id>();
        for (AF_VehicleReservation__c resv : reservations.values()) {
            opportunityIds.add(resv.AF_Opportunity__c);
        }

        Set<Id> opportunityIdsWithInvoice = new Set<Id>();
        for (AF_InvoiceSummary__c inv : [
            SELECT AF_Opportunity__c
            FROM AF_InvoiceSummary__c
            WHERE AF_Opportunity__c IN :opportunityIds
        ]) {
            opportunityIdsWithInvoice.add(inv.AF_Opportunity__c);
        }

        List<AF_InvoiceSummary__c> toInsert = new List<AF_InvoiceSummary__c>();
        Map<Integer, Id> opportunityIdByInsertIndex = new Map<Integer, Id>();

        for (AF_VehicleReservation__c resv : reservations.values()) {
            if (opportunityIdsWithInvoice.contains(resv.AF_Opportunity__c)) {
                continue;
            }
            // A second reservation on the same Opportunity approved in the same batch must not
            // both pass the guard and both insert - track newly-claimed Opportunities as we go.
            opportunityIdsWithInvoice.add(resv.AF_Opportunity__c);

            // Always the full Quote amount - the Invoice Summary tracks the deal's total, not just
            // the vehicle price line, so trade-ins/accessories/discounts are reflected correctly.
            // Falls back to the vehicle price total only when no Quote is linked at all.
            Decimal expectedTotal = resv.AF_Quote__c != null
                ? resv.AF_Quote__r.GrandTotal
                : resv.AF_VehiclePriceTotal__c;

            AF_InvoiceSummary__c inv = new AF_InvoiceSummary__c(
                AF_Opportunity__c = resv.AF_Opportunity__c,
                AF_Account__c = resv.AF_Account__c,
                AF_Contact__c = resv.AF_Contact__c,
                AF_Vehicle__c = resv.AF_Vehicle__c,
                AF_Quote__c = resv.AF_Quote__c,
                AF_ExpectedTotalAmount__c = expectedTotal,
                AF_PaidAmount__c = 0,
                AF_Balance__c = expectedTotal,
                AF_Status__c = INV_UNPAID,
                AF_LegalInvoice__c = false
            );
            opportunityIdByInsertIndex.put(toInsert.size(), resv.AF_Opportunity__c);
            toInsert.add(inv);
        }

        if (toInsert.isEmpty()) {
            return;
        }

        insert toInsert;

        List<Opportunity> oppUpdates = new List<Opportunity>();
        for (Integer i = 0; i < toInsert.size(); i++) {
            oppUpdates.add(new Opportunity(
                Id = opportunityIdByInsertIndex.get(i),
                AF_InvoiceSummary__c = toInsert[i].Id,
                AF_InvoiceBalance__c = toInsert[i].AF_Balance__c
            ));
        }
        update oppUpdates;

        // Found live 2026-09-20 (full retail cycle test on DEV): this method only ever mirrored
        // the new Invoice Summary onto the Opportunity, never back onto the reservation that
        // triggered it - AF_VehicleReservation__c.AF_InvoiceSummary__c stayed null forever even
        // though the field is on the reservation's own layout. Mirror it the same way for every
        // reservation whose Opportunity just got a new Invoice Summary.
        Map<Id, Id> invoiceIdByOpportunity = new Map<Id, Id>();
        for (Integer i = 0; i < toInsert.size(); i++) {
            invoiceIdByOpportunity.put(opportunityIdByInsertIndex.get(i), toInsert[i].Id);
        }

        List<AF_VehicleReservation__c> reservationUpdates = new List<AF_VehicleReservation__c>();
        for (AF_VehicleReservation__c resv : reservations.values()) {
            Id invId = invoiceIdByOpportunity.get(resv.AF_Opportunity__c);
            if (invId != null) {
                reservationUpdates.add(new AF_VehicleReservation__c(
                    Id = resv.Id,
                    AF_InvoiceSummary__c = invId
                ));
            }
        }
        if (!reservationUpdates.isEmpty()) {
            update reservationUpdates;
        }
    }

    /**
     * FR2/AC1/AC2 - recalculates the Invoice Summary(ies) tied to the given Opportunities from
     * their verified AF_Payment__c records. Safe to call repeatedly (e.g. after every Payment
     * save) - it is a full recompute from the payment records, not an incremental add. Derives
     * AF_Status__c: Unpaid (paid = 0) / Partially Paid (0 < paid < expected) / Fully Paid
     * (paid >= expected). Also mirrors the balance onto Opportunity.AF_InvoiceBalance__c, which is
     * what AF_VR_Opp_TakeTheKeysGate and AF_VR_Opp_ClosedWonGate already check.
     */
    public static void recalculateForOpportunities(Set<Id> opportunityIds) {
        if (opportunityIds == null || opportunityIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> paidTotalByOpportunity = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT AF_Opportunity__c opp, SUM(AF_Amount__c) total
            FROM AF_Payment__c
            WHERE AF_Opportunity__c IN :opportunityIds
              AND (AF_Status__c = :STATUS_PAID OR AF_IntegrationStatus__c = :INTEGRATION_SYNCED)
            GROUP BY AF_Opportunity__c
        ]) {
            paidTotalByOpportunity.put((Id) ar.get('opp'), (Decimal) ar.get('total'));
        }

        Map<Id, AF_InvoiceSummary__c> invoicesByOpportunity = new Map<Id, AF_InvoiceSummary__c>();
        for (AF_InvoiceSummary__c inv : [
            SELECT Id, AF_Opportunity__c, AF_ExpectedTotalAmount__c, AF_PaidAmount__c,
                   AF_Balance__c, AF_Status__c
            FROM AF_InvoiceSummary__c
            WHERE AF_Opportunity__c IN :opportunityIds
        ]) {
            invoicesByOpportunity.put(inv.AF_Opportunity__c, inv);
        }

        if (invoicesByOpportunity.isEmpty()) {
            return;
        }

        List<AF_InvoiceSummary__c> invoiceUpdates = new List<AF_InvoiceSummary__c>();
        List<Opportunity> oppUpdates = new List<Opportunity>();

        for (AF_InvoiceSummary__c inv : invoicesByOpportunity.values()) {
            Decimal paid = paidTotalByOpportunity.containsKey(inv.AF_Opportunity__c)
                ? paidTotalByOpportunity.get(inv.AF_Opportunity__c)
                : 0;
            Decimal expected = inv.AF_ExpectedTotalAmount__c == null ? 0 : inv.AF_ExpectedTotalAmount__c;
            Decimal balance = expected - paid;

            String status = INV_UNPAID;
            if (paid > 0 && balance > 0) {
                status = INV_PARTIAL;
            } else if (expected > 0 && balance <= 0) {
                status = INV_FULL;
            }

            invoiceUpdates.add(new AF_InvoiceSummary__c(
                Id = inv.Id,
                AF_PaidAmount__c = paid,
                AF_Balance__c = balance,
                AF_Status__c = status
            ));
            oppUpdates.add(new Opportunity(
                Id = inv.AF_Opportunity__c,
                AF_InvoiceBalance__c = balance
            ));
        }

        update invoiceUpdates;
        update oppUpdates;
    }
}