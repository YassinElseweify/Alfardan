# Retest — LFRDN bugs in "Deployed to QA" (2026-09-27)

**Scope:** the 43 LFRDN bugs in status *Deployed to QA* on 2026-09-27.
**How:** Lightning UI as the personas (Sales Rep, Sales Receptionist, Showroom Manager, Sales/Brand Manager, Used Car Team) on fresh records. Admin was used only for setup, access checks, debug logs and reading generated files.
**Retest records:** deals named `QA RT27 …` — C1–C7 (cancellation), R1–R2 (requisition), M1–M4 (main cycle, reservations, closure).
**Screenshots:** `screenshots/RETEST-2026-09-27/` (01–37)
**Jira status:** approved by the user on 2026-09-28. The 11 comments below were posted, and those tickets moved Deployed to QA → Waiting for Customer Input → **To Do** (confirmed by JQL). 26 fixed tickets were then marked **Done** (DEPLOYED TO QA → QA IN PROGRESS → Done). Held back: 733 (QA IN PROGRESS), and 698, 713, 736, 743, 755 (still Deployed to QA) — see "Fixed tickets left open" below. New findings N1–N4 are drafted as BUG-RT27-01…04 in `tickets/RETEST-2026-09-27/README.md` (not filed).

## Totals

| Result | Count | Tickets |
|---|---|---|
| Fixed | 32 | 674, 698, 704, 707, 708, 709, 711, 712, 713, 720, 721, 722, 723, 731, 732, 733, 734, 735, 736, 739, 740, 741, 742, 743, 744, 746, 747, 748, 749, 751, 753, 755 |
| Partially fixed → To Do | 8 | 719, 729, 730, 738, 745, 750, 754, 756 |
| Not fixed → To Do | 3 | 695, 728, 752 |

## Fixed

| Ticket | Evidence |
|---|---|
| LFRDN-674 Sales Order vehicle details | M1's Sales Order shows Model Year 2025 and the chassis number (falls back to the VIN). |
| LFRDN-698 Sold car still offered | After M1 closed won, RT27M-01 reads **Reserved** and is not offered in the Vehicle Finder. *Minor:* its *Availability For Sale* field still reads "Available for Sale". |
| LFRDN-704 Sales Order status on close | M1 Closed Won → Sales Order Status **Delivered**. |
| LFRDN-707 Closure approver can't see the deal | Rep ran **Request Closure** on M2 (`006FV00C4DTfJzgYUF`). The flow added a Manual/Edit OpportunityShare for the approver QA ShowroomManager2, who opened and approved the request in the UI. M2 is Closed Lost. `32`–`35` |
| LFRDN-708 Regenerated documents keep old values | Vehicle Sale Agreement v2 and Repair Disclaimer v2 carry the updated handover date, location and remarks. |
| LFRDN-709 Handover records visible across BUs | QA ShowroomManager2 (Alsadd) has no access to M1's HO-00075, INVM-00134, PAY-00109 or RES-00237. |
| LFRDN-711 Sign-off without signed documents | Sign-off refused until the signed scan is uploaded under Signed Handover Documents. *Minor:* the panel still labels that document "Optional". `21` |
| LFRDN-712 Handover documents / picker | HO-00075 created with all five agreements; Generate Documents offers the per-document picker. |
| LFRDN-713 Follow-up task goes to the rep | Post-handover tasks are owned by the **Customer Experience** queue with the customer as WhoId (both E2E handovers). |
| LFRDN-720 Reservation can pick another car | The screen shows only the quote's own vehicle. `17`–`19` |
| LFRDN-721 Existing payment not linked | M4 (`006FV00C46i8wuiYEA`): PAY-00111 (40,000, Paid/Verified) taken first; rep created a 7-Day, 40,000 reservation → **RES-00239 Payment = PAY-00111**, status Reserved. `36`–`37` |
| LFRDN-722 Generate Documents button | Documents generate on creation; the action now regenerates single documents. |
| LFRDN-723 Handover location free text | Location is a picklist (Lusail saved). |
| LFRDN-731 Pre-approved credit note | A credit note created as Approved is refused. |
| LFRDN-732 Cancellation approval doesn't close the deal | C1 and C7 → Closed Lost, SO Cancelled, vehicles released. |
| LFRDN-733 Showroom Manager visibility | Confirmed on C6 as the Showroom Manager. |
| LFRDN-734 / 735 Cancel on delivered / no-SO deals | Cancel Sales Order hidden on C4 (Closed Won/Delivered) and C3 (no SO), shown on normal deals. |
| LFRDN-736 Refund evidence gate | CN-00031 submitted only after a file titled "Refund Evidence" was attached; approved → Finance Status Processing. *Gaps:* no Required Documents panel on the credit note, and nothing tells the rep to name the file "Refund Evidence"; an "Approval Needed" email went to the Showroom Manager when the credit note was created, before it was submitted. |
| LFRDN-739 Delete protection | All four deletes refused (run in a savepoint). |
| LFRDN-740 Cancelled deal can progress | C7 can't move forward after cancellation. |
| LFRDN-741 Credit note cross-BU visibility | Other-BU manager blocked. |
| LFRDN-742 Requisition form vehicle details | R1 draft form: Ferrari 296 GTB, MY 2025, quote 00000253. |
| LFRDN-743 Deal locked while requisition pending | R1 stays editable by the rep. *Not checked:* recall. |
| LFRDN-744 Spec change after approval | Status reset to Not Requested; re-request added v3 to the same file. |
| LFRDN-746 Draft form / approval page | Form attached at submission; approval page shows Selected Vehicle. |
| LFRDN-747 Dealer Prep not offered | Offered on a branded deal, Internal Requisition flag set. |
| LFRDN-748 Action shown while pending | Hidden while pending. |
| LFRDN-749 Past completion date | "The completion date cannot be in the past." |
| LFRDN-751 Status not on page | Status and date on the Details tab. |
| LFRDN-753 Service Walk-In | Service Walk-In created the deal and the follow-up task correctly. |
| LFRDN-755 Discount tier / grand total | 16,000 discount routed as Tier 2; Grand Total 247,299.89 (expected 247,300 — 0.11 rounding). *Minor:* Discount % still displays 6.08 (calculated on the net after trade-in). |

