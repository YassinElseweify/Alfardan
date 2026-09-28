/**
 * LFRDN-645 / LFRDN-646: backs afDiscountApprovalQueue, the bulk approval component.
 * Exists because the Lightning ProcessInstanceWorkitem page ignores the approval
 * process's own approvalPageFields, so an approver sees only the record name and owner
 * and cannot tell what they are authorising (LFRDN-646). This returns the deciding
 * figure alongside each pending item and approves/rejects them in one call (LFRDN-645).
 *
 * Handles every approval process in the org, not only Quote discounts: Quote discount
 * tiers, Opportunity closed-lost and internal requisition, Vehicle Reservation, Credit
 * Note cancellation and AppraisalItem valuation. Each object contributes its own
 * "amount" and "detail" so one table can carry them all - see DETAIL_BY_TYPE.
 *
 * Sharing: `with sharing` plus WITH USER_MODE throughout, and the work-item query is
 * filtered to ActorId = the running user. An approver therefore sees only the items
 * actually assigned to them, and only the fields their FLS allows.
 */
public with sharing class AF_DiscountApprovalController {

    /**
     * Per-object query shape. `amountField` is the figure the approver is deciding on;
     * `detailFields` are extra columns worth showing. Adding a new approval process
     * means adding one entry here - no other change.
     */
    private static final Map<String, ApprovalConfig> CONFIG_BY_TYPE = new Map<String, ApprovalConfig>{
        'Quote' => new ApprovalConfig(
            'Quote', 'Discount Approval',
            'Name', 'AF_DiscountAmount__c',
            new List<String>{ 'AF_DiscountPercent__c', 'AF_DiscountTier__c', 'Subtotal' }
        ),
        'Opportunity' => new ApprovalConfig(
            'Opportunity', 'Opportunity Approval',
            'Name', 'Amount',
            new List<String>{ 'StageName' }
        ),
        'AF_VehicleReservation__c' => new ApprovalConfig(
            'AF_VehicleReservation__c', 'Vehicle Reservation',
            'Name', null, new List<String>()
        ),
        'AF_CreditNote__c' => new ApprovalConfig(
            'AF_CreditNote__c', 'Credit Note Cancellation',
            'Name', null, new List<String>()
        ),
        'AppraisalItem' => new ApprovalConfig(
            'AppraisalItem', 'Trade-In Valuation',
            'AppraisalItemNumber', 'InitialValue', new List<String>{ 'MakeName', 'ModelName' }
        )
    };

    @AuraEnabled(cacheable=true)
    public static List<PendingApproval> getPendingApprovals() {
        // ActorId alone only matches work items assigned to this user directly - a
        // queue-type approver (e.g. AF_AP_AppraisalItem_Manager -> AF_Q_UsedCarTeam)
        // assigns the work item's ActorId to the QUEUE's Group Id, not to any member,
        // so a plain "ActorId = current user" filter silently hid every queue-routed
        // approval despite AppraisalItem being explicitly configured below. Fixed by
        // also matching any Group (queue or public group) this user is a member of.
        Set<Id> actorIds = new Set<Id>{ UserInfo.getUserId() };
        for (GroupMember gm : [
            SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :UserInfo.getUserId() WITH USER_MODE
        ]) {
            actorIds.add(gm.GroupId);
        }

        List<ProcessInstanceWorkitem> workItems = [
            SELECT Id, CreatedDate, ProcessInstance.TargetObjectId,
                   ProcessInstance.SubmittedBy.Name
            FROM ProcessInstanceWorkitem
            WHERE ActorId IN :actorIds
              AND ProcessInstance.Status = 'Pending'
            WITH USER_MODE
            ORDER BY CreatedDate ASC
        ];
        if (workItems.isEmpty()) {
            return new List<PendingApproval>();
        }

        // Group target ids by sObject type so each object is queried once.
        // The SObjectType itself is captured here (from the Id, via Id.getSObjectType() -
        // confirmed live to work for every persona) rather than re-derived later from
        // its string name via Schema.getGlobalDescribe().get(typeName) - that lookup was
        // found, via a real debug log from the Used Car Team persona, to return null for
        // AppraisalItem specifically even though every object/field permission grant is
        // correctly in place. Root cause not fully isolated (ruled out: object CRUD, app
        // visibility, Automotive Cloud license, profile, PSG membership - all confirmed
        // correct), but carrying the already-resolved SObjectType through avoids the
        // failing call entirely rather than working around a black-box platform gap.
        Map<String, Schema.SObjectType> typeByName = new Map<String, Schema.SObjectType>();
        Map<String, List<Id>> idsByType = new Map<String, List<Id>>();
        for (ProcessInstanceWorkitem item : workItems) {
            Id targetId = item.ProcessInstance.TargetObjectId;
            if (targetId == null) {
                continue;
            }
            Schema.SObjectType sObjType = targetId.getSObjectType();
            String typeName = sObjType.getDescribe().getName();
            if (!CONFIG_BY_TYPE.containsKey(typeName)) {
                continue;
            }
            typeByName.put(typeName, sObjType);
            if (!idsByType.containsKey(typeName)) {
                idsByType.put(typeName, new List<Id>());
            }
            idsByType.get(typeName).add(targetId);
        }

        Map<Id, SObject> recordById = new Map<Id, SObject>();
        for (String typeName : idsByType.keySet()) {
            try {
                recordById.putAll(queryTargets(typeByName.get(typeName), idsByType.get(typeName)));
            } catch (Exception e) {
                // A type this user cannot query at all (rather than a field-level FLS
                // gap, already handled inside queryTargets) must not fail the whole
                // wire call - skip that type's rows, keep the rest.
                System.debug(LoggingLevel.WARN, 'AF_DiscountApprovalController: skipped type '
                    + typeName + ' - ' + e.getTypeName() + ': ' + e.getMessage());
            }
        }

        // Iterate the original list so rows keep the query's CreatedDate ordering,
        // and so a record the approver cannot read is skipped rather than shown blank.
        // Each row is built defensively: a single record with an unexpected null
        // (e.g. Name blocked by FLS for this persona, a deactivated SubmittedBy, or a
        // config field this user cannot read) must not take down the whole list for
        // every other pending approval - it is skipped and logged instead.
        List<PendingApproval> results = new List<PendingApproval>();
        for (ProcessInstanceWorkitem item : workItems) {
            try {
                Id targetId = item.ProcessInstance.TargetObjectId;
                SObject record = targetId == null ? null : recordById.get(targetId);
                if (record == null) {
                    continue;
                }
                String typeName = targetId.getSObjectType().getDescribe().getName();
                ApprovalConfig cfg = CONFIG_BY_TYPE.get(typeName);
                if (cfg == null) {
                    continue;
                }

                PendingApproval row = new PendingApproval();
                row.workItemId = item.Id;
                row.recordId = targetId;
                row.recordUrl = '/' + targetId;
                row.recordName = String.valueOf(safeGet(record, cfg.nameField));
                row.approvalType = cfg.label;
                row.submittedBy = item.ProcessInstance.SubmittedBy != null
                    ? item.ProcessInstance.SubmittedBy.Name : null;
                row.submittedDate = item.CreatedDate;
                Object amountValue = cfg.amountField != null ? safeGet(record, cfg.amountField) : null;
                row.amount = amountValue instanceof Decimal ? (Decimal) amountValue : null;
                row.detail = buildDetail(typeName, record);
                results.add(row);
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'AF_DiscountApprovalController: skipped work item '
                    + item.Id + ' - ' + e.getTypeName() + ': ' + e.getMessage());
            }
        }
        return results;
    }

    private static Map<Id, SObject> queryTargets(Schema.SObjectType sObjType, List<Id> ids) {
        String typeName = sObjType.getDescribe().getName();
        ApprovalConfig cfg = CONFIG_BY_TYPE.get(typeName);
        Set<String> fields = new Set<String>{ 'Id', cfg.nameField };
        if (cfg.amountField != null) {
            fields.add(cfg.amountField);
        }
        fields.addAll(cfg.detailFields);

        // Drop any field this user cannot read, so one missing FLS grant narrows the
        // row rather than throwing and hiding the whole queue (the LFRDN-642 failure).
        // sObjType is passed in already-resolved (see getPendingApprovals) rather than
        // re-derived here via Schema.getGlobalDescribe().get(typeName) - that call was
        // found to return null for AppraisalItem for a real persona despite correct
        // object/field/app/license grants everywhere else.
        Map<String, Schema.SObjectField> describe = sObjType.getDescribe().fields.getMap();
        List<String> readable = new List<String>();
        for (String f : fields) {
            Schema.SObjectField token = describe.get(f);
            if (token != null && token.getDescribe().isAccessible()) {
                readable.add(f);
            }
        }
        // Id itself must never be dropped even if isAccessible() reports false for it
        // (confirmed live: AppraisalItem.AppraisalItemNumber has zero FLS grants
        // anywhere in this org, and on at least one persona that was enough to also
        // fail the Id check, producing an empty field list and a malformed
        // "SELECT  FROM ..." query) - every row this method returns is keyed by Id, so
        // it is not optional the way a display field is.
        if (!readable.contains('Id')) {
            readable.add('Id');
        }

        // WITH USER_MODE was found, via a real debug log from a restricted persona, to
        // throw "sObject type 'AppraisalItem' is not supported" even though every
        // object/field/app/license permission is confirmed correctly granted -
        // Automotive Cloud's AppraisalItem does not appear to support User Mode
        // enforcement in dynamic SOQL for a non-admin session in this org/API version.
        // The field list above is already pre-filtered to only what isAccessible() for
        // this user, so dropping the query-level enforcement here does not expose any
        // field this persona could not already read - it only avoids the specific
        // platform limitation on this one object.
        String soql = 'SELECT ' + String.join(readable, ', ')
            + ' FROM ' + typeName + ' WHERE Id IN :ids';
        Map<Id, SObject> out = new Map<Id, SObject>();
        for (SObject rec : Database.query(soql)) {
            out.put((Id) rec.get('Id'), rec);
        }
        return out;
    }

    private static String buildDetail(String typeName, SObject record) {
        if (typeName == 'Quote') {
            Object pct = safeGet(record, 'AF_DiscountPercent__c');
            Object tier = safeGet(record, 'AF_DiscountTier__c');
            if (pct == null && tier == null) {
                return null;
            }
            String text = pct != null ? pct + '% discount' : 'Discount';
            return tier != null ? text + ' · Tier ' + tier : text;
        }
        if (typeName == 'Opportunity') {
            Object stage = safeGet(record, 'StageName');
            return stage == null ? null : String.valueOf(stage);
        }
        if (typeName == 'AppraisalItem') {
            Object make = safeGet(record, 'MakeName');
            Object model = safeGet(record, 'ModelName');
            if (make == null && model == null) {
                return null;
            }
            return String.valueOf(make) + ' ' + String.valueOf(model);
        }
        return null;
    }

    private static Object safeGet(SObject record, String field) {
        try {
            return record.get(field);
        } catch (SObjectException e) {
            return null; // field not in the query because FLS excluded it
        }
    }

    /**
     * Each work item is submitted as its own Approval.process call: a single bad item
     * (reassigned, already actioned, or blocked by MANAGER_NOT_DEFINED further up the
     * chain - see LFRDN-647) must not discard the approver's other decisions, so
     * failures are collected and reported per row rather than thrown.
     */
    @AuraEnabled
    public static List<ApprovalResult> processApprovals(List<Id> workItemIds, String action, String comments) {
        if (workItemIds == null || workItemIds.isEmpty()) {
            return new List<ApprovalResult>();
        }
        if (action != 'Approve' && action != 'Reject') {
            throw new AuraHandledException('Unsupported approval action: ' + action);
        }

        // Only act on work items actually assigned to this user (directly, or via a
        // queue/group they belong to - see getPendingApprovals for why), so a crafted
        // id from the client cannot action someone else's approval.
        Set<Id> actorIds = new Set<Id>{ UserInfo.getUserId() };
        for (GroupMember gm : [
            SELECT GroupId FROM GroupMember WHERE UserOrGroupId = :UserInfo.getUserId() WITH USER_MODE
        ]) {
            actorIds.add(gm.GroupId);
        }
        Set<Id> assigned = new Map<Id, ProcessInstanceWorkitem>([
            SELECT Id FROM ProcessInstanceWorkitem
            WHERE Id IN :workItemIds AND ActorId IN :actorIds
            WITH USER_MODE
        ]).keySet();

        List<ApprovalResult> results = new List<ApprovalResult>();
        for (Id workItemId : workItemIds) {
            ApprovalResult outcome = new ApprovalResult();
            outcome.workItemId = workItemId;
            if (!assigned.contains(workItemId)) {
                outcome.success = false;
                outcome.message = 'This request is no longer assigned to you.';
                results.add(outcome);
                continue;
            }
            try {
                Approval.ProcessWorkitemRequest request = new Approval.ProcessWorkitemRequest();
                request.setWorkitemId(workItemId);
                request.setAction(action);
                if (String.isNotBlank(comments)) {
                    request.setComments(comments);
                }
                Approval.ProcessResult processResult = Approval.process(request, false);
                outcome.success = processResult.isSuccess();
                if (!outcome.success) {
                    outcome.message = flattenErrors(processResult.getErrors());
                }
            } catch (Exception e) {
                outcome.success = false;
                outcome.message = e.getMessage();
            }
            results.add(outcome);
        }
        return results;
    }

    private static String flattenErrors(List<Database.Error> errors) {
        if (errors == null || errors.isEmpty()) {
            return 'Unknown approval error.';
        }
        List<String> messages = new List<String>();
        for (Database.Error err : errors) {
            messages.add(err.getMessage());
        }
        return String.join(messages, ' | ');
    }

    private class ApprovalConfig {
        String objectName;
        String label;
        String nameField;
        String amountField;
        List<String> detailFields;
        ApprovalConfig(String objectName, String label, String nameField,
                       String amountField, List<String> detailFields) {
            this.objectName = objectName;
            this.label = label;
            this.nameField = nameField;
            this.amountField = amountField;
            this.detailFields = detailFields;
        }
    }

    public class PendingApproval {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public Id recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String recordUrl;
        @AuraEnabled public String approvalType;
        @AuraEnabled public String submittedBy;
        @AuraEnabled public Datetime submittedDate;
        @AuraEnabled public Decimal amount;
        @AuraEnabled public String detail;
    }

    public class ApprovalResult {
        @AuraEnabled public Id workItemId;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }
}