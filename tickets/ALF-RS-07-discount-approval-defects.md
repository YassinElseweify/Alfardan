# ALF-RS-07 — Discount Approval Workflow: defects found in QA

**Module:** Retail Sales — Discount Approval Workflow
**Status:** Open
**Found during:** QA testing of ALF-RS-07 in the QA sandbox, 2026-09-09
**Scope note:** Defects 1–7 reproduce for **all users, including System Administrator**. Defect **8 is a persona-blocking permission gap** — System Administrator is unaffected, but the approver personas are. Each ticket names the personas it affects.

**Worth stating up front:** the tier matrix, band boundaries, fail-safe routing, rejection handling and re-approval logic are all **correct and well built**. The defects below are concentrated in what happens *around* that core — whether the discount reaches the price, whether the chain can complete, and whether approvers can act in bulk or even see what they are approving.

---

## 1. Approved discounts never actually reduce the customer's price (Highest)

**Description**
A salesperson can enter a discount, the system routes it for approval, managers approve it — and the quotation total does not change by a single riyal. The discount is recorded and governed, but it is never applied to the price. A quote with a 100,000 discount on a 100,000 car still totals 100,000. Every downstream number that depends on the quote total — the deal value, the order, reporting, commission — is therefore based on the undiscounted price.

**Steps to Reproduce**
1. Open (or create) a Quote with a single line item so `Subtotal` is a known figure — 100,000 was used in testing.
2. Record `Subtotal`, `TotalPrice` and `GrandTotal`.
3. Set `AF_DiscountAmount__c` = 10000 and save.
4. Re-query the same three fields: `SELECT Subtotal, AF_DiscountAmount__c, AF_DiscountPercent__c, Discount, TotalPrice, GrandTotal FROM Quote WHERE Id = '<id>'`.
5. Repeat with `AF_DiscountAmount__c` = 100000 (100% of Subtotal) and again with 150000 (150%).
6. Separately, set `AF_DiscountAmount__c` on a `QuoteLineItem` and re-check that line's `TotalPrice`.

**Expected Result**
The quote total falls by the discount amount — a 10,000 discount on a 100,000 subtotal produces a 90,000 total.

**Actual Result**
`TotalPrice` and `GrandTotal` remained **exactly equal to `Subtotal`** in **all 24** discounted quotes tested, at every discount size including 100% and 150%. The standard `Quote.Discount` field stayed `0` throughout. The line-level field behaves the same way: a 20,000 discount on a 100,000 line left that line's `TotalPrice` at 100,000. Only `AF_DiscountPercent__c` responded, correctly deriving the percentage.

**Root Cause**
Confirmed by searching all 72 `AF_` flows and the org's Apex. `Quote.AF_DiscountAmount__c` is referenced by exactly three components — `AF_FL_Opp_CreateQuotation`, `AF_FL_Quote_SetDiscountApprovalStatus` and `AF_FL_Quote_DiscountApprovalRequested` — all of which only *read* it to compute a tier or compose a notification. No formula field, roll-up, before-save flow or Apex writes the discount into `Quote.Discount`, adjusts any line's `UnitPrice`, or otherwise reduces a total. The custom discount field was built as a governance input and was never wired into pricing.

**Proposed Solution**
Decide with the BA which of the two standard mechanisms should carry the discount, then implement it:
- **Simplest:** a before-save flow on Quote that writes the approved discount into the standard `Quote.Discount` field (as a percentage) so Salesforce's own pricing reduces `GrandTotal` natively; or
- **More explicit:** create the discount as a negative `QuoteLineItem` (mirroring how the Trade-In Deduction line already works in ALF-RS-06), which keeps the reduction visible on the printed quotation.
Either way, gate the application on `AF_DiscountApprovalStatus__c` being `Approved` or `Not Required`, so an unapproved discount never reaches the customer's price. Also confirm whether the same treatment is needed for the line-level `QuoteLineItem.AF_DiscountAmount__c`.

**Reference**
BRD §10.7, p.44, Requirement Overview: *"Discounts support numeric value and percentage entry. Any discount applied triggers the appropriate approval path based on the delegation-of-authority matrix…"* — read against BRD §10.6, p.44, AC3, which establishes the principle for the comparable trade-in case: *"the trade-in deduction appears as a line item reducing the total deal value."*

---

## 2. Discount approvals above the first level can never be completed by anyone (Highest)

