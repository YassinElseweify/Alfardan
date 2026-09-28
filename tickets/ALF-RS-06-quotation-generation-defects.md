# ALF-RS-06 — Quotation Generation in Multiple Modes: defects found in QA

**Module:** Retail Sales — Quotation Generation
**Status:** Open
**Found during:** QA testing of ALF-RS-06 in the QA sandbox, 2026-09-09
**Scope note:** Defects 2–7 reproduce for **all users, including System Administrator**. Defects **8 and 9 are persona-blocking permission gaps** — System Administrator is unaffected, but every business persona is blocked from part or all of the story. Each ticket states plainly which personas it affects.

> ⚠ **Correction, 2026-09-10:** defect 1 was raised in error and has been **retracted** — the Create Quotation action does exist and works. Defects 2–7 are unaffected and were each reproduced independently. See section 1 for what went wrong.

---

## 1. ~~The "Create Quotation" button does not exist anywhere in the application~~ — **RETRACTED, NOT A DEFECT**

**This ticket was raised in error and is withdrawn. There is nothing for a developer to do here.**

**What was originally claimed:** that the `AF_Create_Quotation` Quick Action existed but had never been added to the Opportunity, making the entire feature unreachable for every user.

**What is actually true:** the action **is** present and works. On an Opportunity in the **Automotive** app it appears under **Show more actions** → **Create Quotation**, and launching it opens the quotation flow normally.

**Why the error was made — worth recording so it is not repeated:**
1. The UI check was performed in the **Sales** app. Al-Fardan's users work in the **Automotive** app, which is assigned a different Lightning record page (`Opportunity_Record_Page` — the one with the sales Path, Test Drives and Trade Ins related lists).
2. That record page has **Dynamic Actions enabled** (`enableActionsConfiguration = true`), which means the page's own action list **completely replaces** the page layout's actions. The supporting evidence originally cited — that `Opportunity-Opportunity Layout` does not contain `AF_Create_Quotation` — was therefore the wrong artifact entirely. When Dynamic Actions are on, the layout's action list is simply not used.

**The one genuine, much narrower observation that remains:** the action carries a visibility rule limiting it to a single stage:
```
{!Record.StageName} EQUAL "Select"
```
Verified live — the action appears on an Opportunity at stage **Select** and is absent on the same Opportunity at stage **Negotiate**. This looks deliberate rather than accidental (the sibling `AF_Select_Vehicle` action is gated to `Consider` in exactly the same way, so the two form an intentional stage progression). It is raised as a question for the BA in the report rather than as a defect: if a quotation ever needs to be produced or re-produced after the deal has moved past *Select*, there is currently no way to launch the flow. Note the flow independently blocks a second quotation per Opportunity anyway, and the VIN "reissue" described in FR2 happens automatically without re-running it — so this may well be correct as designed.

---
## 2. The VIN is never added to a quotation when the vehicle is already in stock (Highest)

**Description**
When a car is physically in stock and has a chassis number (VIN), that VIN is supposed to appear on the quotation. It never does. Every quotation generated for an in-stock vehicle comes out with the VIN field empty, on both the Customer Quotation and the Bank Quotation. The only way a VIN ever reaches a quotation is the separate "vehicle arrives in stock later" path — if the car was already in stock when the quotation was created, the VIN is simply never written.

**Steps to Reproduce**
1. Pick a Vehicle with `AF_InventoryStatus__c = 'In Stock'` and a real `VehicleIdentificationNumber` (tested with VIN `ZFF95FLA000ROMA02`).
2. Create an Opportunity referencing it via `AF_SelectedVehicle__c`, with a Vehicle line item.
3. Launch the Create Quotation flow for that Opportunity and choose **Customer Quotation**.
4. Complete the flow to the "Quotation created" success screen.
5. Query the resulting record: `SELECT Id, AF_VINDisplay__c FROM Quote WHERE OpportunityId = '<id>'`.
6. Repeat steps 2–5 selecting **Bank Quotation** instead.

