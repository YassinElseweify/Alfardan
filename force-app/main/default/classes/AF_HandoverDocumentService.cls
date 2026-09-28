/**
 * ALF-RS-12 (LFRDN-342) FR4 / FR5 / FR7 - Handover document generation.
 *
 * Generates the handover documents as real PDFs via AF_PdfGenerationService (already built and
 * unit-tested for RS-06's Quote PDF), tagging each ContentVersion.AF_FileUpload__c with the
 * matching AF_Document__mdt.AF_DocumentName__c so the AF_Document__mdt-driven checklist
 * (AF_DocumentService/AF_DocumentGateCheck) can see it as satisfied - the same
 * ContentVersion-tagging convention AF_DocumentService already uses for manual uploads.
 *
 * FR4: automated sequence - generate() with documentName = null (or 'All') generates every
 * document not yet marked complete, in the fixed BRD order (Vehicle Sale Agreement, Warranty
 * Agreement, Service Contract Agreement, Vehicle Repair Disclaimer, Buyer Acknowledgement, then
 * Delivery Note last, per story point 7).
 * FR5: manual single-document generation - pass documentName to generate just one, at the rep's
 * discretion, regardless of sequence position. Already-complete documents are skipped unless
 * bypassGates is set, mirroring AF_ReservationContractService's Result-not-thrown gate pattern
 * and the idempotency check AF_FL_AppraisalItem_GenerateBookInSheet already uses for the same
 * "don't regenerate a document that already exists" problem.
 * FR7: Delivery Note is gated on the handover being scheduled (AF_HandoverDate__c populated) -
 * this org has no separate "delivery schedule booked/confirmed" object, so the Handover's own
 * date/time/location fields (already required for FR1) are the schedule-confirmation signal.
 *
 * Signature: per BRD Assumption 7 / AF_CustomerSignOff__c's own field description, e-signature is
 * excluded from this release - each document prints a wet-ink signature block, the same
 * convention AF_ReservationContractService.buildContractBody uses.
 */