**Description**
Any discount above 3% needs at least two levels of approval. In practice it can get none. The first approver is unable to approve, because the system cannot work out who the next approver should be, and it stops with an error. The quotation is left showing "Pending" forever — it looks as though it is sitting with someone for a decision when in fact no one can action it, and it cannot be rejected either.

**Steps to Reproduce**
1. As a Sales Representative, set `AF_DiscountAmount__c` on a Quote to a value in the Tier 2+ range (4% of `Subtotal` or higher — 10% was used).
2. Confirm the record now shows `AF_DiscountTier__c` = 2 (or higher) and `AF_DiscountApprovalStatus__c` = `Pending`, with a `ProcessInstance` against `AF_AP_Quote_DiscountTiers`.
3. Identify the pending `ProcessInstanceWorkitem` and note its assigned approver.
4. Approve that work item as the assigned approver (UI **Approve** button, or `Approval.process()` with `setAction('Approve')`).
5. Re-query the Quote and its `ProcessInstance`.

**Expected Result**
The first approval succeeds and the request advances to the next approver in the delegation-of-authority chain, ultimately reaching the executive approver for the highest tiers.

**Actual Result**
The approval is refused outright with:
`MANAGER_NOT_DEFINED: This approval request requires the next approver to be determined by the Manager field. This value is empty. Please contact your administrator for more information.`
The Quote remains `Pending` and its `ProcessInstance` remains `Pending`, with the work item still open. Reproduced on a Tier 4 request; the same wall applies to every Tier 2, 3 and 4 request in the org.

**Root Cause**
Confirmed by inspecting the approval process metadata and the live user records. `AF_AP_Quote_DiscountTiers` resolves every step's approver from `nextAutomatedApprover.userHierarchyField = Manager`, so each successive step needs the *previous approver's* Manager to be populated. The org's hierarchy does not support that depth:
- Sales Representative → **Alfardan Salesforce** (`afaoitpowerautomate_…`, a Power Automate integration account) → **no Manager**
- Sales Manager → the same integration account
- Showroom Manager Automobiles → **no Manager**
- QA Test Admin → **no Manager**
The chain is one level deep and terminates on an account that is not a person. **The approval process itself is correctly built — the user hierarchy underneath it was not.**

**Update 2026-09-10 — the hierarchy has since been configured in the QA sandbox** at the client's request, and the chain now works end to end. The Manager field was set to `Sales Rep → Showroom Manager Automobiles → Sales Manager → Arcsen Alfardan → QA Test Admin`, and a live Tier 4 (10%) discount then routed through **all four steps in order** — Showroom Manager, Sales Manager, Arcsen, QA Test Admin — finishing `Approved` with the confirmation email sent. `MANAGER_NOT_DEFINED` no longer occurs.

**This does not close the ticket**, for two reasons:
- Tiers 3 and 4 are staffed by **System Administrator stand-ins** because the org has **no General Manager and no CEO user at all**. Those roles exist (`AF_Role_GM_Automobiles`, `AF_Role_CEO`) but nobody occupies them, and all 10 Salesforce licences are consumed, so neither can be created without freeing a seat. The business still needs to name those two people.
- Nothing prevents the same breakage recurring. The chain depends on a manually-maintained Manager field with no validation behind it; one leaver or one new hire with a blank Manager silently reinstates the fault.

**Proposed Solution**
Two parts:
1. **Populate the Manager field** on every user who participates in selling, so the chain matches the DoA matrix: Sales Representative → Showroom Manager → Sales/Brand Manager → General Manager → CEO. Make this part of user provisioning, since the approval process silently depends on it.
2. **Stop routing a role-based matrix through the manager chain.** The DoA matrix names *roles* (Showroom Manager, Sales/Brand Manager, General Manager, CEO), but `userHierarchyField` resolves whoever happens to sit above the submitter — which is why Tier 1 currently routes to an integration account rather than the Showroom Manager. Consider changing each step's approver to a named user or, better, a queue/public group per role, so routing follows the matrix rather than the org chart. At minimum, add a validation or monitoring check that no user in the selling hierarchy has an empty Manager.

**Reference**
BRD §10.7, p.45, AC2: *"Given a discount exceeds the senior leadership threshold, When the approval chain processes, Then the request escalates to the defined executive approver."* Also p.44, FR3: *"multi-level approval escalation including senior leadership and CEO-level approval above defined thresholds."*

---

## 3. Bulk review and mass approval do not exist (High)

**Description**
An executive with a stack of discount requests waiting must open and approve each one individually. There is no way to select several and approve them together. The BRD asks specifically for bulk review and mass approval for executive reviewers, and that capability has not been built.