**Expected Result**
`Quote.AF_VINDisplay__c` is populated with the vehicle's VIN on both quotation types.

**Actual Result**
`AF_VINDisplay__c` is empty on both types. Reproduced on every in-stock Opportunity tested. Across the whole org, only one Quote of fifteen has a VIN, and that one acquired it through the later restock path, not at creation.

**Root Cause**
Confirmed via metadata retrieve of the flow and a search across all 72 `AF_` flows in the org. Two independent findings:
1. `AF_FL_Opp_CreateQuotation`'s `Create_Quote` element sets only four fields — `AF_QuoteType__c`, `Name`, `OpportunityId`, `Pricebook2Id`. It never writes `AF_VINDisplay__c`, and the flow contains no VIN-related element at all.
2. The flow's own description asserts that *"AF_FL_QuoteLineItem_SyncVINDisplay and AF_FL_Vehicle_SyncVINOnRestock handle VIN suppression/population/reissue automatically."* **`AF_FL_QuoteLineItem_SyncVINDisplay` does not exist in this org.** A `FlowDefinitionView` query and a text search of every retrieved flow both confirm `AF_FL_Vehicle_SyncVINOnRestock` is the only component in the org that ever writes `AF_VINDisplay__c`, and it fires only on a vehicle *changing into* In Stock.

So the VIN population half of the requirement was assumed to be handled by a flow that was never built.

**Proposed Solution**
Add VIN population to the quotation creation path itself. In `AF_FL_Opp_CreateQuotation`, after `Create_Quote`, evaluate the selected Vehicle's `AF_InventoryStatus__c`: if it equals `In Stock`, set `Quote.AF_VINDisplay__c` to that Vehicle's `VehicleIdentificationNumber`; otherwise leave it blank. Building the missing `AF_FL_QuoteLineItem_SyncVINDisplay` (record-triggered on QuoteLineItem when `AF_Vehicle__c` is set or changed) would also work and would match the design the description already assumes — but either way, one of them must actually exist. The flow description should be corrected at the same time, since it currently documents behaviour that is not implemented.

**Reference**
BRD §10.6, p.43, FR2: *"VIN inclusion on both types is conditional on vehicle stock status — VIN is populated when the vehicle is in stock, and suppressed on both types when the vehicle is non-stock, in transit, or on order."*

---

## 3. Internal cost lines are copied onto the customer's quotation and forcibly marked customer-facing (High)

**Description**
Internal-only charges — dealer preparation, registration, internal provider services — are copied straight onto the customer's quotation and added to the price the customer sees. Worse, lines that were explicitly marked "not customer facing" and "not included in quote" on the Opportunity have those two settings **overwritten to the opposite value** during the copy. Staff can flag a line as internal, and the system will silently un-flag it and show it to the customer anyway.

**Steps to Reproduce**
1. Create an Opportunity with a Vehicle line item.
2. Add an `OpportunityLineItem` with `AF_LineItemType__c = 'Internal Requisition'` (tested with Dealer Prep & Registration at 1,500), setting `AF_CustomerFacing__c = false` and `AF_IncludedInQuote__c = false`.
3. Add a second line with `AF_LineItemType__c = 'Provider Service'` (tested with Pre-Delivery Inspection at 350, `AF_ProviderSource__c = 'Alfardan Internal'`), also with both flags set to `false`.
4. Launch the Create Quotation flow and generate a Customer Quotation.
5. Query the result: `SELECT Product2.Name, UnitPrice, AF_LineItemType__c, AF_CustomerFacing__c, AF_IncludedInQuote__c FROM QuoteLineItem WHERE Quote.OpportunityId = '<id>'`.

**Expected Result**
Internal-only line types are excluded from a customer-facing quotation, and any line explicitly marked `AF_CustomerFacing__c = false` / `AF_IncludedInQuote__c = false` is not copied — or at minimum retains those flag values.

**Actual Result**
Both internal lines were copied onto the quotation, and **both flags were changed from `false` to `true`** on the copies. The quotation subtotal came to **249,158**, which includes 1,850 of internal cost (1,500 + 350) presented to the customer as part of the vehicle deal.

