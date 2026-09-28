/**
 * LFRDN-342 interim proof-of-concept: controller extension for the
 * AF_VehicleSaleAgreementPDF Visualforce page, which renders the
 * Vehicle Sale Agreement as a native Salesforce PDF (renderAs="pdf")
 * for a given AF_Handover__c record. No managed package / add-on
 * license required - this uses only core Visualforce PDF rendering,
 * which is always available in this org.
 *
 * Interim document: clause text on the page is generic placeholder
 * language pending Legal review. Merge data below is pulled from real
 * AF_Handover__c relationships (Account, Contact, Vehicle, Opportunity,
 * Invoice Summary) - no invented fields.
 */
public with sharing class AF_VehicleSaleAgreementController {

    public AF_Handover__c handover { get; private set; }

    public AF_VehicleSaleAgreementController(ApexPages.StandardController stdController) {
        Id recordId = stdController.getId();
        handover = [
            SELECT Id, Name, AF_HandoverDate__c, AF_Location__c,
                   AF_Account__r.Name,
                   AF_Contact__r.Name, AF_Contact__r.Email, AF_Contact__r.MobilePhone,
                   AF_Vehicle__r.MakeName, AF_Vehicle__r.ModelName, AF_Vehicle__r.ModelYear,
                   AF_Vehicle__r.VehicleIdentificationNumber, AF_Vehicle__r.StockCode,
                   AF_Vehicle__r.ExteriorColor, AF_Vehicle__r.InteriorColor,
                   AF_Opportunity__r.Name, AF_Opportunity__r.Amount, AF_Opportunity__r.AF_OppOwnerName__c,
                   AF_InvoiceSummary__r.Name, AF_InvoiceSummary__r.AF_PaidAmount__c
            FROM AF_Handover__c
            WHERE Id = :recordId
            LIMIT 1
        ];
    }
}