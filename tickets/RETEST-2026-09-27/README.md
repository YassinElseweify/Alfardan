# Retest of Deployed-to-QA bugs (2026-09-27) — new bug tickets

**Found during:** retest of the 43 LFRDN bugs in *Deployed to QA*, 2026-09-27
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/RETEST-2026-09-27-deployed-to-qa.md`
**Screenshots:** `screenshots/RETEST-2026-09-27/`
**Status:** Filed in Jira 2026-09-28 as **LFRDN-761** (BUG-RT27-01), **LFRDN-762** (BUG-RT27-02), **LFRDN-763** (BUG-RT27-03) — Bug, parent LFRDN-317, assignee Yassin, Sprint 3. BUG-RT27-04 was not filed: it was posted as part of the LFRDN-736 retest comment instead.

> **Reproducible in the Lightning UI.**
> - Sales Representative: `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!`
> - Showroom Manager: `alfardan.qa.showroommanager2@alfardan.com.qa.qa` / `Arcsen@2026!`
> - Sales/Brand Manager: `alfardan.qa.salesbrandmanager2@alfardan.com.qa.qa` / `Arcsen@2026!`
>
> Login is two-step (username, then password). Dismiss *Change Your Password* with **Cancel**.

When approved, each is raised in **LFRDN** as a Bug, assigned to **Yassin**, parent **LFRDN-317**,
Sprint **LFRDN S1- R1 Sprint 3**, labels `QA` / `Retail-Sales` plus the story label, and linked
*relates to* its story subtask:
- BUG-RT27-01 → `ALF-RS-13` (LFRDN-343), also *relates to* LFRDN-728 and LFRDN-707
- BUG-RT27-02, BUG-RT27-03 → `ALF-RS-08` (LFRDN-338)
- BUG-RT27-04 → `ALF-RS-13` (LFRDN-343), also *relates to* LFRDN-736

## Summary

**Approvals are going to someone who can't open them.** The Sales Representative's approvals go to their
*Manager*, QA ShowroomManager2, who manages the Alsadd showroom and can't see Sports Motors records.
LFRDN-707 fixed this for **Request Closure** only, by sharing the deal with the approver before
submitting. Every other approval the rep raises — reservation, discount, internal requisition,
cancellation, credit note — still lands on a manager who can't see the record, so it can never be
approved without an administrator reassigning it (BUG-RT27-01).

**Using a trade-in as the reservation deposit works on screen, but the record behind it is incomplete.**
The follow-up automation never runs on a new reservation, so the trade-in is never linked to the
reservation it pays for (BUG-RT27-02). The amount the rep types is also not checked against what the
trade-in is worth (BUG-RT27-03).

**The refund approver is emailed before there is anything to approve** (BUG-RT27-04).

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-RT27-01 (LFRDN-761) | Approvals the Sales Rep raises go to a manager who can't open the record | High | Sales Representative whose Manager is outside the deal's business unit (QA SalesRep2 → QA ShowroomManager2 today). Admin can approve anything, so it doesn't see it. |
| BUG-RT27-02 (LFRDN-762) | A trade-in used as the deposit is never linked to the reservation | Medium | General — the automation doesn't run for any user |
| BUG-RT27-03 (LFRDN-763) | The trade-in deposit amount isn't limited to the trade-in's value | Medium | General |
| BUG-RT27-04 (not filed — in LFRDN-736) | The refund approver gets an "Approval Needed" email before the credit note is submitted | Low | Approver of cancellation credit notes |

### Already tracked — new evidence, no new ticket

| Jira | What we saw | New evidence |
|---|---|---|
| LFRDN-695 | Create Reservation dead on deals with no approved trade-in, for every user | Posted as the retest comment on 2026-09-27; ticket moved to To Do |
| LFRDN-728 | Cancel Sales Order faults for everyone (`Get_Manager_Record_Access`) | Posted as the retest comment on 2026-09-27; ticket moved to To Do |

---

## BUG-RT27-01 (LFRDN-761) — Approvals the Sales Rep raises go to a manager who can't open the record (High)

**Module:** Retail Sales — Approval routing (reservation, discount, internal requisition, cancellation, credit note)
**Applies to:** QA SalesRep2, whose *Manager* is QA ShowroomManager2 (Showroom Manager – Alsadd). Seen on 11 approvals across 5 approval processes on 2026-09-27. A System Administrator can see every record, so it can approve anything and doesn't hit this.

### Description

Most approvals in the retail cycle go to the submitter's *Manager* field. For the Sales Rep that is
QA ShowroomManager2, who manages the Alsadd (Automobiles) showroom and has **no access** to Sports
Motors deals. So the approver gets the request but can't open the deal, quote, reservation or credit
note behind it, and the request can never be approved.

LFRDN-707 fixed this for **Request Closure** only: that flow now shares the deal with the approver
before submitting (confirmed on 2026-09-27). The other approval paths don't do this, and LFRDN-728
covers the cancellation path only. The rep's reservation, discount, requisition, cancellation and
refund approvals all end up with an approver who can't act on them.

### Steps to Reproduce

1. As System Administrator, note QA SalesRep2's *Manager*: **QA ShowroomManager2**.
2. Log in as QA SalesRep2 → Quote **Customer Quotation - QA RT27 M3** (`0Q0FV004czcSb5Y0AS`, deal *QA RT27 M3 - 7-Day reservation, trade-in as deposit*) → **Create Reservation** → **7-Day (Deposit)** → tick *Trade-In Used As Deposit?* → *Amount to Apply from Trade-In* **30000** → **Next**.
3. The new reservation, **RES-00238**, is *Pending Approval*. Log in as QA ShowroomManager2 → Home → *Items to Approve*, and open the request.

### Expected Result

The approval goes to someone who can open the record and has authority for it, for every approval
the rep raises — as LFRDN-707 now does for Request Closure.

### Actual Result

- RES-00238 is waiting on **QA ShowroomManager2**. `UserRecordAccess` for that user: **HasReadAccess = false** on both the reservation (`a0WFV000h06v1IG2AY`) and its deal (`006FV00C4MeHG0iYUG`).
- Approvals routed to QA ShowroomManager2 on 2026-09-27, none of which they could open (read from `ProcessInstanceStep`):

| Approval process | Record |
|---|---|
| `AF_AP_Reservation_Manager` | RES-00238 (still pending) |
| `AF_AP_Quote_DiscountTiers` | Quote on QA RT27 M1 |
| `AF_AP_Opp_InternalRequisition` | QA RT27 R1, QA RT27 R2 |
| `AF_AP_Opp_Cancellation` | QA RT27 C1, C2, C7 |
| `AF_AP_CreditNote_Cancellation` | CN-00031 |

- To finish the retest, an administrator reassigned each one to QA SalesBrandManager2, who approved them in the UI at once.
- By contrast, **Request Closure** on QA RT27 M2 (`006FV00C4DTfJzgYUF`) created a Manual/Edit `OpportunityShare` for QA ShowroomManager2, who opened and approved it.

### Root Cause

**Confirmed from the approval routing and sharing.**
- These approval processes pick the approver from the submitter's *Manager* field.
- Opportunity sharing is Private, and access comes from business-unit sharing rules. The *Manager* field doesn't follow those rules, so nothing gives the approver access.
- Only `AF_FL_Opp_RequestClosure` grants the approver access (the LFRDN-707 fix). No other submission path does.

### Proposed Solution

1. Route these approvals by the deal's business unit or authority matrix (a queue or named approver per business unit) instead of the *Manager* field. Alternatively, apply the LFRDN-707 pattern — share the record, and its parent deal, with the resolved approver before submitting — in every submission path: reservation, discount, internal requisition, cancellation and credit note.
2. In each submission path, stop with a clear message if the resolved approver still can't read the record.
3. Separately, confirm with the business whether QA SalesRep2's *Manager* should be a Sports Motors manager. LFRDN-728's description says it was set to QA SalesBrandManager2; in QA today it is QA ShowroomManager2.

### Reference

- **BRD** §10.7 ALF-RS-07, p.44, FR2 — *"The system should trigger an approval workflow whenever a Sales Representative applies a discount, routing to the appropriate approver based on the delegation-of-authority matrix."*
- **BRD** §10.13 ALF-RS-13, p.57, FR2 — *"The system should route cancellation requests through an approval workflow aligned to the cancellation authority matrix."*
- **BRD** §10.16 ALF-RS-16, p.61, FR2 — *"The system should route the Internal Requisition Form for approval by the Sales Manager before it is issued to the After Sales team."*

**Screenshots:** `31-m3-tradein-result.png` (RES-00238 submitted), `34-sm2-approval-request.png` / `35-sm2-approved.png` (Request Closure, the working path)

---

## BUG-RT27-02 (LFRDN-762) — A trade-in used as the deposit is never linked to the reservation (Medium)

**Module:** Retail Sales — Vehicle Reservation / Trade-in as deposit
**Applies to:** General — the automation doesn't run for any user. Reproduced once, as QA SalesRep2.

### Description

When the rep reserves a car using the customer's trade-in as the deposit, the automation meant to
link the trade-in to the reservation never runs. The trade-in record doesn't show which reservation
it paid for, and the deposit is never defaulted from the trade-in's value.

### Steps to Reproduce

1. Log in as QA SalesRep2 → Quote **Customer Quotation - QA RT27 M3** (`0Q0FV004czcSb5Y0AS`). The deal has an approved trade-in appraisal (`9ALFV0000w4QAAC4A4`).
2. **Create Reservation** → **7-Day (Deposit)** → tick *Trade-In Used As Deposit?* → *Amount to Apply from Trade-In* **30000** → **Next**.
3. As System Administrator, open the appraisal and read *Related Vehicle Reservation*.

### Expected Result

The appraisal's *Related Vehicle Reservation* points to the new reservation, as
`AF_FL_Reservation_ApplyTradeInDeposit` is designed to do.

### Actual Result

- **RES-00238** (`a0WFV000h06v1IG2AY`) is created with *Trade-In As Deposit* = true and *Deposit Amount* 30,000.
- The appraisal's *Related Vehicle Reservation* is **blank**.
- The debug log for the save shows four reservation flows: *Set Expiry Date*, *Sync Pricing*, *Evaluate Approval*, *Submit Approval*. **Reservation Apply Trade-In Deposit is not among them.**

### Root Cause

**Confirmed from the flow metadata and debug log.** `AF_FL_Reservation_ApplyTradeInDeposit` starts
only when `ISCHANGED({!$Record.AF_TradeInAsDeposit__c}) && {!$Record.AF_TradeInAsDeposit__c}`.
`ISCHANGED` is always false when a record is created. Create Reservation inserts the reservation with
the box already ticked, so the flow never starts.

### Proposed Solution

Change the entry condition to fire on create as well, for example
`AND({!$Record.AF_TradeInAsDeposit__c}, OR(ISNEW(), ISCHANGED({!$Record.AF_TradeInAsDeposit__c})))`,
or set *Trigger the flow when* to *A record is created or updated* with *Only when a record is updated
to meet the condition requirements* switched off.

### Reference

- **BRD** §10.8 ALF-RS-08, p.47, FR11 — *"The system should allow an agreed Trade-In value to be applied as part or whole of the reservation deposit where a Trade-In has been appraised and approved against the same Opportunity."*

**Screenshots:** `30-m3-tradein-as-deposit.png`, `31-m3-tradein-result.png`

---

## BUG-RT27-03 (LFRDN-763) — The trade-in deposit amount isn't limited to the trade-in's value (Medium)

**Module:** Retail Sales — Vehicle Reservation / Trade-in as deposit
**Applies to:** General. Reproduced once, as QA SalesRep2.

### Description

When the rep ticks *Trade-In Used As Deposit?*, they type the *Amount to Apply from Trade-In* freely.
Nothing compares it with what the trade-in was valued at. A deposit covered by a trade-in can
therefore be larger than the trade-in is worth, and the reservation treats it as paid: no payment
record is needed.

### Steps to Reproduce

1. Log in as QA SalesRep2 → Quote **Customer Quotation - QA RT27 M3** (`0Q0FV004czcSb5Y0AS`).
2. **Create Reservation** → **7-Day (Deposit)** → tick *Trade-In Used As Deposit?* → *Amount to Apply from Trade-In* **30000** → **Next**.
3. As System Administrator, read the appraisal's *Final Appraisal Value*.

### Expected Result

The amount applied from the trade-in can't exceed the approved trade-in value, and the screen says so.

### Actual Result

- RES-00238 was saved with a 30,000 deposit from the trade-in.
- The appraisal (`9ALFV0000w4QAAC4A4`) has *Final Appraisal Value* **0** and *Active Trade-In Value* **0**.
- None of the ten validation rules on Vehicle Reservation compares the deposit with the trade-in.

**Caveat:** this appraisal was created through the API for the test and has no valuation. A real
appraisal would carry a value, but nothing enforces it either way.

### Root Cause

**Confirmed from the metadata.** In `AF_FL_Quote_CreateReservation`, `DepositAmountField` is a free
Currency input. `Formula_EffectiveDepositAmount` passes it straight to `AF_DepositAmount__c`. The
reservation validation rules check only that the deposit is not negative, not above the vehicle
price, and that it matches the contract type.

### Proposed Solution

1. Show the approved trade-in value on the screen, and default *Amount to Apply from Trade-In* to it.
2. Add a validation rule, or a screen validation, so that the deposit can't exceed the linked appraisal's approved value when *Trade-In As Deposit* is ticked.

The business should confirm which appraisal value counts: *Final Appraisal Value* or *Active Trade-In Value*.

### Reference

- **BRD** §10.8 ALF-RS-08, p.47, FR11 — *"The system should allow an agreed Trade-In value to be applied as part or whole of the reservation deposit where a Trade-In has been appraised and approved against the same Opportunity."*

**Screenshots:** `30-m3-tradein-as-deposit.png`

---

## BUG-RT27-04 (not filed — posted on LFRDN-736) — The refund approver gets an "Approval Needed" email before the credit note is submitted (Low)

**Module:** Retail Sales — Cancellation credit note
**Applies to:** The credit-note approver (QA ShowroomManager2 in this run). Seen on all three cancellation credit notes created on 2026-09-27 (CN-00031, CN-00032, CN-00033).

### Description

Since LFRDN-736, a cancellation credit note is submitted for approval only after the rep attaches the
refund evidence. The approver's "Approval Needed" email still goes out when the credit note is
**created**, before it is submitted. The approver opens a request that isn't in their approval queue.

### Steps to Reproduce

1. Cancel a Sales Order as QA SalesRep2 on **QA RT27 C1** (`006FV00C3c99bgSYEQ`), so that credit note **CN-00031** is created without evidence.
2. As System Administrator, before any evidence is attached: `SELECT Subject, ToAddress, CreatedDate FROM EmailMessage WHERE RelatedToId = '<credit note id>'` and `SELECT CreatedDate FROM ProcessInstance WHERE TargetObjectId = '<credit note id>'`.
3. Attach a file titled *Refund Evidence* to CN-00031. It is then submitted for approval.

### Expected Result

The approver is emailed only when the credit note is actually submitted for approval.

### Actual Result

"Approval Needed: Cancellation/Refund CN-000nn" emails, sent to the approver's address `alfardan.qa.showroommanager@yopmail.com` (read from the org's EmailMessage log):

| Credit note | Email sent (UTC) | Submitted for approval (UTC) |
|---|---|---|
| CN-00031 (C1) | 16:34:51 | 16:39:47, only after the evidence file was attached |
| CN-00032 (C2) | 16:34:54 | **never** — the cancellation was rejected |
| CN-00033 (C7) | 16:34:56 | **never** |

The approver is told to approve three refunds, and two of them never reach their approval queue.

### Root Cause

**Not isolated.** The email is sent on credit-note creation, separately from the approval
submission. The step that sends it wasn't identified.

### Proposed Solution

Send the "Approval Needed" email from the approval process's initial submission action (or from the
flow step that submits it), not when the credit note is created.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR3 — *"The system should support refund or credit-note handling for approved cancellations, according to the agreed finance policy."*

**Screenshots:** none — evidence is the EmailMessage and ProcessInstance query results above.