**Root Cause**
Confirmed via metadata retrieve of `AF_FL_Opp_CreateQuotation`. Two distinct problems in the same flow:
1. The `Get_Eligible_OpportunityLineItems` lookup filters on **`OpportunityId` only** — there is no line-type filter of any kind. Despite the flow's description claiming an eligible set of "Vehicle/Accessory/Package/Tint/Customization", nothing in the query or anywhere downstream restricts which line types are copied. Every line on the Opportunity is copied.
2. The `Add_Line_To_Collection` assignment hard-codes `NewQuoteLine.AF_CustomerFacing__c = true` and `NewQuoteLine.AF_IncludedInQuote__c = true` as literal boolean values, rather than carrying the source line's values across. This is why the `false` flags are lost.

**Proposed Solution**
Two changes in `AF_FL_Opp_CreateQuotation`:
1. Add filter conditions to `Get_Eligible_OpportunityLineItems` restricting `AF_LineItemType__c` to the documented eligible set (Vehicle, Accessory, Package, Tint, Customization), and additionally exclude any line with `AF_IncludedInQuote__c = false`.
2. In `Add_Line_To_Collection`, assign `AF_CustomerFacing__c` and `AF_IncludedInQuote__c` from `Loop_Eligible_Lines` (the source record) instead of hard-coded `true`, matching how the other fields are already copied.

**Reference**
BRD §10.6, p.43, FR3: *"The quotation supports additional line items for accessories, packages, tint, and upsell elements."* — internal requisition and provider-cost lines are not among the customer-facing categories listed. Also p.43, FR5: *"present the quotation to the customer for review before proceeding to payment"* — the document presented must not expose internal cost lines.

---

## 4. A quotation keeps showing a VIN after that car is no longer available (High)

**Description**
Once a chassis number appears on a quotation, it stays there permanently — even if the car is subsequently sold to someone else or otherwise leaves stock. The customer is left holding a quotation for a specific physical car that is no longer available to them, and nothing in the system corrects or withdraws it.

**Steps to Reproduce**
1. Take a Quote whose `AF_VINDisplay__c` is populated (reachable by creating a quotation while its vehicle is In Transit, then moving that Vehicle to `In Stock`, which populates the VIN — tested VIN `ZFF95FLA000ROMA03`).
2. Confirm the VIN is showing: `SELECT AF_VINDisplay__c FROM Quote WHERE Id = '<id>'`.
3. Change the linked Vehicle's `AF_InventoryStatus__c` from `In Stock` to `Ordered` (simulating the unit being sold to another customer).
4. Re-query the Quote's `AF_VINDisplay__c`.

**Expected Result**
The VIN is cleared from the quotation, because the requirement states the VIN is suppressed whenever the vehicle is non-stock, in transit, or on order.

**Actual Result**
The VIN `ZFF95FLA000ROMA03` remains on the quotation, while the vehicle's status reads `Ordered`. Nothing clears it. Reproduced deterministically.

**Root Cause**
Confirmed via metadata retrieve. `AF_FL_Vehicle_SyncVINOnRestock` — the only automation that touches `AF_VINDisplay__c` — has the entry condition `ISCHANGED({!$Record.AF_InventoryStatus__c}) && ISPICKVAL({!$Record.AF_InventoryStatus__c}, "In Stock")`. It fires **only** on the transition *into* In Stock and contains no branch that clears the field on any other transition. The requirement is written as a state rule ("VIN is suppressed *when* the vehicle is non-stock"), but the implementation is a one-way transition trigger.

**Proposed Solution**
Broaden the flow's entry criteria to `ISCHANGED({!$Record.AF_InventoryStatus__c})` alone, then branch inside: if the new status is `In Stock`, set `AF_VINDisplay__c` to the vehicle's VIN on all related Quotes (existing behaviour); for any other status, set `AF_VINDisplay__c` to blank on those same Quotes. This makes the automation enforce the state rule in both directions.

