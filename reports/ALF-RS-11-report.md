# [ALF-RS-11] Invoicing and Deal Completion Rules — QA report

**Tested:** 2026-09-22
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Personas used:** Sales Representative (QA SalesRep2, `alfardan.qa.salesrep2@alfardan.com.qa.qa`, role *Sales Rep – SportsMotors*, `AF_PSG_Sales_Rep`). System Administrator as a control for every failure, and to carry the cycle past the persona blocker in BUG-RS11-01.
**Harnesses:** Lightning UI via Playwright as the persona (the primary harness) · REST API v68.0 as the persona · `sf` CLI v68.0 for metadata and admin-side Apex
**Test cases:** 12 written + 3 added, in `test-cases/ALF_Retail_RS-08_to_RS-16_Test_Cases.xlsx`
**Tickets:** `tickets/ALF-RS-11/README.md` · **Screenshots:** `screenshots/ALF-RS-11/`

---

## Section 1 — Summary of what was done

ALF-RS-11 is the rule set that decides when a car sale is actually *done*: payment collected, vehicle registered, delivery signed for — and only then Closed Won, with the legal invoice raised in Keyloop rather than in Salesforce.

**I started by mapping how a user actually performs this journey**, before reading the test cases. That meant listing the org's custom Quick Actions and — crucially — checking what each object's **Lightning record page** exposes, rather than what the page layout lists. The two disagree, and only the record page is what a user sees. The journey is:

> **Select Vehicle** (Opportunity, at *Consider*) → test drive completed at *Explore* → **Create Quotation** (Opportunity, at *Select*) → **Start Sync** on the Quote → **Create Reservation** (on the **Quote**) → **Get Payment** (on the **Invoice Summary**) → Path to *Take the Keys*, which auto-creates the Handover → complete the Handover → Path to *Closed Won*.

Two findings came straight out of that mapping. **Payments have exactly one entry point** — *Get Payment* on the Invoice Summary; the *Record Payment* action on the Reservation still exists in metadata but is **not on the Reservation's Lightning page**, and the Apex that replaced it states it "has been removed". And **there is no reservation action on the Opportunity at any stage** — the reservation is created from the Quote, after the quotation.

Deal completion itself is enforced in **three** places, which do not agree with each other: the validation rule `AF_VR_Opp_ClosedWonGate` (handover, delivery, balance, Traffic Form, sign-off), the before-save flow `AF_FL_Opp_ClosedWonPaymentGate` (payment verification, an attached proof file, balance, Close Date stamping), and the Apex class `AF_Opportunity_ClosedWonPaymentGate` — the same conditions **plus** a typed required-document checklist — which the class header calls *"the authoritative FR6 check"* but which only the automatic close path invokes.

I then built the whole scenario matrix up front, ran the test cases, and **re-proved every candidate finding by walking the journey again in the Lightning UI as the Sales Representative**. That last pass changed the outcome materially: two candidate findings turned out to be artefacts of data I had built by direct entry rather than through the product's actions, and three new findings surfaced that only appear when the real actions are used. Every ticket in this story now carries a screenshot of the failure as the persona saw it.

| | |
|---|---|
| Test cases executed | **15** (12 written + 3 added) |
| Passed / Failed / Partial / Blocked | 4 / 5 / 5 / 1 |
| Bugs raised | **8** — see `tickets/ALF-RS-11/README.md` |
| BA / requirement gaps raised | **7** |

