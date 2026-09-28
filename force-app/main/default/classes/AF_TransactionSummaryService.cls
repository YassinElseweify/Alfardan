/**
 * ALF-RS-09 (LFRDN-339) FR5 - generates the Sales Transaction Summary document, produced in
 * parallel with the Sales Order at the point of payment confirmation (06 LLD, "Sales Order
 * document timing" / process step 5). Self-contained query+assemble+render, same shape as the
 * RS-06 quote-document pattern: queries the Opportunity + its Invoice Summary + every payment,
 * builds an HTML document server-side, renders via AF_PdfGenerationService.Blob.toPdf() pattern,
 * and stamps the resulting ContentDocumentId back onto
 * Opportunity.AF_TransactionSummaryDocumentReference__c.
 */
public with sharing class AF_TransactionSummaryService {

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
        label='Generate Sales Transaction Summary'
        description='ALF-RS-09 FR5: generates the Sales Transaction Summary document for an Opportunity, in parallel with the Sales Order, at payment confirmation.'
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

        Map<Id, Opportunity> opportunities = new Map<Id, Opportunity>(
            [
                SELECT Id, Name, AF_Brand__c, AF_BusinessUnit__c, StageName,
                       Account.Name, AF_PrimaryBrandContact__r.Name, AF_PrimaryBrandContact__r.Email,
                       AF_InvoiceSummary__c, AF_InvoiceSummary__r.AF_ExpectedTotalAmount__c,
                       AF_InvoiceSummary__r.AF_PaidAmount__c, AF_InvoiceSummary__r.AF_Balance__c,
                       AF_InvoiceSummary__r.AF_Status__c,
                       AF_SelectedVehicle__c, AF_SelectedVehicle__r.Name,
                       AF_SelectedVehicle__r.VehicleIdentificationNumber
                FROM Opportunity
                WHERE Id IN :opportunityIds
                WITH USER_MODE
            ]
        );

        Map<Id, List<AF_Payment__c>> paymentsByOpportunity = new Map<Id, List<AF_Payment__c>>();
        for (AF_Payment__c pay : [
            SELECT Id, Name, AF_Amount__c, AF_PaymentMethod__c, AF_PaymentDate__c, AF_Status__c,
                   AF_IntegrationStatus__c, AF_Opportunity__c
            FROM AF_Payment__c
            WHERE AF_Opportunity__c IN :opportunityIds
            WITH USER_MODE
            ORDER BY AF_PaymentDate__c ASC NULLS LAST
        ]) {
            if (!paymentsByOpportunity.containsKey(pay.AF_Opportunity__c)) {
                paymentsByOpportunity.put(pay.AF_Opportunity__c, new List<AF_Payment__c>());
            }
            paymentsByOpportunity.get(pay.AF_Opportunity__c).add(pay);
        }

        List<ContentVersion> versionsToInsert = new List<ContentVersion>();
        List<Id> opportunityIdsForInsert = new List<Id>();
        Map<Integer, Result> resultByIndex = new Map<Integer, Result>();

        for (Request req : requests) {
            Result res = new Result();
            res.success = false;
            results.add(res);

            Opportunity opp = opportunities.get(req.opportunityId);
            if (opp == null) {
                res.message = 'Opportunity not found, or you do not have access to it.';
                continue;
            }
            if (opp.AF_InvoiceSummary__c == null) {
                res.message = 'No Invoice Summary exists on this Opportunity yet - a payment must be recorded first.';
                continue;
            }

            List<AF_Payment__c> payments = paymentsByOpportunity.get(opp.Id);
            if (payments == null || payments.isEmpty()) {
                res.message = 'No Payment records exist on this Opportunity yet.';
                continue;
            }

            ContentVersion cv = new ContentVersion();
            cv.Title = 'Sales Transaction Summary - ' + opp.Name;
            cv.PathOnClient = 'Sales_Transaction_Summary_' + opp.Name + '.pdf';
            cv.VersionData = Blob.toPdf(buildHtml(opp, payments));
            cv.FirstPublishLocationId = opp.Id;

            opportunityIdsForInsert.add(opp.Id);
            resultByIndex.put(versionsToInsert.size(), res);
            versionsToInsert.add(cv);
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

        List<Opportunity> oppUpdates = new List<Opportunity>();
        for (Integer i = 0; i < versionsToInsert.size(); i++) {
            ContentVersion cv = versionsToInsert[i];
            Id docId = withDocIds.get(cv.Id).ContentDocumentId;
            Result res = resultByIndex.get(i);

            res.success = true;
            res.contentVersionId = cv.Id;
            res.contentDocumentId = docId;
            res.message = 'Sales Transaction Summary generated.';

            oppUpdates.add(new Opportunity(
                Id = opportunityIdsForInsert[i],
                AF_TransactionSummaryDocumentReference__c = String.valueOf(docId)
            ));
        }
        update as user oppUpdates;

        return results;
    }

    private static String buildHtml(Opportunity opp, List<AF_Payment__c> payments) {
        List<String> b = new List<String>();
        b.add('<html><body style="font-family: Arial, sans-serif; font-size: 12px;">');
        b.add('<h2>Sales Transaction Summary</h2>');
        b.add('<p><b>Opportunity:</b> ' + esc(opp.Name) + '<br/>');
        b.add('<b>Account:</b> ' + esc(opp.Account != null ? opp.Account.Name : '-') + '<br/>');
        b.add('<b>Contact:</b> ' + esc(opp.AF_PrimaryBrandContact__r != null ? opp.AF_PrimaryBrandContact__r.Name : '-') + '<br/>');
        b.add('<b>Brand:</b> ' + esc(opp.AF_Brand__c) + '  |  <b>Business Unit:</b> ' + esc(opp.AF_BusinessUnit__c) + '<br/>');
        b.add('<b>Vehicle:</b> ' + esc(opp.AF_SelectedVehicle__c != null ? opp.AF_SelectedVehicle__r.Name : '-')
              + (opp.AF_SelectedVehicle__c != null && opp.AF_SelectedVehicle__r.VehicleIdentificationNumber != null
                 ? ' (VIN: ' + esc(opp.AF_SelectedVehicle__r.VehicleIdentificationNumber) + ')' : '') + '</p>');

        b.add('<h3>Payments</h3>');
        b.add('<table border="1" cellpadding="4" cellspacing="0" style="border-collapse: collapse; width: 100%;">');
        b.add('<tr style="background:#eee;"><th>Reference</th><th>Date</th><th>Method</th><th>Status</th><th>Amount</th></tr>');
        for (AF_Payment__c pay : payments) {
            b.add('<tr>'
                + '<td>' + esc(pay.Name) + '</td>'
                + '<td>' + (pay.AF_PaymentDate__c == null ? '-' : String.valueOf(pay.AF_PaymentDate__c)) + '</td>'
                + '<td>' + esc(pay.AF_PaymentMethod__c) + '</td>'
                + '<td>' + esc(pay.AF_Status__c) + '</td>'
                + '<td style="text-align:right;">' + money(pay.AF_Amount__c) + '</td>'
                + '</tr>');
        }
        b.add('</table>');

        b.add('<h3>Invoice Position</h3>');
        b.add('<p><b>Expected Total:</b> ' + money(opp.AF_InvoiceSummary__r.AF_ExpectedTotalAmount__c) + '<br/>');
        b.add('<b>Paid Amount:</b> ' + money(opp.AF_InvoiceSummary__r.AF_PaidAmount__c) + '<br/>');
        b.add('<b>Balance:</b> ' + money(opp.AF_InvoiceSummary__r.AF_Balance__c) + '<br/>');
        b.add('<b>Invoice Status:</b> ' + esc(opp.AF_InvoiceSummary__r.AF_Status__c) + '</p>');

        b.add('<p style="color:#666; font-size:10px;">Generated ' + System.now().format('dd MMM yyyy HH:mm') + '</p>');
        b.add('</body></html>');
        return String.join(b, '\n');
    }

    private static String esc(String value) {
        return String.isBlank(value) ? '-' : value.escapeHtml4();
    }

    private static String money(Decimal value) {
        return value == null ? '-' : value.setScale(2).format();
    }
}