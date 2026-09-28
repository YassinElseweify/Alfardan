# [ALF-RS-12] Vehicle Handover Checklist and Delivery — QA report

**Tested:** 2026-09-24
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Personas used:** Sales Representative (QA SalesRep2, `alfardan.qa.salesrep2@alfardan.com.qa.qa`, role *Sales Rep – SportsMotors*, `AF_PSG_Sales_Rep`) for the journey. Showroom Manager – Alsadd (QA ShowroomManager2, Automobiles), Sales Manager – SportsMotors, CRM Agent and Used Car Team for the access test. System Administrator for setup and as a control.
**Harnesses:** Lightning UI via Playwright as the persona (primary) · REST API v68.0 as each persona · `sf` CLI for metadata and admin-side Apex
**Test cases:** 12 written + 4 added, in `test-cases/ALF_Retail_RS-08_to_RS-16_Test_Cases.xlsx`
**Tickets:** `tickets/ALF-RS-12/README.md` · **Screenshots:** `screenshots/ALF-RS-12/`
**Client clarifications applied:** Alfardan Document Register (document list and *Doclist* sequence), received 24-Sep-2026

---

## Section 1 — Summary of what was done

ALF-RS-12 is the last mile of a car sale: the handover. The rep schedules it, generates the five
agreements the customer signs, uploads the Traffic and Insurance forms, records the customer's
signature, and the system marks the Sales Order **Delivered**, closes the deal and — two days
later — creates a customer-experience follow-up task.

**I mapped the journey first**, from the org rather than the test sheet. Metadata was
re-retrieved on the day. The handover lives on its own record, `AF_Handover__c`, which is
**created automatically when the Opportunity moves to Take the Keys**. Its Lightning page offers
exactly two actions — **Edit** and **Generate Documents** (the latter only while the status is
Pending or In Progress) — and a **Required Documents** panel with eight upload rows. Everything
else is automation: a before-save flow derives *Checklist Complete* and *Status = Completed* from
eight checkboxes, an after-save flow pushes *Handover Complete* and *Sales Order Status =
Delivered* to the Opportunity, another closes the deal as Won, and a scheduled path creates the
follow-up task two days after the handover date. There is no Sales Order record (the Sales Order
is a document plus a status field on the Opportunity), no signing tool, and no validation rule on
the Handover at all.

I built eight scenario deals up front (**DEMO RS12 01–08**), each through the same states the real
actions leave — synced Customer Quotation at Commit, a reservation that the org's own automation
auto-confirmed, an invoice the automation created, a verified Bank Transfer payment with its Bank
LPO — and had the **Sales Representative move each one to Take the Keys**, so every Handover was
created by the product itself. DEMO RS12 01 was then walked end to end in the Lightning UI as the
rep: Generate Sales Order → Path to Take the Keys → Generate Documents → schedule → uploads →
sign-off. Every candidate finding was re-proved in the UI as the persona; the access finding was
proved logged in as the Alsadd Showroom Manager.

| | |
|---|---|
| Test cases executed | **16** (12 written + 4 added) |
| Passed / Failed / Partial / Blocked / Not verified | 1 / 11 / 1 / 2 / 1 |
| New bugs raised | **10** — BUG-RS12-05 … BUG-RS12-14, see `tickets/ALF-RS-12/README.md` |
| Earlier bugs re-checked | **LFRDN-696 fixed** · LFRDN-697, 699, 700, 701, 706 still reproduce |
| BA / requirement gaps raised | **7** |

**Headline verdict: a handover can be completed, but it proves nothing.** Following every step
the product offers, the rep reaches a dead end: the uploaded forms never register (LFRDN-697) and
the Delivery Note is never produced (LFRDN-699), so the only way to finish is to tick the boxes by
hand (LFRDN-701). What the customer signs does not name the car and cannot be regenerated
(**BUG-RS12-05**); those signed contracts — and every deal's invoices, payments and reservations —
are open to, and editable by, other business units (**BUG-RS12-06**); the
handover can read *Completed* before the customer signs or with nothing done (**BUG-RS12-07**);
and *Physically Signed* is a dropdown value with no signed document behind it — a deal closed Won
and Delivered through the API with **zero files** on its handover (**BUG-RS12-08**). The documents
are not generated at the handover stage and cannot be generated one at a time (**BUG-RS12-09**),
the rep is never prompted for the Traffic and Insurance Forms (**BUG-RS12-13**), and the Repair
Disclaimer has nowhere to state the repairs (**BUG-RS12-14**).

