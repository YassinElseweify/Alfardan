/**
 * LFRDN-709 - Apex Managed Sharing for AF_Handover__c / AF_InvoiceSummary__c /
 * AF_VehicleReservation__c / AF_Payment__c.
 *
 * All four objects were deployed with sharingModel=ReadWrite (Public Read/Write), so every
 * business unit could open, edit and download every other unit's customer contracts, invoices,
 * payments and reservations - the same records Opportunity itself already segregates by business
 * unit via AF_SR_Opportunity_* sharing rules. Fixed by switching OWD to Private on all four
 * objects; this class replaces the access those rules used to provide implicitly.
 *
 * Why Apex sharing rather than declarative sharing rules: all four objects reach their Opportunity
 * via a Lookup (AF_Opportunity__c), not Master-Detail, so "Controlled by Parent" isn't selectable;
 * and none of them carries its own AF_BusinessUnit__c/AF_Showroom__c field for a criteria-based
 * sharing rule to key off (only Opportunity does), so a rule can't reach the parent's value either.
 * Apex sharing reads the value directly off the related Opportunity at share-time instead of
 * needing it duplicated onto the child record.
 *
 * Grants the same access Opportunity's own rules grant: Edit to the AF_G_BU_* public group for the
 * matching AF_BusinessUnit__c, and Edit to the AF_Role_ShowroomManager_* role group for the
 * matching AF_Showroom__c - both resolved by Group.DeveloperName in one query, same values the
 * BRD-mandated AF_SR_Opportunity_* rules already use. RowCause is a custom Apex Sharing Reason,
 * AF_BusinessUnitAccess (one SharingReason definition deployed per object, same DeveloperName),
 * rather than the generic Manual, so these shares are distinguishable from manual record-sharing a
 * user does themselves and can be recalculated safely.
 *
 * Bulk-safe by construction: called from a trigger/flow with at most the org's normal DML batch
 * size (<=200 records), queries and DML are done once per call, never inside a loop. Also callable
 * from Batch Apex for a one-off backfill over an object's full existing record set without changing
 * the method - the caller controls the batch size, this class only ever processes what it's given.
 */
