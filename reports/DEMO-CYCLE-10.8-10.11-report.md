# Retail cycle, Select Vehicle → Closed Won (ALF-RS-08 → ALF-RS-11) — QA report

**Date:** 2026-09-24 · **Org:** Al-Fardan QA sandbox · **Tickets:** `tickets/DEMO-CYCLE-10.8-10.11/README.md` · **Screenshots:** `screenshots/DEMO-CYCLE/`

---

## 1. Summary of what was done

One complete retail sale was driven end to end in the Lightning UI as **QA SalesRep2** (Sales
Representative), using the product's own actions in the order a rep uses them, to decide whether
10.8–10.11 are demo-ready:

**Select Vehicle → test drive Refused → Create Quotation → Start Sync → Create Reservation (10.8) →
Required Documents + Reservation Contract (10.8) → Get Payment (10.9) → Generate Sales Order (10.10)
→ Take the Keys → Handover → Closed Won (10.11).**

- **Harness:** UI for every business step; Apex / SOQL read-back after each step; metadata and code
  read to root-cause each failure; persona API queries to confirm field access.
- **Set-up done as System Administrator (API), not as the rep:** four new In Stock vehicles (the org
  had only one car that could complete the whole journey), and the customer Account / Contact /
  Opportunity at *Consider*. Every step from Select Vehicle onward was performed as the rep.
- **Test cases:** 28 executed — 21 from the RS-08…RS-12 workbook, 7 added during execution.
  **13 PASS, 7 FAIL, 6 PARTIAL, 2 Not verified.**
- **Verdict: not demo-ready end to end.** Select Vehicle through 10.9 is demo-ready. **10.10 is
  blocked** for every rep by a regression deployed on 2026-09-23 (BUG-RS10-12). **10.11 closes only
  if the rep ticks three handover checkboxes by hand** (BUG-RS12-01, BUG-RS12-02, BUG-RS11-11), and
  once closed, the sold car is offered to the next customer (BUG-RS08-01).
- **Fixes confirmed on the same run:** LFRDN-692 (uploaded documents are now tagged — reservation,
  payment and handover), LFRDN-666 / LFRDN-671 (Get Payment works for the rep), LFRDN-637 (the
  specific vehicle is carried onto the quote line). **LFRDN-678 still reproduces** (see §2).
- **New defects:** 11 tickets drafted — 3 Highest, 3 High, 3 Medium, 2 Low.

---

## 2. Test cases executed

**Cycle records:** Opportunity **DEMO Cycle 01 - Ferrari Roma end-to-end** `006FV00Bq30GjbQYES` ·
Test Drive **TD-00196** · Quote **00000189** `0Q0FV004Xp29WYO0I2` · Reservation **RES-00178**
`a0WFV000g00AQ0m2AG` · Invoice **INVM-00080** `a0TFV00G2U9j5Tg2UI` · Payment **PAY-00050**
`a0UFV005tbUHQ482AH` · Handover **HO-00037** `a0SFV001PomVg8q2IC` · Vehicle **Ferrari Roma - Blu Pozzi
Blue** `0vLFV00057JQdOe2AL`.