**Headline verdict: the controls are well designed, but no one in the business can actually transact, and the three gates disagree about what "complete" means.** *Get Payment* — the only way a payment enters the system — fails for every `AF_PSG_*` persona, which puts the whole story out of reach of the business (**BUG-RS11-01**). Beyond that: a deal that was quoted but never reserved has no invoice at all, and the rep can hand over the keys on it in one click (**BUG-RS11-02**); a manual close is accepted while the authoritative gate is actively refusing it (**BUG-RS11-03**); a Keyloop-pulled payment arrives with no attached proof, so the deal it paid for cannot close until a human uploads a file by hand (**BUG-RS11-04**); a closed deal can be back-dated into a prior accounting period with one inline edit (**BUG-RS11-05**); FR2's Keyloop invoicing event does not exist in any form (**BUG-RS11-06**); every payment is created with the NOC pre-confirmed, so FR3's payee control can never fire — while the document engine then demands a Signed NOC that does not exist (**BUG-RS11-07**); and when a gate does block, it names the wrong outstanding condition (**BUG-RS11-08**).

What does work, and works well: on a deal built through the proper journey, *Take the Keys* correctly refuses an unsettled invoice; Closed Won blocks on incomplete deals through every route including a ten-record bulk API update; and the cheque-copy / Bank-LPO document matrix is correctly conditional on payment method, including re-demanding the right document after a method change.

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Finding |
|---|---|---|---|
| RS-11-TC-001 | Closed Won is blocked before payment, registration and delivery are all confirmed | **PARTIAL** | Blocking works. But the error names the wrong condition: on a deal whose payments were completely satisfied — verified, synced, proof and both required documents attached, balance zero — with only the Handover outstanding, the rep is still told to *"Check the Payment related list"* — **BUG-RS11-08**. |
| RS-11-TC-002 | Where vehicle registration confirmation is captured | **PASS** | Registration is `AF_Handover__c.AF_TrafficFormUploaded__c`, referenced by both the validation rule and the Apex gate; an explicit documented decision (LFRDN-341). Business caveat: the Traffic Form is submitted *before* registration completes — **GAP-RS11-02**. |
| RS-11-TC-003 | The invoicing event is triggered to Keyloop and Salesforce does not generate the legal invoice | **FAIL** | No invoicing event and no Keyloop integration exist — zero Named Credentials, one callout class whose header states *"No live Keyloop integration exists in this org yet… this is built as a full in-Salesforce simulation."* Salesforce correctly does **not** produce a legal invoice (`AF_LegalInvoice__c = false` always). **BUG-RS11-06**. |
| RS-11-TC-004 | Invoice progression is blocked on payee mismatch with no NOC | **FAIL** | The rule and the typed *Signed NOC* requirement both exist, but neither can ever execute: the only payment path sets the payee to the customer's own name and ticks `NOC Recorded` before saving, so both clauses of the rule are permanently false — **BUG-RS11-07**. The exact-string matching concern remains unresolved for when real payees arrive — **GAP-RS11-04**. |
| RS-11-TC-005 | The NOC record structure and who can record it | **PARTIAL** | The NOC is a checkbox plus a typed *Signed NOC* document. Edit on the checkbox **was granted** to the Sales Rep, Sales Manager and Showroom Manager permission set groups on 2026-09-22 at 10:21. No confirming-user or timestamp field exists, so the assertion is unattributable — carried into **BUG-RS11-07**. |
| RS-11-TC-006 | A cheque payment requires a cheque copy before confirmation | **PASS** | Conditional on method and enforced through the document matrix; Cash correctly exempt; the only file of a required type cannot be deleted. |
| RS-11-TC-007 | A bank transfer requires a Bank LPO before confirmation | **PASS** | Including the step the test case expected to fail: after switching Cheque → Bank Transfer, the stale Cheque Copy does **not** carry through — a Bank LPO is demanded and only then does the check pass. |
| RS-11-TC-008 | Whether the Cashier actions in FR3/FR4/FR5 are executable at all | **BLOCKED** | No Cashier profile, role or permission set exists. The Sales Representative both requests the invoice and supplies the proof, so the independent verification FR4/FR5 describe is not happening — **GAP-RS11-03**. |
| RS-11-TC-009 | The Closed Won date reflects completion, not an earlier milestone | **PARTIAL** | Stamped correctly on close (22/09/2026, the day the conditions were met). The rep then moved it to 01/08/2026 — two months back, into a closed period — with one inline edit and no block — **BUG-RS11-05**. |
| RS-11-TC-010 | The full completion path through to confirmed invoiced status | **FAIL** | The journey completes, but not correctly: the deal closed while the authoritative gate returned *not allowed* for missing required documents — **BUG-RS11-03** — and there is no invoicing event, no Keyloop reference and no invoiced status — **BUG-RS11-06**. |
| RS-11-TC-011 | The Closed Won validation holds at the API and bulk layer | **PASS** | A 10-record `composite/sobjects` update as the rep returned **success 0, failed 10**, with the identical validation error. The rule sits on the record, not on a screen. |
| RS-11-TC-012 | The payee check handles Arabic names, trading names and blank values | **PARTIAL** | Not reachable through the product — see TC-004: the payee is always the customer's own name, so no variant can be exercised on a real payment. The structural limitation stands for when the real Keyloop payee arrives: one Account name field, one exact-match comparison — **GAP-RS11-04**. |
| RS-11-TC-013 *(added)* | Whether the payment condition is enforced at Take the Keys | **FAIL** | On a properly reserved deal the gate **correctly refuses** an unsettled invoice. But a deal quoted and synced with **no reservation** has no Invoice Summary at all, and the rep walked it into *Take the Keys* in one click — **BUG-RS11-02**. |
| RS-11-TC-014 *(added)* | Whether the manual close applies the same rules as the automatic one | **FAIL** | It does not. With the Handover complete but the payment's Bank LPO and Signed NOC missing, the authoritative Apex gate returned *not allowed* while the rep's Path close was **accepted** — **BUG-RS11-03**. |
| RS-11-TC-015 *(added)* | Whether Delivery Confirmation is backed by evidence | **PARTIAL** | The rep can tick it inline; its stated source (the Keyloop delivery sync) does not exist. Not a hole on its own, because the gate independently requires the signed sign-off and Traffic Form — **GAP-RS11-07**. |