**Caveat on 729–741:** because of LFRDN-728, Cancel Sales Order can't be run in the UI. The flow's steps were replayed as the rep through the API, and the approvals, evidence upload and results were then done in the UI.

## Fixed tickets left open

| Ticket | Why it is not Done |
|---|---|
| LFRDN-698 | The car shows Reserved, but *Availability For Sale* still reads "Available for Sale". |
| LFRDN-713 | Tasks were correct on the E2E handovers, but M1's handover HO-00075 (handover 25/09 10:00, due +2 days) had still produced no follow-up task at 2026-09-27 22:30 UTC. Recheck. |
| LFRDN-733 | The owner can now read the invoice and payments, but the cancellation itself can't be completed while LFRDN-728 breaks Cancel Sales Order. Left in QA IN PROGRESS. |
| LFRDN-736 | Evidence is only recognised through a file titled "Refund Evidence", and the approval email goes out at creation (BUG-RT27-04). |
| LFRDN-743 | Recall while pending was not checked. |
| LFRDN-755 | The Discount % field still shows 6.08, and the total is 0.11 off. |

## Partially fixed → comment and move to To Do

### LFRDN-719 — Sales Walk-In blocked for the Sales Rep
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** the permission gate. As QA SalesRep2 on contact Reem Al-Ansari, Sales Walk-In now opens and passes the Brand screen instead of stopping at "not enabled for your Business Unit".
>
> **Still failing:** clicking Next on the Brand screen ends on "Something went wrong":
> *"unable to parse field as dataType could not be retrieved for the passed field: RawFieldImpl[tableName: UserRole, columnName: Name]"*
> Nothing is created (no Opportunity, no task). The flow filters users by `UserRole.Name`, which the running user can't read in this context.
>
> **Needed:** resolve the sales-rep lookup without reading `UserRole.Name` in the running user's context, for example by role DeveloperName or Id held in custom metadata, or through an invocable that runs in system mode.
>
> Screenshot: `13-M2-rep-sales-walkin.png`

### LFRDN-729 — Rejected cancellation leaves the credit note pending
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** the credit note is no longer submitted automatically when created, and a rejected cancellation returns the deal to its previous stage (C2, `006FV00C3c9DnpUYES`, back at Commit).
>
> **Still failing:** the credit note raised with that cancellation, **CN-00032** (`a0PFV004ASfLii42YC`), stays *Pending* after the cancellation is rejected. It should become Cancelled/Rejected, or be removed, so finance doesn't see a live refund for a cancellation that was refused.
>
> **Needed:** when the cancellation approval is rejected, close the linked credit note (status Cancelled) in the same rejection path.