| TC | What it tests | Result | Finding |
|---|---|---|---|
| CYC-01 *(added)* | Select Vehicle shows only the Opportunity's brand, offers new stock, and writes vehicle, model and price to the deal | PASS | Ferrari-only cards (296 GTB ×2, Roma ×1, SF90 ×1); Roma + *Spider Package* line → toast *"Vehicle selected"*; Opportunity Amount AED 279,308 (247,308 + 32,000). `01`–`04` |
| CYC-02 *(added)* | Declining the test drive (Refused) releases the stage gate | PASS | TD-00196 auto-created at *Explore*; set Status/Result **Refused** + remarks → `AF_StageGatePassed__c` true, gate unblocked, stage moved to *Select*. *Cancelled* no longer exists as a status |
| CYC-03 *(added)* | Create Quotation + Start Sync carry the specific vehicle | PASS | Quote 00000189, AED 279,308, vehicle line = Ferrari Roma - Blu Pozzi Blue (LFRDN-637 holds); Start Sync → Quote *Presented*, Opportunity synced. `05`–`06` |
| RS-08-TC-001 | Reservation is created from the quotation and linked to Opportunity, Quote and Vehicle | PASS | RES-00178 created from Quote 00000189 with Opportunity, Quote and Vehicle populated; toast *"Reservation created"*. `07`–`09` |
| RS-08-TC-004 | Deposit at/above threshold → auto-flow, 7-day reservation | PASS | Deposit AED 30,000 → Status **Reserved**, Approval **Not Required**, Start 24/09/2026, Expiry **01/10/2026**; vehicle Reservation Status → Reserved; Quote → *Accepted*. `10` |
| RS-08-TC-011 | Contract is blocked while a Required Document is missing, naming the missing one | PARTIAL | Blocked correctly, but the message does not name the document — **BUG-RS08-03**. `11` |
| CYC-04 *(added)* | Approval Reference is required only when a manager approved | FAIL | Required on an auto-approved reservation — **BUG-RS08-02**. `12` |
| CYC-05 *(added)* | Required Documents uploads are tagged and satisfy the checklist (LFRDN-692 retest) | PASS | All five uploads renamed and tagged (`AF_FileUpload__c` = Customer ID, Approval Reference, Quotation, Vehicle Stock / VIN, Payment Receipt), created by QA SalesRep2. Badges flip to *Uploaded* only after a page reload. `16` |
| RS-08-TC-017 | Contract gated until a verified payment exists | PARTIAL | Documents gate fired first so the payment gate was not isolated; after PAY-00050 (*Paid / Verified*) and the documents, the contract generated |
| RS-08-TC-013 | Contract contains every FR14 element | PARTIAL | Real PDF *Reservation Contract - RES-00178* (`069FV007TZItZoyYYF`): vehicle, VIN, colours, quote, amounts, payment reference, period, terms, signatures — **trim missing, BUG-RS08-04**. Email/Phone print "-" because of how the test customer was set up (not a defect). `17`–`18` |
| RS-09-TC-003 | Full payment → Invoice Fully Paid | PASS | Get Payment `KL-PAY-DEMO-C01` as the rep → PAY-00050 AED 279,308 Bank Transfer *Paid / Verified*, linked to RES-00178; INVM-00080 **Fully Paid**, balance 0, mirrored to the Opportunity (LFRDN-666/671 hold). `14`–`15` |
| RS-09-TC-001 | Deposit → Invoice Partially Paid, contract reflects the deposit | Not verified | Get Payment always pulls the full outstanding balance, so a part-payment cannot be recorded (see §3, gap 4) |
| RS-09-TC-011 | Contract shows deposit, balance and duration clearly | PARTIAL | Shows *Deposit Paid 279,308*, *Remaining 0*, start/expiry — correct for a full payment, but the agreed AED 30,000 deposit is not shown as such |
| RS-09-TC-006 | Sales Transaction Summary generated and stored on the Opportunity | PARTIAL | *Transaction Summary Doc Reference* `069FV007TYl3cyqYYA` present on the Opportunity; generated without a Sales Order (the Sales Order itself failed) |
| RS-10-TC-010 | Full-payment confirmation prompt before Sales Order | PASS | Prompt shows total, received, outstanding and requires *"Yes, full payment has been collected"*. Amounts shown in **QAR** while every other screen shows **AED** — **LFRDN-678 still reproduces**. `19` |
| RS-10-TC-001 | Sales Order is created and linked once conditions are met | FAIL | *"An Apex error occurred: System.QueryException: No such column 'Phone' on entity 'Account'…"* — **BUG-RS10-12**. `20` |
| CYC-06 *(added)* | Take the Keys requires a settled invoice and creates the Handover | PASS | Stage moved to *Take the Keys*; HO-00037 created *Pending*. Also reached **without a Sales Order** (see §3, gap 2). Handover created without Vehicle/Contact/Invoice — **BUG-RS12-04**. `21`–`22`, `24` |
| RS-12-TC-005 | Five handover agreements generated automatically | PASS | **Generate Documents** → Vehicle Sale, Warranty, Service Contract, Vehicle Repair Disclaimer, Buyer Acknowledgement PDFs, each tagged; five checklist flags ticked. `23` |
| CYC-07 *(added)* | Delivery Note generated once the handover is scheduled | FAIL | Date + location set, action re-run → no Delivery Note — **BUG-RS12-02**. `27` |
| RS-12-TC-001 | Handover captures date, time, location | PARTIAL | Date and location saved; Vehicle, Contact, Invoice Summary left blank (**BUG-RS12-04**) |
| RS-12-TC-008 | Traffic / Insurance Form uploads recorded | FAIL | Uploaded and tagged, checkboxes never ticked — **BUG-RS12-01**. `27` |
| RS-11-TC-001 | Closed Won blocked while conditions are outstanding | PASS | *"Closed Won requires registration and delivery confirmation on the linked Handover (ALF-RS-11 FR1): the Traffic Form must be uploaded and Customer Sign-Off must be Physically Signed."* `28` |
| RS-11-TC-007 | Bank Transfer requires a Bank LPO upload (LFRDN-692 original case) | PASS | Bank LPO uploaded on PAY-00050 via Required Documents → tagged *Bank LPO* by QA SalesRep2 |
| RS-11-TC-010 | Full completion path to Closed Won | FAIL | Reachable only by ticking three checkboxes by hand; the auto-close in between fails raw — **BUG-RS11-10**, **BUG-RS11-11**. `29`–`30` |
| RS-11-TC-015 | Delivery confirmation backed by evidence, not a self-service checkbox | FAIL | Rep ticked *Delivery Note Generated?* with no Delivery Note → deal **Closed Won** — **BUG-RS11-11** |
| RS-11-TC-009 | Closed Won date stamped when conditions are met | PASS | Close Date set to 24/09/2026 at close. `33` |
| RS-08-TC-022 *(scope extended)* | A vehicle cannot be held/sold twice | FAIL | After Closed Won the sold Roma is offered in Create Reservation — **BUG-RS08-01**; Sales Order Status shows *Delivered* with no Sales Order — **BUG-RS12-03**. `32`–`33` |
| RS-08-TC-025 | Threshold matrix resolves per brand and business unit | Not verified | Values read, not exercised below threshold: Ferrari **0.1**, Rolls-Royce 50,000, BMW/Mini 10,000, Jaguar/Land Rover 5,000 (see §3, gap 1) |