What works: the handover is created automatically and exactly once on Take the Keys; the five
agreements are generated with the right names, in the order the client's Doclist sets, and with a
wet-ink signature block; generation is
idempotent and refuses a cancelled handover; the order is set to Delivered only once the checklist
**and** the signature are both recorded; the follow-up task fires at the handover date + 2 days,
once, and survives re-saves without duplicating; the date picker rejects malformed dates. And the
Sales Order that the rep could not generate two days ago now generates cleanly (LFRDN-696 fixed).

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Finding |
|---|---|---|---|
| RS-12-TC-001 | Checklist captures date, time, location and items, saves against Opportunity and Sales Order; blank date blocked | **FAIL** | Date+time (one DateTime field) and location save and display (HO-00046, 24/09/2026 2:30 PM, Doha Showroom - Sports Motors). Vehicle, Contact and Invoice are **not** pre-populated (LFRDN-706). A blank date saves even with Status Completed (**BUG-RS12-11**). The checklist is linked to the Opportunity only — there is no Sales Order record (GAP-RS12-03). `02-handover-created-on-take-the-keys.png`, `06-…` |
| RS-12-TC-002 | Delivery cannot be confirmed until customer sign-off is captured; direct and API edits blocked | **FAIL** | *Physically Signed* saves with no signed document (UI, HO-00046). Rep's API PATCH on HO-00044 with zero files → Opportunity **Closed Won**, SO **Delivered** (**BUG-RS12-08**, with LFRDN-701). |
| RS-12-TC-003 | Which event sets Delivered — checklist (FR3) or signature (AC2) | **Blocked** (observed) | Build requires **both**: 8 flags without sign-off → SO stays *Generated* (HO-00038); sign-off with 2 flags missing → stays *Generated* (HO-00039). But Handover Status goes *Completed* on the checklist alone (**BUG-RS12-07**). Decision needed: GAP-RS12-01. |
| RS-12-TC-004 | Digital vs physical signing model | **Blocked** (observed) | No digital route exists. Physical = a picklist value; the signed scan has no upload row and is not required (**BUG-RS12-08**). GAP-RS12-02. |
| RS-12-TC-005 | Five documents generated automatically with correct deal data, signature blocks, stored and reachable | **FAIL** | Not generated at the handover stage — only when the rep presses Generate Documents; HO-00039, still Pending, holds 0 files (**BUG-RS12-09**). Exactly five, correctly named, each with a customer + Alfardan signature block (HO-00046 08:37:35). But **Vehicle: - VIN: - Email: - Phone: - Handover: - Location: -** on every one (**BUG-RS12-05**). Stored on the Handover only; reachable from the Opportunity via its *Handover* link, not as Opportunity files. |
| RS-12-TC-006 | Generation sequence; Delivery Note last, only after the schedule is confirmed | **FAIL** | The code generates Vehicle Sale Agreement → Warranty → Service Contract → Repair Disclaimer → Buyer Acknowledgement, Delivery Note last — the order in the client's Doclist (pass). Delivery Note is **never** generated, before or after date and location are set (LFRDN-699, re-confirmed: `04-generate-documents-second-run.png`). |
| RS-12-TC-007 | Manually generated document excluded from the automated run; stale document after a data change | **FAIL** | The rep cannot generate a single document: Generate Documents offers no choice and *Required Documents* rows offer only Upload (**BUG-RS12-09**). A Warranty Agreement the rep **uploaded** is generated again (HO-00041, two copies) — whether an upload counts as done is GAP-RS12-04. After adding the vehicle, date and location, Generate Documents regenerates nothing and still reports success (**BUG-RS12-05**). |
| RS-12-TC-008 | Traffic / Insurance Form prompts after Sales Order with full payment; stored; delivery blocked without them | **FAIL** | No prompt of any kind after Generate Sales Order (`01-…`). Uploads go on the Handover (not the Opportunity), show *Uploaded*, are tagged correctly — and never tick their checkboxes (LFRDN-697, `05-…`). Neither form is generated by Salesforce (pass). Delivery can be confirmed without them by hand-ticking (LFRDN-701). No prompt: **BUG-RS12-13**. |
| RS-12-TC-009 | CRM follow-up task exactly two days after confirmed handover; no duplicates; bulk | **PARTIAL** | Task created at handover date + 2 days (HO-00042 dated 21/09 → task at 08:33:47); re-save and un-ticking the guard create no duplicate (pass). Owner is the **rep**, not a CRM queue, and *Who* is blank (**BUG-RS12-10**). Also fires for an **unsigned** handover (HO-00038, **BUG-RS12-07**). Day-1/day-2 wall-clock and the 30-record bulk run not performed. |
| RS-12-TC-010 | Handover date boundaries | **FAIL** | Blank date accepted, even with Status Completed (**BUG-RS12-11**). 01/09/2026 (before SO) and 10/01/2025 (before manufacture) also accepted — no date range is defined (GAP-RS12-04). 31/02/2026 refused by the UI date picker (pass; the REST API silently rolls it to 03/03). |
| RS-12-TC-011 | Only the assigned rep and their management chain can open/complete the handover; files; history | **FAIL** | Alsadd (Automobiles) Showroom Manager cannot open the Opportunity but opens, edits and downloads the SportsMotors Handover and its agreements; sees all 30 Handovers (**BUG-RS12-06**, `10/11/12-…`). The same user reads all 66 Invoice Summaries, 50 Payments and 35 Reservations and can edit them (INVM-00087, PAY-00057, RES-00185 → HTTP 204). Rep completes (pass); SportsMotors Sales Manager has access (pass). No field history (**BUG-RS12-12**). |
| RS-12-TC-012 | Mid-sequence generation failure handled cleanly | **Not verified** | No way to force a failure on the third document in this org. Code: all five are inserted in one DML, so a failure rolls back all five (no half state); the flow has a fault screen. |
| CYC-RS12-01 *(added)* | Sales Order generation as the Sales Representative (LFRDN-696 regression check) | **PASS** | *"Sales Order generated"* on DEMO RS12 01; status *Generated*. `01-sales-order-generated-as-rep.png`. |
| CYC-RS12-02 *(added)* | Handover auto-created on Take the Keys with the deal's data | **FAIL** | Created once, owner = rep, Status Pending (pass) — Vehicle, Contact, Invoice Summary blank on all 8 (HO-00038–00044, 00046). LFRDN-706; its root cause needs correcting (§4, FR1). |
| CYC-RS12-03 *(added)* | Documented path reaches Delivered / Closed Won with no workaround | **FAIL** | After every available step, HO-00046 stays *Pending*, 5/8 flags (`06-…`). Closed Won only after the rep hand-ticks three boxes (`07-…`). LFRDN-697 + LFRDN-699 + LFRDN-701. |
| CYC-RS12-04 *(added)* | Status *Completed* chosen by hand on an empty handover | **FAIL** | Saves; Generate Documents disappears (`13-…`). **BUG-RS12-07**. |