### LFRDN-730 — Refund cap can be bypassed
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** with the Invoice Summary linked, a refund above the amount paid is refused (C3, CN-00035 at 40,000 accepted).
>
> **Still failing:** the cap only runs when an Invoice Summary is linked, and the New Credit Note form doesn't require one. As QA SalesRep2 on C3 (`006FV00C3c9HzyWYES`), a credit note with no Invoice Summary and **Refund Amount 999,999** was saved: **CN-00034** (`a0PFV004ATQiqge2YB`). This is the same route as the original report.
>
> **Needed:** make Invoice Summary required on credit notes (or default it from the Opportunity's invoice), so the cap always applies.
>
> Screenshot: `03-new-credit-note-form.png`

### LFRDN-738 — Cancellation history snapshot
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** the snapshot fields exist on the credit note, and the flow writes them.
>
> **Still failing:** the Sales Representative has no field-level edit access to the new snapshot fields. The cancellation flow's credit-note step writes them in the rep's context, so it would fail for the rep. Today it's hidden behind LFRDN-728, because the flow faults earlier. When I created the credit note as the rep through the API with those fields set, the save was refused; without them it saved.
>
> **Needed:** grant Edit on the snapshot fields to the Sales Rep permission set (or run that step in system mode), then re-verify once LFRDN-728 is fixed.

### LFRDN-745 — Special characters in the requisition job specification
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** the full job specification now prints, including text with angle brackets (R1, `006FV00C3eKVP2yYEH`).
>
> **Still failing:** Arabic text in the specification prints with its letters in reversed order and unjoined, so it can't be read. See the R1 draft form preview.
>
> **Needed:** render the PDF with an Arabic-capable font and right-to-left shaping (for example `dir="rtl"` on the element, plus a font that supports Arabic in the Visualforce/PDF renderer).
>
> Screenshots: `08-R1-draft-form-preview.png`, `09-R1-draft-form-jobspecs.png`

### LFRDN-750 — Rejection reason missing
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** rejecting the requisition on R2 (`006FV00C3eKZbC0YEL`) now sends the rep a rejection notification.
>
> **Still failing:** the notification reads *"No reason was provided. Please review and resubmit if needed."*, even though QA SalesBrandManager2 rejected with the comment *"Rejected: tint spec not allowed on the windscreen - remove the strip and resubmit"*. The comment isn't carried into the message.
>
> **Needed:** read the comment from the rejection step (ProcessInstanceStep.Comments of the latest Rejected step) and put it in the notification.

### LFRDN-754 — Deal doesn't close when the Bank LPO arrives later
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:**
> 1. On M1 (`006FV00C3frFf08YEC`) with no Bank LPO, sign-off completed the handover, set Delivery Confirmation and kept the deal at Take the Keys, with a Chatter alert.
> 2. Closing manually from the Path works once the LPO is on file.
>
> **Still failing:** uploading the Bank LPO through the Required Documents panel doesn't close the deal automatically. M1 stayed at Take the Keys after the upload (checked after 25+ seconds). The file is linked before its document-type tag is set, so the check doesn't see an LPO — the same pattern as LFRDN-697.
>
> *Minor:* the Chatter alert posted twice.
>
> **Needed:** run the close check when the document tag is set (ContentVersion/Document Type update), not only when the file is linked.
>
> Screenshots: `22-M1-signoff-no-lpo.png`, `23-M1-manual-close.png`

### LFRDN-756 — Trade-in header and item status out of step
> **QA retest 2026-09-27 — partially fixed, moving back to To Do.**
>
> **Fixed:** once the rep sets the trade-in item to Accepted, the trade-in completes correctly at 135,000 and the quote gets the −135,000 deduction line.
>
> **Still failing:** on M1's trade-in (APL-000000137), as soon as the Used Car Team approves the valuation, the **header** shows *Accepted*. The **item** meanwhile has no outcome, a value of 0, and is still *Under Approval*. The header should not say Accepted until the customer accepts the offer on the item.
>
> **Needed:** derive the header outcome from the item's outcome, and leave it blank until the item is Accepted or Refused.
>
> Screenshot: `16-M1-item-accept.png`

## Not fixed → comment and move to To Do

### LFRDN-695 — Create Reservation (regression)
> **QA retest 2026-09-27 — not fixed, moving back to To Do.**
>
> The vehicle-mismatch fix still holds: the screen shows only the quote's vehicle.
>
> **Create Reservation no longer works on any deal without an approved trade-in appraisal, for every user including System Administrator.** On QA RT27 M2 (`006FV00C4DTfJzgYUF`, Quote 00000255, no appraisal):
> - **7-Day (Deposit):** the Deposit Amount field never appears.
> - **3-Day (No Deposit):** clicking **Next** does nothing. No error is shown, and the debug log shows no server call after the first screen.
>
> The same screen works on a deal that has an approved appraisal: on QA RT27 M3 (`006FV00C4MeHG0iYUG`), the checkbox and deposit fields appear and RES-00238 was created. So the screen breaks when `Get_Active_Appraisal` returns nothing. The visibility rules on `TradeInAsDepositField` and the deposit fields reference `Get_Active_Appraisal.Id` and `TradeInAsDepositField`, and with no appraisal record the screen's reactive visibility stops evaluating. That also blocks Next.
>
> **Needed:**
> - Guard the visibility rules against a null `Get_Active_Appraisal`, for example with a Boolean formula variable `HasApprovedAppraisal`.
> - Show `DepositAmountCashField` on 7-Day whenever the trade-in box is not ticked.
> - Retest 3-Day and 7-Day on a deal without a trade-in.
>
> The 3-Day rep-only failure from the last retest can't be re-checked until this is fixed.
>
> Screenshots: `24`–`28` (rep and admin), `29` (working with an appraisal)

### LFRDN-728 — Cancel Sales Order approver access (regression)
> **QA retest 2026-09-27 — not fixed, moving back to To Do.**
>
> **Cancel Sales Order now fails for every user.** As QA SalesRep2 on QA RT27 C1 (`006FV00C3c99bgSYEQ`), Cancel Sales Order ends with *"An unhandled fault has occurred in this flow"*. Nothing is saved: no credit note, and no change on the deal.
>
> Debug log: the new step `Get_Manager_Record_Access` (UserRecordAccess lookup) fails with **"RecordId field must be selected"**. The element uses automatic output storage with no queried fields, and UserRecordAccess requires `RecordId` to be in the SELECT. The step has no fault path.
>
> **Needed:**
> - Select `RecordId` and `HasReadAccess` explicitly in that lookup.
> - Add a fault path.
> - Retest the approver-access check. On C6 the approver would be QA SalesBrandManager2, who can't see Automobiles deals.
>
> Screenshot: `01-C1-cancel-unhandled-fault.png`

### LFRDN-752 — Sales Walk-In notification fails for the receptionist
> **QA retest 2026-09-27 — not fixed, moving back to To Do.**
>
> As QA Receptionist on contact Hamad Al-Kuwari, Sales Walk-In creates the Opportunity (M1, `006FV00C3frFf08YEC`) but then ends on "Something went wrong":
> *"This error occurred when the flow tried to create records: INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY: insufficient access rights on cross-reference id."*
> No task and no notification are created for the assigned rep.
>
> Root cause (debug log): `Create_Notification_Task` runs in the receptionist's context. The deal is owned by the rep, and the receptionist can't see it, so the task's WhatId is refused.
>
> **Needed:** create the task and send the notification in system context (a sub-flow or invocable running without sharing), or share the new deal with the receptionist before the task is created.
>
> Screenshot: `12-M1-sales-walkin-result.png`

## New findings

| # | Finding | Suggested handling |
|---|---|---|
| N1 | **Approvals route to an approver who can't see the record.** The rep's Manager is QA ShowroomManager2 (Showroom Manager – Alsadd), who has no access to Sports Motors deals. The LFRDN-707 fix shares the deal only for **Request Closure**. The discount approval (M1 quote), requisition approval (R1), credit-note approval (CN-00031) and cancellation approvals all landed on ShowroomManager2, who can't open them. To continue testing I reassigned those work items to QA SalesBrandManager2 as admin. This is either user setup (rep's Manager should be a Sports Motors manager) or the same share-before-submit fix is needed on every approval. | New ticket, or ask the team whether ManagerId is set correctly |
| N2 | **Trade-in-as-deposit follow-up never runs.** `AF_FL_Reservation_ApplyTradeInDeposit` starts only when `ISCHANGED(AF_TradeInAsDeposit__c)`, which is false on a new record. Create Reservation always inserts the reservation with the box already ticked, so the flow never fires: the appraisal's *Related Vehicle Reservation* stays blank (RES-00238 / appraisal `9ALFV0000w4QAAC4A4`) and the deposit is never defaulted to the appraised value. | New ticket |
| N3 | **Trade-in deposit isn't limited to the trade-in's value.** The rep types "Amount to Apply from Trade-In" freely; no rule compares it with the appraisal's FinalAppraisalValue. 30,000 was accepted against an appraisal worth 0. Caveat: that appraisal was set up by API without a valuation. | BA question / new ticket |
| N4 | **Credit note "Approval Needed" email sent before submission** (LFRDN-736 area). The Showroom Manager received it when CN-00031 was created, while it was still unsubmitted and waiting for evidence. | Comment on 736 or small new ticket |
| N5 | Minor: 698 *Availability For Sale* not updated on sale; 711 panel shows Signed Handover Documents as "Optional"; 754 Chatter alert posted twice; 755 Discount % shows 6.08; 707's manual share stays on the deal after closure. | Mention only |