**Not independently verified, and why**

- **3-day no-deposit contract (RS-08 AC1)** and **below-threshold manager approval (RS-08 AC6)** —
  not exercised on this cycle; hands-on records DEMO CYCLE 04 and 03 are set up for them (§5).
- **Expiry reminders, expiry and stock release (RS-08 FR5, FR16, FR17, AC4, AC12)** — time-based; need
  the reservation to reach its expiry date.
- **Print / email option for the reservation agreement (RS-08 FR15)** — not exercised.
- **Sales Order document content** — blocked by BUG-RS10-12, so the LFRDN-674 content fix itself could
  not be checked.
- **Invoice trigger to Keyloop (RS-11 FR2, AC3)** — the integration does not exist (LFRDN-685).
- **CRM follow-up task two days after handover (RS-12 FR9)** — time-based.
- **Reservation approval by a manager** — needs the manager persona; not attempted.

---

## 3. BA gaps to raise

1. **Ferrari's deposit threshold is 0.1.** Every other brand carries a whole-currency figure
   (Rolls-Royce 50,000, BMW/Mini 10,000, Jaguar/Land Rover 5,000). The flow compares the deposit to
   the number as an absolute amount, so any Ferrari deposit of AED 0.10 or more auto-approves, and
   the below-threshold approval path (FR8b / AC6) can never trigger for Ferrari. It reads like a
   placeholder or a percentage. BRD §10.8, p.49, Assumption 4: *"Per-brand and per-business-unit
   minimum deposit threshold matrix to be provided by IT (Mukhtar) in coordination with brand managers
   and configured during the design phase."* **Decision needed from IT / Ferrari brand manager:** the
   real Ferrari threshold, and whether any brand's threshold is a percentage.

