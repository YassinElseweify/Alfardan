# [ALF-RS-13] Sales Order Cancellation and Refund Handling — QA report

**Tested:** 2026-09-24
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Personas used:** Sales Representative (QA SalesRep2, Sales Rep – SportsMotors) for requests; QA ShowroomManager2 (Showroom Manager – Alsadd, the rep's *Manager* field) and QA SalesBrandManager2 (Sales Manager – SportsMotors) as approvers. System Administrator for setup, reassignment and controls.
**Harnesses:** Lightning UI via Playwright as each persona (primary) · REST API v68.0 as each persona · `sf` CLI for metadata and admin Apex
**Test cases:** 10 written + 3 added, in `test-cases/ALF_Retail_RS-08_to_RS-16_Test_Cases.xlsx`
**Tickets:** `tickets/ALF-RS-13/README.md` · **Screenshots:** `screenshots/ALF-RS-13/`

---

## Section 1 — Summary of what was done

ALF-RS-13 covers cancelling a sale after the Sales Order: the rep asks, management approves, the
customer's money is refunded or kept as credit through a credit note sent to Keyloop, and every
record is kept.

**The journey in the org:** Opportunity header **Show more actions ▾ → Cancel Sales Order** runs a
screen flow that asks for a reason (7 choices), a *Supporting Evidence Reference* (text) and notes;
it marks the deal *Cancellation Pending*, creates a **Credit Note** for the deal amount with Refund
Path *Refund*, and submits **two separate approvals** — one for the Opportunity, one for the Credit
Note — both to the rep's *Manager* field. Approving the Opportunity sets Sales Order Status
*Cancelled*, cancels the reservation (releasing the vehicle) and denies the quote. Approving the
Credit Note sets Finance Status *Processing*. There is no Keyloop call.

I built six deals through the cycle's states (**DEMO RS13 01–06**: synced quote, auto-confirmed
reservation, auto-created invoice, verified payment, Sales Order; 03 deposit-only; 04 Closed Won and
delivered), then ran every request in the Lightning UI as the rep and every decision in the UI as the
approvers. The rep's assigned approver could not act on any of them (**BUG-RS13-01**), so to test the
rest of the process an administrator reassigned the Opportunity approvals to the SportsMotors Sales
Manager, who sits above the rep in the role hierarchy.

| | |
|---|---|
| Test cases executed | **17** (10 written + 7 added) — first run 24-Sep, full re-run 25-Sep |
| Passed / Failed / Partial / Blocked (25-Sep) | 2 / 11 / 2 / 2 |
| Bugs raised | **14** — BUG-RS13-01 … 14, see `tickets/ALF-RS-13/README.md` |
| BA / requirement gaps raised | **6** |

**Headline verdict (re-run 25-Sep): the cancellation itself works; the refund is now blocked, and a
cancelled order can still be sold.** When the approver approves, the order is cancelled, the vehicle
released and the quote denied — cleanly, and since LFRDN-707 the rep's requests reach an approver who
can see them. But approving the refund now fails on every open deal with a raw error
(**BUG-RS13-11**, from the LFRDN-725 change), so no pre-delivery cancellation can be refunded; the
cancelled deal can still be taken to Take the Keys and closed **Won** while its car is back on sale
(**BUG-RS13-12**); credit notes are open to every business unit (**BUG-RS13-13**); the refund is a
separate approval that stays pending after a rejection and is duplicated on resubmission
(**BUG-RS13-02**); its amount is the deal value, not what was paid — 369,300 against a 40,000 deposit
(**BUG-RS13-03**); a delivered car is put back on sale (**BUG-RS13-04**); and the rep can create an
approved, "synced" credit note through the API (**BUG-RS13-06**). Nothing reaches Keyloop
(**BUG-RS13-08**).

What works: blank reason/evidence are blocked; a pending request locks the Opportunity and credit
note; the rep cannot approve their own request; the rep cannot delete any of the deal's records;
the stock release and quote denial on approval; the rejected order stays active with its stock held.

**Note on test data:** on 24-Sep the rep's Manager field pointed at QA ShowroomManager2 (set during
10-Sep QA setup), which is how BUG-RS13-01 first showed. The Manager was corrected to QA
SalesBrandManager2 under LFRDN-707, so the rep's own requests now route correctly; the mechanism —
routing by the Manager field, which does not grant record access — remains, and QA ShowroomManager2's
Manager still sits in another business unit (BUG-RS13-01, configuration-dependent).

### Re-run — 2026-09-25

