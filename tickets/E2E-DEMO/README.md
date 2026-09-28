# End-to-end retail demo — walk-in to Closed Won — bug tickets

**Found during:** full retail cycle run, 2026-09-26 (mock demo rehearsal)
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/E2E-DEMO-walkin-to-closed-won-report.md`
**Screenshots:** `screenshots/E2E-DEMO/`
**Status:** Filed in Jira 2026-09-26 as LFRDN-752 … LFRDN-756 (Bug, parent LFRDN-317, assignee Yassin).

> **Reproducible in the Lightning UI.**
> - Sales Receptionist: `salesreceptionist.v2.20260823@alfardan.com.qa.qa` / `Arcsen@2030!`
> - Sales Representative: `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!`
> - Approvers, all `Arcsen@2026!`: `alfardan.qa.salesbrandmanager2@…`, `alfardan.qa.generalmanager2@…`, `alfardan.qa.ceo2@…`
> - Used Car Team: `alfardan.qa.usedcarteam2@…`
> - Showroom Manager: `alfardan.qa.showroommanager2@…`
>
> Login is two-step (username, then password). Dismiss *Change Your Password* with **Cancel**.

When approved, each would be raised in **LFRDN** as a Bug, assigned to **Yassin**, parent **LFRDN-317**,
with labels `QA` / `Retail-Sales` plus the story label. Each is linked *relates to* its story subtask:
walk-ins → ALF-RS-01, handover close → ALF-RS-11/12, discount → ALF-RS-07, trade-in → ALF-RS-04.

## Summary

A complete retail sale can be taken from walk-in to **Closed Won**: C1, C2 and C3 all closed. Each of
the problems below either breaks a demo on screen or leaves the numbers wrong.

**The first click of the demo fails.**
- **Sales Walk-In** shows the receptionist an error every time, although it creates the deal
  (BUG-E2E-01).
- **Service Walk-In** fails outright and creates nothing (BUG-E2E-02).

**Reservation is blocked for the rep.** Create Reservation fails for every deal: without a trade-in,
and even with an approved trade-in. This is already tracked as **LFRDN-695**; new root-cause
evidence is below.

**Other problems:**
- A deal whose payment is missing its Bank LPO completes the handover but **silently stays open**.
  The rep then cannot close it at all without an unobvious workaround (BUG-E2E-03).
- An approved discount on a quote with a trade-in is applied at a **higher percentage than
  approved**: AED 24,216.64 off instead of 16,000 (BUG-E2E-04).
- The trade-in approval marks the trade-in *Accepted* by itself, while the field that actually puts
  the deduction on the quote stays blank until the rep finds and sets it (BUG-E2E-05).

| ID | Jira | Title | Priority | Affects |
|---|---|---|---|---|
| BUG-E2E-01 | LFRDN-752 | Sales Walk-In shows the receptionist an error on every use, and the rep's task is not linked to the deal | Highest | Sales Receptionist (every Sales Walk-In) |
| BUG-E2E-02 | LFRDN-753 | Service Walk-In fails with an unhandled fault and creates no Opportunity | Highest | Any receptionist; only an administrator could succeed |
| BUG-E2E-03 | LFRDN-754 | A completed handover silently leaves the deal open when a payment document is missing, and the rep then cannot close it | High | Sales Representative |
| BUG-E2E-04 | LFRDN-755 | An approved discount is over-applied when the quote has a trade-in | High | General — every discounted quote with a trade-in deduction |
| BUG-E2E-05 | LFRDN-756 | Trade-in approval marks the trade-in "Accepted" without the customer, but the deduction only reaches the quote once the rep separately accepts the vehicle line | Medium | Sales Representative |

### Already tracked — new evidence, no new ticket

| Jira | What we saw today | New evidence to add as a comment |
|---|---|---|
| **LFRDN-695** (To Do) | **Create Reservation fails for the rep** on all three deals: C1 (no trade-in), C2 (approved and accepted trade-in) and C3 (3-Day). The 7-Day path never shows a deposit field. | **Probable root cause.** The *"Trade-In Used As Deposit?"* checkbox is only visible when `Get_Active_Appraisal.Status = 'Completed'`. The trade-in lifecycle never reaches *Completed* (an approved, accepted trade-in stays *Under Approval*), so the checkbox is always hidden and passes **null**. The cash *Deposit Amount* field only shows when that checkbox is **false**, so it never appears. `Create_Reservation` writes the null into `AF_TradeInAsDeposit__c`. Replaying the flow's exact field set as the rep through the API returns *"Trade-In Used As Deposit?: value not of required type"* (`INVALID_TYPE_ON_FIELD_IN_RECORD`), and the same insert with `false` succeeds. **Fix:** default the checkbox to `false` (or wrap it in `IF(ISBLANK(...), false, ...)`), show *Deposit Amount* when the checkbox is not true, and fix the visibility rule to use the real trade-in state. |
| LFRDN-678 (deferred) | The Generate Sales Order confirmation and the Sales Order PDF show **QAR**; every other screen shows AED. | — |
| LFRDN-708 | The Vehicle Repair Disclaimer is **duplicated** once repair remarks are entered after the documents were generated (HO-00067). | — |

---

## BUG-E2E-01 (LFRDN-752) — Sales Walk-In shows the receptionist an error on every use, and the rep's task is not linked to the deal (Highest)

**Module:** Retail Sales — Opportunity intake (Sales Walk-In)
**Applies to:** Sales Receptionist, on every Sales Walk-In. Reproduced 4 of 4 times (C1, C2, C3, C5).
A System Administrator would not see it, because they can read every Opportunity.

### Description

The receptionist opens the customer's Contact, runs **Sales Walk-In**, picks the brand, showroom and
source, and assigns a Sales Representative. The last screen says *"Something went wrong"*. The deal
has in fact been created and assigned to the rep, but:
- the receptionist is told it failed, and the message says *"Please try again"*, which invites a
  duplicate deal;
- the rep receives no notification;
- the rep's *"New Showroom Walk-In Opportunity Assigned"* task is created **without a link to the
  deal**.

### Steps to Reproduce

1. Log in as the Sales Receptionist → Contact **Faisal Al-Thani** (`003FV00LdSwVAnQYUW`, account
   *E2E C1 Customer - Faisal Al-Thani*).
2. **Show more actions ▾ → Sales Walk-In** → Brand **Ferrari**, Showroom **Lusail**, Source of
   Business **Showroom Walk-in** → **Next**.
3. Assign to Sales Representative **QA SalesRep2** → **Next**.
4. As admin, read back the deal and task:
   `SELECT Id, Owner.Name FROM Opportunity WHERE AccountId = '001FV00LWpolWCiYMM'` and
   `SELECT Subject, WhatId FROM Task WHERE CreatedBy.Username LIKE 'salesreceptionist%' AND CreatedDate = TODAY`.

### Expected Result

The confirmation screen shows *"The Opportunity has been created under this Account and assigned to
the selected Sales Representative."* The rep gets the real-time notification, and a task that links to
the deal.

### Actual Result

> Something went wrong — We couldn't complete this action. Please try again, or contact your administrator if the problem continues. You can't send a custom notification without a navigation target. Specify either a Target ID or Target Page Reference on the Send Custom Notification action.

- The Opportunity `006FV00BzGl6wCKYUY` exists, owned by QA SalesRep2, stage *Consider*.
- The task `00TFV00GBPF2eKq22J` has `WhatId = null`.
- No custom notification was sent.
- The same happened for C2 (`006FV00Bzwt3cmKYEQ`), C3 (`006FV00BzvT99XQYEZ`) and C5
  (`006FV00BzRzy6HUYUY`).

### Root Cause

**Confirmed from the flow metadata and sharing.**
- `AF_FL_Opp_SalesWalkIn` runs in the receptionist's context (no `runInMode`). It creates the
  Opportunity with `OwnerId` = the chosen rep, then **re-reads** it in `Get_New_Opportunity`.
- Opportunity sharing is **Private**, and the receptionist has no access to a deal owned by the rep
  (`UserRecordAccess.HasReadAccess = false`). The lookup therefore returns nothing.
- As a result, `Create_Notification_Task` writes `WhatId = null` and `Send_Notification` fails on
  `targetId = null`.

### Proposed Solution

Use the Id returned by `Create_Opportunity` (`{!opportunity.Id}`) for the task's `WhatId` and the
notification's `targetId`, instead of re-querying the record. Alternatively, run the flow in system
context (`SystemModeWithoutSharing`) for these steps. Also stop the error screen from telling the
user to *"try again"* after the record was already created.

### Reference

- **BRD** §10.1 ALF-RS-01, p.30, FR4 — *"The system should allow a Sales Receptionist to create an Opportunity under a customer Account for walk-in showroom customers and assign it directly to a selected Sales Representative, triggering a system notification upon assignment."*

**Screenshots:** `03-sales-walkin-screen.png`, `04-assign-rep.png`, `05-walkin-created.png`

---

## BUG-E2E-02 (LFRDN-753) — Service Walk-In fails with an unhandled fault and creates no Opportunity (Highest)

**Module:** Retail Sales — Opportunity intake (Service Walk-In)
**Applies to:** Any receptionist holding the Service Walk-In permission. Reproduced twice with the
Sales Receptionist, after temporarily giving it `AF_PSG_Receptionist_Service` (removed afterwards).
No Service Receptionist user exists in QA.

### Description

A service customer shows interest in a new car. The receptionist runs **Service Walk-In** on their
Contact and chooses the brand and dealership. The flow should create the deal and give it to that
dealership's Showroom Manager. Instead it stops with a generic "unhandled fault" screen, and **no
deal is created**.

### Steps to Reproduce

1. Log in as a receptionist with `AF_PSG_Receptionist_Service`.
2. Open Contact **Hessa Al-Mannai** (`003FV00LdSwhlEWYUY`) → **Show more actions ▾ → Service
   Walk-In** → Brand of Interest **Ferrari**, Preferred Dealership **Alsadd**, Source **Showroom
   Walk-in** → **Next**.

### Expected Result

An Opportunity is created with owner = the Showroom Manager of Alsadd (QA ShowroomManager2), and a
*"Contact Customer Within 15 Minutes"* task is assigned to that manager.

### Actual Result

> An unhandled fault has occurred in this flow — An unhandled fault has occurred while processing the flow. Please contact your system administrator for more information.

No Opportunity is created for the account. The debug log (`07LFV00EL9hxd1w2MA`) shows:

> FLOW_ELEMENT_ERROR | This error occurred when the flow tried to create records: INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY: insufficient access rights on cross-reference id: 006FV00BzxXfABg | FlowRecordCreate | Create_Opportunity

### Root Cause

**Partly confirmed.**
- `Create_Opportunity` fails as shown in the log. The cross-reference Id is the new Opportunity
  itself. The flow creates it with `OwnerId` = the Showroom Manager **and** `ContactId` = the
  customer, in the receptionist's own context.
- The probable mechanism: setting `ContactId` makes Salesforce create the primary Opportunity Contact
  Role inside the same save. Under **Private** Opportunity sharing, the receptionist no longer has
  access to the record they are handing to someone else.
- `Create_Opportunity` has **no fault connector**, which is why the generic screen appears.
- Even if the create succeeded, `Get_New_Opportunity` would hit BUG-E2E-01's problem.

### Proposed Solution

Run `AF_FL_Opp_ServiceWalkIn`, or at least its create, task and notification steps, in system
context. Use `{!opportunity.Id}` rather than re-reading the record, and add a fault path to
`Create_Opportunity`.

### Reference

- **BRD** §10.1 ALF-RS-01, p.30–31, FR5 — *"The system should allow a Service Receptionist to create an Opportunity for a service walk-in customer expressing sales interest, capturing the customer's preferred dealership, and assigning the Opportunity to the Showroom Manager of that dealership. The system should automatically create a task for the Showroom Manager with a 15-minute contact window upon Opportunity assignment."*

**Screenshots:** `51-C4-service-walkin.png`, `52-C4-service-walkin-result.png`, `50-service-walkin-not-enabled.png`

---

## BUG-E2E-03 (LFRDN-754) — A completed handover silently leaves the deal open when a payment document is missing, and the rep then cannot close it (High)

**Module:** Retail Sales — Handover / Deal completion
**Applies to:** Sales Representative. Hit on C1, where the Get Payment pull recorded a *Bank Transfer*
and no Bank LPO had yet been uploaded on the Payment.

### Description

The rep completes the handover: documents, Traffic and Insurance forms, customer sign-off. The
handover turns **Completed** and the Sales Order turns **Delivered**, but the deal **stays at Take
the Keys**. Nothing tells the rep why: the Payment was still missing its Bank LPO.

After uploading the LPO, the rep tries to close the deal manually and is refused, because
*Delivery Confirmation* is only set by the automatic close that already declined to run. The only way
out is to edit and re-save the Completed handover. No rep would know that.

### Steps to Reproduce

1. **E2E C1** (`006FV00BzGl6wCKYUY`): payment **PAY-00093** is a Bank Transfer from Get Payment,
   with no Bank LPO uploaded.
2. On Handover **HO-00067**, set the date and location, run **Generate Documents**, upload the
   Traffic and Insurance forms, then **Edit** → *Customer Sign-Off* **Physically Signed** → **Save**.
3. Open the Opportunity.
4. Upload the Bank LPO on PAY-00093 (**Related** → *Required Documents*). Then, on the Opportunity,
   **Path → Mark Stage as Complete → Closed Won → Save**.
5. Edit the handover (change anything) → **Save**.

### Expected Result

Either the handover cannot be completed until the payment documents are in place, with a message
naming what is missing, or the deal closes as soon as the last condition is met, whichever order the
rep works in.

### Actual Result

- **Step 3:** handover *Completed*, Sales Order *Delivered*, but the stage is *Take the Keys* and
  *Delivery Confirmation* is false. No message is shown anywhere.
- **Step 4:** before the LPO, *"Closed Won requires the correct typed document per Payment
  (ALF-RS-11 FR3/FR4/FR5): … Bank Transfer needs Bank LPO …"*. After the LPO, *"Closed Won requires
  Handover Complete, Delivery Confirmation, full payment (Invoice Balance = 0), the Traffic Form
  (registration) uploaded, and Customer Sign-Off (signed delivery note) on the linked Handover."*
- **Step 5:** the deal closes **Won** at once.
- C2 and C3, where the LPO was uploaded before the handover, closed Won automatically on sign-off.

### Root Cause

**Confirmed from the flow and Apex.**
- `AF_FL_Handover_AutoCloseWon` calls `AF_Opportunity_ClosedWonPaymentGate`. The gate returned
  *"Not every Payment has its required documents (Cheque Copy / Bank LPO / Signed NOC) uploaded"*.
  The flow has no branch for a refusal, so it ends silently.
- `AF_DeliveryConfirmation__c` is set **only** by `Set_Closed_Won` in that flow, and
  `AF_VR_Opp_ClosedWonGate` requires it. The manual close therefore cannot succeed once the
  auto-close has been skipped.
- The auto-close re-runs only when the handover is saved again.

### Proposed Solution

1. When the gate refuses, post the gate's message to the rep (Opportunity feed or a custom
   notification).
2. Set `AF_DeliveryConfirmation__c` from the handover itself (Completed and signed), independent of
   the payment gate. The manual close then works once the remaining conditions are met.
3. Re-run the close check when a Payment document is uploaded.
4. Warn at Get Payment that a Bank Transfer needs a Bank LPO before closing.

### Reference

- **BRD** §10.11 ALF-RS-11, p.54, AC2 — *"Given all completion conditions are met, When the Sales Representative sets the opportunity to Closed Won, Then the stage is accepted and the Closed Won date is stamped."*
- **BRD** §10.11 ALF-RS-11, p.54, AC1 — *"… Then the system blocks the action and prompts for completion of outstanding conditions."*

**Screenshots:** `43-C1-signoff.png`, `46-C1-closed-won.png`, `48-C1-closed-won.png`, `47-C1-bank-lpo.png`

---

## BUG-E2E-04 (LFRDN-755) — An approved discount is over-applied when the quote has a trade-in (High)

**Module:** Retail Sales — Discount approval (quotation)
**Applies to:** General. Every quote with a Trade-In Deduction line and a Discount Amount.

### Description

The rep asks for **AED 16,000** off. The approvers approve AED 16,000, but the customer receives
**AED 24,216.64** off, which is 51% more than was approved. The trade-in also makes the discount look
bigger when it is assessed, so it goes to a more senior approver than it should.

### Steps to Reproduce

1. **E2E C2** (`006FV00Bzwt3cmKYEQ`): Quote **00000243** (`0Q0FV004bL0wB1I0QU`) has the Ferrari
   296 GTB at 369,300, the GTS Package at 29,000 and a Trade-In Deduction of −135,000. Subtotal
   263,300.
2. As the rep, Quote → **Edit** → *Discount Amount* **16,000** → **Save**.
3. Approve at every step of the chain.
4. Read the quote and its lines.

### Expected Result

The discount is assessed against the car's price (16,000 / 398,300 ≈ 4.0%, Tier 2), and the approved
AED 16,000 comes off: Grand Total **247,300**.

### Actual Result

- **Step 2:** *Discount %* **6.08**, *Discount Tier* **3** (16,000 / 263,300).
- **Step 4:** each positive line has *Discount* **6.08%**:
  - 296 GTB 369,300 → 346,846.56
  - GTS 29,000 → 27,236.80
  - Trade-In −135,000, unchanged
- Grand Total **239,083.36**, so the discount applied is 24,216.64.
- The invoice (INVM-00126) and payment (PAY-00094) were raised for **239,083.36**.

### Root Cause

**Confirmed from the flow metadata.**
- `AF_FL_Quote_SetDiscountApprovalStatus` computes
  `Var_DiscountPercent = AF_DiscountAmount__c / Quote.Subtotal × 100`. The Subtotal **includes the
  negative Trade-In Deduction line**.
- `AF_FL_Quote_DiscountApproved` then writes that percentage onto `Discount` of every line **except**
  the Trade-In Deduction. So a percentage computed on the net is applied to the gross.

### Proposed Solution

Compute the percentage on the sum of the positive (customer-priced) lines, excluding the Trade-In
Deduction, for both tiering and application. Better still, apply the approved **amount** (for
example as a single negative *Discount Adjustment* line, a type the approved flow already excludes)
rather than a percentage spread across the lines.

### Reference

- **BRD** §10.7 ALF-RS-07, p.44, FR1 — *"The system should support discount entry as a numeric value only. The system should automatically calculate and display the corresponding discount percentage as a read-only derived field on the quotation."* The customer receives the approved numeric value, not a re-derived percentage.
- **BRD** §10.7 ALF-RS-07, p.44, FR2 — *"The system should trigger an approval workflow whenever a Sales Representative applies a discount, routing to the appropriate approver based on the delegation-of-authority matrix."*

**Screenshots:** `69-C2-discount-saved.png`, `71-C2-discount-approval-page.png`

---

## BUG-E2E-05 (LFRDN-756) — Trade-in approval marks the trade-in "Accepted" without the customer, but the deduction only reaches the quote once the rep separately accepts the vehicle line (Medium)

**Module:** Retail Sales — Trade-in (appraisal) / Quotation
**Applies to:** Sales Representative.

### Description

When the Used Car Team's valuation is approved, the trade-in header immediately reads **Trade-In
Outcome: Accepted**, although nobody has asked the customer, and its status stays **Under
Approval**. The vehicle line's own *Trade-In Outcome* stays blank. That line's outcome is what counts
toward the trade-in value used on the quote. So the quote the rep creates next shows **no trade-in
deduction**, and nothing tells the rep to go and accept the line.

### Steps to Reproduce

1. **E2E C2**, trade-in **APL-000000133**, item **APLI-000000095**: Submit for Evaluation → Used Car
   Team sets *Initial Value* 135,000 → approve.
2. Read the trade-in header and item. Create Quotation on the Opportunity.
3. Trade-in item → **Edit** → *Trade-In Outcome* **Accepted** → **Save**. Re-read the quote.

### Expected Result

The rep records the customer's decision in one clear place. Once accepted, the deduction appears on
the quote, and the trade-in's status reads as finished (e.g. *Completed*).

### Actual Result

- **Step 2:** header *Trade-In Outcome* **Accepted**, *Status* **Under Approval**,
  *Active Trade-In Value* **0**; item *Trade-In Outcome* blank. The new quote 00000243 has **no**
  Trade-In Deduction line.
- **Step 3:** *Active Trade-In Value* becomes 135,000 and a **−135,000 Trade-In Deduction** line is
  added to the existing quote.
- The header status still reads *Under Approval*, which also keeps the Create Reservation deposit
  field hidden (see LFRDN-695).

### Root Cause

**Confirmed from metadata.**
- `Appraisal.AF_ActiveTradeInValue__c` is a roll-up of `AppraisalItem.AF_ActiveValue__c` filtered on
  `AppraisalItem.AF_TradeInOutcome__c = 'Accepted'`.
- The approval updates the header's outcome, not the item's.
- No step moves the header Status past *Under Approval*.

### Proposed Solution

Either keep the header outcome blank until the customer decides and give the rep one *"Record
Customer Decision"* action that sets both header and items, or roll up on the approval status and
use the header outcome for the customer decision. Move the header Status to *Completed* once the
decision is recorded.

### Reference

- **BRD** §10.4 ALF-RS-04, p.38, FR7 — *"The system should feed the accepted trade-in value into the opportunity quotation as a negative / offsetting line item."*
- **BRD** §10.4 ALF-RS-04, p.39, AC2 — *"Given a trade-in value is approved, When the Sales Representative opens the quotation, Then the trade-in value appears as a negative line item in the deal summary."*

**Screenshots:** `63-C2-submitted.png`, `65-C2-evaluated.png`, `67-C2-item-accepted.png`