2. **Take the Keys and the Handover are reachable without a Sales Order.** DEMO Cycle 01 reached
   Take the Keys and Closed Won with Sales Order Status *Not Generated*. The BRD orders the steps —
   §10.12, p.55, FR6: *"Following Sales Order generation with full payment confirmed, the system should
   prompt the Sales Representative to upload the completed Traffic Form…"* — but no FR states that
   Take the Keys or Closed Won require a Sales Order; §10.11 FR1's conditions are *"payment,
   registration, and delivery confirmation"*. **Decision needed from the business:** should a
   generated Sales Order be a gate for Take the Keys (or Closed Won)?

3. **The "pick a different vehicle" list is not limited to the Opportunity's brand.** On a
   Rolls-Royce quote (DEMO RS11 21) the list offered three Ferraris. The reservation takes its price
   from the quote, so a Ferrari reserved there would carry the Rolls-Royce total. The BRD does not say
   whether a reservation's vehicle must match the quoted brand/model (§10.8 FR1: *"vehicle reservation
   linked to the opportunity, triggered after quotation"*, p.46). **Decision needed:** restrict the
   list to the quoted brand, or to the quoted model?

4. **Deposits cannot be recorded as part-payments today.** *Get Payment* — the only payment path —
   pulls the whole outstanding balance, so Invoice *Partially Paid* (RS-09 AC1) and a contract
   showing the agreed deposit (RS-09 AC3) cannot be demonstrated. The amount is meant to come from
   Keyloop, whose payment touchpoints are still open — §10.9, p.51, Assumption 1: *"Detailed payment
   touchpoints with Keyloop and finance systems to be finalized during technical design."*
   **Decision needed:** until Keyloop is connected, should Get Payment let the rep enter the amount
   received?

5. **Reservation documents that are system records must be uploaded as files.** The reservation
   checklist requires the rep to upload a *Quotation* and a *Vehicle Stock / VIN* document, although
   both already exist as records linked to the reservation. §10.8, p.47, FR13 says the system should
   *"reference and link the following Required Documents to the reservation"*, and Assumption 3
   (p.49) leaves the list *"to be confirmed and finalised by the business"*. **Decision needed:**
   should the Quote and the vehicle stock record be linked automatically rather than uploaded?

---

## 4. Walkthrough, by functional requirement and acceptance criterion

All steps as **QA SalesRep2** in the **Automotive** app unless stated.

### Before 10.8 — choosing the car and quoting

- **Select Vehicle** — DEMO Cycle 01 (*Consider*) → **Show more actions** → **Select Vehicle**.
  Vehicle Finder shows Ferrari models only → **Ferrari Roma** → **2025 Ferrari Roma, Blu Pozzi Blue,
  In Stock, STK-ROMA-031** → *Choose a Line*: **Spider Package** (+AED 32,000) → **Confirm Line**.
  Toast *"Vehicle selected"*; Amount AED 279,308. **Passes.**
- **Test drive** — Path → **Mark Stage as Complete** (→ *Explore*) creates **TD-00196** *Requested*
  and blocks the gate. Open TD-00196 → **Edit** → Status **Refused**, Result **Refused**, Refused
  Remarks → **Save**. Gate released; Path → *Select*. **Passes.**
- **Quote** — reload → **Show more actions** → **Create Quotation** → **Customer Quotation** → **Next**
  → *"Quotation created"* → **Finish**. Quote **00000189** → **Show more actions** → **Start Sync** →
  **Continue**. **Passes.**