**Why:** on 24-Sep, after the first run, the build team changed the Opportunity page and layout (a
Credit Notes list), the sharing model of Handover / Invoice / Payment / Reservation (LFRDN-709, new
`AF_ChildRecordSharingService`), QA SalesRep2's Manager (LFRDN-707), and `AF_FL_CreditNote_Approved`
(LFRDN-725: approving a credit note now sets the Opportunity to Closed Lost).
`AF_FL_Opp_RequestCancellation`, both approval processes and the Cancel action's visibility filter
are unchanged.

**How:** seven new deals **QA RT13 T1–T7** (customer *QA RT13 Customer - Aisha Al-Kuwari*), built to
the same states as DEMO RS13 01–06, plus **T6** owned by QA ShowroomManager2 on an Alfardan
Automobiles (Rolls-Royce) deal and **T7** for the path after an approved cancellation. Every request
was raised in the Lightning UI as the rep (T6 as QA ShowroomManager2), every decision in the UI as QA
SalesBrandManager2; screenshots in `screenshots/RETEST-2026-09-25-RS13/`.

| Ticket | 25-Sep result | Evidence |
|---|---|---|
| BUG-RS13-01 | **Still present, configuration-dependent.** Rep → QA SalesBrandManager2 now works; QA ShowroomManager2 → QA SalesBrandManager2, who cannot read the Automobiles deal T6 (0 rows). Priority lowered to Medium. | T1–T4, T7 routing; T6 |
| BUG-RS13-02 | **Still present.** T2 rejected → CN-00012 Pending; resubmitted → CN-00016 — two 369,300 refunds. | T2 |
| BUG-RS13-03 | **Still present.** T3 paid 40,000 → CN-00013 369,300. | T3 |
| BUG-RS13-04 | **Still present.** T4 Closed Won + Delivered → cancelled; car *Available for Sale*, stage Closed Won. | T4 |
| BUG-RS13-05 | **Still present.** Filter still `1 OR 2`; T3 (no SO) → SO *Cancelled*. | T3 |
| BUG-RS13-06 | **Still present.** Rep REST → CN-00017 Approved / Completed / Synced, 999,999, no approval. | T5 |
| BUG-RS13-07 | **Still present.** Evidence is text. | T1 |
| BUG-RS13-08 | **Still present.** CN-00014 approved → Integration Status blank, Synced false. | T4 |
| BUG-RS13-09 | **Partly fixed.** *Credit Notes* related list now on the Opportunity (fixed); first request's reason/evidence still overwritten, no history tracking (still present). | T2 |
| BUG-RS13-10 | **Still present.** Admin delete of CN-00014 and PAY-00086 succeeds (rolled back). | T3, T4 |
| **BUG-RS13-11 (new)** | Approving a refund on an open deal fails: *"FIELD_CUSTOM_VALIDATION_EXCEPTION: Closed Lost can only be reached through the approved Request Closure process…"* — LFRDN-725's Closed Lost update vs `AF_VR_Opp_LostApprovalRequired`. | T1 (CN-00011), T7 (CN-00015) |
| **BUG-RS13-12 (new)** | Cancelled T7 → *Take the Keys* → HO-00064 → sign-off → **Closed Won**, SO still *Cancelled*, car on sale. | T7 |
| **BUG-RS13-13 (new)** | QA ShowroomManager2 (Automobiles) reads all 18 credit notes, opens Sports Motors CN-00013, edits CN-00017 (204). Credit Note OWD still Public Read/Write. | CN-00013, CN-00017 |
| **BUG-RS13-14 (new)** | T6 owner QA ShowroomManager2 → *Cancel Sales Order* → raw `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY`; owner cannot see the deal's invoice/payments (shared only to empty `AF_G_BU_Automobiles`). | T6 |

**Added test cases (25-Sep):**

| TC | What it tests | Result | Finding |
|---|---|---|---|
| CYC-RS13-04 | Approve the refund after an approved cancellation | **FAIL** | Raw validation error, refund stays Pending (**BUG-RS13-11**). |
| CYC-RS13-05 | A cancelled order cannot be progressed (regenerate SO, Take the Keys, Closed Won) | **FAIL** | Regenerate SO refused (pass); Take the Keys, handover and Closed Won all allowed (**BUG-RS13-12**). |
| CYC-RS13-06 | Credit notes segregated by business unit | **FAIL** | Readable and editable across business units (**BUG-RS13-13**). |
| CYC-RS13-07 | A deal owner in another business unit can cancel their own deal | **FAIL** | Raw error; owner cannot see own invoice (**BUG-RS13-14**). |