### Not independently verified

- **TC-003 steps 1, 2, 4, 5** — there is no invoicing endpoint, outbound call or integration log to inspect, and no confirmation can be returned, because the Keyloop integration does not exist. Nothing to test until FR2 is built. This is the one finding in the story with no UI reproduction, because it is an absence rather than a behaviour.
- **TC-006 step 4 (invalid file type)** — the required-document check reads the document *type* field, not the file extension, and no requirement states a permitted format. Recorded as GAP-RS11-06 rather than tested to a verdict.
- **TC-009 step 5 (monthly report)** — verified structurally (the reporting date *is* the editable `CloseDate`, there being no separate system-stamped completion field) rather than by building a saved report.
- **TC-012** — could not be executed as written, because the product gives no way to record a payment with a payee other than the customer. Verified by reading the only payment path instead.

---

## Section 3 — BA / requirement gaps to raise

### GAP-RS11-01 — FR3, FR4 and FR5 assign mandatory work to a Cashier; ALF-RS-08 says Finance is not on Salesforce in Release 1.

**What the documents say:** BRD p. 54, §10.11 FR4 — *"the system should require the **Cashier** to upload a copy of the cheque as proof of payment before the invoice can be confirmed. This copy is retained for filing purposes and verified by the Cashier during invoicing."* FR5 says the same for the Bank LPO; FR3 — *"the **Cashier** must confirm that a signed NOC is in place before the invoice can be processed."* Against that, BRD §10.8 ALF-RS-08 Assumption 8 states the Finance team is not on Salesforce in Release 1, that Sales Representatives create the payment record and attach proof, and that the cashier issues the receipt outside Salesforce.

Both cannot be true. In the build, the Sales Representative does all of it. **Decision needed from the BA:** either Finance/Cashier comes into Release 1 scope with a role and licence, or FR3/FR4/FR5 are restated as Sales-performed steps and the loss of independent verification is accepted in writing.