### Not independently verified

- **TC-012 forced failure** — no fault-injection hook exists in the org; assessed from the code only.
- **TC-009 day-1 / day-2 wall-clock and the 30-record bulk run** — the scheduled path was proven with back-dated handover dates; the 2-day wait itself and the bulk volume were not run.
- **Real signature capture** — there is no signing tool to verify (GAP-RS12-02).
- **Keyloop delivery-status confirmation** (SD p.74 "Close") — no integration exists; the Auto Close Won flow sets *Delivery Confirmation* itself (as documented in ALF-RS-11).

---

## Section 3 — BA / requirement gaps to raise

### GAP-RS12-01 — What sets the Sales Order to Delivered: the checklist (FR3) or the signature (AC2)?
**BRD** p.55 FR3: *"The system should update the sales order to Delivered upon completion of the handover checklist."* **BRD** p.56 AC2: *"Given the customer signs the delivery document, When the signature is captured, Then the handover is confirmed and the sales order status updates to Delivered."* **SD** p.73: *"Sales Order status → Delivered on checklist completion."* The build requires both. **Decision needed (Alfardan sales operations):** confirm "checklist complete **and** signed" as the rule and amend FR3/SD.

### GAP-RS12-02 — The signing model is contradictory and the physical route has no evidence step
FR2 (p.55) allows *"digital or physical customer sign-off"*; FR4 (p.55) says each document *"requires physical customer signature"*; Assumption 3 (p.56): *"Digital signature tool / method to be confirmed."*; SD p.73: *"signing method Pending customer confirmation"*. The build is physical-only, recorded as a picklist. **Decision needed:** physical-only for R1, and what must be uploaded as proof (one signed pack, or each signed agreement).

