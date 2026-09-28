/**
 * ALF-RS-08 (LFRDN-338) FR12 / FR13 / FR14 - Reservation Contract generation.
 *
 * Generates the Reservation Contract document for a Vehicle Reservation and enforces the two
 * gates the BRD puts in front of it:
 *
 *   FR12 - contract generation is blocked until a deposit payment on the reservation is
 *          confirmed. Two independent paths can confirm it, matching the two payment routes the
 *          07-opportunity-quote-reservation-handover-flow LLD describes for AF_Payment__c:
 *            (a) AF_Status__c = 'Paid / Verified' - the FR12 wording itself: "the Sales
 *                Representative create[s] a Payment record... with proof of payment attached,
 *                and gate contract generation until the payment status is Paid / Verified." This
 *                is the manual/cashier path, and the only one that can exist this early in the
 *                cycle - a reservation deposit is taken before any Sales Order or Keyloop
 *                invoicing exists for Keyloop to confirm against.
 *            (b) AF_IntegrationStatus__c = 'Synced' - the LLD's Keyloop/MuleSoft path: "Cashier /
 *                Keyloop payment - money movement OUTSIDE Salesforce... values/status returned
 *                via MuleSoft matched on the SF ID." Once that integration is live for a given
 *                payment, its own confirmation counts too.
 *          A 3-Day (No Deposit) reservation has no deposit to verify, so the payment gate does
 *          not apply to it.
 *   FR13 - Required Documents must be referenced/complete before the contract is produced.
 *
 * The document body carries everything FR14 lists: customer details, vehicle details, deposit
 * amount paid, remaining balance, reservation dates, and a signature block.
 *
 * Gate failures are returned on the Result, not thrown. The caller (a screen action or the
 * AF_FL_Reservation_GenerateContract flow) shows the message to the rep, and a partial batch is
 * never rolled back because one reservation was not ready.
 */