Also observed (not raised separately): after an approved cancellation the invoice still reads
**Fully Paid** and the payments still count as received — no refund is reflected on the invoice
(feeds BUG-RS13-12 and GAP-RS13-02).

What still works (25-Sep): blank reason/evidence blocked; pending records locked (`ENTITY_IS_LOCKED`);
rep self-approval refused; rep and other-BU users cannot delete credit notes; approval of the
cancellation cancels the SO, releases the car and denies the quote; a rejected cancellation leaves the
order and stock intact; the Credit Notes list is now on the deal.

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Finding |
|---|---|---|---|
| RS-13-TC-001 | Reason, evidence and approval required; pending lock; Cancelled only after approval | **FAIL** | Blank submit blocked on both fields (pass, `01-…`). Evidence is text only — *see customer email* accepted (**BUG-RS13-07**, `02-…`). Pending locks the record (pass). Assigned approver cannot approve (**BUG-RS13-01**, `06-…`). After reassignment, approval sets SO *Cancelled* with approver and time in Approval History (pass). |
| RS-13-TC-002 | Approval routing by value / brand / BU; finance involvement | **Blocked** (observed) | Every request, at every value, goes to one approver — the submitter's Manager field. No value tiers, no Finance step. Needs the authority matrix (GAP-RS13-01). |
| RS-13-TC-003 | Refund vs credit note; choice; Keyloop sync; retained credit | **Blocked** (observed) | Always a credit note, Refund Path hard-coded *Refund*, no choice or retained-credit path (GAP-RS13-02). No Keyloop sync (**BUG-RS13-08**). |
| RS-13-TC-004 | Vehicle stock released after cancellation | **PARTIAL** | RES-00195 (Converted) → *Cancelled*; vehicle *Available / Available for Sale* (pass). No notification to the ordering team. Wrongly also releases a **delivered** car (**BUG-RS13-04**). |
| RS-13-TC-005 | Records retained; history visible; no deletion | **PARTIAL** | All records retained and linked (pass). Rep delete refused on Opp, Credit Note (pass). Admin deleted CN-00004 and a payment (restored) (**BUG-RS13-10**). History overwritten (**BUG-RS13-09**); the Credit Notes list, missing on 24-Sep, is on the deal since the 24-Sep layout change. |
| RS-13-TC-006 | Credit note amount for deposit-only, full payment, trade-in | **FAIL** | Deposit-only DEMO RS13 03 (40,000 paid) → CN-00004 **369,300**. Manual CN-00008 **999,999** on a 369,300 deal accepted (**BUG-RS13-03**). Trade-in case not built (GAP-RS13-04). |
| RS-13-TC-007 | Rejected request leaves the order active and recoverable | **FAIL** | Rejection: SO stays *Generated*, stock held, stage unchanged (pass). Its credit note CN-00005 stays *Pending*; a second request adds CN-00009 — two 369,300 refunds (**BUG-RS13-02**). |
| RS-13-TC-008 | Cancellation at On Order / after delivery / after Closed Won | **FAIL** | Delivered Closed Won DEMO RS13 04: request offered and approved; SO *Cancelled*, stage **Closed Won**, car **Available for Sale** (**BUG-RS13-04**, `03-…`, `11-…`). Deal stage never changes on cancellation (GAP-RS13-03). |
| RS-13-TC-009 | Keyloop credit-note sync, failure and replay | **FAIL** | No integration exists; approved CN-00003 stays Integration Status blank, Synced false (**BUG-RS13-08**). Failure/replay not testable. |
| RS-13-TC-010 | Rep cannot self-approve, edit status, or create a credit note without approval | **FAIL** | Self-approval → `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` (pass); pending Opp and CN locked (pass); UI fields read-only (pass). REST: rep created **CN-00007 Approved / Completed / Synced / KL-FAKE-001**, 999,999, no approval (**BUG-RS13-06**). |
| CYC-RS13-01 *(added)* | Cancel Sales Order on a deal with no Sales Order | **FAIL** | Offered and processed on DEMO RS13 03 → SO "Cancelled" (**BUG-RS13-05**). |
| CYC-RS13-02 *(added)* | The assigned approver can act on the request | **FAIL** | Alsadd Showroom Manager: details panel error, Approve does nothing; API `INSUFFICIENT_ACCESS`; can approve the credit note (**BUG-RS13-01/-02**). |
| CYC-RS13-03 *(added)* | Control — approval by a manager with access | **PASS** | QA SalesBrandManager2 approved DEMO RS13 01: SO *Cancelled*, cancellation *Approved*, RES-00195 *Cancelled*, vehicle *Available*, Quote 00000203 *Denied*. |