### GAP-RS11-02 — The Traffic Form proves the registration was *submitted*, not *completed*.

FR1 (BRD p. 53) requires *"registration"* as a completion condition. The build uses `AF_Handover__c.AF_TrafficFormUploaded__c` — a deliberate, documented decision — but the Traffic Form is lodged before the Traffic Department completes registration. **Decision needed:** is submission sufficient to call a deal complete, or does Closed Won need evidence of completed registration (a plate number, a registration card upload, a Keyloop status)?

### GAP-RS11-03 — "Cashier" is not in the personas table at all.

FR3, FR4 and FR5 name the role; BRD §6 System Personas does not define it, and nothing in the org represents it. **Decision needed:** define the Cashier (and the wider Finance persona) in §6 with responsibilities and data rights, or remove the role from these requirements.

### GAP-RS11-04 — The payee-name match rule is undefined for anything but an exact match.

FR3 (BRD p. 54) — *"The system should check whether the payee name matches the customer/owner name at the invoicing stage."* It does not say what "matches" means. The build does an exact string comparison against `Account.Name`, so *"DEMO RS11 Customer Fatima AlThani"* is a mismatch against *"DEMO RS11 Customer - Fatima Al-Thani"*, and an Arabic-script account name can never match an English payee (the Account has a single name field). **Decision needed:** the matching rule — punctuation/whitespace normalisation, a second (English/Arabic) name field, and which name is legally relevant (account, opportunity owner, or contact).

### GAP-RS11-05 — Mixed payment methods on one deal are not addressed.

FR4 and FR5 are each written for a single payment method. In the build the requirement is keyed per **Payment record**, so a cheque deposit and a bank-transfer balance each carry their own proof — a sensible resolution, but not one any document states. **Decision needed:** confirm the per-payment interpretation.

### GAP-RS11-06 — No permitted file format is defined for proof documents.

FR4 and FR5 require a "copy" to be uploaded and retained for filing. The check is on the document *type* the uploader selects, not on the file itself, so any file can be classified as a Cheque Copy. **Decision needed:** permitted formats (PDF/JPG/PNG), and whether that should be enforced.

### GAP-RS11-07 — "Delivery confirmation" has no defined source.

FR1 lists delivery confirmation as a Closed Won condition. The build has `Opportunity.AF_DeliveryConfirmation__c`, whose own design note reserves it for a Keyloop/MuleSoft delivery-status sync that does not exist; today it is a checkbox the closing user can tick. **Decision needed:** define what evidences delivery — and if the signed delivery note on the Handover is the answer (as the gate already independently requires), remove the redundant checkbox from the gate.

---

## Section 4 — Walkthrough by functional requirement and acceptance criterion

Login: `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` — dismiss *Change Your Password* with **Cancel**. Everything below was performed in the Lightning UI as that persona unless it says otherwise.

### The cycle I walked

Two deals were built end to end through the product's own actions, and they are the evidence behind most of this section:

| Record | Id | Built how | Left in this state |
|---|---|---|---|
| **DEMO RS11 20** – Real cycle, unpaid, keys gate test | `006FV00BhqEWRGuYEP` | Select Vehicle (Ferrari Roma + Spider Package) → test drive → Create Quotation → Start Sync → Create Reservation → Get Payment | **Closed Won** with required documents missing and Close Date back-dated to 01/08/2026 |
| **DEMO RS11 21** – Quoted but never reserved | `006FV00BhMDdpSuYUJ` | Select Vehicle (Rolls-Royce Cullinan + Black Badge) → test drive → Create Quotation → Start Sync. **No reservation.** | **Take the Keys** with no invoice, no reservation, no payment |

Please don't "fix" either — they are the repro records for BUG-RS11-02, 03 and 05.

### FR1 / AC1 — *"…cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."*

**What I did**