**Steps to Reproduce**
1. Create at least three Quotes with discounts that route to the same approver (any three in the Tier 1 band, e.g. 2.2%, 2.3%, 2.4%).
2. Log in as that approver.
3. Open App Launcher → **Approvals** → **Approval Requests** → the **"Items to Approve"** list view.
4. Attempt to select more than one row — look for row checkboxes or a select-all control in the header.
5. Look for any mass Approve or mass Reject button on the list view.
6. Check the Home page for an "Items to Approve" Lightning component.

**Expected Result**
Multiple pending requests can be selected together and approved (or rejected) in one action.

**Actual Result**
The "Items to Approve" list view correctly shows all pending requests together (8 were visible in testing), but it has **no selection checkboxes at all** — neither a select-all column nor per-row checkboxes — where ordinary Lightning list views in the same org (an Opportunity list, for example) render them normally. The only control is a per-row **Show Actions** menu offering Approve / Reject / Reassign for that single record. There is no mass-approval button, no custom bulk component anywhere in the org, and no "Items to Approve" component on the Home page. Screenshot: `rs07-tc023-no-bulk-approval.png`.

**Root Cause**
Nothing has been built for this. Salesforce's standard Lightning list view for `ProcessInstanceWorkitem` does not offer mass approval — that capability existed in Classic's "Items to Approve" home-page related list and was never carried into Lightning. Delivering FR4 therefore requires a custom component or screen flow; it is not something the platform provides out of the box for this object.

**Proposed Solution**
Build a bulk-approval screen: a Lightning component or screen flow listing the running user's pending `ProcessInstanceWorkitem` records for this process, with checkboxes and a single Approve / Reject action that calls `Approval.process()` over the selected work items in one transaction. Surface the discount amount, percentage and tier as columns in that component (see defect 4), and add it to the Home page for approver personas. Bulk rejection should behave symmetrically.

**Reference**
BRD §10.7, p.44, FR4: *"The system provides an approval inbox/view supporting bulk review and mass approval actions."* And p.45, AC3: *"Given an executive approver has multiple pending discount requests, When they open the approval view, Then all pending items are visible and bulk approval actions are available."*

---

## 4. Approvers cannot see the discount they are being asked to approve (High)

**Description**
When a manager opens a discount approval request, the screen shows the quotation's name and its owner — and nothing else. The actual discount, the percentage and the authority tier are all missing. The manager is being asked to authorise a commercial concession without being shown its size, and has to go and open the quotation separately to find out what they are approving.

**Steps to Reproduce**
1. Raise a discount approval on a Quote (any tier above 0).
2. Log in as the assigned approver.
3. Open the approval request, either from the notification or via Approval Requests → "Items to Approve" → the record.
4. Read every field shown in the "Approval Details" section.
5. Also review the columns available on the "Items to Approve" list view.

**Expected Result**
The approver sees the discount amount, the derived percentage and the tier, so they can make the decision from the approval screen itself.

**Actual Result**
The approval request record displays only **Quote Name** and **Owner Name**. The list view's columns are only Item Number, Related To, Type, Most Recent Approver, Date Submitted and Action. The discount amount, percentage and tier appear in neither place. The in-app notification is similarly bare — *"Sales Representative is requesting approval for quote — Quote Name: …"* with no figures.

**Root Cause**
Two compounding causes, both confirmed:
1. `AF_AP_Quote_DiscountTiers` **is** configured with the right approval page fields — `Name`, `AF_DiscountAmount__c`, `AF_DiscountPercent__c`, `AF_DiscountTier__c`. Those fields render on the Classic approval page, but the Lightning `ProcessInstanceWorkitem` record page does not surface them, so the configuration has no visible effect in the UI the business actually uses.
2. The approver persona additionally has **no field-level read access** to any of the three discount fields on Quote, so even where Salesforce would render them it must suppress them. (That access gap is persona-specific and is recorded in `qa-notes.md` rather than raised here, but it compounds this defect.)

**Proposed Solution**
Surface the figures where the approver actually looks:
- Add `AF_DiscountAmount__c`, `AF_DiscountPercent__c` and `AF_DiscountTier__c` as columns on the "Items to Approve" list view (and to the bulk-approval component from defect 3).
- Include the amount, percentage and tier in the body of the approval notification and email so the request is actionable without opening anything.
- Grant the approver personas read access to those three fields.