## Records created in this retest

| Record | State |
|---|---|
| QA RT27 C1–C7 | Cancellation scenarios (C1/C7 Closed Lost, C4 Closed Won, others at Commit) |
| QA RT27 R1, R2 | Requisition approved / rejected |
| QA RT27 M1 … Hamad Al-Kuwari (`006FV00C3frFf08YEC`) | Closed Won, Sales Order Delivered |
| QA RT27 M2 (`006FV00C4DTfJzgYUF`) | Closed Lost via Request Closure; no reservation (695 blocks it) |
| QA RT27 M3 - 7-Day reservation, trade-in as deposit (`006FV00C4MeHG0iYUG`) | RES-00238, Pending Approval |
| QA RT27 M4 - deposit paid before reservation (`006FV00C46i8wuiYEA`) | RES-00239 Reserved, PAY-00111 linked |

The walk-in deals "QA RT27 M3/M4 Customer …" share the M3/M4 labels with the reservation deals; they are separate records.

## Org configuration touched
- The approval work items above were reassigned from QA ShowroomManager2 to QA SalesBrandManager2 as admin (precondition workaround for N1).
- The Service Receptionist permission group was temporarily given to the Sales Receptionist for LFRDN-753, then removed.
- The rep's debug trace flag was extended to 2026-09-28 08:00 UTC.