1. Took DEMO RS11 20 through the full journey to *Take the Keys*, which auto-created Handover **HO-00035** (`AF_FL_Opp_CreateHandoverOnTakeTheKeys` fires on that stage change).
2. With the Handover untouched, clicked **Path → Mark Stage as Complete → Closed Won → Save**.
3. Satisfied every payment condition — attached the proof file plus both typed documents (Bank LPO, Signed NOC) — leaving the Handover as the only gap, and tried again.
4. Completed the Handover (Traffic Form ticked, Customer Sign-Off *Physically Signed*), removed the typed documents, and tried once more.
5. Separately, took DEMO RS11 21 — quoted and synced but never reserved — from *Commit* with one click of **Mark Stage as Complete**.

**What happened:** steps 2 and 3 were both refused, correctly in principle. Step 4 **was accepted**. Step 5 **was accepted**.

> ⚠️ **BUG-RS11-02 — step 5.** DEMO RS11 21 moved into *Take the Keys*, the stage where the customer receives the car, with **no Invoice Summary, no reservation and no payment**. `AF_VR_Opp_TakeTheKeysGate` tests `AF_InvoiceBalance__c <> 0`, and that mirror field is `null` when no invoice was ever created — a null Number evaluates as zero, so the gate passes. It fails open exactly when there is nothing to check. On DEMO RS11 20, which *was* reserved, the same gate correctly refused: *"Take the Keys stage requires the invoice balance to be fully settled (zero)."* Screenshot: `rs11-take-the-keys-no-invoice.png`.

> ⚠️ **BUG-RS11-03 — step 4.** The close saved, and the Opportunity's Last Modified By reads **QA SalesRep2** — while `AF_Opportunity_ClosedWonPaymentGate`, called on the same record, returned *"Not every Payment has its required documents (Cheque Copy / Bank LPO / Signed NOC) uploaded."* The build's own "authoritative FR6 check" is not what runs when a user moves the Path. Screenshot: `rs11-bug03-closed-won-despite-gate-refusing.png`.

> ⚠️ **BUG-RS11-08 — step 3.** With every payment condition satisfied and only the Handover outstanding, the banner still read *"Closed Won requires every Payment to be Paid / Verified (or Keyloop-synced) with proof attached, and the Invoice balance to be zero (ALF-RS-09 FR6). Check the Payment related list."* The authoritative gate named the real gap correctly — *"Registration (Traffic Form) and signed delivery note (Customer Sign-Off) must be complete on the linked Handover"* — but the user never sees that. Screenshot: `rs11-bug08-wrong-message-payments-complete.png`.

### FR2 / AC3 — *"…triggering the invoicing event in Keyloop via MuleSoft and receiving the completion confirmation back into Salesforce."*

**What I did:** searched the org for the integration — Named Credentials, Apex callouts, platform events, and any writer of `AF_InvoiceSummary__c.AF_KeyloopInvoiceReference__c` — then completed a deal and looked for an invoiced status.

**What happened:** there is no invoicing event. The org's only callout-shaped class is `AF_KeyloopGetPayment`, whose header states: *"No live Keyloop integration exists in this org yet (confirmed: zero Named Credentials, zero Apex HTTP callouts anywhere)… this is built as a full in-Salesforce simulation."* Nothing writes the Keyloop invoice reference. A completed deal carries no invoiced status.

> ⚠️ **Bug hit here — BUG-RS11-06.** This is the one finding with no UI reproduction, because it is an absence rather than a behaviour.

**One thing FR2 gets right:** Salesforce does **not** generate the legal invoice — `AF_InvoiceSummaryService` sets `AF_LegalInvoice__c = false` on every Invoice Summary it creates, exactly as the requirement demands.

### FR3 — *"…check whether the payee name matches the customer/owner name… block invoice progression if the payee and owner names do not match and no NOC has been recorded."*

**What I did:** tried to record a payment with a third-party payee through the product. Checked the **Get Payment** screen, and the Vehicle Reservation's action bar. Then read the payment that Get Payment actually creates.