**Reference**
BRD §10.6, p.43, FR2: *"…the VIN field is suppressed on both quotation types when the vehicle is non-stock, in transit, or on order."* The wording describes a condition of the vehicle, not a one-time event.

---

## 5. A trade-in the customer declined still reduces the price on their quotation (High)

**Description**
When a customer's trade-in is accepted, its value is deducted from the quotation. If the customer later **declines** the trade-in, that deduction is not removed — the quotation keeps giving them the discount for a trade-in that is not happening. Only the separate "Withdrawn" outcome removes the deduction; "Declined" does not, even though both mean the trade-in is off.

**Steps to Reproduce**
1. Set up an Opportunity with a Quote and an Appraisal at `AF_ApprovalStatus__c = 'Approved'`, `AF_TradeInOutcome__c = 'Accepted'`, with a non-zero `FinalAppraisalValue` (tested at 22,000).
2. Confirm the Quote carries a `Trade-In Deduction` line at the negative value and the Subtotal is reduced (tested: 247,308 → 225,308).
3. Update the Appraisal to `AF_TradeInOutcome__c = 'Declined'`, supplying `AF_FinalRemarks__c` (a validation rule correctly requires it).
4. Re-query the Quote's line items and Subtotal.
5. For comparison, repeat the whole sequence but set `AF_TradeInOutcome__c = 'Withdrawn'` at step 3.

**Expected Result**
A declined trade-in has its deduction removed and the quotation total restored, exactly as happens for a withdrawn trade-in.

**Actual Result**
With the outcome set to `Declined`, the `-22,000` Trade-In Deduction line **remains** on the quotation and the Subtotal stays at **225,308** instead of returning to 247,308. The Appraisal reads `AF_ApprovalStatus__c = Approved, AF_TradeInOutcome__c = Declined` while the customer keeps a 22,000 credit. The `Withdrawn` path by contrast works correctly — the line is deleted, the total returns to 247,308, and an audit Task plus `AF_WithdrawnBy__c`/`AF_WithdrawnDate__c` are stamped. Setting the outcome to `In Progress` likewise leaves the deduction in place.

**Root Cause**
Confirmed via metadata retrieve. `AF_FL_Appraisal_TradeInWithdrawn` is gated on `ISCHANGED({!$Record.AF_TradeInOutcome__c}) && ISPICKVAL({!$Record.AF_TradeInOutcome__c}, "Withdrawn")`. No automation in the org reacts to the outcome moving to `Declined` or back to `In Progress`, so the deduction line created earlier is simply orphaned in place.

**Proposed Solution**
Change the removal trigger from "outcome equals Withdrawn" to "outcome is no longer Accepted". Concretely, alter the entry condition to `ISCHANGED(AF_TradeInOutcome__c) && NOT(ISPICKVAL(AF_TradeInOutcome__c, "Accepted"))`, so `Declined`, `Withdrawn` and a reversion to `In Progress` all remove the deduction and restore the total. Keep the existing audit-stamping behaviour, recording the actual outcome value rather than assuming "Withdrawn".

**Reference**
BRD §10.6, p.43, FR4: *"The quotation reflects approved trade-in values as a negative line item / deduction."* — a declined trade-in is not an approved deduction. Also p.44, AC3: *"the trade-in deduction appears as a line item reducing the total deal value"* — the total deal value must remain correct when the trade-in ceases to apply.

---

## 6. Quotations with a trade-in fail completely for any customer not on the Standard price book (High)

**Description**
If an Opportunity uses any price book other than the Standard one, and the customer has an approved trade-in, generating the quotation fails outright with an error screen and **no quotation is created at all**. The cause is that the "Trade-In Deduction" product has only been priced on the Standard price book, so the system cannot find a price for it anywhere else.