### GAP-RS12-03 — The checklist has no content, and AC1 expects a Sales Order record that does not exist
Assumption 1 (p.56): *"Detailed checklist content to be authored and provided by the business."* The build's checklist is the eight documents only — no physical items (keys, manuals, accessories, inspection). AC1 (p.56) expects the checklist *"saved against the opportunity and sales order"*; the Sales Order is a document, not a record. **Decision needed:** checklist items; and whether "against the sales order" means the Opportunity's Sales Order fields.

### GAP-RS12-04 — "Delivery schedule booked and confirmed" is undefined, and so are date limits
FR8 (p.56) and SD p.74 (*"Delivery Note cannot generate before delivery-schedule confirmation"*) refer to a delivery schedule; there is no schedule object, so the build uses the Handover date + location. No rule defines an acceptable handover date range. **Decision needed:** what counts as a confirmed schedule; earliest/latest acceptable handover date.

### GAP-RS12-05 — The "CRM queue" for follow-up is not defined
AC3 (p.56): *"…a follow-up task is created in the CRM queue for customer experience outreach."* No queue is named in the BRD or SD, per business unit or group-wide. **Decision needed:** the queue(s) and who works them.

### GAP-RS12-06 — Does an agreement the rep uploads count as done?
The **Alfardan Document Register** (client clarification sheet, received 24-Sep-2026), row *Warranty Agreement*, column *Questions*: *"Manual override can be placed to generate any of the documents at earlier stages of the handover. Generated documents will be eliminated in the original automation trigger during the handover stage."* — it covers documents the system **generated** early, not ones the rep prepared and **uploaded**. On HO-00041 a Warranty Agreement uploaded into its *Required Documents* row stays unticked, and Generate Documents then produces a second one (`08-…`, `09-…`). **Decision needed:** should an uploaded agreement mark that document complete and be skipped by generation, or must every agreement be system-generated?

### GAP-RS12-07 — "Earlier stages of the handover": before or after Take the Keys?
The same sheet allows manual generation *"at earlier stages of the handover"*; BRD p.55 FR5 says *"Documents generated manually **prior to the handover stage**…"*. In the build the Handover record — where every document is stored — exists only from *Take the Keys*, so nothing can be generated before the handover stage. **Decision needed:** must the rep be able to generate agreements before *Take the Keys* (which needs the documents to live on the Opportunity, or the Handover to be created earlier), or only earlier than the automatic run within the handover stage?

---

## Section 4 — Walkthrough by functional requirement and acceptance criterion

Log in as the Sales Representative (**Cancel** the *Change Your Password* screen), **Automotive** app.

### The cycle I walked (DEMO RS12 01, `006FV00Bqe0PU3wYEG`)

1. Opportunity at **Commit**, invoice **INVM-00081 Fully Paid**, reservation **RES-00179**.
   **Show more actions ▾ → Generate Sales Order** → *Yes, full payment has been collected* →
   **Next** → *"Sales Order generated — Find it under Notes & Attachments"*. **LFRDN-696 is fixed.**
   (`01-sales-order-generated-as-rep.png`)
2. **Path → Mark Stage as Complete** → *Take the Keys* → *Stage changed successfully.* The
   *Handover* field now links **HO-00046** (`a0SFV001Pteoktw2IA`). (`02-…`)
3. On HO-00046 → **Generate Documents** → five PDFs. (`03-…`)
4. **Edit** → Vehicle, Date 24/09/2026 2:30 PM, Location → **Save** → **Generate Documents**
   again → same success message, nothing new, no Delivery Note. (`04-…`)
5. **Related → Required Documents** → upload **Traffic Form** and **Insurance Form**. (`05-…`)
6. **Edit** → *Customer Sign-Off* **Physically Signed** → **Save**. Handover still **Pending**. (`06-…`)
7. Only way on: **Edit** → tick *Delivery Note Generated?*, *Traffic Form Uploaded?*, *Insurance
   Form Uploaded?* → **Save** → Opportunity **Closed Won**, SO **Delivered**. (`07-…`)