### Not independently verified

- **Keyloop failure/replay (TC-009)** — no integration to fail.
- **Trade-in funded cancellation (TC-006 Order C)** — no defined treatment; not built (GAP-RS13-04).
- **Real email/notification delivery** to approvers — the flows send email and bell notifications; only the *Approval Needed* email activity on CN-00008 was seen.
- **Ordering-team alert on stock release (TC-004 step 5)** — none exists to verify.

---

## Section 3 — BA / requirement gaps to raise

### GAP-RS13-01 — No cancellation authority matrix
**BRD** p.57 FR2: *"…aligned to the cancellation authority matrix."* p.58 Assumption 1: *"Cancellation policy, supporting documents, and approval authority to be provided by the business and finance team."* **SD** p.74: *"matrix Pending customer confirmation"*. The build uses one step to the submitter's Manager for every amount. **Decision needed (Alfardan finance):** the matrix — by value, brand, business unit, and whether Finance approves refunds.

### GAP-RS13-02 — Refund or credit note, and retained credit
**BRD** p.57 Overview: *"Customers may retain funds as credit for another vehicle."* FR3: *"refund or credit-note handling … according to the agreed finance policy."* FR4: *"generate a credit note after cancellation."* The build always creates a credit note with Refund Path *Refund*; *Credit Retained* exists on the field but is never offered, and nothing tracks retained credit. **Decision needed:** when refund vs retained credit, who chooses, how retained credit is consumed.

### GAP-RS13-03 — What happens to the deal, and after delivery / invoicing
The BRD does not say what stage a cancelled deal takes; **SD** p.74: *"the opportunity follows the Closed Lost path where applicable"*. It does not define cancellation after delivery (vehicle return) or after the Keyloop invoice (reversal). The build leaves the stage unchanged. **Decision needed:** stage outcome; whether post-delivery cancellation is a separate return process.

### GAP-RS13-04 — Trade-in funded deals
A trade-in used as deposit (ALF-RS-08 FR11) cannot be refunded as cash. No requirement covers it. **Decision needed:** return of the trade-in vehicle vs cash equivalent.

### GAP-RS13-05 — Cancellation fees / deductions
No fee or deduction policy exists. **Decision needed.**

### GAP-RS13-06 — Two different reason lists
The request screen offers 7 reasons (*Customer Changed Mind, Financing Fell Through, Vehicle Delivery Delay, Trade-In Issue, Duplicate Order, Pricing / Commercial Dispute, Other*); the credit note's *Cancellation / Refund Reason* has 5 different values, its description reads *"Placeholder value list — final policy-driven list pending client"*. **Decision needed:** one agreed list.

---

## Section 4 — Walkthrough by functional requirement and acceptance criterion

Log in as the Sales Representative (**Cancel** the password screen), Automotive app.

### FR1 / AC1 — reason, evidence, management approval — **Fail**
1. **DEMO RS13 01** (`006FV00Br6vomcmYEA`, fully paid, SO *Generated*) → **Show more actions ▾ → Cancel
   Sales Order** → **Next** empty → *"Please select a choice."* / *"Please enter some valid input.
   Input is not optional."* (`01-…`) — pass.
2. Reason *Customer Changed Mind*, Evidence **see customer email** → **Next** → *"The cancellation
   request has been submitted to your manager for approval. A credit note has been created…"*
   (`02-…`). **No document was needed — BUG-RS13-07.**
3. Opportunity: Cancellation *Pending*; REST PATCH of SO status / approval / reason →
   `ENTITY_IS_LOCKED` — pass. Rep self-approval → `INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY` — pass.
4. Log in as **QA ShowroomManager2** → the request → *"Looks like there's a problem. Another user
   recalled or responded to this request."*; **Approve** does nothing (`06-…`). **BUG-RS13-01.**
5. Admin reassigned to **QA SalesBrandManager2** → **Approve** → SO *Cancelled* (`07-…` shows what
   that approver sees: reason, evidence text, notes — no amounts).

### FR2 — authority matrix — **Blocked** (GAP-RS13-01)
All four requests went to QA ShowroomManager2 regardless of amount or stage.

