# [ALF-RS-13] Sales Order Cancellation and Refund Handling — bug tickets

**Found during:** ALF-RS-13 story test, 2026-09-24
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/ALF-RS-13-report.md`
**Screenshots:** `screenshots/ALF-RS-13/` (24-Sep) and `screenshots/RETEST-2026-09-25-RS13/` (25-Sep re-run)
**Re-run:** 2026-09-25 on fresh deals **QA RT13 T1–T7** (customer *QA RT13 Customer - Aisha Al-Kuwari*), after the build changes of 24-Sep (LFRDN-707 Manager field, LFRDN-709 sharing, LFRDN-725 credit-note approval, Opportunity layout).
**Status:** **Filed in Jira 2026-09-25 — LFRDN-728 to LFRDN-741** (Bug, assignee Yassin, parent LFRDN-317, *relates to* LFRDN-343).

> **Reproducible in the Lightning UI.** Sales Representative: `alfardan.qa.salesrep2@alfardan.com.qa.qa`
> / `Arcsen@2026!`. Approver: `alfardan.qa.salesbrandmanager2@…` (Sales Manager – SportsMotors, the
> rep's Manager). Other business unit: `alfardan.qa.showroommanager2@…` (Showroom Manager – Alsadd,
> Automobiles). Same password. Login is two-step (username, then password). Dismiss
> *Change Your Password* with **Cancel**. Automotive app. The cancellation entry point is the
> Opportunity header **Show more actions ▾ → Cancel Sales Order**.

Each is raised in **LFRDN** as a Bug, assigned to **Yassin**, parent **LFRDN-317
(Build)**, labels `ALF-RS-13` / `QA` / `Retail-Sales` (+ `Security` on BUG-RS13-01 and -06,
`Integration` on BUG-RS13-08), linked *relates to* the story **LFRDN-343**. Items that need a
business decision rather than a fix are in the report's Section 3, not here.

## Summary

The Sales Representative can raise a cancellation, and when an approver who can see the deal
approves it, the order is cancelled, the reservation released and the quote denied — that core
works. Around it, the money side is not controlled, and since 24-Sep it is **blocked**: approving
a refund now fails on every open deal (BUG-RS13-11), so an approved cancellation can never be
refunded. The refund is still a **separate approval** that survives a rejected cancellation and is
duplicated on resubmission (BUG-RS13-02); its **amount is the deal value, not what the customer
paid** (BUG-RS13-03). A cancelled order can still be **handed over and closed as Won** while its
car is back on sale (BUG-RS13-12), and a delivered car can be cancelled and **put back on sale**
(BUG-RS13-04). Credit notes — customer name, refund amount, evidence — are **open to every business
unit** (BUG-RS13-13). Approvals go to the submitter's *Manager* field whether or not that person can
see the deal (BUG-RS13-01), and a deal owner outside the business-unit sharing group cannot cancel
at all (BUG-RS13-14). A Sales Order that was never generated can be "cancelled" (BUG-RS13-05); the
rep can create an **already-approved, "synced" credit note** through the API (BUG-RS13-06); evidence
is a text box (BUG-RS13-07); nothing reaches Keyloop (BUG-RS13-08); the request history is
overwritten (BUG-RS13-09); and an administrator can delete credit notes and payments (BUG-RS13-10).

| ID | Jira | Title | Priority | Affects |
|---|---|---|---|---|
| BUG-RS13-01 | LFRDN-728 | Cancellation approvals go to the submitter's Manager field, whether or not that person can see the deal | Medium | Configuration-dependent — any submitter whose Manager is outside their business unit / role branch |
| BUG-RS13-02 | LFRDN-729 | The refund is approved separately from the cancellation — left pending after rejection, and duplicated on resubmission | Highest | General |
| BUG-RS13-03 | LFRDN-730 | The credit note is for the full deal value, not the amount the customer paid | Highest | General |
| BUG-RS13-04 | LFRDN-734 | Cancelling a delivered, Closed Won deal puts the car back on sale and leaves the deal Won | High | General |
| BUG-RS13-05 | LFRDN-735 | "Cancel Sales Order" runs on deals that have no Sales Order | Medium | General |
| BUG-RS13-06 | LFRDN-731 | A Sales Representative can create an already-approved, "synced" credit note through the API | High | Persona-specific — `AF_PSG_Sales_Rep` (and any group with the same field access) |
| BUG-RS13-07 | LFRDN-736 | Supporting evidence is a free-text box — no document is required or attached | Medium | General |
| BUG-RS13-08 | LFRDN-737 | Approved credit notes are never sent to Keyloop | High | General |
| BUG-RS13-09 | LFRDN-738 | A second cancellation request overwrites the first, and no history of either is kept on the deal | Medium | General |
| BUG-RS13-10 | LFRDN-739 | An administrator can delete the credit note and payments of a cancelled deal | Low | System Administrator only |
| BUG-RS13-11 | LFRDN-732 | Approving a refund fails on every open deal, so an approved cancellation can never be refunded | Highest | General |
| BUG-RS13-12 | LFRDN-740 | A cancelled Sales Order can still be handed over and the deal closed as Won | Highest | General |
| BUG-RS13-13 | LFRDN-741 | Credit notes are visible to, and editable by, every business unit | High | General — every persona with Credit Note access |
| BUG-RS13-14 | LFRDN-733 | A deal owner outside the business-unit sharing group cannot see their own invoice, so their cancellation fails | Medium | Configuration-dependent — owners not in the matching `AF_G_BU_*` group (e.g. QA ShowroomManager2 on an Automobiles deal) |

### Screenshots to attach in Jira

| Ticket | Jira | Attach (in `screenshots/ALF-RS-13/` unless a folder is named) |
|---|---|---|
| BUG-RS13-01 | LFRDN-728 | `06-approver-view-opportunity-cancellation.png` (24-Sep) |
| BUG-RS13-02 | LFRDN-729 | `RETEST-2026-09-25-RS13/10b-credit-notes-related-list.png`, `10-credit-notes-list.png` |
| BUG-RS13-03 | LFRDN-730 | `09-deposit-only-credit-note-369300.png`, `04-new-credit-note-999999-form.png`, `05-credit-note-999999-created.png` |
| BUG-RS13-04 | LFRDN-734 | `03-cancel-offered-on-closed-won-delivered.png`, `11-delivered-car-back-on-sale.png` |
| BUG-RS13-05 | LFRDN-735 | `09-deposit-only-credit-note-369300.png` |
| BUG-RS13-06 | LFRDN-731 | `10-credit-notes-list.png` |
| BUG-RS13-07 | LFRDN-736 | `02-cancel-text-only-evidence.png` |
| BUG-RS13-08 | LFRDN-737 | `09-deposit-only-credit-note-369300.png` |
| BUG-RS13-09 | LFRDN-738 | — (data evidence) |
| BUG-RS13-10 | LFRDN-739 | — (API evidence) |
| BUG-RS13-11 | LFRDN-732 | `RETEST-2026-09-25-RS13/04-credit-note-approval-fails-closed-lost-rule.png`, `RETEST-2026-09-25-RS13/05-refund-approval-fails-after-approved-cancellation.png` |
| BUG-RS13-12 | LFRDN-740 | `RETEST-2026-09-25-RS13/07-cancelled-deal-take-the-keys.png`, `RETEST-2026-09-25-RS13/09-cancelled-deal-closed-won.png` |
| BUG-RS13-13 | LFRDN-741 | `RETEST-2026-09-25-RS13/11-other-bu-manager-opens-credit-note.png` |
| BUG-RS13-14 | LFRDN-733 | — (data evidence) |

---

## BUG-RS13-01 (LFRDN-728) — Cancellation approvals go to the submitter's Manager field, whether or not that person can see the deal (Medium)

**Module:** Retail Sales — Sales Order Cancellation / Approval routing
**Applies to:** Configuration-dependent — any submitter whose *Manager* is outside their business unit or
role branch. In QA today: QA ShowroomManager2 (Showroom Manager – Alsadd, Automobiles) → Manager QA
SalesBrandManager2 (Sales Manager – SportsMotors).

### Description

A cancellation request is sent to the submitter's *Manager* (a user field), not to someone who has
authority over the deal. When that person cannot see the Opportunity, the request cannot be
approved and stays *Pending* for ever. Nothing checks the approver's access at submission.

### Steps to Reproduce

1. As System Administrator, note QA ShowroomManager2's *Manager*: QA SalesBrandManager2.
2. As QA SalesBrandManager2, open **QA RT13 T6 - Showroom Manager deal, Automobiles**
   (`006FV00BtPUodnwYUB`, owner QA ShowroomManager2, Alfardan Automobiles).
3. (Reproduced end to end on 24-Sep, when QA SalesRep2's Manager was QA ShowroomManager2:) as the
   Sales Representative, **Cancel Sales Order** on **DEMO RS13 01** (`006FV00Br6vomcmYEA`); as the
   assigned approver QA ShowroomManager2, open the request and **Approve**.

### Expected Result

The request goes to someone who can see the deal and has authority for the amount; if the resolved
approver cannot see it, the submission stops with a clear message.

### Actual Result

Step 2 (25-Sep): the approver cannot open the deal — `SELECT Id FROM Opportunity WHERE Id =
'006FV00BtPUodnwYUB'` as QA SalesBrandManager2 returns **0 rows**; every cancellation QA
ShowroomManager2 submits is routed to them. Step 3 (24-Sep): the approval page showed *"Looks like
there's a problem. Another user recalled or responded to this request."*, **Approve** did nothing and
the request stayed *Pending*; via REST `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY`. After an
administrator reassigned it to QA SalesBrandManager2, approval worked at once. QA SalesRep2's Manager
has since been set to QA SalesBrandManager2 (LFRDN-707), so the rep's own requests now route to an
approver who can see them (QA RT13 T1–T4, T7).

### Root Cause

**Confirmed.** `AF_AP_Opp_Cancellation` has one step with `userHierarchyField` = **Manager**. The
Opportunity OWD is Private and access flows through the role hierarchy and business-unit sharing
rules, which the Manager field does not follow. `AF_FL_Opp_RequestCancellation` checks only that a
Manager exists (`Has_Manager_For_Submission`), not that the Manager can see the record.

### Proposed Solution

1. Route by the deal's business unit / authority matrix (queue or related user per business unit)
   instead of the Manager field.
2. In the request flow, stop with a clear message if the resolved approver has no read access.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR2 — *"The system should route cancellation requests through an approval workflow aligned to the cancellation authority matrix."*
- **BRD** §10.13 ALF-RS-13, p.58, AC1 — *"Given a cancellation is requested, When the Sales Representative submits it, Then an approval request is created and the cancellation cannot proceed without authorization."*

---

## BUG-RS13-02 (LFRDN-729) — The refund is approved separately from the cancellation — left pending after rejection, and duplicated on resubmission (Highest)

**Module:** Retail Sales — Credit Note / Refund control
**Applies to:** General.

### Description

Each cancellation request creates a credit note (the customer's refund) that goes through its
**own, separate approval** to the same approver. The two are never tied together:
- when a cancellation is **rejected**, its refund stays **pending**;
- when the rep asks again, a **second** refund is created — the deal now has two pending refunds
  of 369,300 each;
- the refund's approval acts on the deal by itself: on 24-Sep a refund was **approved while its
  order was still not cancelled** (CN-00003 on DEMO RS13 01), and since LFRDN-725 approving a refund
  tries to close the deal as Lost — whatever the cancellation's outcome.

### Steps to Reproduce

1. **Rejected cancellation:** as the Sales Representative on **QA RT13 T2** (`006FV00BtPUXrDoYUL`) →
   **Cancel Sales Order** → *Pricing / Commercial Dispute*, *customer letter 25-Sep* → **Finish**.
2. As QA SalesBrandManager2, **Reject** the Opportunity approval. Open **Related → Credit Notes**.
3. **Resubmission:** as the rep, **Cancel Sales Order** again → **Finish**. Open **Related → Credit Notes**.

### Expected Result

The refund can be approved only as part of an approved cancellation; a rejected cancellation
rejects or withdraws its refund; one cancellation has at most one refund.

### Actual Result

Step 2: cancellation *Rejected*, SO *Generated* — **CN-00012 still Pending** (369,300, Refund), with
its approval item still in the approver's queue. Step 3: **CN-00016** created (369,300, Pending) —
*Credit Notes (2)*, two open refunds totalling **738,600** for one fully paid 369,300 order. (Same on
24-Sep: DEMO RS13 02 → CN-00005 and CN-00009; DEMO RS13 01 → CN-00003 *Approved, Finance Processing*
while the order was still *Generated*.)

### Root Cause

**Confirmed from the metadata.** `AF_FL_Opp_RequestCancellation` creates the credit note, which
`AF_FL_CreditNote_SubmitApproval` submits to `AF_AP_CreditNote_Cancellation`; the flow then
submits the Opportunity to `AF_AP_Opp_Cancellation`. Neither process's approval or rejection
actions touch the other record, and the request flow never checks for an existing open credit
note.

### Proposed Solution

Use one approval: create the credit note from the **Opportunity approval's final approval**
(or approve/reject it in the same step), cancel the open credit note on rejection, and block a new
credit note while one is open for the deal.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR3 — *"The system should support refund or credit-note handling for approved cancellations, according to the agreed finance policy."*
- **BRD** §10.13 ALF-RS-13, p.58, AC2 — *"Given a cancellation is approved, When the refund is initiated, Then the system generates the appropriate refund or credit note linked to the original deal."*

---

## BUG-RS13-03 (LFRDN-730) — The credit note is for the full deal value, not the amount the customer paid (Highest)

**Module:** Retail Sales — Credit Note amount
**Applies to:** General.

### Description

The credit note created by a cancellation always equals the **deal amount**. On a deal where the
customer paid only a 40,000 deposit, the refund request is for **369,300**. A credit note can also be
entered by hand for any amount — **999,999** on a deal paid 369,300 was accepted and sent for
approval. Nothing compares the refund with the payments received, and the approver is not shown
either figure.

### Steps to Reproduce

1. **DEMO RS13 03 - Deposit only, no Sales Order yet** (`006FV00Br6vxAuqYEE`): invoice **INVM-00097
   Partially Paid**, one payment of **40,000**. **Cancel Sales Order** → reason, evidence → **Finish**.
   Open the new credit note **CN-00004**.
2. App Launcher → **Credit Notes → New** → Account *DEMO RS13 Customer - Nasser Al-Mohannadi*,
   Opportunity *DEMO RS13 05*, Credit Note Amount **999999**, Refund Amount **999999**, Reason
   *Customer Request*, Evidence Reference → **Save**.

### Expected Result

The credit note amount is taken from, and cannot exceed, the verified payments received (40,000 for
DEMO RS13 03).

### Actual Result

CN-00004: **Credit Note Amount 369,300, Refund Amount 369,300**, Refund Path *Refund*. Step 2:
*Credit Note "CN-00008" was created.* — 999,999, Approval Status *Pending*, submitted to the approver.

**Re-confirmed 25-Sep:** **QA RT13 T3** (`006FV00BtPUc3MqYUJ`) — invoice **INVM-00113 Partially Paid,
40,000**; cancellation → **CN-00013 369,300 / 369,300**. The approver's page shows only the credit
note amount (*AED 369,300.00*), not what was paid.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Opp_RequestCancellation` → `Create_Credit_Note` sets
`AF_Amount__c` and `AF_RefundAmount__c` from `AF_Formula_CreditNoteAmount` =
`Get_Opportunity.Amount`. `AF_Payment__c` is not linked and `AF_InvoiceSummary__r.AF_PaidAmount__c`
is not read. `AF_CreditNote__c` has no validation rule on the amount.

