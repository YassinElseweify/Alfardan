/**
 * ALF-RS-10 (LFRDN-340) FR1 / FR5 / AC1 - Sales Order generation.
 *
 * Generates the Sales Order document for an Opportunity. Follows the same pattern as
 * AF_ReservationContractService (ALF-RS-08/LFRDN-338): a rep-triggered Quick Action calls this
 * class, gate failures come back on the Result rather than being thrown, and the document is a
 * real PDF rendered via Blob.toPdf() (LFRDN-676).
 *
 * LFRDN-696 (found live 2026-09-24): the printed buyer-contact block (Account.Phone/AF_Email__c/
 * BillingAddress) and the vehicle's ChassisNumber were added to the main WITH USER_MODE query,
 * which meant every persona without FLS Read on those specific fields got the entire query
 * throwing "No such column" - a total outage of Sales Order generation. Those fields are printed
 * document content, not something the rep is choosing to view on screen; the WITH USER_MODE query
 * above is what actually gates whether this rep may generate a Sales Order for this Opportunity at
 * all. Fixed by moving them to a separate WITH SYSTEM_MODE query, same reasoning
 * AF_KeyloopGetPayment already uses for its own system-of-record writes.
 *
 * This class is the Apex-side mirror of the existing declarative gate AF_VR_Opp_SOGenerationGate.
 * The original DEC-014 first-payment-only design was superseded at explicit business instruction
 * on 2026-09-19 (see the VR's own description) and confirmed again on 2026-09-21 (LFRDN-660):
 * full payment is required before Sales Order generation, matching this ticket's own FR4 wording
 * ("prompt the Sales Representative to confirm full payment collection before allowing
 * generation"). The Apex gate exists alongside the VR (not instead of it) so a Quick Action /
 * Flow calling this class gets the same rep-facing message the VR would otherwise throw as a raw
 * save error, checked before any document is generated:
 *   - an Invoice Summary must exist on the Opportunity with AF_Status__c = 'Fully Paid', and
 *   - a vehicle must be selected (Opportunity.AF_SelectedVehicle__c) and be
 *     AF_InventoryStatus__c = 'In Stock', and
 *   - a Vehicle Reservation must exist on the Opportunity, be AF_Status__c = 'Reserved', and
 *     cover that same selected vehicle (LFRDN-661, confirmed by the business 2026-09-21).
 * These match the same fields and paths the VR checks, so the Apex gate and the VR can never
 * disagree.
 *
 * AC1 ("a sales order record is created and linked to the opportunity") is satisfied by the
 * Opportunity's own AF_SOStatus__c / AF_SODocumentReference__c / AF_SOGeneratedDate__c fields,
 * mirroring how the Reservation Contract is represented on AF_VehicleReservation__c rather than as
 * a separate object.
 */