### FR3 / AC2 — refund or credit note for approved cancellations — **Fail**
- **CN-00003** (DEMO RS13 01) approved by QA ShowroomManager2 **while the order was still pending** —
  **BUG-RS13-02**.
- **DEMO RS13 02** (`006FV00Br6vsyloYEA`): rejected → CN-00005 stays *Pending*; rep requests again →
  CN-00009 — two refunds — **BUG-RS13-02**.
- **DEMO RS13 03** (`006FV00Br6vxAuqYEE`, 40,000 paid, no Sales Order): *Cancel Sales Order* offered
  (**BUG-RS13-05**) → CN-00004 **369,300** (`09-…`) — **BUG-RS13-03**.
- **Credit Notes → New** (App Launcher) → 999,999 on DEMO RS13 05 → *CN-00008 was created* (`04/05-…`)
  — **BUG-RS13-03**. Via REST the rep created **CN-00007 Approved/Synced** — **BUG-RS13-06**.

### FR4 — credit note synced with Keyloop — **Fail**
CN-00003 after approval: Integration Status blank, Synced? false — **BUG-RS13-08**.

### FR5 / AC3 — retain records and full history — **Partial**
- Rep cannot delete Opportunity or Credit Note (pass). Admin deleted CN-00004 and a payment,
  restored — **BUG-RS13-10**.
- DEMO RS13 02's second request overwrote the first reason and evidence; the Opportunity's Credit
  Notes related list does not exist (`08-…`) — **BUG-RS13-09**.

### Cross-cutting — cancellation after delivery (TC-008)
**DEMO RS13 04** (`006FV00Br6w1N3sYEE`, Closed Won, Delivered): *Cancel Sales Order* offered (`03-…`),
approved → Stage **Closed Won**, SO **Cancelled**, vehicle RS13-04 **Available for Sale** (`11-…`) —
**BUG-RS13-04**.

---

## Section 5 — Hands-on: run ALF-RS-13 yourself

### What this story is, and how it is built

Cancellation starts from the Opportunity's **Cancel Sales Order** action. It creates a Credit Note
(App Launcher → **Credit Notes**) and two approval requests. The Opportunity approval is what cancels
the order; the Credit Note approval only marks the refund *Processing*. Approvers act from the bell
notification or **Items to Approve**.

### Records created for you

All owned by **QA SalesRep2**, customer **DEMO RS13 Hands-on Customer - Latifa Al-Sulaiti**, at
**Commit**; search **DEMO RS13 H**.

| Record | Id | State | Use it for |
|---|---|---|---|
| DEMO RS13 H01 - Cancel a fully paid order (main walkthrough) | `006FV00Bqzpzdq8YEA` | 369,300 paid, SO Generated | FR1–FR5, AC1–AC3 |
| DEMO RS13 H02 - Deposit only, no Sales Order | `006FV00Bqzq3pzAYEQ` | 40,000 paid, SO Not Generated | BUG-RS13-03, -05 |
| DEMO RS13 H03 - Delivered and Closed Won, then cancelled | `006FV00Bqzq828CYEQ` | Closed Won, SO Delivered | BUG-RS13-04 |
| DEMO RS13 H04 - Rejected, then requested again | `006FV00BqzqCEHEYE4` | 369,300 paid, SO Generated | BUG-RS13-02, -09 |

### What to do, step by step

**H01 — the main path**
1. As the rep: **Show more actions ▾ → Cancel Sales Order** → **Next** with nothing filled. *Expect
   and see:* both fields refused.
2. Reason *Customer Changed Mind*, Evidence any text → **Next** → **Finish**. *Expect:* a document
   upload. *You will see:* text accepted (BUG-RS13-07).