public without sharing class AF_ChildRecordSharingService {

    private static final Map<String, String> BUSINESS_UNIT_GROUP_BY_VALUE = new Map<String, String>{
        'Alfardan Automobiles' => 'AF_G_BU_Automobiles',
        'Alfardan Premier Motors' => 'AF_G_BU_PremierMotors',
        'Alfardan Sports Motors' => 'AF_G_BU_SportsMotors'
    };

    private static final Map<String, String> SHOWROOM_ROLE_GROUP_BY_VALUE = new Map<String, String>{
        'Alsadd' => 'AF_Role_ShowroomManager_Alsadd',
        'Jery Al Samur' => 'AF_Role_ShowroomManager_JeryAlSamur',
        'Lusail' => 'AF_Role_ShowroomManager_Lusail',
        'Lusail Boulevard' => 'AF_Role_ShowroomManager_LusailBoulevard',
        'Pearl' => 'AF_Role_ShowroomManager_Pearl',
        'Pearl (Motorcycles)' => 'AF_Role_ShowroomManager_PearlMotorcycles',
        'Pearl (Rolls Royce)' => 'AF_Role_ShowroomManager_PearlRollsRoyce',
        'Towers' => 'AF_Role_ShowroomManager_Towers'
    };

    /**
     * @description Shares each record with the same business-unit group / showroom role group
     * Opportunity's own sharing rules would grant, based on the record's AF_Opportunity__c lookup.
     * Idempotent-safe to call again for the same records (e.g. after an Opportunity's business unit
     * changes) - existing shares for these records under this sharing reason are deleted and
     * recreated from the current Opportunity values, rather than accumulating stale grants.
     * @param records Child records with an AF_Opportunity__c field, already inserted/updated (must have Ids).
     * @param sObjType The child object's SObjectType (e.g. AF_Handover__c.SObjectType).
     */
    public static void shareWithBusinessUnitAccess(List<SObject> records, Schema.SObjectType sObjType) {
        if (records == null || records.isEmpty()) {
            return;
        }

        Set<Id> opportunityIds = new Set<Id>();
        Map<Id, Id> opportunityIdByRecordId = new Map<Id, Id>();
        for (SObject rec : records) {
            Id recId = (Id) rec.get('Id');
            Object oppIdObj = rec.get('AF_Opportunity__c');
            if (recId == null || oppIdObj == null) {
                continue;
            }
            Id oppId = (Id) oppIdObj;
            opportunityIds.add(oppId);
            opportunityIdByRecordId.put(recId, oppId);
        }

        if (opportunityIdByRecordId.isEmpty()) {
            return;
        }

        Map<Id, Opportunity> opportunitiesById = new Map<Id, Opportunity>(
            [SELECT Id, AF_BusinessUnit__c, AF_Showroom__c FROM Opportunity WHERE Id IN :opportunityIds]
        );

        Set<String> groupDeveloperNames = new Set<String>();
        for (Opportunity opp : opportunitiesById.values()) {
            if (BUSINESS_UNIT_GROUP_BY_VALUE.containsKey(opp.AF_BusinessUnit__c)) {
                groupDeveloperNames.add(BUSINESS_UNIT_GROUP_BY_VALUE.get(opp.AF_BusinessUnit__c));
            }
            if (SHOWROOM_ROLE_GROUP_BY_VALUE.containsKey(opp.AF_Showroom__c)) {
                groupDeveloperNames.add(SHOWROOM_ROLE_GROUP_BY_VALUE.get(opp.AF_Showroom__c));
            }
        }

        if (groupDeveloperNames.isEmpty()) {
            return;
        }

        Map<String, Id> groupIdByDeveloperName = new Map<String, Id>();
        for (Group g : [SELECT Id, DeveloperName FROM Group WHERE DeveloperName IN :groupDeveloperNames]) {
            groupIdByDeveloperName.put(g.DeveloperName, g.Id);
        }

        String shareObjectName = sObjType.getDescribe().getName().removeEnd('__c') + '__Share';
        String rowCause = 'AF_BusinessUnitAccess__c';
        Set<Id> recordIds = opportunityIdByRecordId.keySet();

        // Clear any previous Apex-managed shares for these records under this reason, so a
        // business-unit change on the Opportunity doesn't leave a stale grant behind.
        List<SObject> existingShares = Database.query(
            'SELECT Id FROM ' + shareObjectName +
            ' WHERE ParentId IN :recordIds AND RowCause = :rowCause'
        );
        if (!existingShares.isEmpty()) {
            delete existingShares;
        }

        List<SObject> sharesToInsert = new List<SObject>();
        for (Id recId : opportunityIdByRecordId.keySet()) {
            Opportunity opp = opportunitiesById.get(opportunityIdByRecordId.get(recId));
            if (opp == null) {
                continue;
            }

            String buGroupName = BUSINESS_UNIT_GROUP_BY_VALUE.get(opp.AF_BusinessUnit__c);
            if (buGroupName != null && groupIdByDeveloperName.containsKey(buGroupName)) {
                sharesToInsert.add(buildShare(shareObjectName, recId, groupIdByDeveloperName.get(buGroupName), rowCause));
            }

            String showroomGroupName = SHOWROOM_ROLE_GROUP_BY_VALUE.get(opp.AF_Showroom__c);
            if (showroomGroupName != null && groupIdByDeveloperName.containsKey(showroomGroupName)) {
                sharesToInsert.add(buildShare(shareObjectName, recId, groupIdByDeveloperName.get(showroomGroupName), rowCause));
            }
        }

        if (!sharesToInsert.isEmpty()) {
            Database.insert(sharesToInsert, false);
        }
    }

    private static SObject buildShare(String shareObjectName, Id parentId, Id userOrGroupId, String rowCause) {
        SObject share = Schema.getGlobalDescribe().get(shareObjectName).newSObject();
        share.put('ParentId', parentId);
        share.put('UserOrGroupId', userOrGroupId);
        share.put('AccessLevel', 'Edit');
        share.put('RowCause', rowCause);
        return share;
    }
}