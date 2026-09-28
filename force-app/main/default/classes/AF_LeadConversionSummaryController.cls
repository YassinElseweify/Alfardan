public with sharing class AF_LeadConversionSummaryController {
    public class Summary {
        @AuraEnabled public Id accountId;
        @AuraEnabled public String accountName;
        @AuraEnabled public String accountType;
        @AuraEnabled public String accountPhone;
        @AuraEnabled public String accountWebsite;
        @AuraEnabled public String accountSite;
        @AuraEnabled public String accountRecordTypeName;
        @AuraEnabled public Id accountOwnerId;
        @AuraEnabled public String accountOwnerName;

        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
        @AuraEnabled public String contactTitle;
        @AuraEnabled public String contactPhone;
        @AuraEnabled public String contactEmail;
        @AuraEnabled public String contactMobile;
        @AuraEnabled public String contactRecordTypeName;
        @AuraEnabled public String contactBrand;
        @AuraEnabled public String contactBusinessUnit;
        @AuraEnabled public String contactCategory;
        @AuraEnabled public String contactRole;
        @AuraEnabled public String contactRelationshipToAccountHolder;
        @AuraEnabled public String contactPreferredLanguage;
        @AuraEnabled public String contactPreferredChannel;
        @AuraEnabled public Boolean contactMarketingOptIn;

        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String opportunityCloseDate;
        @AuraEnabled public String opportunityAmount;
        @AuraEnabled public Id opportunityOwnerId;
        @AuraEnabled public String opportunityOwnerName;
    }

    // One targeted, indexed (by Id), LIMIT-1 query per object — 3 SOQL queries total,
    // regardless of org size. This runs once per lead conversion (a single-user screen
    // interaction, never a batch/trigger context), so there is no realistic path to
    // governor limits here; the query shape is kept minimal anyway as good practice.
    @AuraEnabled(cacheable=true)
    public static Summary getSummary(Id accountId, Id contactId, Id opportunityId) {
        Summary result = new Summary();

        for (Account acc : [
            SELECT Id, Name, Type, Phone, Website, Site, OwnerId, Owner.Name, RecordType.Name
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ]) {
            result.accountId = acc.Id;
            result.accountName = acc.Name;
            result.accountType = acc.Type;
            result.accountPhone = acc.Phone;
            result.accountWebsite = acc.Website;
            result.accountSite = acc.Site;
            result.accountRecordTypeName = acc.RecordType != null ? acc.RecordType.Name : null;
            result.accountOwnerId = acc.OwnerId;
            result.accountOwnerName = acc.Owner.Name;
        }

        for (Contact con : [
            SELECT Id, Name, Title, Phone, Email, MobilePhone, RecordType.Name,
                   AF_Brand__c, AF_BusinessUnit__c, AF_ContactCategory__c, AF_ContactRole__c,
                   AF_RelationshipToAccountHolder__c, AF_PreferredLanguage__c, AF_PreferredChannel__c,
                   AF_MarketingOptIn__c
            FROM Contact
            WHERE Id = :contactId
            LIMIT 1
        ]) {
            result.contactId = con.Id;
            result.contactName = con.Name;
            result.contactTitle = con.Title;
            result.contactPhone = con.Phone;
            result.contactEmail = con.Email;
            result.contactMobile = con.MobilePhone;
            result.contactRecordTypeName = con.RecordType != null ? con.RecordType.Name : null;
            result.contactBrand = con.AF_Brand__c;
            result.contactBusinessUnit = con.AF_BusinessUnit__c;
            result.contactCategory = con.AF_ContactCategory__c;
            result.contactRole = con.AF_ContactRole__c;
            result.contactRelationshipToAccountHolder = con.AF_RelationshipToAccountHolder__c;
            result.contactPreferredLanguage = con.AF_PreferredLanguage__c;
            result.contactPreferredChannel = con.AF_PreferredChannel__c;
            result.contactMarketingOptIn = con.AF_MarketingOptIn__c;
        }

        for (Opportunity opp : [
            SELECT Id, Name, CloseDate, Amount, OwnerId, Owner.Name
            FROM Opportunity
            WHERE Id = :opportunityId
            LIMIT 1
        ]) {
            result.opportunityId = opp.Id;
            result.opportunityName = opp.Name;
            result.opportunityCloseDate = opp.CloseDate != null ? opp.CloseDate.format() : null;
            result.opportunityAmount = opp.Amount != null ? String.valueOf(opp.Amount) : null;
            result.opportunityOwnerId = opp.OwnerId;
            result.opportunityOwnerName = opp.Owner.Name;
        }

        return result;
    }
}