**What happened:** there is no way in. *Get Payment* takes **one input** — the Keyloop Payment ID. Everything else is synthesised: the payee is set to the Invoice Summary's own Account name, and `AF_NOCRecorded__c` is set to `true`. On **PAY-00043** the Details tab reads *Payee Name: DEMO RS10 Customer - Khalid Al-Mannai* and *NOC Recorded?: True*, on a payment no human reviewed.

`AF_VR_Payment_PayeeMismatchNOC` requires `AF_PayeeName__c <> AF_Account__r.Name` **and** `NOT(AF_NOCRecorded__c)`. Both clauses are permanently false, so the rule can never fire.

> ⚠️ **Bug hit here — BUG-RS11-07**, and it bites twice. Because the NOC flag is set, the document engine then demands a **Signed NOC** document on every payment — the Required Documents panel on PAY-00043 shows *Signed NOC — Missing* — for a certificate that does not exist and was never requested. Screenshots: `rs11-bug07-noc-preconfirmed-payee-is-customer.png`, `rs11-bug04-07-required-docs-missing-on-keyloop-payment.png`.

**The design note is explicit** that this is a stopgap: *"because the simulated payee is always the Invoice Summary's own Account, a payee mismatch cannot occur yet… The NOC generation path is re-introduced alongside the real Keyloop callout."* Reasonable as an interim, but FR3 has never executed against real data and should be tracked as uncovered rather than built.

### FR4 / FR5 — cheque copy and Bank LPO before the invoice is confirmed

**What I did:** exercised the `AF_Document__mdt` matrix — a Cheque payment with and without a typed *Cheque Copy*; a Cash payment with nothing attached; a switch from Cheque to Bank Transfer with only the cheque copy on file. Then checked what the real payment action produces.

**What happened:** the matrix itself is the best-built part of the story. Cheque with no copy → unmet; add a *Cheque Copy* → met. Cash with nothing → met (correctly exempt). After the method switch → unmet again, and only a *Bank LPO* satisfied it. Deleting the only file of a required type is refused.

> ⚠️ **Bug hit here — BUG-RS11-04.** The payment the product itself creates arrives with **no file attached at all** — only a text reference, *"Keyloop payment KL-PAY-RS11-020"*. The close gate requires a real `ContentDocumentLink`, deliberately: *"the BRD's own vocabulary… is consistently 'attach'/'attached'/'upload', never 'reference field'."* So every payment taken by the intended route blocks the deal it just paid for until a human uploads a file by hand. Nothing in the product offers to do it.

> ⚠️ **And BUG-RS11-03 again.** Once the Handover is complete, the typed-document requirement stops mattering — the manual Path close ignores it entirely.

### FR6 / AC2 — *"…record the Closed Won date based on when the agreed completion conditions are satisfied, not on an earlier sales milestone."*

**What I did:** closed DEMO RS11 20 (Close Date preset to 22/10/2026), checked the stamped date, then edited it inline as the rep.

**What happened:** on close the date became **22/09/2026** — the day the conditions were met — applied by the before-save flow's `Stamp_Close_Date`. Correct.

> ⚠️ **Bug hit here — BUG-RS11-05.** Immediately afterwards, the pencil next to **Close Date** on the Details tab took **01/08/2026** — two months back, into a closed period — and saved with no block, warning or approval. None of the Opportunity's thirteen validation rules references `CloseDate`, and there is no separate system-stamped completion date, so management reporting follows the edited value. Screenshot: `rs11-bug05-close-date-backdated-by-rep.png`.

### Cross-cutting — the persona blocker

Everything above needed a payment, and **the Sales Representative cannot make one**. *Get Payment* fails for the rep with *"We couldn't pull the payment"* over a `DmlException` on the Opportunity; the same button works for a System Administrator on the same record. Edit on `Opportunity.AF_InvoiceBalance__c` — written by the recalculation every payment triggers — is granted only to System Admin, `AF_PS_Opportunity_FullAccess` and the MuleSoft user. All seven `AF_PSG_*` groups have read-only.