### Proposed Solution

Default the amount from `AF_InvoiceSummary__r.AF_PaidAmount__c` (verified payments only) and add a
validation rule that the refund cannot exceed it; show paid amount and refund amount on the approval
page.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR3 — *"…refund or credit-note handling for approved cancellations, according to the agreed finance policy."*
- **BRD** §10.13 ALF-RS-13, p.57, Requirement Overview — *"…so that exceptions do not break financial and customer records."*

---

## BUG-RS13-04 (LFRDN-734) — Cancelling a delivered, Closed Won deal puts the car back on sale and leaves the deal Won (High)

**Module:** Retail Sales — Cancellation after delivery / Inventory
**Applies to:** General.

### Description

**Cancel Sales Order** is offered on a deal that is already **Closed Won** with the car
**delivered**, and it is processed like any other cancellation. After approval the Sales Order
reads *Cancelled*, but the deal stays **Closed Won** (still counted as a sale), and the car the
customer drove away with is marked **Available for Sale** again.

### Steps to Reproduce

1. **DEMO RS13 04 - Closed Won and delivered, then cancelled** (`006FV00Br6w1N3sYEE`): Stage Closed
   Won, Sales Order Status Delivered, Handover Completed.
2. **Show more actions ▾ → Cancel Sales Order** → reason, evidence → **Finish**.
3. Approve as an approver with access (QA SalesBrandManager2).
4. Open the Opportunity, and the vehicle **Ferrari 296 GTB - Rosso Scuderia RS13-04**
   (`0vLFV000593uevM2AQ`).