**Reference**
BRD §10.7, p.45, AC3: *"…all pending items are visible and bulk approval actions are available."* Visibility of the item without visibility of the discount does not meet the intent of a delegation-of-authority review.

---

## 5. A salesperson can discount the price in the UI with no approval at all — and it is the only discount field they can actually reach (High)

> **Revised 2026-09-10 after a client observation.** This ticket originally described a bypass via the custom field `QuoteLineItem.AF_DiscountAmount__c`. That field turns out **not to be on the Quote Line Item layout at all**, so it is not the reachable route. The reachable route is worse: the **standard `Discount` field**, which *is* on the layout, *is* editable by the Sales Representative, *does* reduce the customer's price — and triggers no governance whatsoever.

**Description**
Open a quotation line, type a percentage into **Discount**, save. The price drops. No approval is requested, no authority level is worked out, nobody is notified — the deal value simply changes. In testing a Sales Representative applied **20%** to a 100,000 line and the quotation total fell to **80,000** with no approval of any kind.

This sits in direct contradiction with the discount field the approval process actually governs. On the Quote header there is a **Discount Amount** field which routes correctly through the whole delegation-of-authority matrix — but which has **no effect on the price** (see defect 1). So the org currently has:
- a **governed** discount that does not change the price, and
- an **ungoverned** discount that does.

A salesperson wanting to give away margin has an easy, visible, entirely legitimate-looking way to do it that the matrix never sees.

**Steps to Reproduce**
1. Log in as the **Sales Representative** persona and open a Quote with a known Subtotal (100,000 was used).
2. Open the **Quote Line Items** related list and click into a line.
3. Note `UnitPrice`, `Discount` and `TotalPrice` before the change.
4. Set the standard **Discount** field to `20` and save.
5. Re-check the line, then the parent Quote's `Subtotal`, `TotalPrice` and `GrandTotal`.
6. Check for any governance: `SELECT AF_DiscountAmount__c, AF_DiscountTier__c, AF_DiscountApprovalStatus__c FROM Quote WHERE Id = '<id>'` and `SELECT COUNT(Id) FROM ProcessInstance WHERE TargetObjectId = '<quote id>'`.

**Expected Result**
Any discount that reduces what the customer pays is routed through the delegation-of-authority matrix, whatever field it was entered in.

**Actual Result**
The line's `TotalPrice` fell from **100,000 to 80,000**, and the Quote's `TotalPrice` and `GrandTotal` both fell from **100,000 to 80,000** — the customer's price genuinely changed. Meanwhile on the parent Quote, `AF_DiscountAmount__c`, `AF_DiscountPercent__c`, `AF_DiscountTier__c` and `AF_DiscountApprovalStatus__c` all remained **blank**, and the `ProcessInstance` count returned **0**. A 20% concession with no approval, no tier, no audit trail and no notification.

**Root Cause**
Confirmed from layout metadata, field permissions and live DML. Three things combine:
1. **The Quote Line Item layout exposes only the standard `Discount` field.** Its full field list is `AF_LineItemType__c, CreatedById, Description, Discount, HasSchedule, LastModifiedById, LineNumber, ListPrice, Product2Id, Quantity, QuoteId, Subtotal, TotalPrice, UnitPrice`. The custom `AF_DiscountAmount__c` and `AF_DiscountPercentage__c` are **absent from the layout**, so the fields the solution was designed around are invisible to users — while the standard one is right there.
2. **The Sales Representative has read/edit on `QuoteLineItem.Discount`** (granted via `AF_PSG_Sales_Rep`), so using it is entirely within their permissions.
3. **`Discount` is a native Salesforce pricing field**, so it reduces the line and quote totals automatically — no custom automation required. Nothing in the org watches it: `AF_FL_Quote_SetDiscountApprovalStatus` is a before-save flow on **Quote** triggered only by `Quote.AF_DiscountAmount__c` changing, and the approval process is defined on Quote only. No flow, roll-up or Apex reads `QuoteLineItem.Discount` at all.

**Proposed Solution**
Close the ungoverned route and make the governed route real — both are needed, and neither is sufficient alone:
1. **Govern line-level discounting.** Add a record-triggered flow on `QuoteLineItem` that, on insert/update/delete, aggregates the line-level discount across the quote and feeds it into the same DoA evaluation the header discount uses — so the tier is computed from the customer's *total* concession however it was entered.
2. **Decide which field is the discount field, and remove the other from the UI.** Either put `AF_DiscountAmount__c` on the Quote Line Item layout and make the standard `Discount` read-only for business personas, or drop the custom line fields and govern the standard one. Leaving both live, with only the ungoverned one visible, guarantees the matrix is bypassed by ordinary use.
3. Apply this together with defect 1's fix, so that the governed discount actually reaches the price. Until both are done, the two fields remain exactly inverted.