### FR1 / AC1 — *"…a vehicle handover checklist capturing date, time, location, and required handover items."* — **Partial**
- **Creation** (step 2): HO-00046 created by `AF_FL_Opp_CreateHandoverOnTakeTheKeys`, owner QA
  SalesRep2. **At this step you will see Vehicle, Contact and Invoice Summary empty — LFRDN-706.**
  *Correction to LFRDN-706's root cause:* the flow was redeployed 23-Sep and now sets
  `AF_Account__c` and `AF_Contact__c = Opportunity.ContactId`; the Contact is still blank because
  the retail cycle stores the customer in `AF_PrimaryBrandContact__c`, not `ContactId` (confirmed
  on HO-00032…00046: `oppContact=null`, `primary=003…`). Vehicle and Invoice are still unmapped.
- **Date, time, location** (step 4): saved and shown as *24/09/2026, 2:30 PM* /
  *Doha Showroom - Sports Motors*. Handover Date is a single DateTime field.
- **Validation**: on HO-00040 (DEMO RS12 04) a blank date saved with Status Completed —
  **BUG-RS12-11**. 01/09/2026 and 10/01/2025 also saved; no date range is defined (GAP-RS12-04). 31/02/2026 refused by the picker.
- **Items**: the checklist is the eight document checkboxes plus sign-off (GAP-RS12-03).
- **AC1 — saved against the Opportunity and Sales Order**: the Handover's *Opportunity* lookup
  and the Opportunity's *Handover* lookup are both set; there is no Sales Order record.

### FR2 / AC2 — *"…require digital or physical customer sign-off … before the delivery can be confirmed as complete."* — **Fail**
- Step 6: *Physically Signed* saves with **no signed document anywhere** — **BUG-RS12-08**.
- **HO-00044** (DEMO RS12 08): the rep's REST PATCH setting all flags + *Physically Signed* with
  **zero files** → Opportunity **Closed Won**, **Delivered** — **BUG-RS12-08** / LFRDN-701.
- **HO-00038** (DEMO RS12 02): eight flags, sign-off blank → Handover Status **Completed** —
  **BUG-RS12-07**. Order correctly stays *Generated*.
- **HO-00040**: *Completed* picked by hand on an empty handover → saved; Generate Documents gone
  (`13-…`) — **BUG-RS12-07**.

### FR3 — *"…update the sales order to Delivered upon completion of the handover checklist."* — **Pass (with GAP-RS12-01)**
- HO-00038 (checklist, no signature) → SO *Generated*; HO-00039 (signed, two flags missing) → SO
  *Generated*; HO-00046 / HO-00042 (both) → SO **Delivered**. The build requires checklist **and**
  signature — stricter than FR3, matching AC2. **LFRDN-704** (Delivered with no Sales Order) remains
  open for deals where Generate Sales Order never ran.

### FR4 — *"…automated generation of the following handover documents in the agreed sequence at the handover stage…"* — **Fail**
- Step 2: moving to *Take the Keys* creates HO-00046 with **no documents**; they appear only at
  step 3, when the rep presses **Generate Documents**. HO-00039, created the same way
  and still *Pending*, holds **0 files** (`16-…`) — **BUG-RS12-09**.
- Step 3: five PDFs, correctly named, each with a signature block. Open **Vehicle Sale Agreement -
  HO-00046**: **Vehicle: - VIN: - Email: - Phone: - Handover: - Location: -** — **BUG-RS12-05**.
  Same on HO-00043, generated by System Administrator (`12-…`).
- Open **Vehicle Repair Disclaimer - HO-00046**: one fixed sentence, no remarks; there is no remarks
  field to fill (`15-…`) — **BUG-RS12-14**.
- Step 4: after filling vehicle/date/location, **Generate Documents** regenerates nothing and still
  says *"Handover documents generated"* — **BUG-RS12-05**.
- **Sequence — Pass.** The client's Doclist orders the handover documents Vehicle Sale Agreement,
  Warranty Agreement, Service Contract Agreement, Vehicle Repair Disclaimer, Buyer Acknowledgement,
  Traffic Form, Insurance Form, Delivery Note. `AF_HandoverDocumentService` generates the five
  agreements in that order and keeps the Delivery Note last.

### FR5 — *"…manual document generation option … Documents generated manually … excluded from the automated trigger…"* — **Fail**
- On HO-00046, **Generate Documents** offers no choice of document (`03-…`), and each *Required
  Documents* row offers only **Upload Files** (`05-…`). The rep cannot generate one agreement on
  its own — **BUG-RS12-09**. (The service underneath can, and would then skip it in the full run;
  nothing on screen calls it that way.)