### Expected Result

Cancellation after delivery is either blocked or handled as a vehicle return (return evidence
required, stock not released until the car is back); the deal does not remain Closed Won.

### Actual Result

Step 2 is accepted (*"The cancellation request has been submitted…"*). After approval: Stage
**Closed Won**, SO Status **Cancelled**, reservation **RES-00198 Cancelled**, vehicle Reservation
Status **Available**, Availability **Available for Sale**, Inventory **In Stock**.

**Re-confirmed 25-Sep:** **QA RT13 T4** (`006FV00BtPUgFVsYUN`, Closed Won, SO *Delivered*, HO-00063
Completed): **Cancel Sales Order** offered and accepted; approved → SO **Cancelled**, stage **Closed
Won**, RES-00216 **Cancelled**, vehicle RT13-04 **Available / Available for Sale**; its credit note
CN-00014 approves (the deal is already closed, so BUG-RS13-11 does not block it).

### Root Cause

**Confirmed from the metadata.** `AF_FL_Opp_RequestCancellation` blocks only SO *Cancelled* or a
pending request — not *Delivered* or Closed Won. `AF_FL_Opp_CancellationReleaseReservation` cancels
every non-terminal reservation, so the vehicle is released; nothing changes the stage.

### Proposed Solution

Block the request when `AF_SOStatus__c = 'Delivered'` or `IsWon` (or route it to a separate
vehicle-return process); do not release stock for a delivered vehicle. The stage outcome after
cancellation is raised as a BA gap (report GAP-RS13-03).

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, Requirement Overview — *"…handle sales order cancellation and refund scenarios in a controlled way so that exceptions do not break financial and customer records."*
- **SD** §10 Handover, Delivery, Cancellation & Credit Note, p.74 — *"…the opportunity follows the Closed Lost path where applicable."*