### 10.8 — Vehicle Reservation with Governance

| FR / AC | What was done | Outcome |
|---|---|---|
| **FR1** reservation linked to the opportunity after quotation | Quote 00000189 → **Create Reservation** → *Yes, reserve the same vehicle* | RES-00178 created with Opportunity, Quote, Vehicle. **Pass** |
| **FR2 / AC2** 7-day contract with deposit | Contract Type **7-Day (Deposit)**, Deposit **30000**, Source **In Stock** → **Next** → **Finish** | Expiry 01/10/2026 (start + 7). **Pass** |
| **FR7 / FR8a / AC5** at/above threshold → auto-flow | Same step | Approval **Not Required**, Status **Reserved**. **Pass** — but see §3 gap 1 on the Ferrari value |
| **FR10** remaining balance | RES-00178 → Details | Remaining Balance AED 249,308 (279,308 − 30,000) before payment; 0 after full payment. **Pass** |
| **FR13 / AC10** Required Documents before contract | RES-00178 → **Generate Reservation Contract** | Refused: *"Required Documents are not fully uploaded on this reservation (FR13)…"* — **at this step the message does not name the missing document: BUG-RS08-03.** Related tab → checklist lists Approval Reference, Customer ID, Payment Receipt, Quotation, Vehicle Stock / VIN — **Approval Reference is demanded on an auto-approved reservation: BUG-RS08-02.** Each uploaded via its **Upload Files**; all five tagged (LFRDN-692 **fixed**). **Partial** |
| **FR12 / AC9** contract after verified payment | After 10.9 below → **Generate Reservation Contract** | *"Reservation Contract generated"*. **Pass** |
| **FR14 / FR15** contract content, PDF | Notes & Attachments → *Reservation Contract - RES-00178* | PDF with customer, vehicle, VIN, colours, amounts, payment reference PAY-00050, period, terms, signature block — **trim missing: BUG-RS08-04.** **Partial** |
| **Overview / FR17** inventory control | After Closed Won: another quote → **Create Reservation** → *No, let me pick a different one* → **Next** | **The sold Roma is listed as In Stock and selectable: BUG-RS08-01.** **Fail** |

### 10.9 — Payment and Deposit Processing

| FR / AC | What was done | Outcome |
|---|---|---|
| **FR1 / AC1** deposit capture, Partially Paid | — | Not verified: Get Payment pulls the full balance (§3 gap 4) |
| **FR2 / FR4 / AC2** Fully Paid | INVM-00080 → **Get Payment** → Keyloop Payment ID `KL-PAY-DEMO-C01` → **Next** → *No, I'm done* → **Next** | *"Payment KL-PAY-DEMO-C01 pulled from Keyloop and recorded, with payment advice attached."* PAY-00050 *Paid / Verified*; INVM-00080 **Fully Paid**, balance 0. **Pass** |
| **FR3 / AC3** contract reflects deposit and balance | Contract PDF | *Deposit Paid 279,308*, *Remaining Balance 0*. **Partial** |
| **FR5** Sales Transaction Summary | Opportunity → Details → Sales Order section | *Transaction Summary Doc Reference* populated. **Partial** — produced without a Sales Order |
| **FR6** Closed Won needs proof on each payment | PAY-00050 → Related → Required Documents → **Bank LPO** → **Upload Files** | Tagged *Bank LPO*. **Pass** |

### 10.10 — Sales Order and Customer-Order Lifecycle

| FR / AC | What was done | Outcome |
|---|---|---|
| **FR4** confirm full payment before generation | Path → *Commit*; reload → **Show more actions** → **Generate Sales Order** | Prompt: *Invoice total QAR 279,308 · Received QAR 279,308 · Outstanding QAR 0* + confirmation radio. **Pass** — currency label contradicts the AED used elsewhere (LFRDN-678 still reproduces) |
| **FR1 / AC1** Sales Order created and linked | *Yes, full payment has been collected* → **Next** | **At this step you will see** *"Something went wrong … An Apex error occurred: System.QueryException: No such column 'Phone' on entity 'Account'…"* — **BUG-RS10-12.** Sales Order Status stays *Not Generated*. **Fail** |
| **FR5** no Sales Order for non-stock vehicles | — | Not re-tested (vehicle was In Stock) |

