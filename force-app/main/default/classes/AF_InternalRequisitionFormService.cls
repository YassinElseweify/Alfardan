/**
 * LFRDN-346 (ALF-RS-16) - Internal Requisition Form generation.
 *
 * Replaces the plain-text ContentVersion previously generated inline by
 * AF_FL_Opp_RequisitionApproved (via the generic AF_DocumentGenerationService) with a properly
 * styled PDF, matching AF_FL_AppraisalItem_GenerateBookInSheet's Eval Expert Book-In Sheet look
 * (Alfardan navy header, status pill, bordered detail tables) and rendered via the same
 * AF_PdfGenerationService (Blob.toPdf(), Spring 26+) used there - not a new custom PDF pipeline.
 *
 * A Flow-only body formula (the org's existing convention for single-record document bodies -
 * see AF_FL_AppraisalItem_GenerateBookInSheet, AF_FL_Opp_RequisitionApproved's old formula) can't
 * loop over the flagged OpportunityLineItems to list each accessory/PDI job spec, which AC1
 * requires ("vehicle details and job specifications populated"). No Flow in this org loops line
 * items into a string (confirmed by inspection of every Quote/Opportunity flow that builds an
 * HTML/text body); the one other document that needs line-item detail, the Sales Order
 * (AF_SalesOrderService), delegates to Apex for exactly this reason. This class follows that same
 * convention rather than inventing a new one.
 */