---

## BUG-RS13-05 (LFRDN-735) — "Cancel Sales Order" runs on deals that have no Sales Order (Medium)

**Module:** Retail Sales — Sales Order Cancellation
**Applies to:** General.

### Description

The **Cancel Sales Order** action appears, and completes, on a deal whose Sales Order was never
generated. After approval the deal shows a Sales Order Status of **Cancelled** for an order that
never existed, and a full-value credit note (BUG-RS13-03).

### Steps to Reproduce

On **DEMO RS13 03** (SO Status *Not Generated*): **Show more actions ▾** — *Cancel Sales Order* is
listed → run it → approve.

### Expected Result

The action is hidden, or refuses, while the Sales Order is *Not Generated*; an unreserved/unordered
deal is closed through Closed Lost instead.

### Actual Result

Request accepted; after approval **SO Status Cancelled**, **CN-00004** 369,300, reservation
RES-00197 Cancelled.

**Re-confirmed 25-Sep:** the visibility filter on `Opportunity_Record_Page` is unchanged (`1 OR 2`).
**QA RT13 T3** (SO *Not Generated*): *Cancel Sales Order* listed, run, approved → SO **Cancelled**.

### Root Cause

**Confirmed from the FlexiPage metadata.** On `Opportunity_Record_Page`, the action's visibility is
`{!Record.AF_SOStatus__c} NE 'Cancelled'` **OR** `{!Record.AF_SOStatus__c} NE 'Not Generated'`
(`booleanFilter 1 OR 2`) — always true. The flow does not check *Not Generated* either.

### Proposed Solution

Change the filter to `1 AND 2`, and add the same check in `Is_Already_Cancelled_Or_Pending`.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR1 — *"The system should require a cancellation reason, supporting evidence, and management approval before a sales order cancellation is processed."*

---

## BUG-RS13-06 (LFRDN-731) — A Sales Representative can create an already-approved, "synced" credit note through the API (High)

**Module:** Retail Sales — Credit Note controls
**Applies to:** Persona-specific — `AF_PSG_Sales_Rep` grants Edit on the control fields; any group
with the same field access is affected. In the UI these fields are read-only on the page layout.

### Description

Through the API, the rep created a credit note that says it is **Approved**, **Finance
Completed**, **Synced** to Keyloop with a Keyloop reference — for 999,999, with no evidence and no
approval ever raised. In the UI the same fields are read-only, so the protection is only the page
layout.