> ⚠️ **BUG-RS11-01.** Screenshot: `rs11-getpayment-fails-for-rep.png`. The same root cause still breaks **Create Reservation** for the rep (`rs11-create-reservation-still-fails-for-rep.png`, ALF-RS-10 LFRDN-671) — a batch of Opportunity field permissions was granted on 2026-09-22 at 10:21 but missed this field.

**Where admin was used:** the payments on DEMO RS11 20 and the reservation creation, because the persona is blocked. Every stage change, every close attempt, the Close Date edit and all record reading were done as the Sales Representative.

### Cross-cutting — API and bulk enforcement (BRD §10.9 ALF-RS-09 FR6)

Ten incomplete opportunities (`DEMO RS11 Bulk 01–10`) updated in one `composite/sobjects` call as the rep: **0 succeeded, 10 failed**, same validation error. The control is on the record, not the screen. **Verdict: PASS.**

---

## Section 5 — Hands-on: run ALF-RS-11 yourself

### What this story is, and how it is built

In business terms: a car is not *sold* just because the customer said yes. ALF-RS-11 is the rule that the deal only counts once the money is in, the car is registered, and the customer has signed for delivery — and that the **legal invoice is raised in Keyloop, not in Salesforce**.

Four things are worth knowing before you click anything:

- **Payments have one entry point only.** *Get Payment* on the Invoice Summary. The *Record Payment* action on the Reservation is not on that object's Lightning page and should be treated as gone.
- **The reservation is created from the Quote**, not the Opportunity — there is no reservation action on the Opportunity at any stage.
- **The Handover creates itself** when the Opportunity reaches *Take the Keys*.
- **Three gates, one of which does not run.** A validation rule and a before-save flow fire when you move the Path. An Apex class — the one the build calls authoritative, and the only one that checks the typed documents — runs only on the automatic close path.

### Records created for you

| Record | Id | What it shows |
|---|---|---|
| **DEMO RS11 20** – Real cycle, unpaid, keys gate test | `006FV00BhqEWRGuYEP` | Closed Won with documents missing, Close Date back-dated — BUG-RS11-03, 05, 08 |
| **DEMO RS11 21** – Quoted but never reserved | `006FV00BhMDdpSuYUJ` | At *Take the Keys* with no invoice — BUG-RS11-02 |
| **PAY-00043** (on DEMO RS11 20) | `a0UFV005pRsnTDE2Q2` | Keyloop payment: payee = the customer, NOC pre-ticked, required documents missing — BUG-RS11-04, 07 |
| **HO-00035** | `a0SFV001Mwbae6G2IQ` | The auto-created Handover |
| DEMO RS11 01–08 | — | The original scenario matrix, built by direct entry — useful for reading, not for judging behaviour |
| DEMO RS11 Bulk 01–10 | from `006FV00BhIjPw0qYUC` | Ten incomplete deals for the bulk-close test |

### What to do, step by step

**1 — See the blocker first. Log in as the Sales Rep.**
Open **DEMO RS11 21** → Details → click through to any Invoice Summary you can find on another deal (RS11 21 has none) — e.g. **INVM-00077** on DEMO RS11 20 → click **Get Payment**, type any reference, **Next**.
- *You should see:* the payment pulled. *You will see:* **"Something went wrong."** → **BUG-RS11-01**

**2 — The keys gate, both ways.**
Open **DEMO RS11 21**. Details tab: **Invoice Summary blank, Vehicle Reservation blank, Invoice Balance blank**, Payments related list empty. Its Stage is **Take the Keys**.
- *You should see:* a deal stuck at Commit. *You will see:* it is already past the gate → **BUG-RS11-02**
- For contrast, DEMO RS11 20 *was* reserved, and that same gate refused it while it was unpaid — the control works when there is an invoice to check.