public with sharing class AF_SalesOrderService {

    private static final String INVENTORY_STATUS_IN_STOCK = 'In Stock';

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;
    }

    @InvocableMethod(
        label='Generate Sales Order'
        description='ALF-RS-10 FR1/FR4/FR5: generates the Sales Order document for an Opportunity, after checking the full-payment, vehicle-in-stock, and vehicle-reservation gates.'
    )
    public static List<Result> generate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> opportunityIds = new Set<Id>();
        for (Request req : requests) {
            if (req.opportunityId != null) {
                opportunityIds.add(req.opportunityId);
            }
        }

        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>([
            SELECT Id, Name, AF_Brand__c, AF_BusinessUnit__c, AF_SOStatus__c,
                   AF_SODocumentReference__c, AF_SOGeneratedDate__c,
                   AccountId, Account.Name,
                   AF_PrimaryQuote__c, AF_PrimaryQuote__r.QuoteNumber, AF_PrimaryQuote__r.GrandTotal,
                   AF_InvoiceSummary__c, AF_InvoiceSummary__r.AF_PaidAmount__c,
                   AF_InvoiceSummary__r.AF_Status__c,
                   AF_InvoiceSummary__r.AF_ExpectedTotalAmount__c, AF_InvoiceSummary__r.AF_Balance__c,
                   AF_InvoiceSummary__r.AF_Contact__c, AF_InvoiceSummary__r.AF_Contact__r.Name,
                   AF_InvoiceSummary__r.AF_Contact__r.Phone, AF_InvoiceSummary__r.AF_Contact__r.Email,
                   AF_InvoiceSummary__r.AF_Contact__r.MailingAddress,
                   AF_SelectedVehicle__c, AF_SelectedVehicle__r.Name,
                   AF_SelectedVehicle__r.VehicleIdentificationNumber,
                   AF_SelectedVehicle__r.MakeName, AF_SelectedVehicle__r.ModelName,
                   AF_SelectedVehicle__r.ModelYear, AF_SelectedVehicle__r.ManufacturedDate,
                   AF_SelectedVehicle__r.ExteriorColor,
                   AF_SelectedVehicle__r.InteriorColor,
                   AF_SelectedVehicle__r.AF_InventoryStatus__c,
                   AF_SelectedVehicle__r.AF_BrandSubStatus__c,
                   AF_SelectedVehicle__r.VehicleDefinition.Name,
                   AF_SelectedVehicle__r.VehicleDefinition.VariantName,
                   AF_SelectedVehicle__r.VehicleDefinition.AF_Brand__c,
                   AF_SelectedVehicle__r.VehicleDefinition.BodyType,
                   AF_VehicleReservation__c, AF_VehicleReservation__r.Name,
                   AF_VehicleReservation__r.AF_Status__c, AF_VehicleReservation__r.AF_Vehicle__c,
                   AF_VehicleReservation__r.AF_KeyloopReservationReference__c,
                   Owner.Name, Owner.Email
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ]);

        // LFRDN-696: Account.Phone/AF_Email__c/BillingAddress and Vehicle.ChassisNumber are
        // printed document content, not data the rep is choosing to view on screen - the record
        // access check above (WITH USER_MODE on the main query) is what actually gates whether
        // this rep may generate a Sales Order for this Opportunity at all. Requiring FLS Read on
        // every field the printed document happens to need is unrelated to that authorization
        // question, and broke generation for every persona the moment these two fields were added
        // without a matching permission grant. Queried here in system mode, in the same method
        // rather than a shared helper, since only this document needs them.
        Map<Id, Account> accountContactFields = new Map<Id, Account>();
        Map<Id, String> vehicleChassisNumbers = new Map<Id, String>();
        Set<Id> accountIds = new Set<Id>();
        Set<Id> vehicleIds = new Set<Id>();
        for (Opportunity opp : opportunities.values()) {
            if (opp.AccountId != null) {
                accountIds.add(opp.AccountId);
            }
            if (opp.AF_SelectedVehicle__c != null) {
                vehicleIds.add(opp.AF_SelectedVehicle__c);
            }
        }
        if (!accountIds.isEmpty()) {
            for (Account acc : [
                SELECT Id, Phone, AF_Email__c, BillingAddress
                FROM Account
                WHERE Id IN :accountIds
                WITH SYSTEM_MODE
            ]) {
                accountContactFields.put(acc.Id, acc);
            }
        }
        if (!vehicleIds.isEmpty()) {
            for (Vehicle v : [
                SELECT Id, ChassisNumber
                FROM Vehicle
                WHERE Id IN :vehicleIds
                WITH SYSTEM_MODE
            ]) {
                vehicleChassisNumbers.put(v.Id, v.ChassisNumber);
            }
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Request> requestsForInsert = new List<Request>();
        Map<Integer, Result> resultByRequestIndex = new Map<Integer, Result>();

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            results.add(res);

            Opportunity opp = opportunities.get(req.opportunityId);
            if (opp == null) {
                res.message = 'Opportunity not found, or you do not have access to it.';
                continue;
            }

            String blocker = findBlocker(opp);
            if (blocker != null) {
                res.message = blocker;
                continue;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Sales Order - ' + opp.Name;
            cv.PathOnClient = 'Sales_Order_' + opp.Name + '.pdf';
            cv.VersionData = Blob.toPdf(buildSalesOrderBody(
                opp,
                opp.AccountId != null ? accountContactFields.get(opp.AccountId) : null,
                opp.AF_SelectedVehicle__c != null ? vehicleChassisNumbers.get(opp.AF_SelectedVehicle__c) : null
            ));
            cv.FirstPublishLocationId = opp.Id;

            versionsToInsert.add(cv);
            requestsForInsert.add(req);
            resultByRequestIndex.put(versionsToInsert.size() - 1, res);
        }

        if (versionsToInsert.isEmpty()) {
            return results;
        }

        insert as user versionsToInsert;

        Set<Id> versionIds = new Set<Id>();
        for (ContentVersion cv : versionsToInsert) {
            versionIds.add(cv.Id);
        }
        Map<Id, ContentVersion> withDocIds = new Map<Id, ContentVersion>(
            [SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionIds]
        );

        List<Opportunity> opportunityUpdates = new List<Opportunity>();
        List<AF_VehicleReservation__c> reservationUpdates = new List<AF_VehicleReservation__c>();
        for (Integer idx = 0; idx < versionsToInsert.size(); idx++) {
            ContentVersion cv = versionsToInsert[idx];
            Result res = resultByRequestIndex.get(idx);
            Id docId = withDocIds.get(cv.Id).ContentDocumentId;
            Id oppId = requestsForInsert[idx].opportunityId;
            Opportunity opp = opportunities.get(oppId);

            res.success = true;
            res.contentVersionId = cv.Id;
            res.contentDocumentId = docId;
            res.message = 'Sales Order generated.';

            opportunityUpdates.add(new Opportunity(
                Id = oppId,
                AF_SOStatus__c = 'Generated',
                AF_SODocumentReference__c = String.valueOf(docId),
                AF_SOGeneratedDate__c = System.now(),
                // LFRDN-662 FR4: this method is only reached after the calling flow's payment
                // confirmation screen, so the running user is the confirming user - stamped in the
                // same transaction as generation, giving the control a lasting audit trail.
                AF_SOPaymentConfirmedBy__c = UserInfo.getUserId(),
                AF_SOPaymentConfirmedDate__c = System.now()
            ));

            // AC1 - the reservation converts once its Sales Order exists, matching the
            // reservation contract's own terms text ("If the reservation is not converted to a
            // Sales Order before expiry...").
            if (opp.AF_VehicleReservation__c != null) {
                reservationUpdates.add(new AF_VehicleReservation__c(
                    Id = opp.AF_VehicleReservation__c,
                    AF_Status__c = 'Converted'
                ));
            }
        }

        if (!opportunityUpdates.isEmpty()) {
            update as user opportunityUpdates;
        }
        if (!reservationUpdates.isEmpty()) {
            update as user reservationUpdates;
        }

        return results;
    }

    private static final String INVOICE_STATUS_FULLY_PAID = 'Fully Paid';
    private static final String RESERVATION_STATUS_RESERVED = 'Reserved';

    /**
     * Returns the first unmet gate as a rep-facing message, or null when clear to generate.
     * Mirrors AF_VR_Opp_SOGenerationGate exactly: the Invoice Summary must be Fully Paid
     * (LFRDN-660 - supersedes the earlier DEC-014 first-payment-only design at explicit business
     * instruction, 2026-09-21), a vehicle must be selected and In Stock, and a Reserved Vehicle
     * Reservation must exist covering that same vehicle (LFRDN-661, confirmed by the business
     * 2026-09-21: "there must be a vehicle and there must be a reservation for this vehicle").
     */
    private static String findBlocker(Opportunity opp) {
        if (opp.AF_SOStatus__c == 'Generated' || opp.AF_SOStatus__c == 'Sent to Customer' || opp.AF_SOStatus__c == 'Signed') {
            return 'A Sales Order already exists for this Opportunity (' + opp.AF_SOStatus__c + ').';
        }

        if (opp.AF_InvoiceSummary__c == null
            || opp.AF_InvoiceSummary__r.AF_Status__c != INVOICE_STATUS_FULLY_PAID) {
            Decimal paid = opp.AF_InvoiceSummary__c != null ? opp.AF_InvoiceSummary__r.AF_PaidAmount__c : null;
            Decimal total = opp.AF_InvoiceSummary__c != null ? opp.AF_InvoiceSummary__r.AF_ExpectedTotalAmount__c : null;
            if (paid != null && total != null) {
                return 'A Sales Order can only be generated once the invoice is fully paid. QAR ' +
                       money(paid) + ' of QAR ' + money(total) + ' has been received - QAR ' +
                       money(total - paid) + ' is still outstanding.';
            }
            return 'A Sales Order can only be generated once the invoice is fully paid, and no payment has been recorded yet on this Opportunity.';
        }

        if (opp.AF_SelectedVehicle__c == null) {
            return 'A Sales Order cannot be generated: no vehicle is selected on this Opportunity.';
        }

        if (opp.AF_SelectedVehicle__r.AF_InventoryStatus__c != INVENTORY_STATUS_IN_STOCK) {
            return 'The selected vehicle is currently "' + nv(opp.AF_SelectedVehicle__r.AF_InventoryStatus__c) +
                   '" (not In Stock). A Sales Order cannot be generated until the vehicle is In Stock.';
        }

        if (opp.AF_VehicleReservation__c == null
            || opp.AF_VehicleReservation__r.AF_Status__c != RESERVATION_STATUS_RESERVED
            || opp.AF_VehicleReservation__r.AF_Vehicle__c != opp.AF_SelectedVehicle__c) {
            return 'A Sales Order cannot be generated: there is no active Reserved reservation on this Opportunity for the selected vehicle.';
        }

        return null;
    }

    /**
     * Follows the real Alfardan "NEW VEHICLE SALE CONTRACT" template (Sales Binder - JLR v.7,
     * page 7) section-for-section: Seller/Buyer parties, vehicle description, purchase price and
     * terms of payment (down-payment already paid + remaining balance), buyer acknowledgements,
     * and a delivery/title clause - the same structure AF_ReservationContractService follows for
     * the earlier Reservation Agreement in that same binder. A signature block is printed for wet
     * signing, matching the real form.
     *
     * LFRDN-676: rendered as HTML through Blob.toPdf(), the same pattern AF_TransactionSummaryService
     * already uses - the plain-text ContentVersion this replaced predates AF_PdfGenerationService
     * existing in this org and was never updated once it did.
     */
    private static String buildSalesOrderBody(Opportunity opp, Account accountContactFields, String vehicleChassisNumber) {
        AF_VehicleReservation__c resv = opp.AF_VehicleReservation__r;
        Boolean hasVehicle = opp.AF_SelectedVehicle__c != null;
        Boolean hasInvoice = opp.AF_InvoiceSummary__c != null;
        Boolean hasContact = hasInvoice && opp.AF_InvoiceSummary__r.AF_Contact__c != null;

        String buyerName = hasContact ? opp.AF_InvoiceSummary__r.AF_Contact__r.Name
            : (opp.Account != null ? opp.Account.Name : null);
        String buyerPhone = hasContact ? opp.AF_InvoiceSummary__r.AF_Contact__r.Phone
            : (accountContactFields != null ? accountContactFields.Phone : null);
        String buyerEmail = hasContact ? opp.AF_InvoiceSummary__r.AF_Contact__r.Email
            : (accountContactFields != null ? accountContactFields.AF_Email__c : null);
        Address buyerAddress = hasContact ? opp.AF_InvoiceSummary__r.AF_Contact__r.MailingAddress
            : (accountContactFields != null ? accountContactFields.BillingAddress : null);

        Decimal totalPrice = opp.AF_PrimaryQuote__c != null ? opp.AF_PrimaryQuote__r.GrandTotal
            : (hasInvoice ? opp.AF_InvoiceSummary__r.AF_ExpectedTotalAmount__c : null);
        Decimal downPayment = hasInvoice ? opp.AF_InvoiceSummary__r.AF_PaidAmount__c : null;
        Decimal remaining = hasInvoice && opp.AF_InvoiceSummary__r.AF_Balance__c != null
            ? opp.AF_InvoiceSummary__r.AF_Balance__c
            : (totalPrice != null && downPayment != null ? totalPrice - downPayment : null);

        // LFRDN-674: make/model/brand live on VehicleDefinition (the model line), not on the
        // Vehicle record itself (the physical unit) - every vehicle in the org had these blank
        // because the document was reading the wrong object. VehicleDefinition has no per-unit
        // fields (model year, chassis number), so those still come from Vehicle, with Vehicle's
        // own Make/Model as a fallback in case a vehicle predates having a linked definition.
        VehicleDefinition vDef = hasVehicle ? opp.AF_SelectedVehicle__r.VehicleDefinition : null;
        String vehicleType = vDef != null && String.isNotBlank(vDef.AF_Brand__c) ? vDef.AF_Brand__c
            : (hasVehicle ? opp.AF_SelectedVehicle__r.MakeName : null);
        String vehicleModel = vDef != null && String.isNotBlank(vDef.VariantName) ? vDef.VariantName
            : (hasVehicle ? opp.AF_SelectedVehicle__r.ModelName : null);

        // LFRDN-675: this text was written for the earlier DEC-014 first-payment-only gate. The
        // gate was raised to require full payment before generation (LFRDN-660), but the document
        // text was left behind, so a fully-paid customer was told a balance was still due at
        // delivery. Derives from the actual figures instead, so document and gate can't diverge again.
        Boolean isFullyPaid = remaining == null || remaining <= 0;
        String paymentStatusLine = isFullyPaid
            ? 'Paid in full. No balance outstanding.'
            : 'Partially paid. QAR ' + money(remaining) + ' remains outstanding, due at delivery of the Vehicle to the Buyer.';

        List<String> b = new List<String>();
        b.add('<html><body style="font-family: Arial, sans-serif; font-size: 12px;">');
        b.add('<h2 style="text-align:center;">NEW VEHICLE SALE CONTRACT</h2>');
        b.add('<p><b>Opportunity:</b> ' + esc(opp.Name) + '<br/>');
        b.add('<b>Business Unit:</b> ' + esc(opp.AF_BusinessUnit__c) + '  |  <b>Brand:</b> ' + esc(opp.AF_Brand__c) + '<br/>');
        b.add('<b>Reservation:</b> ' + esc(resv != null ? resv.Name : null)
              + '  |  <b>Keyloop Reference:</b> ' + esc(resv != null ? resv.AF_KeyloopReservationReference__c : null) + '</p>');

        b.add('<h3>1. Parties</h3>');
        b.add('<p><b>Seller:</b> Alfardan Automobiles<br/>');
        b.add('<b>Buyer:</b> ' + esc(buyerName) + '<br/>');
        b.add('<b>Address:</b> ' + esc(addressLine(buyerAddress)) + '<br/>');
        b.add('<b>Telephone No.:</b> ' + esc(buyerPhone) + '<br/>');
        b.add('<b>Email:</b> ' + esc(buyerEmail) + '</p>');

        b.add('<h3>2. Description of the Vehicle</h3>');
        b.add('<table border="1" cellpadding="4" cellspacing="0" style="border-collapse: collapse; width: 100%;">');
        b.add(tableRow('Type of Vehicle', vehicleType));
        b.add(tableRow('Vehicle Model', vehicleModel));
        b.add(tableRow('Model Year', hasVehicle ? String.valueOf(opp.AF_SelectedVehicle__r.ModelYear) : null));
        b.add(tableRow('Manufacturing Date', dt(hasVehicle ? opp.AF_SelectedVehicle__r.ManufacturedDate : null)));
        b.add(tableRow('Chassis No.', hasVehicle ? vehicleChassisNumber : null));
        b.add(tableRow('VIN', hasVehicle ? opp.AF_SelectedVehicle__r.VehicleIdentificationNumber : null));
        b.add(tableRow('Exterior Color', hasVehicle ? opp.AF_SelectedVehicle__r.ExteriorColor : null));
        b.add(tableRow('Interior Color', hasVehicle ? opp.AF_SelectedVehicle__r.InteriorColor : null));
        b.add(tableRow('Inventory Status', hasVehicle ? opp.AF_SelectedVehicle__r.AF_InventoryStatus__c : null));
        b.add(tableRow('Brand Sub-Status', hasVehicle ? opp.AF_SelectedVehicle__r.AF_BrandSubStatus__c : null));
        b.add('</table>');

        b.add('<h3>3. Purchase Price &amp; Terms of Payment</h3>');
        b.add('<p><b>Quote Number:</b> ' + esc(opp.AF_PrimaryQuote__c != null ? opp.AF_PrimaryQuote__r.QuoteNumber : null) + '<br/>');
        b.add('<b>Total Purchase Price (QAR):</b> ' + money(totalPrice) + '<br/>');
        b.add('<b>Down-payment (QAR):</b> ' + money(downPayment) + '<br/>');
        b.add('<b>Remaining Price (QAR):</b> ' + money(remaining) + '<br/>');
        b.add('<b>Payment Status:</b> ' + esc(paymentStatusLine) + '</p>');

        b.add('<h3>4. Acknowledgements of the Buyer</h3>');
        b.add('<p>4.1 that he has fully inspected the Vehicle and accepts it "As-Is".<br/>');
        b.add('4.2 that he is aware the Manufacturing Year may differ from the Model Year shown above, ');
        b.add('as may be reflected on registration under Traffic Authority policy.<br/>');
        b.add('4.3 that he has had an adequate opportunity to read and review this Contract before executing it.</p>');

        b.add('<h3>5. Delivery and Transfer of Title</h3>');
        b.add('<p>Seller shall deliver the Vehicle, and Buyer shall take possession of the same, on or before ');
        b.add('the Estimated Delivery Date, at which point risk and title pass to the Buyer.</p>');

        b.add('<p><b>Sales Representative:</b> ' + esc(opp.Owner != null ? opp.Owner.Name : null) + '</p>');

        b.add('<h3>Signatures</h3>');
        b.add('<p>Seller: ______________________________&nbsp;&nbsp;&nbsp;Date: ______________</p>');
        b.add('<p>Buyer: _______________________________&nbsp;&nbsp;&nbsp;&nbsp;Date: ______________<br/>');
        b.add('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;' + esc(buyerName) + '</p>');

        b.add('<p style="color:#666; font-size:10px;">Generated ' + System.now().format('dd MMM yyyy HH:mm') + ' | ' + esc(opp.Name) + '</p>');
        b.add('</body></html>');

        return String.join(b, '\n');
    }

    private static String tableRow(String label, String value) {
        return '<tr><td><b>' + esc(label) + '</b></td><td>' + esc(value) + '</td></tr>';
    }

    private static String addressLine(Address addr) {
        if (addr == null) {
            return null;
        }
        List<String> parts = new List<String>();
        if (String.isNotBlank(addr.getStreet())) parts.add(addr.getStreet());
        if (String.isNotBlank(addr.getCity())) parts.add(addr.getCity());
        if (String.isNotBlank(addr.getCountry())) parts.add(addr.getCountry());
        return parts.isEmpty() ? null : String.join(parts, ', ');
    }

    private static String nv(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static String esc(String value) {
        return String.isBlank(value) ? '-' : value.escapeHtml4();
    }

    private static String money(Decimal value) {
        return value == null ? '-' : value.setScale(2).format();
    }

    private static String dt(Date value) {
        return value == null ? '-' : DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }
}