### Steps to Reproduce

As the Sales Representative (REST, same user):
`POST /services/data/v68.0/sobjects/AF_CreditNote__c` with `AF_Opportunity__c` = DEMO RS13 05,
`AF_Account__c`, `AF_Amount__c` 999999, `AF_RefundPath__c` "Refund", `AF_Reason__c` "Customer
Request", `AF_ApprovalStatus__c` "Approved", `AF_FinanceStatus__c` "Completed", `AF_Synced__c` true,
`AF_IntegrationStatus__c` "Synced", `AF_KeyloopCreditNoteReference__c` "KL-FAKE-001".

### Expected Result

Rejected: a credit note can be created only as Pending and reach Approved only through the
approval process; Finance/Keyloop fields are set only by the integration.

### Actual Result

`{"id":"a0PFV00476cLXng2AG","success":true}` — **CN-00007**: Approved, Completed, Synced,
KL-FAKE-001, Evidence blank, **no ProcessInstance**. (The Opportunity-side equivalents are
correctly blocked: a pending Opportunity is locked, and self-approval returns
`INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY`.)

**Re-confirmed 25-Sep:** same POST as the rep on **QA RT13 T5** (`006FV00BtPUkReuYUF`) →
`{"id":"a0PFV0047kmoasm2AA","success":true}` — **CN-00017**: 999,999, Approved, Completed, Synced,
*KL-FAKE-RT13*, Evidence blank, **0** ProcessInstances. Opportunity controls still hold: PATCH on a
pending Opportunity → `ENTITY_IS_LOCKED`; self-approval → `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY`.

### Root Cause

**Confirmed.** `FieldPermissions` for `AF_PSG_Sales_Rep` grant Edit on
`AF_CreditNote__c.AF_ApprovalStatus__c`, `AF_FinanceStatus__c`, `AF_Synced__c`,
`AF_IntegrationStatus__c`, `AF_KeyloopCreditNoteReference__c`, `AF_ApprovalReference__c`.
`AF_FL_CreditNote_SetApprovalStatus` defaults only a **blank** status to Pending; there is no
validation rule like the Opportunity's `AF_VR_Opp_ApprovalStatusNoDirectSet`.

### Proposed Solution

Remove Edit on those fields from the business groups, and add a validation rule mirroring
`AF_VR_Opp_ApprovalStatusNoDirectSet` for `AF_CreditNote__c.AF_ApprovalStatus__c`.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR1 — *"…management approval before a sales order cancellation is processed."*
- **SD** §10, p.74 — *"AF_CreditNote__c -- Salesforce creates the refund/cancellation request, Keyloop/Finance processes it, Salesforce tracks status/outcome."*

---

## BUG-RS13-07 (LFRDN-736) — Supporting evidence is a free-text box — no document is required or attached (Medium)

**Module:** Retail Sales — Sales Order Cancellation
**Applies to:** General.

### Description

The cancellation screen asks for *Supporting Evidence Reference* as a line of text. Typing "see
customer email" is enough; no file is requested, attached or checked, on the request or on the
credit note.

### Steps to Reproduce

**Cancel Sales Order** on any eligible deal → Reason → *Supporting Evidence Reference*: `see customer
email` → **Next**.

### Expected Result

The rep attaches the evidence document (customer letter, bank decline, etc.), and the request cannot
be submitted without it.

### Actual Result

*"The cancellation request has been submitted to your manager for approval…"* — DEMO RS13 01,
evidence stored as the text *see customer email*; no file on the Opportunity or CN-00003.

**Re-confirmed 25-Sep:** the screen is unchanged — *Supporting Evidence Reference* is a text input;
*"see customer email 25-Sep"* accepted on QA RT13 T1 (`RETEST-2026-09-25-RS13/01-cancel-screen-text-evidence.png`).

### Root Cause

**Confirmed from the metadata.** `EvidenceReferenceField` is a required `InputField` of type String;
`AF_VR_CreditNote_EvidenceRequired` checks only that `AF_EvidenceReference__c` (Text) is not blank.
The field's own description says *"Actual file lives via ContentDocumentLink"* — nothing requires it.

### Proposed Solution

Add a file-upload component to the screen (or an `AF_Document__mdt` required-document row for
cancellations) and require at least one tagged file before submission.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR1 — *"The system should require a cancellation reason, supporting evidence, and management approval before a sales order cancellation is processed."*

---

## BUG-RS13-08 (LFRDN-737) — Approved credit notes are never sent to Keyloop (High)

**Module:** Retail Sales — Credit Note / Keyloop integration
**Applies to:** General.

### Description

After a cancellation and its credit note are approved, nothing is sent to Keyloop. The credit
note's *Integration Status* stays blank and *Synced?* unticked indefinitely; finance in Keyloop
never learns the customer is owed money.

### Steps to Reproduce

DEMO RS13 01 after approval: open **CN-00003** → *Keyloop Mirror* section.

### Expected Result

The approved credit note is sent to Keyloop through MuleSoft; Integration Status and the Keyloop
reference are updated from the response; failures are flagged.

### Actual Result

CN-00003: Approval **Approved**, Finance Status **Processing**, Integration Status **blank**,
Synced? **false**, Keyloop Credit Note Reference **blank** (checked 10:57 and 11:00 UTC).

