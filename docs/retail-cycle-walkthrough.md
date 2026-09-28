# Retail Sales Cycle — step-by-step walkthrough

**Scope:** Opportunity at *Consider* → Select Vehicle → test drive → quotation → reservation (ALF-RS-08)
→ payment (ALF-RS-09) → Sales Order (ALF-RS-10) → handover → Closed Won (ALF-RS-11 / ALF-RS-12)
**Org:** Al-Fardan QA sandbox — `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Last walked end to end:** 2026-09-24, as QA SalesRep2, on *DEMO Cycle 01 - Ferrari Roma end-to-end* (`006FV00Bq30GjbQYES`)

This is written so you can drive a deal through the whole cycle yourself and know, after every click,
what the screen should show and what the system should have changed underneath. Each step gives:

- **Who** — the persona to be logged in as.
- **Where / Do** — the record and the exact click path.
- **Expect on screen** — what the user sees.
- **Expect in data** — what the automation should have written, and which component does it.
- **Gate** — what blocks the step, with the literal message.
- **Known issue** — an open defect hit at this step, by ticket ID (`tickets/DEMO-CYCLE-10.8-10.11/README.md`).

Every step is marked **✅ Verified** (walked live on 2026-09-24) or **⚙️ From configuration** (read from
the metadata, not exercised in the UI on that run).

---

## 0. Before you start

### Personas

| Persona | Username | Used for |
|---|---|---|
| **Sales Representative** | `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` | Every step of the cycle |
| **Showroom Manager** (the rep's manager) | `alfardan.qa.showroommanager2@alfardan.com.qa.qa` | Approving a below-threshold / VIP / extended reservation |
| **System Administrator** | `arcsen@alfardan.com.qa` (API) | Set-up only — creating stock, customers, Opportunities |

Log in, and on the *Change Your Password* screen click **Cancel**. Open the **Automotive** app.

### Stage model

`Consider → Explore → Select → Commit → Take the Keys → Closed (Won / Lost)`

Stages move **one step at a time** — `AF_VR_Opp_SequentialStageProgression` rejects any jump of more than
one stage. Move with **Path → Mark Stage as Complete**. Several actions only appear at a given stage and
only after a **page reload** following the stage change.

### What the starting records must look like

**Opportunity** — at **Consider**, owned by the Sales Representative, with:
- **Brand** set (e.g. *Ferrari*) — Select Vehicle only shows that brand, and the deposit threshold is looked up by Brand + Business Unit.
- **Account** — for an Individual, **QID** (11 digits) or Other ID is required.
- **Contact** (standard `ContactId`) — *Create Quotation* copies it onto the Quote, and the Quote passes it to the reservation and contract. Without it the contract prints *Email: -* and *Phone: -*.
- The customer Contact needs **Phone** and **Brand**, or it cannot be saved.

Creating the Opportunity itself (walk-in, lead conversion) is outside this walkthrough.

**Vehicle** — to appear in **Select Vehicle** *and* be usable through to the Sales Order, a unit needs:

| Field | Value | Why |
|---|---|---|
| Record Type | **Regular_Vehicle** (not Demo_Vehicle) | Demo units are test-drive cars and are excluded |
| `AF_InventoryVehicle__c` | true | Finder scope |
| `AF_InventoryStatus__c` | **In Stock** | Sales Order gate rejects In Transit / Ordered |
| `AF_ReservationStatus__c` | **Available** | "Pick a different vehicle" list in Create Reservation |
| `AF_AvailabilityForSale__c` | **Available for Sale** | Same list |
| `VehicleDefinition` | with `AF_Brand__c` = the Opportunity's brand, and a Product with an **active Standard Price Book entry** | Model card, brand scoping, price |
| VIN | populated | Carried onto the quote line and contract |
| Asset | one per vehicle | Required by the Vehicle object |

Ready-made records: **DEMO CYCLE 02 / 03 / 04** (search `DEMO CYCLE`) — see §18.

---

## 1. Select Vehicle — ✅ Verified

**Who:** Sales Representative
**Where / Do:** Opportunity (stage *Consider*) → header **Show more actions (▾)** → **Select Vehicle**.
1. The **Vehicle Finder** opens with one card per model that has available stock, each showing a unit count and the catalogue price.
2. Click a model card → the list of units (colour, In Stock badge, stock code).
3. Click a unit → if the model has lines/trims, *Choose a Line for <model>* appears → select one → **Confirm Line**.

**Expect on screen:** toast **"Vehicle selected — The vehicle, its model, and pricing have been assigned to this opportunity."**

**Expect in data:**
- `Opportunity.AF_SelectedVehicle__c` = the unit; `AF_VehicleModel__c` = its Vehicle Definition.
- Opportunity Products: the model at its Standard Price + one line per chosen trim (e.g. Ferrari Roma 247,308 + Spider Package 32,000).
- `Amount` = sum of the lines.

**What the finder hides:** other brands, demo vehicles, and any unit held by a reservation in *Requested*, *Pending Approval*, *Reserved* or *Converted* (`AF_VehicleExplorerController.BLOCKING_RESERVATION_STATUSES`). **Proceed without Vehicle** is available at the top right.

---

## 2. Move to Explore — test drive and appraisal are created — ✅ Verified

**Who:** Sales Representative
**Do:** Path → **Mark Stage as Complete** (Consider → Explore).

**Expect on screen:** toast *"Stage changed successfully."*; **Test Drives (1)** and **Trade Ins (1)** appear in the related lists.

**Expect in data** (`AF_FL_Opp_CreateExploreSideProcesses`, fires once on Consider → Explore):
- One **Test Drive** (`AF_TestDrive__c`, e.g. TD-00196), Status **Requested**, `AF_StageGatePassed__c` false.
- One **Appraisal** (Purpose *Trade-In*, e.g. APL-000000127), and a Task.
- `Opportunity.AF_TestDriveGateBlocked__c` = **true** (`AF_FL_TestDrive_SyncOpportunityGate`).

**Gate:** `AF_VR_Opp_ExploreRequiresVehicle` — Explore and later require a Vehicle Model or Selected Vehicle.

---

## 3. Record the test drive outcome — ✅ Verified (Refused path)

**Who:** Sales Representative
**Where / Do:** open the Test Drive → **Edit**. Either path passes the gate:

| Outcome | Set | Rule |
|---|---|---|
| Customer declined (the "cancel" case) | Test Drive Status **Refused**, Test Drive Result **Refused**, **Refused Remarks** | `AF_VR_TestDrive_RefusedRemarksRequired`, `AF_VR_TestDrive_StatusResultConsistency` (Status and Result must match) |
| Drive taken | Status **Completed**, Result **Completed** | same consistency rule |

To book a drive instead: Status **Scheduled** needs Date/Time and Location (`AF_VR_TestDrive_ScheduledNeedsDateLoc`); the **Select Demo Vehicle** action picks the demo car.

*Cancelled* is no longer a status — it was merged into *Refused* on 2026-09-09.

**Expect in data:** `AF_TestDrive__c.AF_StageGatePassed__c` = true as soon as a Result is recorded (`AF_FL_TestDrive_UpdateGate`); `Opportunity.AF_TestDriveGateBlocked__c` = false.

**Gate:** `AF_VR_Opp_TestDriveGate` blocks moving to Select or later while a test drive has no Result.

---

## 4. Move to Select — ✅ Verified

**Do:** Opportunity → Path → **Mark Stage as Complete** (Explore → Select), then **reload the page**.

**Expect:** *"Stage changed successfully."* After reload, **Show more actions** includes **Create Quotation** (visible at *Select* only).

---

## 5. Create Quotation — ✅ Verified

**Who:** Sales Representative
**Do:** **Show more actions** → **Create Quotation** → Quote Type **Customer Quotation** (or *Bank Quotation*) → **Next**.

**Expect on screen:** *"Quotation created. Review the line items on the new Quote record and present it to the customer."* → **Finish**.

**Expect in data** (`AF_FL_Opp_CreateQuotation`):
- A Quote (e.g. 00000189), Status **Draft**, `GrandTotal` = the Opportunity amount.
- Quote lines copied from the Opportunity products; the vehicle line carries `AF_Vehicle__c` = the selected unit (VIN).
- `Quote.ContactId` = `Opportunity.ContactId`.

---

## 6. Start Sync — ✅ Verified

**Do:** open the Quote → **Show more actions** → **Start Sync** → dialog *"Sync Quote … you'll replace all opportunity products with the quote line items"* → **Continue**.

**Expect in data:** `Opportunity.SyncedQuoteId` = this quote; Quote Status → **Presented**.
**Gate it satisfies:** `AF_VR_Opp_CommitGate` — Commit requires a synced quote.

Discounts: if the quote carries a discount awaiting approval (`AF_DiscountApprovalStatus__c` = Pending), Create Reservation will stop at a *discount pending* screen until it is decided.

---

## 7. Create Reservation (ALF-RS-08) — ✅ Verified (7-Day, deposit ≥ threshold)

**Who:** Sales Representative
**Where / Do:** the synced **Quote** → header **Create Reservation**. There is no reservation action on the Opportunity.

**Screen 1 — Reservation details** (*"Reserving against <Opportunity> for Quote Number <n> (total <amount>)"*):

| Field | Options |
|---|---|
| *Reserve the vehicle already on this Quote (<vehicle>)?* | **Yes, reserve the same vehicle** (normal path) / **No, let me pick a different one** |
| Contract Type | **3-Day (No Deposit)** · **7-Day (Deposit)** · **VIP / Extended** |
| Deposit Amount | shown for 7-Day; any amount from 0 to the full price |
| Trade-In Used As Deposit? | uses an approved appraisal value |
| Vehicle Source | **In Stock** · **In Transit / Ordered** · **Pre-Order (Placeholder)** |

→ **Next**. If *No, let me pick a different one*: a table of available units (In Stock / In Transit) or of Vehicle Definitions (Pre-Order) → select → **Next**.

**Expect on screen:** *"Reservation created — Expiry date, approval routing and remaining balance are calculated automatically."* → **Finish**.

**Expect in data — which branch you land in** (`AF_FL_Reservation_EvaluateApproval`, before-save):

| Contract Type | Condition | Status / Approval Status | Expiry (`AF_FL_Reservation_SetExpiryDate`) |
|---|---|---|---|
| 3-Day (No Deposit) | — | **Reserved** / **Not Required** | start + 3 days |
| 3-Day (No Deposit) | Requested Extra Days > 0 | **Pending Approval** / **Pending** | on approval |
| 7-Day (Deposit) | Deposit ≥ threshold for Brand + Business Unit | **Reserved** / **Not Required** | start + 7 days |
| 7-Day (Deposit) | Deposit < threshold, or no threshold row | **Pending Approval** / **Pending** | on approval |
| VIP / Extended | — | **Pending Approval** / **Pending** | set by the manager (no automatic expiry) |
| any | extension of an existing reservation | **Pending Approval** / **Pending** | on approval |

Current thresholds (`AF_DepositThreshold__mdt`): Ferrari / Alfardan Sports Motors **0.1** · Rolls-Royce /
Alfardan Automobiles **50,000** · BMW, Mini / Alfardan Automobiles **10,000** · Jaguar, Land Rover /
Alfardan Premier Motors **5,000**. With 0.1, every Ferrari deposit auto-approves.

**When the reservation is Reserved** (auto path) the following also happens:
- **Invoice created** — `AF_FL_Reservation_AutoConfirmed` → `AF_InvoiceSummary_EnsureOnResv` → `AF_InvoiceSummaryService`: Invoice Summary (e.g. INVM-00080), Status **Unpaid**, Expected Total = quote total, Paid 0, Balance = total; mirrored to `Opportunity.AF_InvoiceSummary__c` / `AF_InvoiceBalance__c`.
- **Quote → Accepted** (`AF_FL_Reservation_SyncQuoteAccepted`).
- **Vehicle → Reservation Status Reserved** (`AF_VehicleReservationStatusSync`); the unit disappears from Select Vehicle.
- `Opportunity.AF_VehicleReservation__c` = the reservation; `AF_RemainingBalance__c` = price + add-ons − deposit.

Verified example: RES-00178, 7-Day, deposit 30,000 → Reserved / Not Required, Start 24/09/2026, Expiry 01/10/2026, Remaining 249,308; INVM-00080 Unpaid 279,308.

**Gate:** `AF_ReservationDoubleBookingGuard` — a vehicle already held by a live reservation shows *"Vehicle already held"*.

**Known issues:** the *No, let me pick a different one* list is not limited to the quote's brand, and can offer a car that has already been sold — **BUG-RS08-01**.

---

## 8. Manager approval (below-threshold / VIP / extension) — ⚙️ From configuration

**Trigger:** reservation saved with Approval Status **Pending** → `AF_FL_Reservation_SubmitApproval` submits it into approval process **`AF_AP_Reservation_Manager`**.

**Who:** Showroom Manager (expected approver: the rep's manager, QA ShowroomManager2)
**Do:** open the approval request (bell notification or **Approval History** on the reservation) → **Approve** or **Reject**.
For VIP / Extended, the manager must set an Expiry Date before approving (`AF_VR_VIPExpiryRequiredOnApproval`).

**Expect in data:**

| Decision | Result |
|---|---|
| **Approve** | `AF_FL_Reservation_Approved`: Status → **Reserved**; Invoice created (as §7); Quote → Accepted; email + in-app notification to the reservation owner |
| **Reject** | `AF_FL_Reservation_Rejected`: Status → **Requested** so the rep can change terms and resubmit; notification to the owner |

---

## 9. Reservation Required Documents — ✅ Verified

**Who:** Sales Representative
**Where / Do:** Reservation → **Related** tab → **Required Documents** panel. For each document: **Upload Files** → choose file → wait for *1 of 1 file uploaded* → **Done**.

**Documents required** (`AF_Document__mdt`, by contract type):

| Contract type | Documents |
|---|---|
| 3-Day (No Deposit) | Customer ID · Quotation · Vehicle Stock / VIN |
| 3-Day with trade-in | + Trade-In Appraisal |
| 7-Day (Deposit) | Customer ID · Quotation · Vehicle Stock / VIN · **Payment Receipt** · **Approval Reference** |
| 7-Day with trade-in | + Trade-In Appraisal |

**Expect on screen:** toast *"<Document> uploaded."*; the badge changes from **Missing** to **Uploaded** after a **page reload**.

**Expect in data:** the file is renamed to the document name and tagged — `ContentVersion.AF_FileUpload__c` = the document name (`AF_DocumentService.renameUploadedDocuments`).

**Known issues:**
- Approval Reference is required even when the reservation was auto-approved — **BUG-RS08-02**.

---

## 10. Get Payment (ALF-RS-09) — ✅ Verified

**Who:** Sales Representative
**Where / Do:** open the Invoice (Opportunity → Invoice Summary link, or the Invoices related list) → header **Get Payment** → **Keyloop Payment ID** (e.g. `KL-PAY-DEMO-C01`) → **Next**.

**Expect on screen:** *"Payment pulled from Keyloop — Payment <ID> pulled from Keyloop and recorded, with payment advice attached."* → *Do you have another payment ID to pull?* **No, I'm done** → **Next**.

**Expect in data** (`AF_KeyloopGetPayment`):
- A Payment (e.g. PAY-00050): **Amount = the whole outstanding balance**, Method **Bank Transfer**, Status **Paid / Verified**, Integration **Synced**, NOC Recorded false, linked to the Invoice, Opportunity, Quote and the reservation.
- A *Keyloop Payment Advice* file attached to the Payment.
- Invoice → Paid = total, Balance **0**, Status **Fully Paid**; Opportunity `AF_InvoiceBalance__c` = 0.
- A **Sales Transaction Summary** document is referenced on the Opportunity (*Transaction Summary Doc Reference*).

A part-payment cannot be recorded this way today — Get Payment always takes the full balance.

**Payment Required Documents:** Payment → **Related** → **Required Documents**. Required by method (`AF_Document__mdt`):

| Payment method | Document |
|---|---|
| Cheque | **Cheque Copy** |
| Bank Transfer | **Bank LPO** |
| NOC recorded (payee ≠ customer) | **Signed NOC** |

Get Payment always records *Bank Transfer*, so upload a **Bank LPO** (it becomes *Uploaded* after reload; tag `Bank LPO`). Needed before Closed Won (`AF_FL_Opp_ClosedWonPaymentGate`).

---

## 11. Generate Reservation Contract (ALF-RS-08) — ✅ Verified

**Who:** Sales Representative
**Where / Do:** Reservation → header **Generate Reservation Contract**.

**Gate** (`AF_ReservationContractService`), checked in this order:
1. All Required Documents uploaded — else *"Not ready yet — Required Documents are not fully uploaded on this reservation (FR13). Attach the required customer documents (see the Required Documents Checklist) before generating the contract."*
2. A verified payment on the reservation (3-Day no-deposit is exempt) — else *"No payment on this reservation has been confirmed (FR12)…"*.

**Expect on screen:** *"Reservation Contract generated — Find it under Notes & Attachments on this reservation."* → **Finish**.

**Expect in data:** PDF **Reservation Contract - <RES-number>** on the reservation (customer, vehicle, VIN, colours, stock scenario, quote number, price + add-ons, deposit paid, remaining balance, payment reference, start/expiry, terms, signature block); `AF_ContractGeneratedDate__c` and `AF_ContractDocumentReference__c` set.

**Known issues:** the block message does not name the missing document — **BUG-RS08-03**; the contract does not print the trim — **BUG-RS08-04**. The *Required Documents Complete?* checkbox on the Details tab is a legacy field and stays unticked.

---

## 12. Move to Commit — ✅ Verified

**Do:** Opportunity → Path → **Mark Stage as Complete** (Select → Commit), then reload.
**Gate:** `AF_VR_Opp_CommitGate` — requires a synced quote (§6).
**Expect:** *"Stage changed successfully."* **Generate Sales Order** and **Cancel Sales Order** are in **Show more actions** at every stage; Commit is where the Sales Order is normally generated.

---

## 13. Generate Sales Order (ALF-RS-10) — ❌ Blocked for the Sales Representative

**Who:** Sales Representative
**Do:** **Show more actions** → **Generate Sales Order**.

**Screen 1 (FR4 confirmation):** *"Before the Sales Order is generated, confirm that full payment has been collected. Invoice total: QAR … Received: QAR … Outstanding: QAR 0"* → **Yes, full payment has been collected** → **Next**.

**Gate** (`AF_SalesOrderService.findBlocker`, mirrored by `AF_VR_Opp_SOGenerationGate`):
- Invoice **Fully Paid** — else *"A Sales Order can only be generated once the invoice is fully paid. QAR x of QAR y has been received…"*
- Selected vehicle present and **In Stock** — else *"The selected vehicle is currently "<status>" (not In Stock)…"*
- A **Reserved** reservation for that same vehicle — else *"…there is no active Reserved reservation on this Opportunity for the selected vehicle."*
- No Sales Order already *Generated / Sent to Customer / Signed*.

**Expected result:** *"Sales Order generated."*; PDF *Sales Order - <Opportunity>* on the Opportunity; `AF_SOStatus__c` **Generated**, `AF_SODocumentReference__c`, `AF_SOGeneratedDate__c`, `AF_SOPaymentConfirmedBy__c` / `AF_SOPaymentConfirmedDate__c` stamped; reservation → **Converted**.

**Actual today:** *"Something went wrong … An Apex error occurred: System.QueryException: No such column 'Phone' on entity 'Account'…"* — **BUG-RS10-12**. The prompt's QAR labels differ from AED everywhere else — LFRDN-678.

**Cancel Sales Order** (same menu) starts the cancellation / credit-note path (ALF-RS-13) and is not covered here.

---

## 14. Move to Take the Keys — handover is created — ✅ Verified

**Do:** Path → **Mark Stage as Complete** (Commit → Take the Keys).
**Gate:** `AF_VR_Opp_TakeTheKeysGate` — *"Take the Keys stage requires the invoice balance to be fully settled (zero)."* (requires an Invoice Summary and balance 0).
**Expect in data:** `AF_FL_Opp_CreateHandoverOnTakeTheKeys` creates a **Handover** (e.g. HO-00037), Status **Pending**, linked to the Opportunity (Account derived).

This stage is currently reachable without a Sales Order.

**Known issue:** the handover's Vehicle, Contact and Invoice Summary are left blank — **BUG-RS12-04**.

---

## 15. Handover (ALF-RS-12) — ⚠️ Partly blocked

**Who:** Sales Representative. **Where:** the Handover record.

**15a. Generate the agreements — ✅ Verified.** Header **Generate Documents**.
*Expect:* *"Handover documents generated — Every not-yet-complete document in the standard sequence was generated as a PDF and attached below…"*; five PDFs: **Vehicle Sale Agreement, Warranty Agreement, Service Contract Agreement, Vehicle Repair Disclaimer, Buyer Acknowledgement** (each `- HO-<n>`, tagged); the five matching *Complete?* checkboxes ticked.

**15b. Schedule — ✅ Verified.** **Edit** → **Handover Date** (date + time) and **Handover Location** → **Save**.

**15c. Delivery Note — ❌.** *Expected:* run **Generate Documents** again → *Delivery Note - HO-<n>* PDF, **Delivery Note Generated?** ticked. *Actual:* nothing is generated — **BUG-RS12-02**.

**15d. Customer forms — ❌.** **Related** → **Required Documents** → upload **Traffic Form** and **Insurance Form**.
*Expected:* **Traffic Form Uploaded?** and **Insurance Form Uploaded?** ticked (`AF_HandoverUploadSyncService`). *Actual:* the panel reads *Uploaded* but the checkboxes stay empty — **BUG-RS12-01**.

**15e. Sign-off and completion.** **Edit** → **Customer Sign-Off** = **Physically Signed** → **Save**.

**What completes the handover** (`AF_FL_Handover_UpdateChecklistGate`, before-save):
- `AF_ChecklistComplete__c` = all **eight** flags true (5 agreements + Delivery Note + Traffic Form + Insurance Form).
- `AF_ClosedWonGatePassed__c` = checklist complete **and** Sign-Off *Physically Signed* → Handover Status set to **Completed**.

**What then happens automatically:**
- `AF_FL_Handover_SyncOpportunityGate`: `Opportunity.AF_HandoverComplete__c` = the gate value; Sales Order Status → **Delivered**.
- `AF_FL_Handover_AutoCloseWon`: if the Opportunity is at *Take the Keys* and `AF_Opportunity_ClosedWonPaymentGate` allows, sets **Closed Won**, Delivery Confirmation ✓, Close Date = today.
- `AF_FL_Handover_FollowUpTask`: 2 days after the handover date, a CRM follow-up Task (if Completed).

**Known issues:** the auto-close can fail with *"We can't save this record because the "Handover Auto Close Won" process failed … CANNOT_EXECUTE_FLOW_TRIGGER …"* — **BUG-RS11-10**; the three system checkboxes are editable by the rep, and ticking them closes the deal without the documents — **BUG-RS11-11**; Sales Order Status becomes *Delivered* even with no Sales Order — **BUG-RS12-03**.

---

## 16. Closed Won (ALF-RS-11) — ⚠️ Reachable only via BUG-RS11-11

**Who:** Sales Representative
**Do (manual):** Opportunity → Path → **Closed** → **Mark Stage as Complete** → Stage **Closed Won** → **Save**. Usually the auto-close in §15 does this first.

**Gates — all must pass:**

| Gate | Requires | Message when it fails |
|---|---|---|
| `AF_VR_Opp_ClosedWonGate` | Handover Complete, Delivery Confirmation, Invoice present with balance 0, Handover linked, Traffic Form uploaded, Sign-Off not Pending | *"Closed Won requires Handover Complete, Delivery Confirmation, full payment (Invoice Balance = 0), the Traffic Form (registration) uploaded, and Customer Sign-Off (signed delivery note) on the linked Handover."* |
| `AF_FL_Opp_ClosedWonPaymentGate` | Every payment verified, each with its typed proof document (§10), invoice balance 0 | *"Closed Won requires the correct typed document per Payment (ALF-RS-11 FR3/FR4/FR5): Cheque needs Cheque Copy, Bank Transfer needs Bank LPO, NOC Recorded needs Signed NOC…"* |
| Handover registration check | Traffic Form uploaded, Sign-Off Physically Signed | *"Closed Won requires registration and delivery confirmation on the linked Handover (ALF-RS-11 FR1): the Traffic Form must be uploaded and Customer Sign-Off must be Physically Signed."* |

**Expect in data after close:**
- Stage **Closed Won**, Probability 100%, Close Date = the day conditions were met (locked afterwards — `AF_VR_Opp_LockCloseDateAfterWon`).
- Reservation → **Converted** (`AF_FL_Opp_ConvertReservationOnClosedWon`); `Opportunity.AF_VehicleReservation__c` cleared.
- Sales Order Status **Delivered**; Handover Complete ✓; Delivery Confirmation ✓.

**Known issue:** the sold vehicle's Reservation Status returns to **Available**; the Vehicle Finder hides it, but Create Reservation's "different vehicle" list offers it — **BUG-RS08-01**.

**Not in Salesforce yet:** the invoicing event to Keyloop via MuleSoft and the confirmed-invoiced status (ALF-RS-11 FR2) — LFRDN-685.

---

## 17. Side paths (not walked on 2026-09-24)

- **Closed Lost:** **Request Closure** (header) → Lost Reason → manager approval (`AF_VR_Opp_LostApprovalRequired` blocks Closed Lost until approved).
- **Cancel Sales Order:** reason + evidence + manager approval → credit note (ALF-RS-13).
- **Reservation expiry:** `AF_FL_Reservation_ExpiryAutomation` sends reminders and sets **Expired** on the expiry date; Expired or Cancelled releases the vehicle.

---

## 18. Quick reference

### Stage gates

| Moving to | Blocked unless | Rule |
|---|---|---|
| any | one stage at a time | `AF_VR_Opp_SequentialStageProgression` |
| Explore and later | Vehicle Model or Selected Vehicle set | `AF_VR_Opp_ExploreRequiresVehicle` |
| Select and later | test drive has a Result | `AF_VR_Opp_TestDriveGate` |
| Commit | synced quote | `AF_VR_Opp_CommitGate` |
| Take the Keys | Invoice Summary exists, balance 0 | `AF_VR_Opp_TakeTheKeysGate` |
| Closed Won | see §16 | `AF_VR_Opp_ClosedWonGate`, `AF_FL_Opp_ClosedWonPaymentGate` |
| Closed Lost | lost approval Approved | `AF_VR_Opp_LostApprovalRequired` |

### Actions and where they live

| Action | Object | Visible |
|---|---|---|
| Select Vehicle | Opportunity | Consider |
| Create Quotation | Opportunity | Select |
| Start Sync | Quote | always |
| Create Reservation | Quote | always |
| Generate Reservation Contract | Vehicle Reservation | always |
| Get Payment / Notify Cashier | Invoice Summary | always |
| Generate Sales Order / Cancel Sales Order | Opportunity | every stage (used at Commit) |
| Generate Documents | Handover | always |
| Request Closure | Opportunity | open stages |

### Records auto-created along the way

| When | Record |
|---|---|
| Consider → Explore | Test Drive, Appraisal (Trade-In), Task |
| Reservation becomes Reserved (auto or approved) | Invoice Summary |
| Get Payment | Payment + Keyloop Payment Advice file; Sales Transaction Summary |
| Generate Reservation Contract | Reservation Contract PDF |
| Generate Sales Order | Sales Order PDF |
| Commit → Take the Keys | Handover |
| Generate Documents | 5 handover agreement PDFs (+ Delivery Note — see BUG-RS12-02) |
| Handover date + 2 days | CRM follow-up Task |

### Ready-made records (owned by QA SalesRep2, at Consider, clean)

| Record | Id | Car | Use for |
|---|---|---|---|
| DEMO CYCLE 02 - Ferrari happy path 7-day deposit (SF90 Rosso Corsa) | `006FV00BqZJP7dEYUT` | Ferrari SF90 Stradale — Rosso Corsa Red | Full cycle, deposit at/above threshold |
| DEMO CYCLE 03 - Rolls-Royce deposit below threshold, manager approval (Cullinan Midnight Sapphire) | `006FV00BqZJTJmGYUX` | Rolls-Royce Cullinan — Midnight Sapphire | §8 approval — deposit below 50,000 |
| DEMO CYCLE 04 - Ferrari 3-day no-deposit reservation (296 GTB Giallo Modena) | `006FV00BqZJXVvIYUX` | Ferrari 296 GTB — Giallo Modena Yellow | 3-Day, no deposit |

Sample upload documents: `demo-docs/` in the QA workspace.