Worth confirming with the BA whether header and line discounts should ever coexist, or whether one should be blocked when the other is present — that determines whether the aggregate is a sum or a validation error.

**Reference**
BRD §10.7, p.44, FR2: *"An approval workflow is triggered whenever a Sales Representative applies a discount, routing to the appropriate approver based on the delegation-of-authority matrix."* A percentage typed into the Discount field on a quotation line is a discount applied by a Sales Representative. Also p.44, Requirement Overview: *"Any discount applied triggers the appropriate approval path based on the delegation-of-authority matrix, potentially escalating to CEO level."*

## 6. Negative discounts escape the approval workflow completely (Medium)

**Description**
Entering a negative discount is accepted without complaint, and because the system only checks for discounts *greater than* zero, no approval is ever raised. A negative discount is, in effect, a surcharge applied to the customer with no authorisation and no record of anyone agreeing to it.

**Steps to Reproduce**
1. As a Sales Representative, take a Quote with a known `Subtotal`.
2. Set `AF_DiscountAmount__c` = -5000 and save.
3. Query `AF_DiscountPercent__c`, `AF_DiscountTier__c` and `AF_DiscountApprovalStatus__c`.
4. Check for any approval: `SELECT COUNT(Id) FROM ProcessInstance WHERE TargetObjectId = '<quote id>'`.

**Expected Result**
Either the negative value is rejected on save, or it is treated as a governed change and routed for approval.

**Actual Result**
The save **succeeded**. `AF_DiscountPercent__c` computed **-5%**, while `AF_DiscountTier__c` and `AF_DiscountApprovalStatus__c` were both left **blank** and **no approval request was raised**. The value sits on the record entirely outside the governance workflow.

**Root Cause**
Confirmed from the flow definition. `AF_FL_Quote_SetDiscountApprovalStatus`'s entry condition is `{!$Record.AF_DiscountAmount__c} > 0 && (ISNEW() || ISCHANGED(...)) && NOT(ISPICKVAL(..., "Pending"))`. Any value at or below zero fails the first clause, so the flow never runs and no tier or status is stamped. `Quote` has **zero** validation rules, so nothing else blocks the entry either.

**Proposed Solution**
Add a validation rule on Quote rejecting `AF_DiscountAmount__c < 0` with a clear message (a discount cannot be negative), and apply the same rule to `QuoteLineItem.AF_DiscountAmount__c`. If the business genuinely needs to record a price uplift, that should be a separate, explicitly-named field with its own approval path rather than a negative discount. While making this change, also consider capping the discount at the quote's `Subtotal` — a discount exceeding the deal value currently saves without objection too (it is at least routed for approval by the fail-safe, but it should not be enterable).

**Reference**
BRD §10.7, p.44, FR2: *"An approval workflow is triggered whenever a Sales Representative applies a discount."*

---

## 7. The tier that decides who approves can be edited by the person requesting approval (Medium)

**Description**
The system works out which authority level a discount needs and stores it on the quotation. That stored level is what the approval routing reads. A Sales Representative can type over it. In testing, a quotation with a genuine 1% discount was made to display authority level 4 simply by editing the field.

**Steps to Reproduce**
1. As a Sales Representative, set a discount well inside the self-authorized band (1% of `Subtotal`) and confirm `AF_DiscountTier__c` = 0 and `AF_DiscountApprovalStatus__c` = 'Not Required'.
2. As the same Sales Representative, update **only** `AF_DiscountTier__c` to 4, changing nothing else.
3. Re-query the record.
4. Check whether any `ProcessInstance` was created.

**Expected Result**
The write is rejected — `AF_DiscountTier__c` is derived by the system and should be read-only to the submitter, exactly as `AF_DiscountApprovalStatus__c` already is.

**Actual Result**
The write **succeeded and persisted**. The record then read `AF_DiscountTier__c` = 4, `AF_DiscountApprovalStatus__c` = 'Not Required', `AF_DiscountPercent__c` = 1% — an internally contradictory state. No approval was raised by the edit alone, because the status field is correctly read-only and cannot be set to `Pending` by the rep; and any later change to the discount amount re-derives the tier. **This is therefore a data-integrity and reporting defect, not a live routing bypass** — but the field it corrupts is the one every approval step keys on (`Quote.AF_DiscountTier__c >= 2 / >= 3 / >= 4`).