public with sharing class AF_ReservationContractService {

    private static final String CONTRACT_3DAY = '3-Day (No Deposit)';
    private static final String STATUS_PAID = 'Paid / Verified';
    private static final String INTEGRATION_SYNCED = 'Synced';

    public class Request {
        @InvocableVariable(required=true label='Reservation Id')
        public Id reservationId;

        @InvocableVariable(label='Bypass Gates' description='Reserved for admin/data-fix use. Leave false in normal operation - true skips the FR12 payment and FR13 document checks.')
        public Boolean bypassGates = false;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;
    }

    @InvocableMethod(
        label='Generate Reservation Contract'
        description='ALF-RS-08 FR14: generates the Reservation Contract document for a Vehicle Reservation, after checking the FR12 verified-payment gate and the FR13 required-documents gate.'
    )
    public static List<Result> generate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> reservationIds = new Set<Id>();
        for (Request req : requests) {
            if (req.reservationId != null) {
                reservationIds.add(req.reservationId);
            }
        }

        Map<Id, AF_VehicleReservation__c> reservations = new Map<Id, AF_VehicleReservation__c>(
            [
                SELECT Id, Name, AF_Status__c, AF_ContractType__c, AF_StartDate__c, AF_ExpiryDate__c,
                       AF_DepositAmount__c, AF_RemainingBalance__c, AF_VehiclePriceTotal__c,
                       AF_RequiredDocumentsComplete__c, AF_TradeInAsDeposit__c,
                       AF_ContractDocumentReference__c, AF_ContractGeneratedDate__c,
                       AF_VehicleSourceType__c, AF_KeyloopReservationReference__c,
                       AF_Account__c, AF_Account__r.Name,
                       AF_Contact__c, AF_Contact__r.Name, AF_Contact__r.Email, AF_Contact__r.Phone,
                       AF_Opportunity__c, AF_Opportunity__r.Name,
                       AF_Opportunity__r.AF_Brand__c, AF_Opportunity__r.AF_BusinessUnit__c,
                       AF_Quote__c, AF_Quote__r.QuoteNumber, AF_Quote__r.GrandTotal,
                       AF_Vehicle__c, AF_Vehicle__r.Name, AF_Vehicle__r.VehicleIdentificationNumber,
                       AF_Vehicle__r.ExteriorColor, AF_Vehicle__r.InteriorColor,
                       AF_VehicleDefinition__c, AF_VehicleDefinition__r.Name,
                       Owner.Name, Owner.Email
                FROM AF_VehicleReservation__c
                WHERE Id IN :reservationIds
                WITH USER_MODE
            ]
        );

        // FR12: a reservation is cleared once it has at least one verified payment, verified by
        // either the manual cashier path (AF_Status__c) or the Keyloop/MuleSoft sync path
        // (AF_IntegrationStatus__c) - see the class-level comment for why both count.
        Map<Id, AF_Payment__c> verifiedPaymentByReservation = new Map<Id, AF_Payment__c>();
        Map<Id, Decimal> verifiedTotalByReservation = new Map<Id, Decimal>();
        for (AF_Payment__c pay : [
            SELECT Id, Name, AF_Amount__c, AF_PaymentMethod__c, AF_PaymentDate__c,
                   AF_ProofReference__c, AF_VerifiedDate__c, AF_IntegrationStatus__c,
                   AF_IntegrationReceivedDate__c, AF_VehicleReservation__c
            FROM AF_Payment__c
            WHERE AF_VehicleReservation__c IN :reservationIds
              AND (AF_Status__c = :STATUS_PAID OR AF_IntegrationStatus__c = :INTEGRATION_SYNCED)
            WITH USER_MODE
            ORDER BY AF_PaymentDate__c ASC NULLS LAST
        ]) {
            if (!verifiedPaymentByReservation.containsKey(pay.AF_VehicleReservation__c)) {
                verifiedPaymentByReservation.put(pay.AF_VehicleReservation__c, pay);
            }
            Decimal running = verifiedTotalByReservation.containsKey(pay.AF_VehicleReservation__c)
                ? verifiedTotalByReservation.get(pay.AF_VehicleReservation__c)
                : 0;
            verifiedTotalByReservation.put(
                pay.AF_VehicleReservation__c,
                running + (pay.AF_Amount__c == null ? 0 : pay.AF_Amount__c)
            );
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Request> requestsForInsert = new List<Request>();
        Map<Integer, Result> resultByRequestIndex = new Map<Integer, Result>();

        for (Integer i = 0; i < requests.size(); i++) {
            Request req = requests[i];
            Result res = new Result();
            res.success = false;
            results.add(res);

            AF_VehicleReservation__c resv = reservations.get(req.reservationId);
            if (resv == null) {
                res.message = 'Reservation not found, or you do not have access to it.';
                continue;
            }

            Boolean bypass = req.bypassGates == true;
            String blocker = bypass ? null : findBlocker(
                resv,
                verifiedPaymentByReservation.get(resv.Id),
                verifiedTotalByReservation.get(resv.Id)
            );
            if (blocker != null) {
                res.message = blocker;
                continue;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Reservation Contract - ' + resv.Name;
            cv.PathOnClient = 'Reservation_Contract_' + resv.Name + '.txt';
            cv.VersionData = Blob.valueOf(
                buildContractBody(resv, verifiedPaymentByReservation.get(resv.Id), verifiedTotalByReservation.get(resv.Id))
            );
            cv.FirstPublishLocationId = resv.Id;

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

        List<AF_VehicleReservation__c> reservationUpdates = new List<AF_VehicleReservation__c>();
        for (Integer idx = 0; idx < versionsToInsert.size(); idx++) {
            ContentVersion cv = versionsToInsert[idx];
            Result res = resultByRequestIndex.get(idx);
            Id docId = withDocIds.get(cv.Id).ContentDocumentId;

            res.success = true;
            res.contentVersionId = cv.Id;
            res.contentDocumentId = docId;
            res.message = 'Reservation Contract generated.';

            reservationUpdates.add(new AF_VehicleReservation__c(
                Id = requestsForInsert[idx].reservationId,
                AF_ContractDocumentReference__c = String.valueOf(docId),
                AF_ContractGeneratedDate__c = System.now()
            ));
        }

        if (!reservationUpdates.isEmpty()) {
            update as user reservationUpdates;
        }

        return results;
    }

    /**
     * Returns the first unmet gate as a rep-facing message, or null when the reservation is clear
     * to generate. Order matters: status first (the cheapest, most obvious problem to fix), then
     * documents, then payment.
     */
    private static String findBlocker(
        AF_VehicleReservation__c resv,
        AF_Payment__c verifiedPayment,
        Decimal verifiedTotal
    ) {
        if (resv.AF_Status__c == 'Cancelled' || resv.AF_Status__c == 'Expired') {
            return 'Cannot generate a contract for a ' + resv.AF_Status__c.toLowerCase() + ' reservation.';
        }

        // FR13 - required documents must be referenced before the contract is produced.
        // Uses the LFRDN-342 document-requirements engine (AF_DocumentService / AF_Document__mdt /
        // afDocumentComponent) rather than the older flat AF_RequiredDocumentsComplete__c checkbox -
        // real files uploaded and tagged against the reservation, resolved per contract-type/
        // trade-in condition via AF_DynamicObject__mdt("VehicleReservation"), not a rep-attested
        // boolean. The older AF_RequiredDocument__c/AF_RequiredDocumentService mechanism is left in
        // place (unused by this gate now) rather than removed, since other code may still reference
        // it - a separate cleanup decision, not part of this change.
        if (!AF_DocumentService.areRequiredDocumentsUploaded(resv.Id)) {
            return 'Required Documents are not fully uploaded on this reservation (FR13). ' +
                   'Attach the required customer documents (see the Required Documents Checklist) before generating the contract.';
        }

        // FR12 - the deposit must be verified. A 3-Day (No Deposit) reservation has no deposit
        // to verify, so the payment gate simply does not apply to it.
        Boolean depositExpected = resv.AF_ContractType__c != CONTRACT_3DAY
            || (resv.AF_DepositAmount__c != null && resv.AF_DepositAmount__c > 0);

        if (!depositExpected) {
            return null;
        }

        if (verifiedPayment == null) {
            return 'No payment on this reservation has been confirmed (FR12). Either record the ' +
                   'deposit payment with proof of payment and mark it "Paid / Verified", or wait ' +
                   'for the Keyloop/MuleSoft sync to return "Synced" on the payment, before generating the contract.';
        }

        // A Trade-In agreed as (part of) the deposit is not represented by any AF_Payment__c
        // record, so the verified-payment total cannot be compared against the full deposit
        // requirement for these reservations - existence of a verified payment is as far as
        // this gate can check for them.
        if (resv.AF_TradeInAsDeposit__c == true) {
            return null;
        }

        Decimal requiredDeposit = resv.AF_DepositAmount__c == null ? 0 : resv.AF_DepositAmount__c;
        Decimal confirmedTotal = verifiedTotal == null ? 0 : verifiedTotal;

        if (confirmedTotal < requiredDeposit) {
            return 'The verified payment total (' + money(confirmedTotal) + ') does not yet cover ' +
                   'the required deposit of ' + money(requiredDeposit) + ' (FR12). Record and verify ' +
                   'the remaining deposit amount before generating the contract.';
        }

        return null;
    }

    /**
     * FR14 - the contract body. Plain text rather than PDF: the BRD explicitly excludes
     * e-signature from this release, and Salesforce cannot render a PDF from Apex without a
     * VisualForce/OmniStudio template. The signature block is therefore printed for wet signing.
     */
    private static String buildContractBody(
        AF_VehicleReservation__c resv,
        AF_Payment__c verifiedPayment,
        Decimal verifiedTotal
    ) {
        Decimal depositPaid = verifiedTotal != null
            ? verifiedTotal
            : (resv.AF_DepositAmount__c == null ? 0 : resv.AF_DepositAmount__c);

        Decimal priceTotal = resv.AF_VehiclePriceTotal__c != null
            ? resv.AF_VehiclePriceTotal__c
            : (resv.AF_Quote__c != null && resv.AF_Quote__r.GrandTotal != null ? resv.AF_Quote__r.GrandTotal : null);

        Decimal remaining = resv.AF_RemainingBalance__c != null
            ? resv.AF_RemainingBalance__c
            : (priceTotal == null ? null : priceTotal - depositPaid);

        String customerName = resv.AF_Contact__c != null && resv.AF_Contact__r.Name != null
            ? resv.AF_Contact__r.Name
            : (resv.AF_Account__r != null ? resv.AF_Account__r.Name : '');

        String vehicleLine;
        if (resv.AF_Vehicle__c != null) {
            vehicleLine = resv.AF_Vehicle__r.Name;
        } else if (resv.AF_VehicleDefinition__c != null) {
            vehicleLine = resv.AF_VehicleDefinition__r.Name + ' (pre-order placeholder - VIN to be assigned)';
        } else {
            vehicleLine = 'Not specified';
        }

        List<String> b = new List<String>();
        b.add('VEHICLE RESERVATION CONTRACT');
        b.add('============================================================');
        b.add('Reservation Number : ' + nv(resv.Name));
        b.add('Business Unit      : ' + nv(resv.AF_Opportunity__r != null ? resv.AF_Opportunity__r.AF_BusinessUnit__c : null));
        b.add('Brand              : ' + nv(resv.AF_Opportunity__r != null ? resv.AF_Opportunity__r.AF_Brand__c : null));
        b.add('Contract Type      : ' + nv(resv.AF_ContractType__c));
        b.add('Status             : ' + nv(resv.AF_Status__c));
        b.add('');
        b.add('CUSTOMER DETAILS');
        b.add('------------------------------------------------------------');
        b.add('Customer           : ' + nv(customerName));
        b.add('Account            : ' + nv(resv.AF_Account__r != null ? resv.AF_Account__r.Name : null));
        b.add('Email              : ' + nv(resv.AF_Contact__r != null ? resv.AF_Contact__r.Email : null));
        b.add('Phone              : ' + nv(resv.AF_Contact__r != null ? resv.AF_Contact__r.Phone : null));
        b.add('');
        b.add('VEHICLE DETAILS');
        b.add('------------------------------------------------------------');
        b.add('Vehicle            : ' + nv(vehicleLine));
        b.add('VIN                : ' + nv(resv.AF_Vehicle__r != null ? resv.AF_Vehicle__r.VehicleIdentificationNumber : null));
        b.add('Exterior Colour    : ' + nv(resv.AF_Vehicle__r != null ? resv.AF_Vehicle__r.ExteriorColor : null));
        b.add('Interior Colour    : ' + nv(resv.AF_Vehicle__r != null ? resv.AF_Vehicle__r.InteriorColor : null));
        b.add('Stock Scenario     : ' + nv(resv.AF_VehicleSourceType__c));
        b.add('Keyloop Reference  : ' + nv(resv.AF_KeyloopReservationReference__c));
        b.add('');
        b.add('FINANCIAL SUMMARY');
        b.add('------------------------------------------------------------');
        b.add('Quote Number       : ' + nv(resv.AF_Quote__r != null ? resv.AF_Quote__r.QuoteNumber : null));
        b.add('Vehicle + Add-Ons  : ' + money(priceTotal));
        b.add('Deposit Paid       : ' + money(depositPaid));
        if (resv.AF_TradeInAsDeposit__c == true) {
            b.add('                     (includes an agreed Trade-In value applied as deposit)');
        }
        b.add('Remaining Balance  : ' + money(remaining));
        if (verifiedPayment != null) {
            b.add('Payment Reference  : ' + nv(verifiedPayment.Name)
                  + '  |  Method: ' + nv(verifiedPayment.AF_PaymentMethod__c)
                  + '  |  Proof: ' + nv(verifiedPayment.AF_ProofReference__c));
            if (verifiedPayment.AF_VerifiedDate__c != null) {
                b.add('Payment Verified   : ' + verifiedPayment.AF_VerifiedDate__c.format('dd MMM yyyy HH:mm')
                      + ' (cashier confirmed)');
            } else if (verifiedPayment.AF_IntegrationStatus__c == INTEGRATION_SYNCED) {
                b.add('Payment Verified   : ' + (verifiedPayment.AF_IntegrationReceivedDate__c == null
                      ? 'Synced with Keyloop' : verifiedPayment.AF_IntegrationReceivedDate__c.format('dd MMM yyyy HH:mm') + ' (Keyloop synced)'));
            } else {
                b.add('Payment Verified   : Yes');
            }
        } else {
            b.add('Payment Reference  : No deposit required for this contract type.');
        }
        b.add('');
        b.add('RESERVATION PERIOD');
        b.add('------------------------------------------------------------');
        b.add('Start Date         : ' + dt(resv.AF_StartDate__c));
        b.add('Expiry Date        : ' + (resv.AF_ExpiryDate__c == null
              ? 'Open-ended (VIP / Extended - subject to manager approval)'
              : dt(resv.AF_ExpiryDate__c)));
        b.add('Sales Representative: ' + nv(resv.Owner != null ? resv.Owner.Name : null));
        b.add('');
        b.add('TERMS');
        b.add('------------------------------------------------------------');
        b.add('1. This reservation holds the vehicle described above until the expiry date shown.');
        b.add('2. If the reservation is not converted to a Sales Order before expiry, the');
        b.add('   reservation lapses and the vehicle is released back to available stock.');
        b.add('3. Any extension of this reservation requires management approval.');
        b.add('4. Deposit refund terms are governed by the prevailing Alfardan Automobiles policy.');
        b.add('');
        b.add('SIGNATURES');
        b.add('------------------------------------------------------------');
        b.add('');
        b.add('Customer: ____________________________   Date: ______________');
        b.add('          ' + nv(customerName));
        b.add('');
        b.add('For Alfardan: ________________________   Date: ______________');
        b.add('          ' + nv(resv.Owner != null ? resv.Owner.Name : null) + ', Sales Representative');
        b.add('');
        b.add('============================================================');
        b.add('Generated ' + System.now().format('dd MMM yyyy HH:mm') + ' | Reservation ' + nv(resv.Name));

        return String.join(b, '\n');
    }

    private static String nv(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static String money(Decimal value) {
        return value == null ? '-' : value.setScale(2).format();
    }

    private static String dt(Date value) {
        return value == null ? '-' : DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }
}