**Re-confirmed 25-Sep:** **CN-00014** (QA RT13 T4) approved → Finance Status *Processing*,
Integration Status **blank**, Synced? **false**.

### Root Cause

**Confirmed from the metadata.** Searching the retrieved flows and the org's custom Apex, only
the five credit-note approval/notification flows, `AF_FL_Opp_RequestCancellation` and
`AF_DiscountApprovalController` (an approvals list component) reference `AF_CreditNote__c`; none
calls out. The org's only platform event is `AF_LeadChange__e`. The integration fields are plain
editable fields (see BUG-RS13-06).

### Proposed Solution

Publish an outbound event on credit-note approval for MuleSoft (as designed for TP-010) and write
back Integration Status / Keyloop reference; alert Finance on failure.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR4 — *"The system should generate a credit note after cancellation and sync it with Keyloop for processing."*
- **SD** §10, p.74, Integration design — *"Credit-note request/outcome (TP-010) … Bidirectional … Approved cancellation."*

---

## BUG-RS13-09 (LFRDN-738) — A second cancellation request overwrites the first, and no history of either is kept on the deal (Medium)

**Module:** Retail Sales — Cancellation audit trail
**Applies to:** General.

### Description

When a cancellation is rejected and requested again, the second request **overwrites** the first
reason and evidence on the deal, and no field history records either. The first request survives
only as a comment in Approval History. (The deal's *Credit Notes* list is on the page and lists
every credit note, but nothing ties each credit note to the request that raised it.)

### Steps to Reproduce

1. **QA RT13 T2** (`006FV00BtPUXrDoYUL`): first request *Pricing / Commercial Dispute* / *customer
   letter 25-Sep* → rejected by QA SalesBrandManager2 → second request *Customer Changed Mind* /
   *second request - customer email 25-Sep*.
2. Opportunity **Details** → *Cancellation* fields; **Related** → *Credit Notes*.

### Expected Result

Every request, its reason, evidence and outcome remain visible from the deal.

### Actual Result

*Cancellation Reason* **Customer Changed Mind**, *Evidence* **second request - customer email
25-Sep** — the first request's values are gone. `FieldDefinition` shows **no** history-tracked field
on Opportunity. *Credit Notes (2)*: CN-00012 and CN-00016, both Pending.

### Root Cause

**Confirmed.** `Update_Opportunity` in `AF_FL_Opp_RequestCancellation` overwrites
`AF_CancellationReason__c`, `AF_CancellationEvidenceReference__c` and `AF_CancellationNotes__c` on
each request; no Opportunity field is history-tracked.

### Proposed Solution

Keep one child record per request (reason, evidence, requester, outcome, linked credit note), or at
minimum track the cancellation fields' history.

### Reference

- **BRD** §10.13 ALF-RS-13, p.58, AC3 — *"Given a cancellation is processed, When any user views the original opportunity, Then the full history including the cancellation reason and outcome is visible."*
- **SD** §10, p.75, Exception handling — *"…disputed cancellations stay in approval with full history."*

---

## BUG-RS13-10 (LFRDN-739) — An administrator can delete the credit note and payments of a cancelled deal (Low)

**Module:** Retail Sales — Record retention
**Applies to:** System Administrator only. The Sales Representative cannot delete Opportunity,
Credit Note, Invoice Summary, Payment or Reservation (correct).

### Description

The requirement says records of a cancelled deal must not be deleted. The business rep cannot, but
an administrator can delete the deal's credit note and payments.

### Steps to Reproduce

As System Administrator on DEMO RS13 03 (cancelled): delete **CN-00004**; delete its payment.
(Restored from the Recycle Bin afterwards.)

### Expected Result

Deletion is prevented for all users, or at minimum blocked by a trigger on cancelled deals.

### Actual Result

Both deletes succeed (`Database.delete` → success). Deleting the Opportunity itself fails, but only
because the credit note's lookup blocks it (*"…associated with the following credit notes: CN-00004"*).

**Re-confirmed 25-Sep:** as System Administrator, inside a savepoint that was rolled back: delete
**CN-00014** (approved refund on cancelled QA RT13 T4) → success; delete **PAY-00086** (QA RT13 T3) →
success. No before-delete trigger exists on Credit Note, Payment, Invoice Summary or Reservation.
The Sales Representative and QA ShowroomManager2 are still refused (`INSUFFICIENT_ACCESS_OR_READONLY`).

### Root Cause

**Confirmed.** No before-delete trigger or validation exists on `AF_CreditNote__c` or `AF_Payment__c`.

### Proposed Solution

Before-delete triggers on `AF_CreditNote__c`, `AF_Payment__c`, `AF_InvoiceSummary__c` and
`AF_VehicleReservation__c` that refuse deletion when the Opportunity has a cancellation.

### Reference

- **BRD** §10.13 ALF-RS-13, p.58, FR5 — *"The system should retain the original opportunity, sales order, and all related records with full history after cancellation -- records must not be deleted."*
- **SD** §10, p.74 — *"…records are fully retained -- deletion is prohibited…"*

---

## BUG-RS13-11 (LFRDN-732) — Approving a refund fails on every open deal, so an approved cancellation can never be refunded (Highest)

**Module:** Retail Sales — Credit Note approval
**Applies to:** General — any cancellation on a deal that is not already Closed Won / Closed Lost.

### Description