### 10.11 — Invoicing and Deal Completion Rules

| FR / AC | What was done | Outcome |
|---|---|---|
| **Take the Keys** (payment gate) | Path → **Mark Stage as Complete** from *Commit* | Accepted (invoice balance 0); HO-00037 created — **with no Vehicle, Contact or Invoice: BUG-RS12-04.** Reached without a Sales Order (§3 gap 2) |
| **Handover documents** (ALF-RS-12 FR4, needed for FR1) | HO-00037 → **Generate Documents** | Five agreements generated and ticked. **Pass** |
| **Delivery Note** (ALF-RS-12 FR8) | **Edit** → Date 24/09/2026, Location *Doha Showroom - Automobiles* → **Save** → **Generate Documents** again | Same success message, no Delivery Note — **BUG-RS12-02.** |
| **Registration / Traffic Form** (FR1) | Related → Required Documents → **Traffic Form** and **Insurance Form** → **Upload Files** | Panel *Uploaded*; Details checkboxes stay empty after reload — **BUG-RS12-01.** |
| **AC1** block while conditions outstanding | **Edit** → Sign-Off *Physically Signed*, Status *Completed* → **Save**; Opportunity → Path → **Closed** → **Closed Won** → **Save** | *"Closed Won requires registration and delivery confirmation on the linked Handover (ALF-RS-11 FR1): the Traffic Form must be uploaded and Customer Sign-Off must be Physically Signed."* **Pass** |
| **Auto-close on completion** | HO-00037 → **Edit** → tick *Traffic Form Uploaded?*, *Insurance Form Uploaded?* → **Save** | **At this step you will see** *"We can't save this record because the "Handover Auto Close Won" process failed … CANNOT_EXECUTE_FLOW_TRIGGER …"* — **BUG-RS11-10.** |
| **FR1** conditions backed by evidence | Same Edit, also tick *Delivery Note Generated?* → **Save** | Save succeeds; Opportunity **Closed Won** with no Delivery Note in the system — **BUG-RS11-11**; Sales Order Status *Delivered* with no Sales Order — **BUG-RS12-03.** **Fail** |
| **FR6 / AC2** Closed Won date stamped | Opportunity → Details | Close Date 24/09/2026, Delivery Confirmation ✓, Handover Complete ✓, reservation → *Converted*. **Pass** |
| **FR2 / AC3** invoicing event to Keyloop | — | Not verified (LFRDN-685) |

---

## 5. Hands-on

### How the cycle is built

- **Select Vehicle** (Opportunity) is a finder scoped to the Opportunity's brand. It hides demo cars
  and any car held by a live or converted reservation, and adds the car, its model line and price to
  the deal.
- The **test drive** is created when the deal enters *Explore* and blocks *Select* until it has a
  Result — *Completed* or *Refused*.
- **Create Quotation** (Opportunity, *Select* only) builds the quote from the deal's products;
  **Start Sync** on the quote makes it the deal's primary quote.
- **Create Reservation** (Quote) reserves the quoted car. Its approval routing looks up the deposit
  threshold for the deal's brand and business unit: at or above → *Reserved* immediately; below →
  *Pending Approval* for the rep's manager.
- Confirming the reservation automatically creates the **Invoice** (Invoice Summary) for the quote
  total.
- **Get Payment** (Invoice) records a Keyloop payment for the outstanding balance.
- The **Reservation Contract** needs a verified payment and every Required Document uploaded
  through the reservation's own checklist.
- **Generate Sales Order** (Opportunity) confirms full payment and produces the Sales Order.
- *Take the Keys* creates the **Handover**, where the agreements are generated and the customer's
  forms uploaded.