public with sharing class AF_HandoverDocumentService {

    public static final String DOC_VEHICLE_SALE_AGREEMENT = 'Vehicle Sale Agreement';
    public static final String DOC_WARRANTY_AGREEMENT = 'Warranty Agreement';
    public static final String DOC_SERVICE_CONTRACT_AGREEMENT = 'Service Contract Agreement';
    public static final String DOC_VEHICLE_REPAIR_DISCLAIMER = 'Vehicle Repair Disclaimer';
    public static final String DOC_BUYER_ACKNOWLEDGEMENT = 'Buyer Acknowledgement';
    public static final String DOC_DELIVERY_NOTE = 'Delivery Note';

    // FR4 sequence order. Delivery Note is generated separately (FR7 - after schedule confirmed),
    // never as part of the automated 5-document sequence.
    private static final List<String> SEQUENCE_DOCUMENTS = new List<String>{
        DOC_VEHICLE_SALE_AGREEMENT, DOC_WARRANTY_AGREEMENT, DOC_SERVICE_CONTRACT_AGREEMENT,
        DOC_VEHICLE_REPAIR_DISCLAIMER, DOC_BUYER_ACKNOWLEDGEMENT
    };

    public class Request {
        @InvocableVariable(required=true label='Handover Id')
        public Id handoverId;

        @InvocableVariable(label='Document Name' description='One of the 5 agreement names or "Delivery Note". Leave blank to generate every not-yet-complete document in the FR4 sequence.')
        public String documentName;

        @InvocableVariable(label='Bypass Gates' description='Admin/data-fix use only. True regenerates even an already-complete document.')
        public Boolean bypassGates = false;
    }

    public class Result {
        @InvocableVariable public Boolean success;
        @InvocableVariable public String message;
        @InvocableVariable public String documentName;
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;
    }

    @InvocableMethod(
        label='Generate Handover Document(s)'
        description='ALF-RS-12 FR4/FR5/FR7: generates one or all handover documents as PDFs and marks the matching checklist checkbox complete.'
    )
    public static List<Result> generate(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null || requests.isEmpty()) {
            return results;
        }

        Set<Id> handoverIds = new Set<Id>();
        for (Request req : requests) {
            if (req.handoverId != null) {
                handoverIds.add(req.handoverId);
            }
        }

        Map<Id, AF_Handover__c> handovers = new Map<Id, AF_Handover__c>([
            SELECT Id, Name, AF_HandoverDate__c, AF_Location__c, AF_Status__c,
                   AF_VehicleSaleAgreementComplete__c, AF_WarrantyAgreementComplete__c,
                   AF_ServiceContractAgreementComplete__c, AF_VehicleRepairDisclaimerComplete__c,
                   AF_BuyerAcknowledgementComplete__c, AF_DeliveryNoteGenerated__c, AF_RepairRemarks__c,
                   AF_Opportunity__c, AF_Opportunity__r.Name,
                   AF_Opportunity__r.AF_Brand__c, AF_Opportunity__r.AF_BusinessUnit__c,
                   AF_Opportunity__r.AF_SelectedVehicle__c, AF_Opportunity__r.AF_SelectedVehicle__r.Name,
                   AF_Opportunity__r.AF_SelectedVehicle__r.VehicleIdentificationNumber,
                   AF_Opportunity__r.AF_SelectedVehicle__r.ExteriorColor, AF_Opportunity__r.AF_SelectedVehicle__r.InteriorColor,
                   AF_Opportunity__r.AF_PrimaryBrandContact__c, AF_Opportunity__r.AF_PrimaryBrandContact__r.Name,
                   AF_Opportunity__r.AF_PrimaryBrandContact__r.Email, AF_Opportunity__r.AF_PrimaryBrandContact__r.Phone,
                   AF_Account__c, AF_Account__r.Name,
                   AF_Contact__c, AF_Contact__r.Name, AF_Contact__r.Email, AF_Contact__r.Phone,
                   AF_Vehicle__c, AF_Vehicle__r.Name, AF_Vehicle__r.VehicleIdentificationNumber,
                   AF_Vehicle__r.ExteriorColor, AF_Vehicle__r.InteriorColor,
                   Owner.Name
            FROM AF_Handover__c
            WHERE Id IN :handoverIds
            WITH USER_MODE
        ]);

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<String> docNamesForInsert = new List<String>();
        List<Id> handoverIdsForInsert = new List<Id>();
        List<Result> resultForInsertIndex = new List<Result>();

        for (Request req : requests) {
            AF_Handover__c ho = handovers.get(req.handoverId);
            if (ho == null) {
                Result res = new Result();
                res.success = false;
                res.message = 'Handover not found, or you do not have access to it.';
                results.add(res);
                continue;
            }

            List<String> docsToGenerate = String.isBlank(req.documentName)
                ? SEQUENCE_DOCUMENTS
                : new List<String>{ req.documentName };

            for (String docName : docsToGenerate) {
                Result res = new Result();
                res.documentName = docName;
                res.success = false;
                results.add(res);

                String blocker = findBlocker(ho, docName, req.bypassGates == true);
                if (blocker != null) {
                    res.message = blocker;
                    continue;
                }

                ContentVersion cv = new ContentVersion();
                cv.Title = docName + ' - ' + ho.Name;
                cv.PathOnClient = docName.deleteWhitespace() + '_' + ho.Name + '.pdf';
                cv.VersionData = Blob.toPdf(buildDocumentHtml(docName, ho));
                cv.FirstPublishLocationId = ho.Id;
                cv.AF_FileUpload__c = docName;

                versionsToInsert.add(cv);
                docNamesForInsert.add(docName);
                handoverIdsForInsert.add(ho.Id);
                resultForInsertIndex.add(res);
            }
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

        Map<Id, AF_Handover__c> handoverUpdates = new Map<Id, AF_Handover__c>();
        for (Integer idx = 0; idx < versionsToInsert.size(); idx++) {
            ContentVersion cv = versionsToInsert[idx];
            Result res = resultForInsertIndex[idx];
            Id docId = withDocIds.get(cv.Id).ContentDocumentId;

            res.success = true;
            res.contentVersionId = cv.Id;
            res.contentDocumentId = docId;
            res.message = res.documentName + ' generated.';

            Id hoId = handoverIdsForInsert[idx];
            if (!handoverUpdates.containsKey(hoId)) {
                handoverUpdates.put(hoId, new AF_Handover__c(Id = hoId));
            }
            setCompletionField(handoverUpdates.get(hoId), docNamesForInsert[idx]);
        }

        if (!handoverUpdates.isEmpty()) {
            // System mode: same reasoning as AF_HandoverUploadSyncService - LFRDN-701 mutes rep
            // Edit on these completion flags to block manual ticking, not the generation itself.
            Database.update(handoverUpdates.values(), AccessLevel.SYSTEM_MODE);
        }

        return results;
    }

    /**
     * Returns the first unmet gate as a rep-facing message, or null when generation may proceed.
     */
    private static String findBlocker(AF_Handover__c ho, String docName, Boolean bypass) {
        if (String.isBlank(docName) || !isKnownDocument(docName)) {
            return 'Unknown handover document: ' + docName;
        }

        if (ho.AF_Status__c == 'Cancelled') {
            return 'Cannot generate documents for a cancelled handover.';
        }

        // LFRDN-708: the customer is asked to sign an agreement naming the vehicle - refuse to
        // print one with a blank vehicle rather than silently producing a document that doesn't
        // say which car is being sold. Checked even when bypass=true, since bypass exists to
        // regenerate an already-complete document, not to produce a document missing a mandatory
        // field. Resolves the same fallback buildDocumentHtml uses (Handover's own AF_Vehicle__c,
        // else the Opportunity's AF_SelectedVehicle__c).
        if (resolveVehicleId(ho) == null) {
            return 'Cannot generate ' + docName + ': no vehicle is set on the Handover or its Opportunity.';
        }

        if (bypass) {
            return null;
        }

        // FR5 idempotency: skip regenerating a document already marked complete, unless bypassed.
        if (isAlreadyComplete(ho, docName)) {
            return docName + ' has already been generated.';
        }

        // FR7: Delivery Note is the final document - it requires the delivery schedule (date,
        // time, location) to be confirmed on the Handover first.
        if (docName == DOC_DELIVERY_NOTE) {
            if (ho.AF_HandoverDate__c == null || String.isBlank(ho.AF_Location__c)) {
                return 'Delivery Note requires the handover date/time and location to be confirmed first (FR7).';
            }
        }

        return null;
    }

    private static Boolean isKnownDocument(String docName) {
        return SEQUENCE_DOCUMENTS.contains(docName) || docName == DOC_DELIVERY_NOTE;
    }

    private static Boolean isAlreadyComplete(AF_Handover__c ho, String docName) {
        if (docName == DOC_VEHICLE_SALE_AGREEMENT) return ho.AF_VehicleSaleAgreementComplete__c == true;
        if (docName == DOC_WARRANTY_AGREEMENT) return ho.AF_WarrantyAgreementComplete__c == true;
        if (docName == DOC_SERVICE_CONTRACT_AGREEMENT) return ho.AF_ServiceContractAgreementComplete__c == true;
        if (docName == DOC_VEHICLE_REPAIR_DISCLAIMER) return ho.AF_VehicleRepairDisclaimerComplete__c == true;
        if (docName == DOC_BUYER_ACKNOWLEDGEMENT) return ho.AF_BuyerAcknowledgementComplete__c == true;
        if (docName == DOC_DELIVERY_NOTE) return ho.AF_DeliveryNoteGenerated__c == true;
        return false;
    }

    private static void setCompletionField(AF_Handover__c hoUpdate, String docName) {
        if (docName == DOC_VEHICLE_SALE_AGREEMENT) hoUpdate.AF_VehicleSaleAgreementComplete__c = true;
        else if (docName == DOC_WARRANTY_AGREEMENT) hoUpdate.AF_WarrantyAgreementComplete__c = true;
        else if (docName == DOC_SERVICE_CONTRACT_AGREEMENT) hoUpdate.AF_ServiceContractAgreementComplete__c = true;
        else if (docName == DOC_VEHICLE_REPAIR_DISCLAIMER) hoUpdate.AF_VehicleRepairDisclaimerComplete__c = true;
        else if (docName == DOC_BUYER_ACKNOWLEDGEMENT) hoUpdate.AF_BuyerAcknowledgementComplete__c = true;
        else if (docName == DOC_DELIVERY_NOTE) hoUpdate.AF_DeliveryNoteGenerated__c = true;
    }

    /**
     * LFRDN-708: falls back to the Opportunity's own AF_SelectedVehicle__c/AF_PrimaryBrandContact__c
     * when the Handover's own AF_Vehicle__c/AF_Contact__c are blank - LFRDN-706 fixed this going
     * forward for newly-created Handovers, but every Handover created before that fix (and any
     * created some other way) still has blank lookups of its own.
     */
    private static Id resolveVehicleId(AF_Handover__c ho) {
        if (ho.AF_Vehicle__c != null) {
            return ho.AF_Vehicle__c;
        }
        return ho.AF_Opportunity__c != null ? ho.AF_Opportunity__r.AF_SelectedVehicle__c : null;
    }

    private static String buildDocumentHtml(String docName, AF_Handover__c ho) {
        Boolean hasOwnVehicle = ho.AF_Vehicle__c != null;
        Boolean hasOppVehicle = !hasOwnVehicle && ho.AF_Opportunity__c != null && ho.AF_Opportunity__r.AF_SelectedVehicle__c != null;
        String vehicleLine = hasOwnVehicle ? ho.AF_Vehicle__r.Name
            : (hasOppVehicle ? ho.AF_Opportunity__r.AF_SelectedVehicle__r.Name : '-');
        String vin = hasOwnVehicle ? ho.AF_Vehicle__r.VehicleIdentificationNumber
            : (hasOppVehicle ? ho.AF_Opportunity__r.AF_SelectedVehicle__r.VehicleIdentificationNumber : '-');

        Boolean hasOwnContact = ho.AF_Contact__c != null && ho.AF_Contact__r.Name != null;
        Boolean hasOppContact = !hasOwnContact && ho.AF_Opportunity__c != null && ho.AF_Opportunity__r.AF_PrimaryBrandContact__c != null;
        String customerName = hasOwnContact ? ho.AF_Contact__r.Name
            : (hasOppContact ? ho.AF_Opportunity__r.AF_PrimaryBrandContact__r.Name
                : (ho.AF_Account__c != null ? ho.AF_Account__r.Name : '-'));
        String customerEmail = hasOwnContact ? ho.AF_Contact__r.Email : (hasOppContact ? ho.AF_Opportunity__r.AF_PrimaryBrandContact__r.Email : null);
        String customerPhone = hasOwnContact ? ho.AF_Contact__r.Phone : (hasOppContact ? ho.AF_Opportunity__r.AF_PrimaryBrandContact__r.Phone : null);

        String body = bodyFor(docName, ho);

        return '<html><body style="font-family: Arial, sans-serif; font-size: 12px;">'
            + '<h2>' + esc(docName) + '</h2>'
            + '<p><b>Opportunity:</b> ' + esc(nv(ho.AF_Opportunity__c != null ? ho.AF_Opportunity__r.Name : null)) + '<br/>'
            + '<b>Brand:</b> ' + esc(nv(ho.AF_Opportunity__c != null ? ho.AF_Opportunity__r.AF_Brand__c : null))
            + ' &nbsp; <b>Business Unit:</b> ' + esc(nv(ho.AF_Opportunity__c != null ? ho.AF_Opportunity__r.AF_BusinessUnit__c : null)) + '</p>'
            + '<p><b>Customer:</b> ' + esc(customerName) + '<br/>'
            + '<b>Email:</b> ' + esc(nv(customerEmail))
            + ' &nbsp; <b>Phone:</b> ' + esc(nv(customerPhone)) + '</p>'
            + '<p><b>Vehicle:</b> ' + esc(vehicleLine) + ' &nbsp; <b>VIN:</b> ' + esc(nv(vin)) + '</p>'
            + '<hr/>'
            + '<p>' + body + '</p>'
            + '<hr/>'
            + '<p><b>Handover:</b> ' + (ho.AF_HandoverDate__c == null ? '-' : ho.AF_HandoverDate__c.format('dd MMM yyyy HH:mm'))
            + ' &nbsp; <b>Location:</b> ' + esc(nv(ho.AF_Location__c)) + '</p>'
            + '<br/><br/>'
            + '<table width="100%"><tr>'
            + '<td>Customer: ______________________________<br/>' + esc(customerName) + '<br/>Date: ______________</td>'
            + '<td>For Alfardan: __________________________<br/>' + esc(nv(ho.Owner != null ? ho.Owner.Name : null)) + ', Sales Representative<br/>Date: ______________</td>'
            + '</tr></table>'
            + '<p style="font-size: 10px; color: #666;">Generated ' + System.now().format('dd MMM yyyy HH:mm') + ' | Handover ' + esc(ho.Name) + '</p>'
            + '</body></html>';
    }

    private static String bodyFor(String docName, AF_Handover__c ho) {
        if (docName == DOC_VEHICLE_SALE_AGREEMENT) {
            return 'This Vehicle Sale Agreement confirms the sale of the vehicle described above from Alfardan to the customer named above, subject to the agreed terms of sale.';
        }
        if (docName == DOC_WARRANTY_AGREEMENT) {
            return 'This Warranty Agreement confirms the manufacturer/dealer warranty coverage applicable to the vehicle described above from the date of handover.';
        }
        if (docName == DOC_SERVICE_CONTRACT_AGREEMENT) {
            return 'This Service Contract Agreement confirms the service package (if any) purchased with the vehicle described above.';
        }
        if (docName == DOC_VEHICLE_REPAIR_DISCLAIMER) {
            // LFRDN-717: the customer must see what they were actually told about repairs done to
            // THIS vehicle, not just a generic disclaimer sentence.
            String remarks = String.isBlank(ho.AF_RepairRemarks__c) ? 'No repair remarks.' : ho.AF_RepairRemarks__c;
            return 'This Vehicle Repair Disclaimer confirms the customer has been informed of the vehicle\'s pre-delivery inspection and repair history, where applicable.<br/><br/><b>Repair Remarks:</b> ' + esc(remarks);
        }
        if (docName == DOC_BUYER_ACKNOWLEDGEMENT) {
            return 'This Buyer Acknowledgement confirms the customer has received and reviewed the vehicle, its documentation, and accessories at handover.';
        }
        if (docName == DOC_DELIVERY_NOTE) {
            return 'This Delivery Note confirms the vehicle described above was delivered to the customer at the date, time, and location shown below, completing the handover.';
        }
        return '';
    }

    private static String nv(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static String esc(String value) {
        return value == null ? '' : value.escapeHtml4();
    }
}