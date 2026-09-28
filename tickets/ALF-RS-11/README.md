# [ALF-RS-11] Invoicing and Deal Completion Rules — bug tickets

**Found during:** QA testing of [ALF-RS-11], 2026-09-22
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/ALF-RS-11-report.md`
**Status:** **CREATED IN JIRA, 2026-09-22.** Seven are in **LFRDN** as Bugs, assigned to **Yassin**, parent **LFRDN-317 (Build)**, linked *relates to* the story **LFRDN-341**, labels `ALF-RS-11` / `QA` / `Retail-Sales`. BUG-RS11-01 was **not** created — it duplicates the existing **LFRDN-666**, which received a QA verification comment instead.

> **Every ticket below is reproducible entirely in the Lightning UI.** Log in as
> `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` (dismiss the *Change Your Password*
> screen with **Cancel**), open the **Automotive** app, and use the `DEMO RS11 …` records named in
> each ticket — search the prefix `DEMO RS11` in the global search box and they all come back.
> API calls and SOQL appear only under **Root Cause**, where a developer needs them.


## Jira keys

| Local ID | Jira | Priority | Notes |
|---|---|---|---|
| BUG-RS11-01 | **LFRDN-666** *(existing)* | High | Not re-raised — already filed 2026-09-21. Commented with the wider scope: every `AF_PSG_*` persona, blocks all of ALF-RS-11, same root cause as LFRDN-671. |
| BUG-RS11-02 | **LFRDN-681** | Highest | |
| BUG-RS11-03 | **LFRDN-682** | Highest | |
| BUG-RS11-04 | **LFRDN-683** | High | Linked to LFRDN-666 |
| BUG-RS11-05 | **LFRDN-684** | High | |
| BUG-RS11-06 | **LFRDN-685** | High | |
| BUG-RS11-07 | **LFRDN-686** | Medium | Linked to LFRDN-685 |
| BUG-RS11-08 | **LFRDN-687** | Medium | Linked to LFRDN-682 |
| BUG-RS11-09 | **LFRDN-692** | Highest | Linked to LFRDN-341, LFRDN-682, LFRDN-683 |

### Screenshots to attach in Jira

Attachments cannot be uploaded through the Atlassian connector, so these are to be
attached by hand. All files are in `screenshots/ALF-RS-11/`.

| Jira | Attach |
|---|---|
| **LFRDN-666** | `rs11-getpayment-fails-for-rep.png`, `rs11-create-reservation-still-fails-for-rep.png` |
| **LFRDN-681** | `rs11-take-the-keys-no-invoice.png` |
| **LFRDN-682** | `rs11-bug03-closed-won-despite-gate-refusing.png` |
| **LFRDN-683** | `rs11-bug04-07-required-docs-missing-on-keyloop-payment.png` |
| **LFRDN-684** | `rs11-bug05-close-date-backdated-by-rep.png` |
| **LFRDN-685** | *(none — the finding is an absence of integration; nothing to photograph)* |
| **LFRDN-686** | `rs11-bug07-noc-preconfirmed-payee-is-customer.png`, `rs11-bug04-07-required-docs-missing-on-keyloop-payment.png` |
| **LFRDN-687** | `rs11-bug08-wrong-message-payments-complete.png` |
| **LFRDN-692** | `newbug-bank-lpo-upload-not-tagged-still-missing.png` |

Also available, not cited in any ticket: `rs11-closed-won-blocked-rep-ui.png` (the close
correctly refused while the proof was genuinely missing — useful as a "working" control).

## Summary

ALF-RS-11 decides when a car sale is actually finished: the money collected, the vehicle registered,
the customer signed for delivery — and the legal invoice raised in Keyloop rather than in Salesforce.
Tested by walking the journey in the Lightning UI as the Sales Representative, using the product's
own actions: **Select Vehicle → Test Drive → Create Quotation → Create Reservation → Get Payment →
Path to Closed Won**.

The controls are real and, on a deal built that way, mostly work: *Take the Keys* correctly refuses an
unsettled invoice, Closed Won blocks on incomplete deals through every route including a ten-record
bulk API update, and the cheque-copy / Bank-LPO proof matrix is well designed and correctly
conditional on payment method.

The most serious problem is that **no business persona can record a payment at all**. *Get Payment* on
the Invoice Summary is the only payment path in the product, and it fails for every `AF_PSG_*`
persona (**BUG-RS11-02**), which puts the whole of ALF-RS-11 out of reach of the business. Beneath
that, three controls can still be passed: a deal that was quoted but never reserved has no invoice at
all, and the rep can walk it into *Take the Keys* with one click (**BUG-RS11-08**); a manual close is
accepted even while the authoritative Apex gate is returning *not allowed* (**BUG-RS11-05**); and a
closed deal can be moved into a different accounting period with one field edit (**BUG-RS11-06**).

Two more are the payment path contradicting the close path: a Keyloop-pulled payment carries no
attached proof file, so the deal it paid for cannot close until a human manually uploads one
(**BUG-RS11-04**), and the same action sets the payee to the customer's own name and ticks
`NOC Recorded`, so FR3's payee-mismatch control can never fire on any real payment (**BUG-RS11-07**).
Finally, when a gate does block it names the wrong outstanding condition (**BUG-RS11-01**), and FR2's
Keyloop invoicing event does not exist in any form (**BUG-RS11-03**), so AC3 cannot be met.

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-RS11-02 | *Get Payment* — the only way to record a payment — fails for every business persona | Highest | Persona-specific — all `AF_PSG_*` personas; System Administrator unaffected |
| BUG-RS11-08 | A deal that was never reserved has no invoice, and the rep can hand over the keys on it | Highest | General |
| BUG-RS11-05 | A manual close is accepted while the authoritative gate is refusing it | Highest | General |
| BUG-RS11-04 | Keyloop-pulled payments carry no attached proof file, so the deal they paid for cannot close | High | General |
| BUG-RS11-06 | The Closed Won date can be freely back-dated into an earlier accounting period | High | General |
| BUG-RS11-03 | FR2 Keyloop invoicing event does not exist, so no deal ever reaches a confirmed invoiced status | High | General |
| BUG-RS11-07 | Every payment is created with the NOC pre-confirmed, so FR3's payee control can never fire | Medium | General |
| BUG-RS11-01 | Closed Won is refused with a message naming the wrong outstanding condition | Medium | General |

---

## BUG-RS11-09 — Uploading a required document does not tag it, so it stays "Missing" and the deal can never close (Highest)

**Module:** Retail Sales — Invoicing controls / Deal Completion
**Status:** Open — filed as **LFRDN-692**, found 2026-09-22 after the LFRDN-682 fix
**Applies to:** Persona-specific — reproduced as the Sales Representative; no permission set in the org grants the field.
**Verified through the real retail cycle, entirely in the Lightning UI.**

### Description

Closed Won now correctly requires the typed document per payment — a Bank Transfer needs a Bank LPO
(LFRDN-682, fixed). But **uploading that document through the product's own Required Documents
component does not satisfy the requirement.** The file uploads, appears under Files, and the
checklist still says **Missing**. There is no other way to supply it.

The result is that the fix for LFRDN-682 closed the loophole without opening the door: the deal
completion path that was finally unblocked this morning is blocked again, one step further along.
No business user can complete a retail sale.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS11 22 – Confirmation test after fixes**
   (`006FV00BiG6RDvQYUW`) — built through the full cycle and paid in full via **Get Payment**.
2. **Related** tab → **Payments** → open **PAY-00045** → **Related** tab.
3. In the **Required Documents** panel, find **Bank LPO — Missing** and click **Upload Files**.
4. Choose any file and let it upload. It completes with no error.
5. Reload the page and re-open **Related → Required Documents**.
6. Go back to the Opportunity and click **Path → Mark Stage as Complete → Closed Won → Save**.

### Expected Result

The uploaded file is recorded as the *Bank LPO* document type, the checklist flips to satisfied, and
the deal closes — the whole point of the component.

### Actual Result

**Step 5:** the panel still reads **Bank LPO — Missing**, after a full page reload. The file is
there — it appears on the record as `BankLPO` — but it is not recognised as the required document.
Screenshot: `screenshots/ALF-RS-11/newbug-bank-lpo-upload-not-tagged-still-missing.png`.

**Step 6** is refused and the stage holds at Take the Keys:

> Closed Won requires the correct typed document per Payment (ALF-RS-11 FR3/FR4/FR5): Cheque needs
> Cheque Copy, Bank Transfer needs Bank LPO, NOC Recorded needs Signed NOC. Check the Required
> Documents checklist on each Payment.

There is no path forward for the user: the checklist demands a document, the upload control accepts
one, and the two never meet.

### Root Cause

**Confirmed.** The document's type lives in `ContentVersion.AF_FileUpload__c`.
`AF_DocumentService.renameUploadedDocuments()` is supposed to set it after an upload — its own
comment says *"Renames newly uploaded files to the metadata document name and tags
AF_FileUpload__c."* On the file uploaded through the UI as the rep, that field is **null** and the
title is the raw file name, so the tagging step did not take effect.

A `FieldPermissions` query for `ContentVersion.AF_FileUpload__c` returns **zero rows** — no
permission set or permission set group in the org grants Read or Edit on it. This is the same class
of omission as LFRDN-670 (`AF_SOPaymentConfirmedBy__c`) and LFRDN-666 (`AF_InvoiceBalance__c`): the
automation must write a field that no business persona can write, and the failure is silent because
`AF_DocumentService` swallows exceptions (`catch (Exception e) { return false; }`).

The two checks also read the field differently, which is why this was not caught:

| Check | How it identifies a document |
|---|---|
| `AF_FL_Opp_ClosedWonPaymentGate` (what runs on a manual close) | `AF_FileUpload__c = 'Bank LPO'` only |
| `AF_DocumentService.getUploadedDocuments` (the Apex gate) | `AF_FileUpload__c` **if set, else falls back to the file Title** |

So the authoritative Apex gate returns `allowed = true` for a file merely *named* "Bank LPO", while
the flow refuses it. Two implementations of one rule, disagreeing again — and the Title fallback is
itself a control weakness, since any file named "Bank LPO" satisfies the authoritative check.

### Proposed Solution

1. Grant **Edit** on `ContentVersion.AF_FileUpload__c` to the `AF_PSG_*` permission set groups that
   use the Required Documents component — at minimum Sales Rep, Sales Manager, Showroom Manager.
   Better, have `renameUploadedDocuments` perform that write in system context, since the tag is
   set by automation and not by the user.
2. Stop swallowing the exception in `AF_DocumentService` — a failed tag should surface to the user,
   not leave the checklist silently wrong.
3. Align the two checks on one field. If the Title fallback is intentional for legacy files, apply
   it in both places; if not, remove it, because today it lets an untyped file pass the gate the
   build calls authoritative.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR5 — *"…the Bank LPO must be attached before the invoice is confirmed."*
- **BRD**, p. 54, §10.11 ALF-RS-11 FR4 — the cheque copy equivalent.

### Evidence

- Records: Opportunity `006FV00BiG6RDvQYUW` (DEMO RS11 22), payment **PAY-00045**, the uploaded file `BankLPO` with `AF_FileUpload__c = null`
- Screenshot: `screenshots/ALF-RS-11/newbug-bank-lpo-upload-not-tagged-still-missing.png`
- Harness: Lightning UI as QA SalesRep2 throughout — the file was uploaded with the component's own **Upload Files** control, not by API; `FieldPermissions` checked as System Administrator

---

## BUG-RS11-01 — *Get Payment* — the only way to record a payment — fails for every business persona (Highest)

**Module:** Retail Sales — Invoicing and payments
**Status:** Open
**Applies to:** Persona-specific — every `AF_PSG_*` persona. System Administrator unaffected.
**Verified through the real retail cycle.**

### Description

There is exactly one way for a payment to enter this system: the **Get Payment** button on the
Invoice Summary, which pulls the payment from Keyloop by its reference. (The *Record Payment*
action on the Reservation is not on the Lightning record page, and the Apex that replaced it states
it "has been removed".) That one button fails for the Sales Representative — and for every other
business persona — with a technical message. Nothing is recorded, the invoice stays Unpaid, and
because every later gate in ALF-RS-11 depends on the invoice being settled, **no part of this story
can be completed by anyone in the business.** Only a System Administrator can take a payment.

### Steps to Reproduce

1. Log in as the Sales Representative and open the **Automotive** app.
2. Search **DEMO RS10 13** and open **DEMO RS10 13 – Real retail cycle end to end** — a deal built
   entirely through the real journey (Select Vehicle → test drive → Create Quotation → Create
   Reservation).
3. On the **Details** tab, **Vehicle & Order** section, click through to the Invoice Summary
   **INVM-00074**. It reads **Invoice Status = Unpaid**, Expected Total 398,300, Balance 398,300.
4. In the highlights panel click **Get Payment**.
5. Enter any Keyloop Payment ID — e.g. `KL-PAY-RS11-001` — and click **Next**.
6. Repeat steps 4–5 logged in as a System Administrator.

### Expected Result

The payment is pulled and recorded, the Invoice Summary moves to Partially Paid or Fully Paid, and
the Opportunity's Invoice Balance follows.

### Actual Result

Step 5 ends on a screen titled **"Something went wrong"**:

```
We couldn't pull the payment. Please try again, or contact your administrator if the problem continues.