- **Closed Won** requires the handover complete, sign-off, the Traffic Form, and zero balance.

### Login

**Automotive** app, `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!`. On *Change Your
Password*, click **Cancel**. Search `DEMO CYCLE` in the global search to find all records below.
Demo documents to upload are in `demo-docs/` (Customer_ID_QID, Quotation, Vehicle_Stock_VIN,
Approval_Reference, Payment_Receipt, Bank_LPO, Insurance_Form, Traffic_Form).

### Fresh records — one per scenario, each with its own car, all at *Consider*, owned by QA SalesRep2

| Record | Id | Car to pick in Select Vehicle | Scenario |
|---|---|---|---|
| **DEMO CYCLE 02 - Ferrari happy path 7-day deposit (SF90 Rosso Corsa)** | `006FV00BqZJP7dEYUT` | Ferrari SF90 Stradale — Rosso Corsa Red (STK-SF90-032) | Full 10.8 → 10.11 path, deposit at/above threshold |
| **DEMO CYCLE 03 - Rolls-Royce deposit below threshold, manager approval (Cullinan Midnight Sapphire)** | `006FV00BqZJTJmGYUX` | Rolls-Royce Cullinan — Midnight Sapphire (STK-CULL-033) | 10.8 FR8b / AC6 — deposit below the AED 50,000 threshold |
| **DEMO CYCLE 04 - Ferrari 3-day no-deposit reservation (296 GTB Giallo Modena)** | `006FV00BqZJXVvIYUX` | Ferrari 296 GTB — Giallo Modena Yellow (STK-296GT-002) | 10.8 FR2 / AC1 — 3-day, no deposit |

Each has its own Account, a Contact with phone and email, and the Opportunity's Contact set, so
quotes and contracts carry the customer's details. Spare In Stock car: Rolls-Royce Phantom — Arctic
White (STK-PHAN-034). The vehicle photos on the new units were borrowed from sibling units and may
show a different colour from the car's name.

### What to do and what you should see

**DEMO CYCLE 02 — happy path (all of 10.8 → 10.11)**
1. **Show more actions** → **Select Vehicle** → Ferrari SF90 Stradale → Rosso Corsa Red → confirm the line → toast *"Vehicle selected"*.
2. Path → **Mark Stage as Complete** (→ *Explore*); open the new Test Drive → **Edit** → Status and Result **Refused**, add remarks → **Save**.
3. Back on the Opportunity → Path → **Mark Stage as Complete** (→ *Select*); reload.
4. **Show more actions** → **Create Quotation** → *Customer Quotation* → **Next** → **Finish**; open the quote → **Show more actions** → **Start Sync** → **Continue**.
5. Quote → **Create Reservation** → *Yes* / **7-Day (Deposit)** / Deposit ≥ 1 → **Next** → **Finish**. **Expect:** reservation *Reserved*, Approval *Not Required*, expiry today + 7; an Invoice appears, *Unpaid*, total = quote total.
6. Reservation → **Generate Reservation Contract**. **Expect:** *"Not ready yet … Required Documents are not fully uploaded"*. **You will see:** no document named (BUG-RS08-03).
7. Reservation → **Related** → upload the five documents. **You will see:** *Approval Reference* required although nothing was approved (BUG-RS08-02); badges turn *Uploaded* only after a reload.
8. Invoice → **Get Payment** → any ID → **Next** → *No, I'm done* → **Next**. **Expect:** Invoice *Fully Paid*, balance 0. Then Payment → Related → upload **Bank LPO** → reload → *Uploaded*.
9. Reservation → **Generate Reservation Contract** → *"Reservation Contract generated"*; open the PDF. **You will see:** no trim line (BUG-RS08-04).
10. Opportunity → Path → *Commit*; reload → **Show more actions** → **Generate Sales Order** → *Yes* → **Next**. **Expect:** Sales Order generated. **You will see:** *"No such column 'Phone' on entity 'Account'"* (BUG-RS10-12), and QAR on the prompt (LFRDN-678).
11. Path → *Take the Keys*; open the Handover. **You will see:** Vehicle, Contact, Invoice Summary blank (BUG-RS12-04). **Generate Documents** → five agreements. **Edit** → Date + Location → **Save** → **Generate Documents** again. **You will see:** no Delivery Note (BUG-RS12-02).
12. Handover → Related → upload **Traffic Form** and **Insurance Form**; reload; Details. **You will see:** both checkboxes still empty (BUG-RS12-01).
13. **Edit** → Sign-Off *Physically Signed* → **Save**; Opportunity → Path → **Closed** → *Closed Won*. **Expect:** blocked with the Traffic Form / Sign-Off message.
14. *(Shows the control gap — optional on a demo.)* Handover → **Edit** → tick the three document checkboxes → **Save**. **You will see:** the deal closes as Won with no Delivery Note (BUG-RS11-11), and Sales Order Status *Delivered* (BUG-RS12-03).
15. Afterwards, on any other open quote → **Create Reservation** → *No, let me pick a different one* → **Next**. **You will see:** the SF90 you just sold, listed *In Stock* (BUG-RS08-01).