## Update 2026-09-28 — remaining tickets settled

| Ticket | Outcome | Why |
|---|---|---|
| LFRDN-698 | **Done** | Every car with a Converted reservation now reads Reserved (incl. the backfilled RS12-01/06/08, SF90, In Transit), and none is offered in Create Reservation. *Availability For Sale* is "Available for Sale" on every car, including open deals — it isn't maintained by any automation and isn't part of this ticket. |
| LFRDN-713 | **Done** | Post-fix tasks on HO-00063 / HO-00064 are owned by the Customer Experience queue with the customer as WhoId. M1 (HO-00075) got none only because its handover date was entered backdated to 25/09 at 20:38; the scheduled path fired at once, before sign-off at 20:44, saw `AF_ClosedWonGatePassed__c` = false, and never re-runs. Minor edge case: a handover date entered more than two days in the past before sign-off produces no follow-up task. |
| LFRDN-743 | **To Do** (commented) | Recall works, but after recall `AF_RequisitionStatus__c` stays Pending Approval — the approval process has no recall action — so Request Internal Requisition is hidden and the direct link says a request is pending. The rep can never re-request. Screenshots 38–41. |
| LFRDN-736 | **To Do** (commented) | No Required Documents panel on the credit note (evidence only recognised via a file titled "Refund Evidence"); the "Approval Needed" email is sent at credit-note creation (CN-00031/32/33), before submission. This replaces BUG-RT27-04. |
| LFRDN-733 | **QA IN PROGRESS** (commented) | Owner access fixed; end-to-end cancellation blocked by LFRDN-728. |
| LFRDN-755 | **To Do** (commented 2026-09-28) | The applied discount is correct (4.0171%, Grand Total 247,299.89), but the quote's *Discount %* still shows **6.08**. The ticket lists that value as part of the actual result, and BRD §10.7 FR1 (p.44) requires the displayed percentage to correspond to the discount — so it is not fully fixed. |

New tickets filed: **LFRDN-761** (approvals routed to an approver without access), **LFRDN-762** (trade-in deposit never linked to the reservation), **LFRDN-763** (trade-in deposit not capped at the trade-in value).

**LFRDN-755 recheck (2026-09-28):** reproduced on a fresh deal, QA RT27 M5 (`006FV00C4aVclsKYER`), Quote 00000260: trade-in −100,000, discount 10,000. Applied 2.5107% ✅, Grand Total 288,299.88 ✅, Tier 1 ✅, but *Discount %* shows 3.35% (should be 2.51%). Cause: formula `AF_DiscountPercent__c = AF_DiscountAmount__c / Subtotal`. Commented and moved to To Do. Screenshots 42–43.