- **HO-00041** (DEMO RS12 05): a Warranty Agreement **uploaded** through *Required Documents*, then
  Generate Documents → **two Warranty Agreements** (`08-…`, `09-…`). FR5 and the client's register
  speak of documents *generated* early, so whether an upload counts is GAP-RS12-06; when
  "earlier" may be is GAP-RS12-07.

### FR6 / FR7 — *"…prompt the Sales Representative to upload the completed Traffic Form / the Insurance Form…"* — **Fail**
- No prompt, task or notification after Generate Sales Order (step 1, `01-…`) — **BUG-RS12-13**.
  The client's register confirms: *"After Sales order is generated with full payment. Prompt
  required."*
- Step 5: both uploaded, tagged `Traffic Form` / `Insurance Form`, panel shows *Uploaded*;
  **Traffic Form Uploaded? and Insurance Form Uploaded? stay unticked — LFRDN-697** (`06-…`).

### FR8 — *"…generate the Delivery Note after the delivery schedule has been booked and confirmed…"* — **Fail**
- Step 4: date and location set, Generate Documents run again → **no Delivery Note — LFRDN-699**.

### FR9 / AC3 — *"…CRM follow-up task two days after confirmed vehicle handover…"* — **Partial**
- **HO-00042** (DEMO RS12 06), completed and signed with Handover Date 21/09/2026 10:00 → Task
  *Post-Handover Customer Experience Follow-Up* at 08:33:47, once; no duplicate after re-save or
  un-ticking *Follow-Up Task Created?*. **Owner QA SalesRep2, Who blank — BUG-RS12-10.**
- **HO-00038** (unsigned, not closed) got the same task (`14-…`) — **BUG-RS12-07**.

### Cross-cutting — business-unit segregation (BRD §7 item 1, SD p.75) — **Fail**
- Logged in as **QA ShowroomManager2** (Showroom Manager – Alsadd, Automobiles): DEMO RS12 07's
  Opportunity → *Unable to load* (`10-…`); its Handover **HO-00043** opens with Edit and Generate
  Documents (`11-…`); **Vehicle Sale Agreement - HO-00043** previews with Download and Share
  (`12-…`). API: 30 Handovers visible, PATCH 204 — **BUG-RS12-06**. CRM Agent and Used Car Team:
  no access. *Handover History* shows only *Created.* — **BUG-RS12-12**.
- The same Showroom Manager, via the API, reads **all 66 Invoice Summaries, 50 Payments and 35
  Reservations** in the org and edits DEMO RS12 07's **INVM-00087, PAY-00057 (payee name, Bank LPO)
  and RES-00185** (HTTP 204; *Last Modified By* QA ShowroomManager2) — **BUG-RS12-06**.

### Controls and cross-checks run after the first draft
- **System Administrator** reproduces BUG-RS12-07 (HO-00041 set Completed unsigned → saved) and the
  upload duplicate behind GAP-RS12-06 (HO-00040 → two Warranty Agreements): both **General**. On HO-00039 (signed, Traffic flag ticked) *Completed* instead fails with the raw
  *"Handover Auto Close Won" process failed* error — **LFRDN-700 still reproduces**.
- **Fully UI-built deal** DEMO Cycle 01 / HO-00037 (Select Vehicle → Quotation → Create Reservation →
  Get Payment → handover, all clicked as the rep on 23-Sep): Closed Won, Delivered, no Delivery Note,
  Vehicle/Contact/Invoice blank, and its Vehicle Sale Agreement prints *Vehicle: - VIN: -* — the same
  results as the API-staged RS12 deals, so those findings are not artefacts of the setup.

---

## Section 5 — Hands-on: run ALF-RS-12 yourself

### What this story is, and how it is built

The handover is a record created **for** you the moment an Opportunity moves to **Take the Keys**.
You find it from the Opportunity's **Handover** field. On it you have two buttons — **Edit** and
**Generate Documents** — and on the **Related** tab a **Required Documents** panel with eight
rows: the five agreements, the Delivery Note, the Traffic Form and the Insurance Form. Each row
turns *Uploaded* when a file with that name exists. The **Details** tab has the matching eight
checkboxes; when all eight are ticked the handover becomes *Completed*, and when *Customer
Sign-Off* is also *Physically Signed* the Opportunity is marked *Handover Complete*, the Sales
Order *Delivered*, and the deal is closed Won automatically. Two days after the Handover Date a
follow-up task appears on the Opportunity.