After a cancellation is approved, its credit note (the customer's refund) goes to the approver. On
any deal that is still open — every cancellation before delivery — clicking **Approve** on the
credit note fails with a raw system error and the refund stays *Pending*. There is no other way to
approve it, so the customer's money cannot be released.

### Steps to Reproduce

1. As the Sales Representative, **QA RT13 T7** (`006FV00BtPUspwyYUB`, SO *Generated*, fully paid) →
   **Show more actions ▾ → Cancel Sales Order** → reason, evidence → **Next** → **Finish**.
2. Log in as QA SalesBrandManager2 → approve the **Opportunity** cancellation (SO becomes *Cancelled*).
3. Open the credit note approval **CN-00015** → **Approve** → Comments → **Approve**.

### Expected Result

The refund is approved and handed to Finance / Keyloop.

### Actual Result

Step 3:

> error occurred when the flow tried to update records: FIELD_CUSTOM_VALIDATION_EXCEPTION: Closed Lost can only be reached through the approved Request Closure process, not by editing Stage directly.. You can look up ExceptionCode values in the SOAP API Developer Guide.

CN-00015 stays **Pending**. Same on **QA RT13 T1** (CN-00011, cancellation still pending). Only a
refund on an already-closed deal approves (CN-00014 on Closed Won QA RT13 T4).

### Root Cause

**Confirmed from the metadata.** `AF_FL_CreditNote_Approved` v2 (deployed 24-Sep 17:05 UTC under
LFRDN-725) adds `Update_Opportunity_Closed`, which sets `StageName = 'Closed Lost'` whenever the
Opportunity is not already closed. `AF_VR_Opp_LostApprovalRequired` rejects Closed Lost unless
`AF_LostApprovalStatus__c = 'Approved'` (the Request Closure approval), so the update fails and rolls
back the approval.

### Proposed Solution

1. Set the Opportunity's outcome from the **Opportunity cancellation approval** rather than the credit
   note, and let that path satisfy the Closed Lost rule — e.g. set `AF_LostApprovalStatus__c` and a
   Lost Reason in the same update, or exempt approved cancellations in `AF_VR_Opp_LostApprovalRequired`.
2. Add a fault path so the approver sees a plain message, never the raw exception.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR3 — *"The system should support refund or credit-note handling for approved cancellations, according to the agreed finance policy."*
- **BRD** §10.13 ALF-RS-13, p.58, AC2 — *"Given a cancellation is approved, When the refund is initiated, Then the system generates the appropriate refund or credit note linked to the original deal."*

---

## BUG-RS13-12 (LFRDN-740) — A cancelled Sales Order can still be handed over and the deal closed as Won (Highest)

**Module:** Retail Sales — Cancellation / Handover / Deal completion
**Applies to:** General.

### Description

Once a cancellation is approved the Sales Order reads *Cancelled*, the reservation is cancelled and
the car goes back on sale — but the deal stays open at its stage and every later step still works.
The rep moved the cancelled deal to *Take the Keys*, a handover was created, and on sign-off the deal
closed **Won** and **Delivered** — for a car already released to other buyers, with the customer's
refund still pending.

### Steps to Reproduce

1. **QA RT13 T7** (`006FV00BtPUspwyYUB`) after its cancellation was approved (SO *Cancelled*,
   RES-00219 *Cancelled*, vehicle RT13-07 *Available*, CN-00015 *Pending*).
2. As the Sales Representative: **Path → Mark Stage as Complete** → *Take the Keys*.
3. Open the new Handover **HO-00064** → complete the checklist (the three document flags were set by
   an administrator, as the rep cannot) → **Edit** → *Customer Sign-Off* **Physically Signed** → **Save**.
4. Open the Opportunity.

### Expected Result

A deal whose Sales Order is Cancelled cannot move forward — no Take the Keys, no handover, no
Closed Won — and is closed through the cancellation outcome instead.

### Actual Result

Step 2: *"Stage changed successfully."* — HO-00064 created. Step 3: *saved*. Step 4: **Closed Won**,
*Sales Order Status* **Cancelled**, *Handover Complete* ✓, *Delivery Confirmation* ✓, *Cancellation
Approval Status* **Approved**. The invoice INVM-00116 still reads **Fully Paid** (369,300), which is
what lets the payment gates pass. (Regenerating the Sales Order on the cancelled deal is correctly
refused: *"there is no active Reserved reservation"*.)

### Root Cause

**Confirmed from the metadata.** Nothing reads `AF_SOStatus__c = 'Cancelled'` or
`AF_CancellationApprovalStatus__c = 'Approved'` after approval: `AF_VR_Opp_TakeTheKeysGate` checks
only the Invoice Summary, `AF_FL_Opp_CreateHandoverOnTakeTheKeys` has no status condition, and
`AF_VR_Opp_ClosedWonGate` / `AF_FL_Handover_AutoCloseWon` check the handover and balance only. The
approved cancellation changes neither the stage nor the invoice.

### Proposed Solution

1. Block Take the Keys, handover creation and Closed Won while `AF_SOStatus__c = 'Cancelled'` or a
   cancellation is pending.
2. Close the deal as part of the approved cancellation (see BUG-RS13-11) so it cannot be progressed.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, Requirement Overview — *"…handle sales order cancellation and refund scenarios in a controlled way so that exceptions do not break financial and customer records."*
- **SD** §10 Handover, Delivery, Cancellation & Credit Note, p.74 — *"…the opportunity follows the Closed Lost path where applicable."*

---

## BUG-RS13-13 (LFRDN-741) — Credit notes are visible to, and editable by, every business unit (High)

**Module:** Retail Sales — Credit Note / Security model
**Applies to:** General — every persona with Credit Note object access. Reproduced as QA
ShowroomManager2 (Showroom Manager – Alsadd, **Automobiles**) against **Sports Motors** deals.

### Description

The Alsadd (Automobiles) Showroom Manager cannot open the Sports Motors deals — correctly — but can
list, open and edit their credit notes: the customer's name, the refund amount, the reason and the
evidence reference. Handover, invoice, payment and reservation records were made private on 24-Sep
(LFRDN-709); credit notes were left public.

### Steps to Reproduce

1. Log in as `alfardan.qa.showroommanager2@alfardan.com.qa.qa`.
2. Open credit note **CN-00013** (`a0PFV0047jufsKy2AI`, deal QA RT13 T3, Alfardan Sports Motors).
3. Via REST as the same user: `SELECT COUNT() FROM AF_CreditNote__c`; `PATCH` an unlocked credit note
   (CN-00017, `a0PFV0047kmoasm2AA`).

### Expected Result

A user outside the deal's business unit and role hierarchy cannot see or change its credit notes,
exactly as they cannot see the deal.

### Actual Result

Step 2: the credit note opens with **Edit** — Account *QA RT13 Customer - Aisha Al-Kuwari*, Credit
Note Amount *AED 369,300.00*, Evidence *bank decline letter*; the *Opportunity* field is blank to them
because they cannot see the deal. Step 3: **18** credit notes returned (every one in the org); PATCH
on CN-00017 → **HTTP 204**, *Last Modified By* QA ShowroomManager2. (Credit notes locked in a pending
approval return `ENTITY_IS_LOCKED`; delete is refused.)

### Root Cause

**Confirmed from the org settings.** `EntityDefinition.InternalSharingModel` for `AF_CreditNote__c` is
**ReadWrite** (Public Read/Write), while Opportunity, Handover, Invoice Summary, Payment and
Reservation are Private. `AF_ChildRecordSharingService` does not cover `AF_CreditNote__c`.

### Proposed Solution

Set `AF_CreditNote__c` to **Private** and add it to `AF_ChildRecordSharingService` with the same
business-unit / showroom shares as the other four child objects (plus the Opportunity owner — see
BUG-RS13-14).

### Reference

- **BRD** §7 Cross-Cutting Requirements, p.10, item 1 — *"Customer profile visibility is shared at account level, while opportunities, cases, service appointments, quotations, and other transactional records remain segregated by business unit, brand and department as per the security model."*
- **SD** §10 Handover, Delivery, Cancellation & Credit Note, p.75, Security and access impact — *"Handover and credit-note records are segregated to the deal's business unit."*

---

## BUG-RS13-14 (LFRDN-733) — A deal owner outside the business-unit sharing group cannot see their own invoice, so their cancellation fails (Medium)

**Module:** Retail Sales — Sales Order Cancellation / Record sharing
**Applies to:** Configuration-dependent — any Opportunity owner who is not a member of the matching
`AF_G_BU_*` group or showroom role group. Reproduced for QA ShowroomManager2 on an Alfardan
Automobiles deal (the `AF_G_BU_Automobiles` group has no members in QA).

### Description

A Showroom Manager who owns a deal clicked **Cancel Sales Order** and got a raw system error; no
request or credit note was created. They own the deal but cannot see its invoice or payments,
because those records are shared only with the business-unit and showroom groups — never with the
deal's owner.

### Steps to Reproduce

1. Log in as `alfardan.qa.showroommanager2@alfardan.com.qa.qa`.
2. Open **QA RT13 T6 - Showroom Manager deal, Automobiles** (`006FV00BtPUodnwYUB`, owner QA
   ShowroomManager2, fully paid, SO *Generated*) → **Show more actions ▾ → Cancel Sales Order** →
   *Customer Changed Mind*, evidence → **Next**.

### Expected Result

The owner of a deal can raise its cancellation.

### Actual Result

> Something went wrong — We couldn't complete this action… This error occurred when the flow tried to create records: INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY: insufficient access rights on cross-reference id

As the same user, `SELECT … FROM AF_InvoiceSummary__c WHERE AF_Opportunity__c = '006FV00BtPUodnwYUB'`
and the same on `AF_Payment__c` return **0 rows**. INVM-00117 is owned by the integration user and
shared only with `AF_G_BU_Automobiles` (Edit), which has no members.

### Root Cause

**Confirmed.** `AF_FL_Opp_RequestCancellation` → `Create_Credit_Note` sets `AF_InvoiceSummary__c`
from the Opportunity, so the user must be able to see that invoice. `AF_ChildRecordSharingService`
(LFRDN-709) shares child records with the business-unit and showroom role groups only; the
Opportunity owner gets no share, so owning the deal no longer gives access to its invoice, payments,
reservation or handover.

### Proposed Solution

Also share each child record with the Opportunity **owner** (and re-share on owner change), so access
does not depend on group membership; confirm the `AF_G_BU_*` groups are populated in every
environment.

### Reference

- **BRD** §10.13 ALF-RS-13, p.57, FR1 — *"The system should require a cancellation reason, supporting evidence, and management approval before a sales order cancellation is processed."*
- **BRD** §7 Cross-Cutting Requirements, p.10, item 1 — records remain *"segregated by business unit, brand and department as per the security model"* — segregation that must still give the deal's own owner access.