**Root Cause**
Confirmed from `FieldPermissions`. `AF_PSG_Sales_Rep` grants `Quote.AF_DiscountTier__c` with `PermissionsRead = true` **and `PermissionsEdit = true`**, whereas the comparable system-maintained field `Quote.AF_DiscountApprovalStatus__c` is correctly granted read-only (`PermissionsEdit = false`). The tier field appears simply to have been missed when field-level security was set.

**Proposed Solution**
Set `Quote.AF_DiscountTier__c` to read-only for `AF_PSG_Sales_Rep` and for every other business persona, matching the existing treatment of `AF_DiscountApprovalStatus__c`. Leave it writable only for the automation context and System Administrator. Then re-check any existing records for tier values inconsistent with their discount percentage.

**Reference**
BRD §10.7, p.44, FR2: *"…routing to the appropriate approver based on the delegation-of-authority matrix."* The stored tier is the mechanism by which that routing is decided, so it must not be editable by the requester.

---

## 8. The approver cannot see any discount figure on the quote they are approving (High)

**Affects:** Sales Manager / Showroom Manager (the approver personas). System Administrator is unaffected.

**Description**
The Sales Manager is the person the system routes discount approvals to — and they have no permission to see the discount. Not the amount, not the percentage, not the authority tier. Opening the Quote itself does not help, because the fields are hidden there too. They are asked to authorise a commercial concession whose size is invisible to them, and the only way to find out is to ask the salesperson.

**Steps to Reproduce**
1. Raise a discount approval on a Quote (set `AF_DiscountAmount__c` above the Tier 0 band as a Sales Representative) so it routes to the Sales Manager.
2. Log in as the **Sales Manager** persona.
3. Open the approval request — via the bell notification, or App Launcher → **Approvals** → **Approval Requests** → **Items to Approve**.
4. Read the fields shown on the approval request.
5. Click through to the Quote itself and look for **Discount Amount**, **Discount Percent** and **Discount Tier**.

**Expected Result**
The approver can see the discount amount, the derived percentage and the tier — the three facts the delegation-of-authority decision depends on — on the approval request, and certainly on the Quote.

**Actual Result**
The approval request shows only **Quote Name** and **Owner Name**. On the Quote record the three discount fields are **not visible at all**. Confirmed against `FieldPermissions`: across every permission set assigned to the Sales Manager user, the only discount-related Quote field readable is the unrelated standard `Quote.Discount`; `AF_DiscountAmount__c`, `AF_DiscountPercent__c`, `AF_DiscountTier__c` and `AF_DiscountApprovalStatus__c` are all absent.

**Root Cause**
Confirmed via `PermissionSetAssignment` and `FieldPermissions`. Read access to those four fields is granted by the permission set group `AF_PSG_Sales_Manager` — which is **assigned to no user in the org**. Only `AF_PSG_Sales_Rep` has been assigned to anyone. The permission set group is correctly built and shows status `Updated`; it was simply never granted to the Sales Manager user.

This is the same root cause as defect 9 in the ALF-RS-06 ticket list (the Sales Manager being unable to create any quotation, because `Opportunity.AF_VehicleModel__c` is likewise invisible). One assignment fixes both.

It also compounds a second, independent problem worth fixing at the same time: the approval process `AF_AP_Quote_DiscountTiers` **is** configured with the correct approval page fields (`Name`, `AF_DiscountAmount__c`, `AF_DiscountPercent__c`, `AF_DiscountTier__c`), but those render on the Classic approval page only — the Lightning `ProcessInstanceWorkitem` record page does not surface them. So even once the permission is granted, the figures still will not appear on the approval screen without the change described in defect 4.

**Proposed Solution**
1. Assign the `AF_PSG_Sales_Manager` permission set group to the Sales Manager user, and audit every other business persona for the same omission.
2. Separately apply defect 4's fix so the amount, percentage and tier actually render on the approval request and in the "Items to Approve" list — the permission grant alone is necessary but not sufficient.

**Reference**
BRD §10.7, p.45, AC3: *"Given an executive approver has multiple pending discount requests, When they open the approval view, Then all pending items are visible and bulk approval actions are available."* Visibility of the request without visibility of the discount does not meet the intent of a delegation-of-authority review. Also p.44, FR2: *"routing to the appropriate approver based on the delegation-of-authority matrix"* — an approver who cannot see the amount cannot apply the matrix.