**Steps to Reproduce**
1. Create an Opportunity on a non-standard price book (tested with "Dream Cars and EV", `01sa3000re0jGZYAA2`), including a vehicle line priced on that book.
2. Attach an Appraisal with `AF_ApprovalStatus__c = 'Approved'` and `AF_TradeInOutcome__c = 'Accepted'` and a non-zero `FinalAppraisalValue`.
3. Run the Create Quotation flow for that Opportunity.
4. Alternatively reproduce the underlying lookup directly: `SELECT Id FROM PricebookEntry WHERE Product2.ProductCode = 'AF-TRADEIN-DEDUCT' AND Pricebook2Id = '<non-standard book>' AND IsActive = true`.

**Expected Result**
The quotation generates successfully, with the trade-in deduction priced against the Opportunity's own price book.

**Actual Result**
The lookup returns **0 rows**, and creating the deduction line then fails with:
`Insert failed. First exception on row 0; first error: REQUIRED_FIELD_MISSING, Required fields are missing: [PricebookEntryId]: [PricebookEntryId]`
The flow raises an unhandled fault and the entire quotation is rolled back — no Quote, and no line items.

**Root Cause**
Confirmed by querying the product's price book coverage. The flow logic is correct and org-portable: `Get_TradeIn_Product` resolves the product by `ProductCode = 'AF-TRADEIN-DEDUCT'` and `Get_TradeIn_PricebookEntry` looks up its active entry on the Opportunity's own `Pricebook2Id`. The **data** is the problem — product `AF-TRADEIN-DEDUCT` has exactly one active `PricebookEntry`, on the Standard Price Book, and none on any of the org's thirteen other active price books. When the lookup finds nothing, the flow passes a null `PricebookEntryId` into the record create, which is a required field.

**Proposed Solution**
Two parts, both worth doing:
1. **Data:** add an active `PricebookEntry` for `AF-TRADEIN-DEDUCT` (price 0, as on Standard) to every price book that retail Opportunities can use, and make this part of the standard setup whenever a new price book is introduced.
2. **Resilience:** add a fault path to `Get_TradeIn_PricebookEntry` in both `AF_FL_Opp_CreateQuotation` and `AF_FL_Appraisal_RetroAddTradeInToQuote` so that a missing entry produces a clear, specific message (e.g. "The trade-in deduction product is not priced on this Opportunity's price book — contact your administrator") instead of an unhandled fault that discards the entire quotation.

**Reference**
BRD §10.6, p.43, FR4: *"The quotation reflects approved trade-in values as a negative line item / deduction."* Also p.44, AC3: *"Given an approved trade-in value exists, When the quotation is generated, Then the trade-in deduction appears as a line item reducing the total deal value."*

---

## 7. The "only one quotation per Opportunity" rule is not actually enforced (Medium)

**Description**
The system is designed to allow only one quotation per Opportunity, and the on-screen flow does block a second attempt with a clear message. However, the rule exists only in that screen. Anything that creates a quotation another way — an integration, a data load, an automation, or a developer script — can add as many additional quotations to the same Opportunity as it likes, with no check at all.

**Steps to Reproduce**
1. Generate a quotation for an Opportunity through the Create Quotation flow, so one Quote exists.
2. Re-launch the flow on the same Opportunity and confirm it blocks (expected behaviour).
3. Now insert a second Quote directly against the same Opportunity via the API, as an ordinary business user (tested as Sales Representative):
   `INSERT Quote (Name='dup', OpportunityId='<same id>', Pricebook2Id='<same>', AF_QuoteType__c='Customer Quotation')`
4. Query the Opportunity's quotations: `SELECT Id, Name FROM Quote WHERE OpportunityId = '<same id>'`.

**Expected Result**
The one-quotation-per-Opportunity constraint holds regardless of how the record is created.

**Actual Result**
The second insert **succeeded**, leaving two live Quotes on the same Opportunity. Performed as the Sales Representative persona, so this is not an administrator-only bypass.

**Root Cause**
Confirmed via metadata query. The constraint is implemented solely as the `Get_Existing_Quote` / `Quote_Already_Exists` decision inside `AF_FL_Opp_CreateQuotation`, which is a screen flow. The `Quote` object has **zero validation rules** and no `before insert` automation enforcing uniqueness, so nothing evaluates the rule outside that one screen.