An Apex error occurred: System.DmlException: Insert failed. First exception on row 0; first error:
UNKNOWN_EXCEPTION, We can't save this record because the "Payment Recalculate Invoice Summary"
process failed. Give your Salesforce admin these details. CANNOT_EXECUTE_FLOW_TRIGGER: An Apex error
occurred: System.DmlException: Operation failed due to fields being inaccessible on Sobject
Opportunity, check errors on Exception or Result! Error ID: 1575678203-27884 (-1515484096): []
```

No payment is created and the invoice is unchanged. Screenshot:
`screenshots/ALF-RS-11/rs11-getpayment-fails-for-rep.png`.

Step 6 as System Administrator succeeds on the same record and the same button: payment
**PAY-00041** is created for the full 398,300, the invoice moves to **Fully Paid** and the
Opportunity's Invoice Balance drops to 0.

### Root Cause

**Confirmed.** Every payment save fires `AF_FL_Payment_RecalculateInvoiceSummary`, which calls
`AF_InvoiceSummaryService.recalculate` → `update as user` on the Opportunity, writing
`AF_InvoiceBalance__c`. Field-level security on that field grants **Edit to System Admin,
`AF_PS_Opportunity_FullAccess` and the MuleSoft integration user only**; all seven `AF_PSG_*`
persona groups have Read but not Edit. `update as user` therefore throws, and the whole payment
insert rolls back.

This is the same field and the same cause as ALF-RS-10's **LFRDN-671** (Create Reservation fails
for the rep). A batch of Opportunity field permissions was granted on 2026-09-22 at 10:21 —
`AF_InvoiceSummary__c` and `AF_VehicleReservation__c` both received Edit for every persona — but
`AF_InvoiceBalance__c` was missed, so both symptoms persist. Re-tested after that change: Create
Reservation still fails for the rep on a brand-new deal
(`screenshots/ALF-RS-11/rs11-create-reservation-still-fails-for-rep.png`).

### Proposed Solution

1. Grant **Edit** on `Opportunity.AF_InvoiceBalance__c` to the `AF_PSG_*` permission set groups that
   need to transact — at minimum Sales Rep, Sales Manager and Showroom Manager — alongside the
   `AF_InvoiceSummary__c` / `AF_VehicleReservation__c` grants already made.
2. Better, since this field is a system-maintained rollup no user should type into: make the
   recalculation run in system context (`without sharing` service invoked from the trigger) so a
   denormalised field does not require end-user write access at all. That fixes this ticket and
   LFRDN-671 together and prevents the next recurrence.
3. Whichever route is taken, have the flow's fault path show a business message rather than a raw
   `DmlException`.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR1 — *"…cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."* — unreachable while payment cannot be recorded.
- `AF_KeyloopGetPayment.cls` header — *"Sales Reps no longer create Payment records directly (Record Payment has been removed) — the only path onto a deal's Invoice Summary is pulling a real payment from Keyloop by its payment reference."*

### Evidence

- Records: Opportunity `006FV00Bhdn1CVAYE2` (DEMO RS10 13, cycle-built), Invoice Summary `a0TFV00FrvtCkfM2ES` (INVM-00074), payment `PAY-00041` (admin-created)
- Screenshots: `screenshots/ALF-RS-11/rs11-getpayment-fails-for-rep.png`, `screenshots/ALF-RS-11/rs11-create-reservation-still-fails-for-rep.png`
- Harness: Lightning UI as QA SalesRep2 and as System Administrator, using the real **Get Payment** Quick Action; `FieldPermissions` query as System Administrator

---

## BUG-RS11-02 — A deal that was never reserved has no invoice, and the rep can hand over the keys on it (Highest)

**Module:** Retail Sales — Deal Completion
**Status:** Open
**Applies to:** General — reproduced in the UI as the Sales Representative
**Verified through the real retail cycle.**

### Description

"Take the Keys" is the stage where the customer physically takes the car, and the system is supposed
to refuse it until the invoice is settled. The check reads a mirror field on the Opportunity that is
only ever populated when an Invoice Summary is created — and an Invoice Summary is only created by
the **Create Reservation** step. Nothing in the journey forces a reservation: the preceding gate,
*Commit*, asks only for a synced Quote. So a rep who quotes a car, syncs the quote and skips the
reservation reaches a deal with **no invoice, no reservation and no payment** — and the stage that
hands over the keys is granted on a single click, with no warning.

### Steps to Reproduce

1. Log in as the Sales Representative and open the **Automotive** app.
2. Search **DEMO RS11 21** and open **DEMO RS11 21 – Quoted but never reserved, keys gate**. It was
   built entirely through the real journey: **Select Vehicle** (Rolls-Royce Cullinan → Black Badge
   Package → **Confirm Line**) → test drive completed → **Create Quotation** → **Start Sync** on
   the Quote. **Create Reservation was deliberately never run.**
3. On the **Details** tab confirm what is missing: **Invoice Summary** is blank, **Vehicle
   Reservation** is blank, **Invoice Balance** is blank, and the **Vehicle Reservations** and
   **Payments** related lists are empty. Amount reads AED 560,000.
4. If the record is already past it, set the Stage back to **Commit** first (moving backwards is
   always allowed).
5. In the **Path**, with **Commit** selected, click **Mark Stage as Complete**.
6. To build one from scratch instead: new Opportunity → **Select Vehicle** → pick any model and
   vehicle → **Confirm Line** → complete the test drive that appears at Explore → **Create
   Quotation** → on the Quote, **Show more actions → Start Sync → Continue** → then advance the
   Path. Do not create a reservation.

### Expected Result

The stage change is refused — a car cannot be handed to a customer on a deal that has never been
invoiced. Either the gate fails closed when there is no Invoice Summary, or *Commit* requires one.

### Actual Result

The Path moves straight to **Take the Keys**. No error, no warning, no confirmation. Screenshot:
`screenshots/ALF-RS-11/rs11-take-the-keys-no-invoice.png`. The record afterwards reads:

| Where | Field | Value |
|---|---|---|
| Opportunity | **Stage** | Take the Keys |
| Opportunity | **Invoice Summary** | *(blank)* |
| Opportunity | **Vehicle Reservation** | *(blank)* |
| Opportunity | **Invoice Balance** | *(blank)* |
| Opportunity → Payments | — | *no records* |
| Opportunity | **Last Modified By** | QA SalesRep2 |

### Tested and working — for contrast

On **DEMO RS11 20 – Real cycle, unpaid, keys gate test** (`006FV00BhqEWRGuYEP`), built through the
same journey **including Create Reservation** and left completely unpaid, the same stage change is
correctly refused:

```
Take the Keys stage requires the invoice balance to be fully settled (zero).
```

Its Invoice Balance reads **279,308**, so the gate sees the debt and holds. The control itself is
sound; it is the missing-invoice case that slips through.

### Root Cause

**Confirmed.** `AF_VR_Opp_TakeTheKeysGate` is
`AND(ISPICKVAL(StageName, "Take the Keys"), AF_InvoiceBalance__c <> 0)`.

`Opportunity.AF_InvoiceBalance__c` is a denormalised mirror, written by
`AF_InvoiceSummaryService.ensureForReservations` at the moment an Invoice Summary is created (it
sets the Opportunity's `AF_InvoiceSummary__c` and `AF_InvoiceBalance__c` together) and refreshed by
`recalculate` on every payment. Where no reservation has been created, none of that has ever run and
the field is `null`. In a validation-rule formula a null Number is evaluated as zero, so
`AF_InvoiceBalance__c <> 0` is **false** and the rule passes. The gate is open exactly when there is
no financial record to check — it fails open instead of closed.

`AF_VR_Opp_CommitGate` requires only a synced Quote, so nothing upstream forces the reservation that
would create the invoice.

### Proposed Solution

1. Make the gate fail closed when there is nothing to check:

```
AND(
    ISPICKVAL(StageName, "Take the Keys"),
    OR(
        ISBLANK(AF_InvoiceSummary__c),
        AF_InvoiceBalance__c <> 0
    )
)
```

   with a message that distinguishes "this deal has no invoice" from "this deal still owes money".
2. Consider evaluating `AF_InvoiceSummary__r.AF_Balance__c` — the Invoice Summary's own field —
   rather than the Opportunity mirror, so the check does not depend on a rollup having run. This is
   what the ALF-RS-09 before-save flow already does, which is why the Closed Won gate does not have
   this hole.
3. Decide with the BA whether reaching *Commit* should itself require a reservation (GAP-RS11-08).

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR1 — *"The system should ensure that an opportunity cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."* The same logic must hold at the stage where the vehicle physically changes hands.

### Evidence

- Records: Opportunity `006FV00BhMDdpSuYUJ` (DEMO RS11 21, no invoice — reproduces), Opportunity `006FV00BhqEWRGuYEP` (DEMO RS11 20, reserved and unpaid — correctly blocked), Quote `0Q0FV004Ugd1sWC0IY` (00000185)
- Screenshot: `screenshots/ALF-RS-11/rs11-take-the-keys-no-invoice.png`
- Harness: Lightning UI as QA SalesRep2 throughout, using the real Quick Actions and the Path; rule text from metadata retrieved 2026-09-22

---

## BUG-RS11-03 — A manual close is accepted while the authoritative gate is refusing it (Highest)

**Module:** Retail Sales — Deal Completion
**Status:** Open
**Applies to:** General
**Verified through the real retail cycle.**

### Description

Deal completion is checked in three places that do not agree with each other. The Apex class the
build's own comments call *"the authoritative FR6 check"* verifies that every payment carries its
typed proof document — Cheque Copy, Bank LPO or Signed NOC. The validation rule and the before-save
flow that actually fire when a user moves the Path do not. The result is a deal that the
authoritative gate is actively refusing, closing anyway on a manual stage change — and the closed
record looks identical to a properly completed one.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS11 20 – Real cycle, unpaid, keys gate
   test** (`006FV00BhqEWRGuYEP`) — a deal driven through the whole journey: Select Vehicle
   (Ferrari Roma → Spider Package → Confirm Line) → test drive → Create Quotation → Start Sync →
   Create Reservation → **Get Payment** for the full amount.
2. Confirm the deal looks complete: on the **Details** tab **Invoice Balance = 0.00**; click through
   to Invoice Summary **INVM-00077** — **Fully Paid**; the linked **Handover HO-00035** has
   **Traffic Form Uploaded** ticked and **Customer Sign-Off = Physically Signed**; **Handover
   Complete** and **Delivery Confirmation** are ticked.
3. Now look at the one thing that is not satisfied. Open payment **PAY-00043 → Related → Required
   Documents**. It reads **Bank LPO — Missing** and **Signed NOC — Missing**. The payment method is
   Bank Transfer, so the Bank LPO is mandatory before the invoice may be confirmed.
4. Back on the Opportunity, click **Path → Mark Stage as Complete**, choose **Closed Won** in the
   *Close This Opportunity* dialog, and **Save**.
5. Re-open the Opportunity and read the Stage, then re-open the Required Documents panel on
   PAY-00043.

### Expected Result

The close is refused for the same reason the Required Documents checklist gives — the Bank LPO is
missing — or the checklist is wrong and should say so. The two must not disagree.

### Actual Result

**The stage saves. The Opportunity is Closed Won** and the Close Date is stamped **22/09/2026**,
while the authoritative gate, called on the very same record in the very same transaction, returns:

```
allowed = false :: Not every Payment has its required documents (Cheque Copy / Bank LPO /
Signed NOC) uploaded - check the Required Documents checklist on the Payment.
```

So the deal is closed and the system simultaneously holds the position that it should not be. The
Required Documents checklist on PAY-00043 still shows **Bank LPO — Missing** and **Signed NOC — Missing** after the close, and the Opportunity's Last Modified By reads **QA SalesRep2**.

### Root Cause

**Confirmed.** Three checks, two rule sets:

| Where | What it checks | Fires on a manual Path close? |
|---|---|---|
| `AF_VR_Opp_ClosedWonGate` (validation rule) | handover complete, delivery confirmation, Invoice Summary present, `AF_InvoiceBalance__c = 0`, Traffic Form, sign-off | **yes** |
| `AF_FL_Opp_ClosedWonPaymentGate` (before-save flow) | payments verified, *a* file attached, balance zero; stamps Close Date | **yes** |
| `AF_Opportunity_ClosedWonPaymentGate` (Apex) | all of the above **plus** the typed `AF_Document__mdt` checklist per payment | **no** — only the automatic path invokes it |

The class header states the intent and the risk in the same breath: *"this class is the
authoritative FR6 check and is meant to be called before the rep is allowed to set the Stage"*, and
*"Mirrors AF_FL_Opp_ClosedWonPaymentGate.flow's Get_Handover/Handover_Conditions_Met — if this
class's rule changes, that flow must be updated to match, since there is no way to share logic
between an Apex class and a before-save Flow."* The typed-document requirement was added to the
class and never mirrored into the flow, so the two have drifted.

### Proposed Solution

1. Mirror the typed required-documents check into `AF_FL_Opp_ClosedWonPaymentGate` so the declarative
   path enforces what the Apex path does — the mechanism already exists as the invocable
   `AF_DocumentConditionEvaluator`, which the flow can call directly.
2. Better, and what the class header is really asking for: have the before-save flow call
   `AF_Opportunity_ClosedWonPaymentGate` itself, so there is **one** implementation of FR6 rather
   than three that must be kept in step by hand.
3. Until then, treat the manual Path route to Closed Won as unguarded for FR4/FR5 and say so to the
   business.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR4 — *"…a copy of the cheque must be attached before the invoice is confirmed."*
- **BRD**, p. 54, §10.11 ALF-RS-11 FR5 — *"…the Bank LPO must be attached before the invoice is confirmed."*

### Evidence

- Records: Opportunity `006FV00BhqEWRGuYEP` (**DEMO RS11 20** — left **Closed Won with Bank LPO and Signed NOC outstanding**, please do not "fix" it), payment `PAY-00043`, Handover `HO-00035` (`a0SFV001Mwbae6G2IQ`), Invoice Summary `INVM-00077`. Second occurrence on Opportunity `006FV00Bhdn1CVAYE2` (DEMO RS10 13).
- Screenshot: `screenshots/ALF-RS-11/rs11-bug03-closed-won-despite-gate-refusing.png`
- Harness: the whole journey walked in the Lightning UI as QA SalesRep2 — Select Vehicle, Create Quotation, Create Reservation, Get Payment, then **Path → Mark Stage as Complete → Closed Won**, which saved. `AF_Opportunity_ClosedWonPaymentGate.check()` was called against the same record to capture the authoritative verdict for comparison.

---

## BUG-RS11-04 — Keyloop-pulled payments carry no attached proof file, so the deal they paid for cannot close (High)

**Module:** Retail Sales — Invoicing and payments
**Status:** Open
**Applies to:** General
**Verified through the real retail cycle.**

### Description

The **Get Payment** action records a payment that came back from Keyloop and writes a proof
*reference* into the record — `Keyloop payment KL-PAY-RS11-001`. The Closed Won gate does not accept
a reference; it requires a real file attached to the Payment. Nothing in the product attaches one,
and no action offers to. So every payment the system takes by its own intended route arrives in a
state that blocks the deal it just paid for, and somebody has to notice and manually upload a file
to a payment that no human ever touched.

### Steps to Reproduce

1. Log in as a System Administrator (the rep cannot record a payment at all — **BUG-RS11-01**).
2. Open an Opportunity with an unpaid Invoice Summary built through the cycle — e.g.
   **DEMO RS11 20 – Real cycle, unpaid, keys gate test** (`006FV00BhqEWRGuYEP`) → Details → its
   Invoice Summary.
3. Click **Get Payment**, enter any Keyloop Payment ID, **Next**, then **No, I am done**.
4. Open the payment the action created → **Details**. **Proof of Payment / Receipt Reference** reads
   *Keyloop payment (your id)*; Status is **Paid / Verified**; Integration Status is **Synced**.
5. Open the same payment's **Files** related list.
6. Complete the rest of the deal (handover with Traffic Form uploaded and Customer Sign-Off
   *Physically Signed*, Handover Complete and Delivery Confirmation ticked) and move the Path to
   **Closed Won**.

### Expected Result

Either the action attaches the Keyloop payment advice as a file, or the gate accepts the Keyloop
reference as proof for an integration-sourced payment. A payment that the system itself pulled and
marked verified should not need a human to supply evidence of it.

### Actual Result

Step 5: the **Files** list is **empty** — the action attaches nothing.

Step 6 is refused:

```
Closed Won requires every Payment to be Paid / Verified (or Keyloop-synced) with proof attached,
and the Invoice balance to be zero (ALF-RS-09 FR6). Check the Payment related list.
```

and the authoritative gate, called on the same record, returns:

```
allowed = false :: Not every Payment record has a proof/receipt document attached
(upload the file under Files).
```

Attaching any file by hand to that payment clears this particular condition and the deal then
closes — which is the workaround, and also the evidence that the file, not the reference, is what
the gate wants.

### Root Cause

**Confirmed.** `AF_Opportunity_ClosedWonPaymentGate` deliberately requires a `ContentDocumentLink`
on each Payment and says why in its header: *"the BRD's own vocabulary throughout RS-08/RS-09/RS-11
is consistently 'attach'/'attached'/'upload', never 'reference field'. AF_ProofReference__c (a text
field) is kept as a human-readable label ... but the actual gate requires a real ContentDocumentLink
on the Payment record."*

`AF_KeyloopGetPayment.getPayment()` sets `AF_ProofReference__c = 'Keyloop payment ' + reference` and
inserts the Payment. It creates no `ContentVersion` and no `ContentDocumentLink`. The two were built
to different definitions of "proof", and because Get Payment is now the only payment path, every
payment in the system lands on the wrong side of the gate.

### Proposed Solution

1. Decide with the BA what proof means for a payment the system pulled rather than a person
   collected (GAP-RS11-09). An integration-sourced payment arguably *is* self-evidencing.
2. If a file is still required, have `AF_KeyloopGetPayment` generate and attach the Keyloop payment
   advice as a `ContentVersion` on the Payment it creates — a few lines in the same method,
   alongside the reference it already writes.
3. If a reference is acceptable for synced payments, relax the gate to accept
   `AF_IntegrationStatus__c = 'Synced'` with a non-blank `AF_ProofReference__c` in place of an
   attached file, and keep the file requirement for manually recorded ones.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR4 / FR5 — the cheque copy and Bank LPO must be *attached*.
- **BRD**, §10.9 ALF-RS-09 FR6 — *"...including attaching the receipt or deposit document..."*
- `AF_KeyloopGetPayment.cls` — the insert that omits any document link.

### Evidence

- Records: payment `PAY-00043` on Opportunity `006FV00BhqEWRGuYEP` (DEMO RS11 20), Invoice Summary `INVM-00077`; same behaviour on `PAY-00041` / DEMO RS10 13
- Screenshot: `screenshots/ALF-RS-11/rs11-bug04-07-required-docs-missing-on-keyloop-payment.png` — the Payment's **Required Documents** panel reading *Bank LPO — Missing*
- Harness: real **Get Payment** Quick Action in the Lightning UI, then the Payment's Related tab read on screen; the close attempted from the Path as QA SalesRep2

---

## BUG-RS11-05 — The Closed Won date can be freely back-dated into an earlier accounting period (High)

**Module:** Retail Sales — Deal Completion
**Status:** Open
**Applies to:** General

### Description

The system correctly stamps the Close Date at the moment a deal's conditions are met — that is the whole point of FR6. But the moment after it does so, any user who can edit the Opportunity can simply change that date to an earlier one, including into the previous month. Nothing blocks it, nothing warns, nothing is approved, and there is no separate system date to fall back on, so management reporting follows the edited value. The control FR6 describes is applied once and then left unlocked.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS11 20 – Real cycle, unpaid, keys gate
   test** (`006FV00BhqEWRGuYEP`), which is **Closed Won**.
2. Read the **Close Date**: it now shows **01/08/2026**. The system stamped **22/09/2026** — the day
   the deal was closed — and the date shown is the one I changed it to afterwards, in the UI, as the
   rep.
3. Reproduce it on any Closed Won Opportunity. On the **Details** tab click the pencil next to
   **Close Date**, type an earlier date in a different month — e.g. **01/08/2026** — and click
   **Save**.
4. Re-open the record and read the Close Date, then look at the Opportunities list view or any
   Closed Won report filtered on that month — the deal now appears in the earlier period.

### Expected Result

The Close Date reflects when the completion conditions were satisfied and cannot be moved to an earlier period without control.

### Actual Result

Step 2 works correctly — the date becomes `2026-09-22`, replacing `2026-10-31`.
Step 4 saves without a murmur — no error banner, no warning, no approval. Step 5 then reads:

```
Stage:      Closed Won
Close Date: 01/08/2026
```

…and the deal now reports in September's first ten days, a period it was never completed in.

### Root Cause

**Confirmed.** `AF_FL_Opp_ClosedWonPaymentGate` stamps the date with a single before-save assignment, `Stamp_Close_Date: $Record.CloseDate = $Flow.CurrentDate`, reached only on the transition into Closed Won (`Is_Closing_Won` → … → `Missing_Proof_After_Loop` default). On any later save the flow does not re-enter that branch, and no validation rule protects `CloseDate` on a closed Opportunity. There is also no separate completion-date field: `CloseDate` is both the stamped value and the user-editable one — a `FieldDefinition` query for Opportunity fields matching `%Clos%` returns only `CloseDate`, `IsClosed`, `LastCloseDateChangedHistoryId` and `AF_ClosedWonGatePassed__c`.

### Proposed Solution

Two changes, ideally both:

1. Add a validation rule locking the date once the deal is closed, e.g. `AND(ISCHANGED(CloseDate), PRIORVALUE(IsClosed), NOT($Permission.AF_Can_Adjust_Close_Date))`, with that custom permission granted only to Finance/Admin so a genuine correction remains possible and attributable.
2. Add a separate read-only `AF_CompletionDate__c`, stamped by the same flow and never user-editable, and point the Closed Won reporting at it. That keeps the standard `CloseDate` usable as a forecast field without compromising the accounting date.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR6 — *"The system should record the Closed Won date based on when the agreed completion conditions are satisfied, not on an earlier sales milestone."*
- **BRD**, p. 54, §10.11 ALF-RS-11 AC2 — *"Given all completion conditions are met, When the Sales Representative sets the opportunity to Closed Won, Then the stage is accepted and the Closed Won date is stamped."*

### Evidence

- Record: Opportunity `006FV00BhqEWRGuYEP` (**DEMO RS11 20**) — closed 22/09/2026 by the system, then moved by the rep to **01/08/2026**, two months into a closed period; left that way as evidence
- Screenshot: `screenshots/ALF-RS-11/rs11-bug05-close-date-backdated-by-rep.png`
- Harness: Lightning UI as QA SalesRep2 — inline pencil on **Close Date**, retype, **Save**. No Opportunity validation rule references `CloseDate` (all 13 checked in metadata retrieved 2026-09-22).

---

## BUG-RS11-06 — FR2's Keyloop invoicing event does not exist, so no deal reaches a confirmed invoiced status (High)

**Module:** Retail Sales — Keyloop invoicing integration
**Status:** Open
**Applies to:** General

### Description

FR2 and AC3 describe Salesforce asking Keyloop to raise the legal invoice and then recording Keyloop's confirmation against the deal. Neither half exists. Nothing triggers an invoicing event, nothing receives a confirmation, and no completed deal carries a Keyloop invoice number — so the traceability chain from reservation through to the legal invoice stops inside Salesforce. The one part of FR2 that is correct is the negative: Salesforce does not produce a legal invoice of its own.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS11 20** (`006FV00BhqEWRGuYEP`), a
   fully completed Closed Won deal.
2. On the **Details** tab, look for any invoiced status or Keyloop invoice reference on the
   Opportunity — there is none.
3. **Related** tab → **Invoices** → open the Invoice Summary. Read **Keyloop Invoice Reference**
   (blank), **Keyloop Total Amount** (blank), **Synced** (unticked) and **Legal Invoice** (unticked —
   correct, Salesforce must not produce the legal invoice).
4. As a System Administrator, in **Setup**: **Named Credentials** contains four entries and none of
   them is Keyloop; **Apex Jobs / Scheduled Jobs** contains no invoicing job; **Apex Classes** →
   `AF_KeyloopGetPayment` → read its header comment.
5. Complete any other deal to Closed Won and check the same fields again — they stay empty.

### Expected Result

Per AC3: the invoice trigger is sent to Keyloop and the Salesforce opportunity reflects the confirmed invoiced status, carrying the Keyloop invoice reference.

### Actual Result

Step 2: the org has four Named Credentials, none of them Keyloop (`ToolingRestDPE`, `FSC_fsc_integrations_V1_0_0`, `AUTOSCHEDULER`, `ApexMDAPI`), and the only `AF_*` class making an HTTP callout is `AF_KeyloopGetPayment`, whose header states:

```
No live Keyloop integration exists in this org yet (confirmed: zero Named Credentials, zero
Apex HTTP callouts anywhere). Per explicit instruction, this is built as a full in-Salesforce
simulation for now...
```

Steps 3 and 4: no invoiced status is set, and a grep across all 156 Flows and 118 Apex classes finds **no writer** of `AF_KeyloopInvoiceReference__c` or `AF_Synced__c`.

### Root Cause

**Confirmed — the integration was never built.** This is undelivered scope rather than defective code. The fields to receive the result already exist on `AF_InvoiceSummary__c` (`AF_KeyloopInvoiceReference__c`, `AF_KeyloopTotalAmount__c`, `AF_Synced__c`, `AF_IntegrationStatus__c`, `AF_TotalMismatch__c`), so the data model anticipates it; only the integration and the trigger point are missing.

Worth recording as correct: `AF_InvoiceSummaryService` sets `AF_LegalInvoice__c = false` on every Invoice Summary it creates, so Salesforce genuinely does not generate the legal invoice — the second half of FR2 is satisfied.

### Proposed Solution

Build the FR2 touchpoint on the same pattern the org uses for the reservation hold and payment retrieval: an outbound MuleSoft call raised at the deal-completion moment carrying the deal reference and amount, and an inbound confirmation that writes `AF_KeyloopInvoiceReference__c` and flips an invoiced status on the Opportunity. Per TC-003 step 5, a failed call must leave the deal *not* invoiced and raise an alert — an opportunity showing an invoiced status that Keyloop never confirmed would recognise revenue against a non-existent invoice.

If FR2 is not in the Release 1 delivery scope, AC3 should be formally deferred with it, since it cannot be met without the integration.

### Reference

- **BRD**, p. 53, §10.11 ALF-RS-11 FR2 — *"The system should support invoice generation as a step within the deal completion flow by triggering the invoicing event in Keyloop via MuleSoft and receiving the completion confirmation back into Salesforce; Salesforce does not independently generate the legal sales invoice."*
- **BRD**, p. 54, §10.11 ALF-RS-11 AC3 — *"Given an invoice is generated, When the deal is complete, Then the invoice trigger is sent to Keyloop and the Salesforce opportunity reflects the confirmed invoiced status."*
- **Solution Design**, p. 47, DEC-013 — *"AF_InvoiceSummary__c tracks totals/balance/gate — never the legal invoice (Keyloop creates the legal invoice)."*

### Evidence

- Record: Opportunity `006FV00BhIjDLZkYUO` (Closed Won, no invoiced status, no Keyloop reference)
- Harness: `sf` CLI metadata listing and grep over all retrieved Flows and Apex classes (retrieved 2026-09-22)

---

## BUG-RS11-07 — Every payment is created with the NOC pre-confirmed, so FR3's payee control can never fire (Medium)

**Module:** Retail Sales — Invoicing controls
**Status:** Open
**Applies to:** General
**Verified through the real retail cycle.**

### Description

FR3 says that when someone other than the customer pays, the system must block the invoice until a
signed NOC is confirmed. The control is built — there is a validation rule, and a typed *Signed NOC*
document requirement — but it can never be reached. The only way a payment enters the system sets
the payee to the customer's own name and ticks **NOC Recorded** to `true` before saving. A mismatch
is therefore impossible by construction, and the NOC is asserted on every single payment, including
ones where no NOC exists and none was ever needed.

The effect is not a blocked deal; it is the opposite. Every payment record in the org now carries an
affirmative statement that a signed No Objection Certificate is on file. None of them is backed by
anything.

### Steps to Reproduce

1. Log in as a System Administrator and open an Opportunity with an unpaid Invoice Summary built
   through the cycle — e.g. **DEMO RS11 20** (`006FV00BhqEWRGuYEP`) → Details → its Invoice Summary.
2. Click **Get Payment**, enter any Keyloop Payment ID, **Next**, **No, I am done**.
3. Open the payment the action created → **Details**.
4. Read two fields: **Payee Name** and **NOC Recorded?**.
5. Look for any way to record a payment with a *different* payee — check the **Get Payment** screen
   (one field: the Keyloop Payment ID), and the Vehicle Reservation's action bar (**Record Payment**
   is not there).

### Expected Result

The payee comes from the payment as received, and **NOC Recorded** stays false until somebody
confirms a signed NOC — so that a genuine third-party payment is caught and a genuine NOC is
recorded deliberately.

### Actual Result

Step 4: **Payee Name** is the Account's own name — *DEMO RS10 Customer - Khalid Al-Mannai* on
PAY-00043 — and **NOC Recorded?** is already **ticked**, on a payment nobody reviewed. The Required Documents panel on the same record then demands a **Signed NOC** document, for a certificate that does not exist and was never requested.

Step 5: there is no other way in. `AF_VR_Payment_PayeeMismatchNOC` requires
`AF_PayeeName__c <> AF_Account__r.Name` **and** `NOT(AF_NOCRecorded__c)`; both clauses are
permanently false, so the rule can never fire, and the typed *Signed NOC* document is never
requested.

### Root Cause

**Confirmed, and deliberate as a stopgap.** `AF_KeyloopGetPayment` sets
`AF_PayeeName__c = inv.AF_Account__r.Name` and `AF_NOCRecorded__c = true`, and its header explains:
*"because the simulated payee is always the Invoice Summary's own Account, a payee mismatch cannot
occur yet, so AF_NOCRecorded__c is simply set to true and no No Objection Certificate is produced.
The NOC generation path is re-introduced alongside the real Keyloop callout, when a returned payee
name can genuinely differ from the customer of record."*

That is a reasonable decision for a simulation. The problem is that it is invisible from the
records: nothing on a Payment distinguishes "an NOC was confirmed" from "the simulator asserted one",
and FR3/AC coverage is nil while it stands. It also interacts with **BUG-RS11-01**: if the payee ever
does become real, there is still no confirming-user or timestamp field on the record to show who
accepted the NOC.

### Proposed Solution

1. Do not assert `AF_NOCRecorded__c = true` in the simulation. Leave it false and let the payee
   always match, which produces the same unblocked behaviour without recording a false statement.
2. Add `AF_NOCConfirmedBy__c` (User) and `AF_NOCConfirmedDate__c` (Date/Time), stamped when the box
   is ticked, so that once the real callout lands the confirmation is attributable. An unattributed
   checkbox is not evidence that a signed NOC exists.
3. Track FR3 as **not covered** until the real Keyloop payee arrives, rather than as built — the
   rule and the document requirement both exist but neither has ever executed against real data.
4. Consider making the box settable only when the typed *Signed NOC* document is attached, so the
   assertion and the evidence cannot diverge.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 FR3 — *"The system should check whether the payee name matches the customer/owner name at the invoicing stage. If a mismatch is identified, the Cashier must confirm that a signed NOC is in place before the invoice can be processed. The system should block invoice progression if the payee and owner names do not match and no NOC has been recorded against the opportunity."*
- **BRD**, §6 System Personas — the Cashier role is not defined (see GAP-RS11-03).
- `AF_KeyloopGetPayment.cls` header — the NOC handling note quoted above.

### Evidence

- Records: payments `PAY-00043` (DEMO RS11 20) and `PAY-00041` (DEMO RS10 13) — both show **Payee Name = the Account's own name** and **NOC Recorded? = True** on the Details tab, and both have **Signed NOC — Missing** on the Required Documents panel
- Screenshots: `screenshots/ALF-RS-11/rs11-bug07-noc-preconfirmed-payee-is-customer.png`, `screenshots/ALF-RS-11/rs11-bug04-07-required-docs-missing-on-keyloop-payment.png`
- Harness: real **Get Payment** Quick Action in the Lightning UI, values read on screen; rule text and class source from metadata retrieved 2026-09-22

---

## BUG-RS11-08 — Closed Won is refused with a message naming the wrong outstanding condition (Medium)

**Module:** Retail Sales — Deal Completion
**Status:** Open
**Applies to:** General

### Description

When a deal cannot be closed, the system tells the user it is a payment problem and sends them to the Payment related list — even when payment is complete and the real gap is the vehicle registration or the customer's signature on the delivery note. The user checks the payments, finds nothing wrong, and has no way to discover what is actually missing. The block is correct; the explanation is not.

### Steps to Reproduce

1. Log in as the Sales Representative and open a cycle-built deal at **Take the Keys** whose
   payments are completely satisfied but whose Handover is not yet done. **DEMO RS11 20**
   (`006FV00BhqEWRGuYEP`) was in exactly that state when this was captured.
2. Confirm the money side is spotless: **Details** tab → **Invoice Balance = 0.00**; click through to
   Invoice Summary **INVM-00077** — **Fully Paid**; **Related** → **Payments** → **PAY-00043** is
   **Paid / Verified**, Integration Status **Synced**, with a proof file **and** both required
   documents (Bank LPO, Signed NOC) uploaded. The Required Documents panel shows nothing
   outstanding.
3. Now look at what is actually missing: open the linked **Handover**. **Traffic Form Uploaded** is
   unticked and **Customer Sign-Off** is not *Physically Signed*.
4. Back on the Opportunity, click **Path → Mark Stage as Complete**, choose **Closed Won** in the
   *Close This Opportunity* dialog, and **Save**.
5. Read the error banner and compare it with what step 2 showed you.

### Expected Result

Per AC1, the system *"prompts for completion of outstanding conditions"* — naming what is outstanding, and ideally listing all of them at once rather than revealing them one at a time.

### Actual Result

Both records return the same payment-worded error:

```
Closed Won requires every Payment to be Paid / Verified (or Keyloop-synced) with proof attached, and the Invoice balance to be zero (ALF-RS-09 FR6). Check the Payment related list.
```

Screenshot: `screenshots/ALF-RS-11/rs11-bug08-wrong-message-payments-complete.png` — DEMO RS11 20, every payment condition satisfied, still told to check the payments.

### Root Cause

**Confirmed.** `AF_FL_Opp_ClosedWonPaymentGate` has a single custom error element, `Block_Closed_Won`, and four separate decisions route into it:

| Decision | What actually failed |
|---|---|
| `Balance_Is_Zero` (default) | invoice balance not zero |
| `Handover_Conditions_Met` (default) | **Traffic Form missing or sign-off Pending** |
| `Any_Unverified_Payments` | a payment not verified |
| `Missing_Proof_After_Loop` | a payment with no proof file |

All four emit the same payment-worded text. The validation rule `AF_VR_Opp_ClosedWonGate` has a fuller message that does list every condition, but it never gets the chance to fire, because the before-save flow blocks first.

### Proposed Solution

Split `Block_Closed_Won` into one custom error per branch — balance, registration/sign-off, payment verification, payment proof — each naming what is missing and where to fix it. Better still, collect the failures into a text variable through the existing decision path and emit one message listing all outstanding conditions, which is what AC1 asks for and what the validation rule already does in one line.

Related: the two gates duplicate each other's logic (see BUG-RS11-03); consolidating them would fix the message and the divergence together.

### Reference

- **BRD**, p. 54, §10.11 ALF-RS-11 AC1 — *"Given a Sales Representative attempts to close an opportunity as Won before payment is confirmed, When they submit, Then the system blocks the action and prompts for completion of outstanding conditions."*
- **BRD**, p. 53, §10.11 ALF-RS-11 FR1 — *"…including payment, registration, and delivery confirmation."*

### Evidence

- Record: Opportunity `006FV00BhqEWRGuYEP` (**DEMO RS11 20**) with payment `PAY-00043` fully satisfied — Paid / Verified, Keyloop-synced, proof attached, **Bank LPO and Signed NOC both uploaded**, invoice balance zero — and only the Handover incomplete
- Screenshot: `screenshots/ALF-RS-11/rs11-bug08-wrong-message-payments-complete.png`
- Harness: Lightning UI as QA SalesRep2, **Path → Mark Stage as Complete → Closed Won → Save**. For comparison, `AF_Opportunity_ClosedWonPaymentGate.check()` on the same record named the real gap: *"Registration (Traffic Form) and signed delivery note (Customer Sign-Off) must be complete on the linked Handover."*