public with sharing class AF_InternalRequisitionFormService {

    public class Request {
        @InvocableVariable(required=true label='Opportunity Id')
        public Id opportunityId;
    }

    public class Result {
        @InvocableVariable public Id contentDocumentId;
        @InvocableVariable public Id contentVersionId;
    }

    @InvocableMethod(
        label='Generate Internal Requisition Form PDF'
        description='LFRDN-346: renders the approved Internal Requisition Form as a styled PDF (via AF_PdfGenerationService) listing the vehicle and every flagged accessory/PDI line item, and attaches it to the Opportunity.'
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
            SELECT Id, Name, AF_Brand__c, AF_RequisitionCompletionDate__c,
                   AF_PrimaryQuote__c, AF_PrimaryQuote__r.QuoteNumber,
                   AF_SelectedVehicle__c, AF_SelectedVehicle__r.MakeName,
                   AF_SelectedVehicle__r.ModelName, AF_SelectedVehicle__r.ModelYear,
                   AF_SelectedVehicle__r.VehicleIdentificationNumber,
                   AF_SelectedVehicle__r.ExteriorColor,
                   Owner.Name
            FROM Opportunity
            WHERE Id IN :opportunityIds
            WITH USER_MODE
        ]);

        Map<Id, List<OpportunityLineItem>> lineItemsByOpp = new Map<Id, List<OpportunityLineItem>>();
        for (OpportunityLineItem oli : [
            SELECT OpportunityId, Product2.Name, Quantity, AF_CustomizationDescription__c
            FROM OpportunityLineItem
            WHERE OpportunityId IN :opportunityIds
            AND AF_RequiresInternalRequisition__c = true
            WITH USER_MODE
            ORDER BY Product2.Name
        ]) {
            if (!lineItemsByOpp.containsKey(oli.OpportunityId)) {
                lineItemsByOpp.put(oli.OpportunityId, new List<OpportunityLineItem>());
            }
            lineItemsByOpp.get(oli.OpportunityId).add(oli);
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Id> oppIdsForInsert = new List<Id>();

        for (Request req : requests) {
            Opportunity opp = opportunities.get(req.opportunityId);
            Result res = new Result();
            results.add(res);
            if (opp == null) {
                continue;
            }

            List<OpportunityLineItem> lines = lineItemsByOpp.get(opp.Id);
            if (lines == null) {
                lines = new List<OpportunityLineItem>();
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Internal Requisition Form - ' + opp.Name;
            cv.PathOnClient = 'Internal_Requisition_Form_' + opp.Id + '.pdf';
            cv.VersionData = Blob.toPdf(buildBody(opp, lines));
            cv.FirstPublishLocationId = opp.Id;

            versionsToInsert.add(cv);
            oppIdsForInsert.add(opp.Id);
        }

        if (versionsToInsert.isEmpty()) {
            return results;
        }

        insert as user versionsToInsert;

        Map<Id, ContentVersion> withDocIds = new Map<Id, ContentVersion>([
            SELECT Id, ContentDocumentId FROM ContentVersion WHERE Id IN :versionsToInsert
        ]);

        Integer insertIdx = 0;
        for (Result res : results) {
            if (res.contentDocumentId != null || insertIdx >= versionsToInsert.size()) {
                continue;
            }
            ContentVersion cv = versionsToInsert[insertIdx];
            res.contentVersionId = cv.Id;
            res.contentDocumentId = withDocIds.get(cv.Id).ContentDocumentId;
            insertIdx++;
        }

        return results;
    }

    @TestVisible
    private static String buildBody(Opportunity opp, List<OpportunityLineItem> lines) {
        Boolean hasVehicle = opp.AF_SelectedVehicle__c != null;

        List<String> rows = new List<String>();
        for (OpportunityLineItem oli : lines) {
            rows.add(
                '<tr>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;">' + nv(oli.Product2.Name) + '</td>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;text-align:center;">' + (oli.Quantity == null ? '-' : String.valueOf(oli.Quantity.intValue())) + '</td>' +
                '<td style="padding:10px 0;border-bottom:1px solid #EAEAEA;">' + nv(oli.AF_CustomizationDescription__c) + '</td>' +
                '</tr>'
            );
        }
        String lineItemRows = rows.isEmpty()
            ? '<tr><td colspan="3" style="padding:10px 0;color:#9A9A9A;">No accessory/PDI line items were flagged.</td></tr>'
            : String.join(rows, '');

        return
            '<html><body style="margin:0;font-family:Helvetica,Arial,sans-serif;color:#1A1A1A;">' +
            '<div style="max-width:680px;margin:0 auto;">' +
                '<div style="background:#0B2545;padding:24px 32px;">' +
                    '<div style="color:#8FA6C7;font-size:11px;font-weight:bold;letter-spacing:.1em;text-transform:uppercase;">Alfardan Automobiles</div>' +
                    '<h1 style="margin:6px 0 0;font-size:22px;color:#FFF;">Internal Requisition Form</h1>' +
                '</div>' +
                '<div style="padding:16px 32px 0;">' +
                    '<span style="display:inline-block;background:#DFF3E6;color:#1E7A46;font-size:11px;font-weight:bold;text-transform:uppercase;padding:5px 12px;border-radius:3px;">Approved</span>' +
                    '<p style="color:#6B6B6B;font-size:13px;line-height:1.5;margin:12px 0 0;">PDI and accessory fitting requisition, approved by the Sales Manager, for action by the After Sales team.</p>' +
                '</div>' +
                '<div style="padding:14px 32px 4px;">' +
                    '<div style="color:#0B2545;font-size:12px;font-weight:bold;text-transform:uppercase;border-bottom:2px solid #0B2545;padding-bottom:5px;">Opportunity &amp; Vehicle Details</div>' +
                    '<table style="width:100%;border-collapse:collapse;font-size:14px;">' +
                        '<tr><td style="padding:10px 0;width:38%;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Opportunity</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(opp.Name) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Brand</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(opp.AF_Brand__c) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Quote Number</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(opp.AF_PrimaryQuote__c != null ? opp.AF_PrimaryQuote__r.QuoteNumber : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Vehicle</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(hasVehicle ? (opp.AF_SelectedVehicle__r.MakeName + ' ' + opp.AF_SelectedVehicle__r.ModelName) : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">VIN</td><td style="padding:10px 0;font-weight:600;font-family:monospace;border-bottom:1px solid #EAEAEA;">' + nv(hasVehicle ? opp.AF_SelectedVehicle__r.VehicleIdentificationNumber : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;border-bottom:1px solid #EAEAEA;">Exterior Colour</td><td style="padding:10px 0;font-weight:600;border-bottom:1px solid #EAEAEA;">' + nv(hasVehicle ? opp.AF_SelectedVehicle__r.ExteriorColor : null) + '</td></tr>' +
                        '<tr><td style="padding:10px 0;color:#6B6B6B;">Requested Completion Date</td><td style="padding:10px 0;font-weight:600;">' + dt(opp.AF_RequisitionCompletionDate__c) + '</td></tr>' +
                    '</table>' +
                '</div>' +
                '<div style="padding:4px 32px 20px;">' +
                    '<div style="color:#0B2545;font-size:12px;font-weight:bold;text-transform:uppercase;border-bottom:2px solid #0B2545;padding-bottom:5px;">Accessory / PDI Job Specifications</div>' +
                    '<table style="width:100%;border-collapse:collapse;font-size:14px;">' +
                        '<tr><td style="padding:8px 0;color:#6B6B6B;font-size:11px;text-transform:uppercase;border-bottom:2px solid #EAEAEA;">Item</td><td style="padding:8px 0;color:#6B6B6B;font-size:11px;text-transform:uppercase;text-align:center;border-bottom:2px solid #EAEAEA;">Qty</td><td style="padding:8px 0;color:#6B6B6B;font-size:11px;text-transform:uppercase;border-bottom:2px solid #EAEAEA;">Job Specification</td></tr>' +
                        lineItemRows +
                    '</table>' +
                '</div>' +
                '<div style="border-top:1px solid #EAEAEA;padding:14px 32px;color:#9A9A9A;font-size:11px;">Sales Representative: ' + nv(opp.Owner != null ? opp.Owner.Name : null) + ' | Generated ' + System.now().format('dd MMM yyyy HH:mm') + '</div>' +
            '</div></body></html>';
    }

    private static String nv(String value) {
        return String.isBlank(value) ? '-' : value;
    }

    private static String dt(Date value) {
        return value == null ? '-' : DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0)).format('dd MMM yyyy');
    }
}