**Proposed Solution**
Enforce the rule at the data layer so every entry point is covered. The simplest robust option is a record-triggered before-save flow (or Apex trigger) on `Quote` that, on insert, counts existing Quotes for the same `OpportunityId` and raises a clear error if one already exists — mirroring the wording the screen flow already uses. Note a plain validation rule cannot do this alone, since it cannot query sibling records; a roll-up or trigger-based approach is required. If duplicate quotations should in fact be permitted for some scenario (for example superseded revisions), confirm that with the BA first, as the current screen message states the opposite.

**Reference**
BRD §10.6, p.43, FR1: *"The system supports two quotation types: Customer Quotation and Bank Quotation, both generated from Salesforce."* The one-per-Opportunity constraint itself is documented in `AF_FL_Opp_CreateQuotation`'s own description — *"only one quotation per Opportunity - use the existing one to review/reissue"* — and is surfaced to users in the flow's block message, so it is intended behaviour that is currently unenforced.

---

## 8. A salesperson cannot produce a quotation for any customer with an approved trade-in (Highest)

**Description**
This is the single most damaging defect in the story. If a customer is trading their old car in and that trade-in has been approved and accepted, the salesperson simply cannot produce a quotation for them. Clicking **Create Quotation** returns *"An unhandled fault has occurred in this flow"* and **nothing at all is saved** — no quotation, no line items. The salesperson is left with an error message and no way forward, on exactly the kind of deal the business most wants to close. The only account in the org that can complete this action is the single System Administrator, who is not a person who sells cars.

**Steps to Reproduce**
1. Log in as the **Sales Representative** persona (or any business persona — Sales Manager, Showroom Manager all behave the same).
2. Switch to the **Automotive** app.
3. Open an Opportunity at stage **Select** that has a vehicle selected and an `Appraisal` with `AF_ApprovalStatus__c = 'Approved'` **and** `AF_TradeInOutcome__c = 'Accepted'` and a non-zero `FinalAppraisalValue`. Ready-made record: **DEMO RS06 06** (`006FV00AqZ0QcOiYUK`), trade-in `APL-000000071` worth 60,000.
4. Click **Show more actions → Create Quotation**, choose **Customer Quotation**, click **Next**.
5. Check the Opportunity's **Quotes** related list afterwards.

**Expected Result**
The quotation generates, containing the vehicle line plus a negative Trade-In Deduction line for the approved value, with the total reduced accordingly.

**Actual Result**
The flow stops on *"An unhandled fault has occurred in this flow. An unhandled fault has occurred while processing the flow. Please contact your system administrator for more information."* The Quotes related list stays **empty** — the entire transaction is rolled back, including the Quote header and the line items that had already been written. Reproduced repeatedly as the Sales Representative persona, and independently by the client in their own session.

**Root Cause**
Confirmed from the Sales Representative's own debug log. The failing element is `Get_TradeIn_Product` in `AF_FL_Opp_CreateQuotation`:
```
FLOW_ELEMENT_ERROR | This error occurred when the flow tried to look up records:
SELECT Id, ProductCode FROM Product2 WHERE ...
ERROR at Row:1:Column:12
No such column 'ProductCode' on entity 'Product2'.
| FlowRecordLookup | Get_TradeIn_Product
```
The flow resolves the trade-in deduction product with a filter on `Product2.ProductCode`, and it has **no `runInMode` setting**, so as a screen flow it executes **in the running user's context**. Read access to `Product2.ProductCode` is granted by only two permission sets in the org — `AF_PS_Product2_FullAccess`, which is **assigned to nobody**, and `AF_System_Admin`, which is assigned **only** to `arcsen@alfardan.com.qa`. For every business persona the field is invisible, the SOQL is therefore invalid, the element throws, and because it is not the terminal element the whole flow faults and Salesforce rolls the transaction back.

The failure is silent about its real cause: nothing in the message tells the rep, or an admin reading over their shoulder, that a field-level permission is at fault.