**3 — The message that points the wrong way.**
On a deal at *Take the Keys* whose payments are clean but whose Handover is not done, click **Path → Mark Stage as Complete → Closed Won → Save**.
- *You should see:* a message naming the registration or the signature. *You will see:* *"Check the Payment related list."* → **BUG-RS11-08**

**4 — The gate that is overruled.**
Open **DEMO RS11 20**. It is **Closed Won**. Now open **PAY-00043 → Related → Required Documents**: **Bank LPO — Missing**, **Signed NOC — Missing**.
- *You should see:* a deal that could not close without its Bank LPO. *You will see:* closed anyway → **BUG-RS11-03**

**5 — The NOC nobody confirmed.**
Still on PAY-00043 → **Details**. **Payee Name** is the customer's own name; **NOC Recorded?** is **True**. No one ticked it.
- *You should see:* a false NOC flag and no Signed NOC demand. *You will see:* both wrong → **BUG-RS11-07**

**6 — The date that will not stay put.**
On **DEMO RS11 20**, Details tab, pencil next to **Close Date**, set any earlier date, **Save**.
- *You should see:* refused, or an approval. *You will see:* it saves → **BUG-RS11-05**

**7 — Bulk enforcement, which does work.**
Select **DEMO RS11 Bulk 01–10** in a list view and mass-update the Stage to Closed Won.
- *You should see:* all ten rejected. *You will see exactly that.* ✓

### Scorecard — fill in as you go

| # | What you are checking | Record | Expected | Matches? |
|---|---|---|---|---|
| 1 | Get Payment works for the rep | INVM-00077 | Payment recorded | ☐ |
| 2 | No-invoice deal cannot reach Take the Keys | DEMO RS11 21 | Still at Commit | ☐ |
| 3 | Reserved unpaid deal is blocked at Take the Keys | DEMO RS11 20 | Refused | ☐ |
| 4 | Error names the real missing condition | any at Take the Keys | Names registration | ☐ |
| 5 | No Bank LPO, no close | DEMO RS11 20 / PAY-00043 | Not Closed Won | ☐ |
| 6 | NOC not asserted without a person | PAY-00043 | NOC Recorded = False | ☐ |
| 7 | Keyloop payment carries its proof file | PAY-00043 → Files | File present | ☐ |
| 8 | Close Date cannot be back-dated | DEMO RS11 20 | Edit refused | ☐ |
| 9 | Keyloop invoice reference present | any closed deal | Reference stored | ☐ |
| 10 | Ten incomplete deals rejected | DEMO RS11 Bulk 01–10 | 0 succeed | ☐ |

---

## Records left in the org as evidence

Two cycle-built deals, **DEMO RS11 20** (Closed Won, documents missing, Close Date 01/08/2026) and **DEMO RS11 21** (Take the Keys, no invoice), plus payment PAY-00043 and Handover HO-00035. The earlier `DEMO RS11 01–08` matrix, the Arabic-script account, and `DEMO RS11 Bulk 01–10` remain. **Please don't "fix" DEMO RS11 20 or 21** — they are the repro records.

## Org configuration changed during testing

- No metadata, permission or setting was altered by me.
- **Changed by others during the session:** `AF_OpportunityReservationMirrorSync` was deployed at 10:17 (the LFRDN-669 fix), and Opportunity/Payment field permissions were granted across the `AF_PSG_*` groups at 10:20–10:21 — including Edit on `AF_Payment__c.AF_NOCRecorded__c`, which had previously been granted to nobody. `AF_SalesOrderService`, `AF_ReservationContractService` and `AF_VehicleOrderStatusSync` were also redeployed between 10:48 and 11:11. Findings in this report reflect the org **after** those changes.
- Payments and documents on DEMO RS11 20 were created by System Administrator, because the Sales Representative is blocked by BUG-RS11-01.