### Records created for you

All owned by **QA SalesRep2**, customer **DEMO RS12 Hands-on Customer - Hessa Al-Naimi**, each at
**Commit**, invoice **Fully Paid (369,300, balance 0)**, reservation **Reserved**, Sales
Order **Not Generated**, **no Handover yet** — you start exactly where a rep does.
Search **DEMO RS12 H** in global search to list them.

| Record | Id | Vehicle | Use it for |
|---|---|---|---|
| DEMO RS12 H01 - Full handover journey (your main walkthrough) | `006FV00Br1nk3vAYEQ` | Ferrari 296 GTB - Rosso Scuderia RS12-H01 | FR1–FR4, FR6–FR8, AC1–AC2 |
| DEMO RS12 H02 - Manual Warranty Agreement then Generate Documents | `006FV00Br1noG4CYEU` | … RS12-H02 | FR5 |
| DEMO RS12 H03 - Complete without customer signature, follow-up task | `006FV00Br1nsSDEYE2` | … RS12-H03 | FR2/FR3, FR9/AC3 |
| DEMO RS12 H04 - Handover date and status controls | `006FV00Br1nweMGYEY` | … RS12-H04 | FR1 validation, status |
| DEMO RS12 H05 - Other business unit opens the handover | `006FV00Br1o0qVIYEY` | … RS12-H05 | Segregation |

On every one, first do: **Show more actions ▾ → Generate Sales Order → Yes → Next → Finish**, then
**Path → Mark Stage as Complete** (to *Take the Keys*), then open the **Handover** link in Details.

### What to do, step by step

**H01 — the full journey**
1. When **Generate Sales Order** finishes, look for a prompt to upload the Traffic and Insurance
   Forms. *Expect:* a prompt. *You will see:* only *"Sales Order generated"* (BUG-RS12-13).
2. After Take the Keys, open the Handover. *Expect:* Status Pending, Account set, Vehicle, Contact
   and Invoice Summary filled, and the five agreements already under **Related → Notes &
   Attachments**. *You will see:* Vehicle, Contact, Invoice Summary empty (LFRDN-706) and **no
   documents** (BUG-RS12-09).
   Now **Generate Documents → Finish** → open *Vehicle Sale Agreement*. *Expect:* car, VIN,
   customer details. *You will see:* **Vehicle: - VIN: -** (BUG-RS12-05). Open *Vehicle Repair
   Disclaimer*. *Expect:* the vehicle's repair remarks. *You will see:* one standard sentence, and no
   field anywhere to enter remarks (BUG-RS12-14).
3. **Edit** → Vehicle *Ferrari 296 GTB - Rosso Scuderia RS12-H01*, Date today, a time, Location
   *Doha Showroom - Sports Motors* → **Save** → **Generate Documents** again. *Expect:* corrected
   agreements and a Delivery Note. *You will see:* the same success text, nothing new (BUG-RS12-05,
   LFRDN-699).
4. **Related → Required Documents** → upload a PDF under **Traffic Form** and **Insurance Form**
   (e.g. `demo-docs/Traffic_Form.pdf`, `Insurance_Form.pdf`). Rows turn *Uploaded*.
   **Details** → *Expect:* both checkboxes ticked. *You will see:* unticked (LFRDN-697).
5. **Edit** → *Customer Sign-Off* **Physically Signed** → **Save**. *Expect:* the system asks for the
   signed document. *You will see:* it saves; Status stays Pending (BUG-RS12-08).
6. **Edit** → tick the three remaining boxes → **Save**. Open the Opportunity. *You will see:*
   **Closed Won**, Sales Order Status **Delivered**, Delivery Confirmation ✓ — with no Delivery Note
   on file (LFRDN-701). *Handover History* on the Handover shows only *Created.* (BUG-RS12-12).

**H02 — generate one document on its own (FR5)**: after Take the Keys, try to generate only the
Warranty Agreement. **Related → Required Documents → Warranty Agreement** — *Expect:* a Generate
option. *You will see:* only **Upload Files**. Handover header, top right next to **Edit** → **Generate Documents** — *Expect:* a choice
of document. *You will see:* no choice; it generates everything (BUG-RS12-09).
Optional, for GAP-RS12-06: on a fresh handover, first **Upload Files** a PDF under *Warranty
Agreement*, then **Generate Documents** → two Warranty Agreements.