**Proposed Solution**
Any one of these fixes it; the first is the smallest and safest:
1. **Grant the field.** Add `Product2.ProductCode` read access to `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager` and `AF_PSG_Showroom_Manager` — or simply assign the existing, currently-unassigned `AF_PS_Product2_FullAccess` permission set to the business personas. Reading a product code is not sensitive.
2. **Remove the dependency on user context** by setting the flow to run in system context without sharing for that lookup, so product configuration data does not need to be exposed to every seller. Note this must be applied to `AF_FL_Appraisal_RetroAddTradeInToQuote` as well, which performs the identical lookup and will fail the same way when a rep records a trade-in outcome after the quote exists.
3. **Add a fault path** on `Get_TradeIn_Product` (and `Get_TradeIn_PricebookEntry`) regardless of which fix is chosen, so that a future configuration problem produces a specific, actionable message instead of discarding a quotation the rep has already built.

Whichever is chosen, fix 3 should be done in addition, because the current behaviour destroys work silently.

**Reference**
BRD §10.6, p.43, FR4: *"The quotation reflects approved trade-in values as a negative line item / deduction."* And p.44, AC3: *"Given an approved trade-in value exists, When the quotation is generated, Then the trade-in deduction appears as a line item reducing the total deal value."* The story's Related Personas name the **Sales Representative** as the user who generates quotations — the persona for whom this is currently impossible.

---

## 9. The Sales Manager cannot create any quotation at all (High)

**Description**
Separate from defect 8, and easy to miss because it looks identical from the outside. The Sales Manager cannot generate a quotation for **any** customer — not just trade-in deals. The flow fails immediately, before even asking which quotation type is wanted. The cause is that this user was never given the permission set group built for their role.

**Steps to Reproduce**
1. Log in as the **Sales Manager** persona (`mpapa_sales…@alfardan.com.qa.qa`).
2. Switch to the **Automotive** app and open any Opportunity at stage **Select** that has a vehicle selected — no trade-in required.
3. Click **Show more actions → Create Quotation**.

**Expected Result**
The Quote Type selection screen appears and a quotation can be generated, as it can for the Sales Representative.

**Actual Result**
The flow fails instantly with *"An unhandled fault has occurred in this flow"* — the type-selection screen never renders. No quotation is created.

**Root Cause**
Confirmed from the Sales Manager's own debug log. The flow dies on its very first element, `Get_Opportunity`:
```
FLOW_ELEMENT_ERROR | This error occurred when the flow tried to look up records:
SELECT Id, Name, AF_VehicleModel__c, Pricebook2Id ...
No such column 'AF_VehicleModel__c' on entity 'Opportunity'.
| FlowRecordLookup | Get_Opportunity
```
`Opportunity.AF_VehicleModel__c` read access is granted by the permission set group `AF_PSG_Sales_Manager` — which is **assigned to no user in the org**. A check of `PermissionSetAssignment` shows only `AF_PSG_Sales_Rep` has been assigned to anyone (Sales Representative and Sales Receptionist). The permission set group itself is correctly built and shows status `Updated`; it was simply never granted to the Sales Manager user. Because the flow runs in user context, the field is invisible, the query is invalid, and the flow faults on its first step.

**Proposed Solution**
Assign the `AF_PSG_Sales_Manager` permission set group to the Sales Manager user. Then audit the other business personas the same way — confirm every operational user holds the permission set group built for their role, since the same omission would silently break any user-context flow that reads a custom field. This is a provisioning fix, not a code change.

Worth noting alongside defect 8: this same gap also means the Sales Manager cannot see `AF_DiscountAmount__c`, `AF_DiscountPercent__c` or `AF_DiscountTier__c` on a Quote, which is why they are asked to approve discounts they cannot see in ALF-RS-07.

**Reference**
BRD §10.6, p.43 — the story's Related Personas are *Sales Representative, System*; the Sales Manager is named throughout ALF-RS-07 as the approver and is a business user who would reasonably need to raise or review a quotation. BRD §10.6, p.43, FR1: *"both generated from Salesforce."*