3. Try **Edit** on the Opportunity. *Expect and see:* locked while pending.
4. Log in as `alfardan.qa.salesbrandmanager2@…` (the rep's Manager). **Items to Approve** shows
   **two** requests — the Opportunity and a **CN-…** credit note (BUG-RS13-02). Approve the
   **Opportunity** one. *Expect and see:* SO *Cancelled*, reservation *Cancelled*, vehicle RS13-H01
   *Available*, quote *Denied*; stage unchanged (GAP-RS13-03).
5. Approve the **CN-…** request. *Expect:* refund approved. *You will see:* *"FIELD_CUSTOM_VALIDATION_EXCEPTION:
   Closed Lost can only be reached through the approved Request Closure process…"* — it stays
   Pending (BUG-RS13-11).
6. Back as the rep on H01: **Path → Mark Stage as Complete**. *Expect:* refused — the order is
   cancelled. *You will see:* *Take the Keys* and a new Handover (BUG-RS13-12).
7. Opportunity **Related → Credit Notes** lists the credit note (fixed 24-Sep); open it: Integration
   Status blank (BUG-RS13-08).

**H02 — deposit only**: *Cancel Sales Order* is in the menu although no Sales Order exists
(BUG-RS13-05); submit → the credit note is **369,300** against **40,000** paid (BUG-RS13-03).

**H03 — delivered**: *Cancel Sales Order* is offered on a Closed Won, delivered deal; after approval
the car shows *Available for Sale* and the deal stays Closed Won (BUG-RS13-04).

**H04 — reject and retry**: submit (reason A); have it rejected; the credit note stays *Pending*;
submit again (reason B) → a second credit note; the Opportunity now shows only reason B
(BUG-RS13-02, -09).

### Scorecard — fill in as you go

| # | Check | Expected | Actual (fill in) | Ticket if it fails |
|---|---|---|---|---|
| 1 | Blank reason/evidence refused | Refused | | — |
| 2 | Evidence needs a document | Required | | BUG-RS13-07 |
| 3 | Assigned approver can see and approve | Yes | | BUG-RS13-01 |
| 4 | One approval covers cancellation and refund | One request | | BUG-RS13-02 |
| 5 | Approval cancels SO, releases car, denies quote | Yes | | — |
| 6 | Credit note = amount paid | 40,000 on H02 | | BUG-RS13-03 |
| 7 | Cancel hidden when no Sales Order | Hidden | | BUG-RS13-05 |
| 8 | Delivered car not put back on sale | Held | | BUG-RS13-04 |
| 9 | Rejection withdraws the refund; no duplicate on retry | One | | BUG-RS13-02 |
| 10 | Credit note sent to Keyloop | Synced | | BUG-RS13-08 |
| 11 | Both requests' reasons visible on the deal after a retry | Visible | | BUG-RS13-09 |
| 12 | Refund approves after the cancellation is approved | Approved | | BUG-RS13-11 |
| 13 | Cancelled deal cannot go to Take the Keys / Closed Won | Refused | | BUG-RS13-12 |
| 14 | Another business unit cannot open your credit notes | No access | | BUG-RS13-13 |

---

## Records left in the org as evidence

| Record | State | Evidence for |
|---|---|---|
| DEMO RS13 01 / CN-00003 | Cancelled via reassigned approval; CN approved before the order | BUG-RS13-01, -02, -08 |
| DEMO RS13 02 / CN-00005, CN-00009 | Rejected then resubmitted; two pending credit notes | BUG-RS13-02, -09 |
| DEMO RS13 03 / CN-00004 | 40,000 paid, credit note 369,300, SO "Cancelled" | BUG-RS13-03, -05, -10 |
| DEMO RS13 04 / CN-00006 | Closed Won + Cancelled, car on sale | BUG-RS13-04 |
| DEMO RS13 05 / CN-00007, CN-00008 | API-approved 999,999; UI 999,999 pending | BUG-RS13-06, -03 |
| DEMO RS13 06 | Untouched spare | — |
| QA RT13 T1 / CN-00011 | Cancellation pending; refund approval failed | BUG-RS13-11 |
| QA RT13 T2 / CN-00012, CN-00016 | Rejected then resubmitted; two pending refunds | BUG-RS13-02, -09 |
| QA RT13 T3 / CN-00013 | 40,000 paid, refund 369,300, SO "Cancelled" | BUG-RS13-03, -05 |
| QA RT13 T4 / CN-00014 | Closed Won + Cancelled, car on sale, refund approved, not synced | BUG-RS13-04, -08, -10 |
| QA RT13 T5 / CN-00017 | Rep-forged approved/synced 999,999 credit note | BUG-RS13-06, -13 |
| QA RT13 T6 | Showroom Manager's Automobiles deal; cancellation fails | BUG-RS13-01, -14 |
| QA RT13 T7 / CN-00015 / HO-00064 | Cancelled, then Closed Won via handover; refund stuck | BUG-RS13-11, -12 |

## Org configuration changed during testing

None. Approval work items for DEMO RS13 01–04 were reassigned by an administrator (data, not
configuration). CN-00004 and one DEMO RS13 03 payment were deleted and restored from the Recycle Bin.
25-Sep: QA RT13 T6's reservation deposit approval was approved by an administrator (setup); T4 and
T7's handover checklist flags were set by an administrator (the rep cannot set three of them); the
admin delete test ran inside a rolled-back savepoint.