**DEMO CYCLE 03 — deposit below threshold**
Steps 1–4 as above with the Rolls-Royce Cullinan Midnight Sapphire; then **Create Reservation** →
*7-Day (Deposit)*, Deposit **20000** → **Next** → **Finish**. **Expect:** Status *Pending
Approval*, Approval Status *Pending*, one approval covering reservation and deposit. The approver is
expected to be the rep's manager, **QA ShowroomManager2** (`alfardan.qa.showroommanager2@alfardan.com.qa.qa`)
— not exercised in this cycle. On approval, *Reserved* and an Invoice created.

**DEMO CYCLE 04 — 3-day, no deposit**
Steps 1–4 as above with the Ferrari 296 GTB Giallo Modena; then **Create Reservation** → *3-Day
(No Deposit)* → **Next** → **Finish**. **Expect:** *Reserved*, Approval *Not Required*, expiry today +
3; checklist without Payment Receipt or Approval Reference (Customer ID, Quotation, Vehicle Stock /
VIN only); contract can be generated without a payment (FR12: *"the no-deposit 3-day path is
exempt"*).

### Scorecard

| # | Check | Record | Expected | Your result |
|---|---|---|---|---|
| 1 | Select Vehicle shows only the deal's brand | 02 | Ferrari only | |
| 2 | Refused test drive releases the gate | 02 | Can move to *Select* | |
| 3 | Reservation auto-approves at/above threshold | 02 | *Reserved*, expiry +7 | |
| 4 | Contract block names the missing document | 02 | Named | *(BUG-RS08-03)* |
| 5 | Approval Reference not required when auto-approved | 02 | Not listed | *(BUG-RS08-02)* |
| 6 | Get Payment → Fully Paid | 02 | Balance 0 | |
| 7 | Contract PDF includes trim | 02 | Spider/package line shown | *(BUG-RS08-04)* |
| 8 | Sales Order generates | 02 | *Generated* | *(BUG-RS10-12)* |
| 9 | Delivery Note generates after scheduling | 02 | PDF attached | *(BUG-RS12-02)* |
| 10 | Traffic Form upload ticks the checkbox | 02 | Ticked | *(BUG-RS12-01)* |
| 11 | Closed Won blocked while outstanding | 02 | Blocked with message | |
| 12 | Rep cannot tick document checkboxes | 02 | Read-only | *(BUG-RS11-11)* |
| 13 | Sold car not offered again | 02 | Not listed | *(BUG-RS08-01)* |
| 14 | Below-threshold deposit → manager approval | 03 | *Pending Approval* | |
| 15 | 3-day no-deposit reservation | 04 | *Reserved*, expiry +3, no payment needed for contract | |