**H03 — completed without a signature**: **Edit** → Handover Date **three days ago**, Location, tick
all eight checkboxes, leave *Customer Sign-Off* empty → **Save**. *Expect:* not Completed, no
follow-up. *You will see:* Status **Completed**; Sales Order stays *Generated* (FR3 behaves); within
about a minute the Opportunity's **Activity** shows *Post-Handover Customer Experience Follow-Up*,
owned by QA SalesRep2, no contact (BUG-RS12-07, BUG-RS12-10).

**H04 — date and status controls**: **Edit** → Handover Date **31/02/2026** (*refused — correct*);
clear the date and set *Handover
Status* **Completed** → **Save** (*saves*; Generate Documents disappears) (BUG-RS12-11, BUG-RS12-07).

**H05 — another business unit**: as the rep run Generate Documents on H05's handover and note its
number. **Log out**, log in as `alfardan.qa.showroommanager2@alfardan.com.qa.qa` / `Arcsen@2026!`
(**Cancel** the password screen). Search the handover number. *Expect:* no access (the Opportunity
itself gives *Unable to load*). *You will see:* the handover opens, is editable, and its agreements
preview and download (BUG-RS12-06).

### Scorecard — fill in as you go

| # | Check | Expected | Actual (fill in) | Ticket if it fails |
|---|---|---|---|---|
| 1 | Generate Sales Order as rep | Generated | | LFRDN-696 |
| 2 | Handover auto-created with vehicle/contact/invoice | All three set | | LFRDN-706 |
| 3 | Agreements name the vehicle and VIN | Named | | BUG-RS12-05 |
| 4 | Re-generate after fixing data | New versions | | BUG-RS12-05 |
| 5 | Delivery Note after date + location | Generated | | LFRDN-699 |
| 6 | Traffic / Insurance upload ticks checkbox | Ticked | | LFRDN-697 |
| 7 | Sign-off needs a signed document | Required | | BUG-RS12-08 |
| 8 | Deal closes only through the documented path | Yes | | LFRDN-701 |
| 9 | Agreements present on reaching Take the Keys; one agreement can be generated on its own | Yes / Yes | | BUG-RS12-09 |
| 10 | Completed only after signature | Blocked | | BUG-RS12-07 |
| 11 | Follow-up task in CRM queue, with contact | Queue, contact | | BUG-RS12-10 |
| 12 | Blank handover date refused | Refused | | BUG-RS12-11 |
| 13 | Other BU cannot open handover or files | No access | | BUG-RS12-06 |
| 14 | History shows who changed status / sign-off | Tracked | | BUG-RS12-12 |
| 15 | Prompt for Traffic / Insurance Form after Generate Sales Order | Prompted | | BUG-RS12-13 |
| 16 | Repair Disclaimer states the vehicle's repair remarks | Remarks printed | | BUG-RS12-14 |

---

## Records left in the org as evidence

| Record | State | Evidence for |
|---|---|---|
| DEMO RS12 01 / HO-00046 | Closed Won via hand-ticks; 5 blank-vehicle agreements, Traffic + Insurance files, flags ticked by hand | BUG-RS12-05, -08, -14, LFRDN-697/699/701 |
| DEMO RS12 02 / HO-00038 | Completed, unsigned, follow-up task created | BUG-RS12-07, -10 |
| DEMO RS12 03 / HO-00039 | Signed, two flags missing, Pending | FR3 check |
| DEMO RS12 04 / HO-00040 | Completed with nothing done, blank date | BUG-RS12-07, -11 |
| DEMO RS12 05 / HO-00041 | Two Warranty Agreements (one uploaded, one generated) | GAP-RS12-06 |
| DEMO RS12 06 / HO-00042 | Closed Won, follow-up task | BUG-RS12-10 |
| DEMO RS12 07 / HO-00043 | Admin-generated agreements, opened by Alsadd manager | BUG-RS12-06, -05 |
| DEMO RS12 08 / HO-00044 | Closed Won, Delivered, zero files | BUG-RS12-08, -09 |

## Org configuration changed during testing

None — data only.
