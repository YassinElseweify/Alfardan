# [ALF-RS-08 → ALF-RS-11] Retail cycle, Select Vehicle to Closed Won — bug tickets

**Found during:** end-to-end demo-readiness cycle, 2026-09-24
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/DEMO-CYCLE-10.8-10.11-report.md`
**Screenshots:** `screenshots/DEMO-CYCLE/`
**Status:** **Filed in Jira 2026-09-24** — LFRDN-696 to LFRDN-706, all assigned to Yassin, parent LFRDN-317.

> **Every ticket below is reproducible in the Lightning UI.** Log in as
> `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` (dismiss *Change Your Password*
> with **Cancel**), open the **Automotive** app, and use the records named in each ticket —
> the cycle Opportunity is **DEMO Cycle 01 - Ferrari Roma end-to-end** (`006FV00Bq30GjbQYES`).
> API calls and SOQL appear only under **Root Cause**, where a developer needs them.

The cycle crosses four stories, so each ticket carries its own story's ID sequence, continuing
from the tickets already filed for that story. Each is raised in **LFRDN** as a Bug,
assigned to **Yassin**, parent **LFRDN-317 (Build)**, labels `ALF-RS-xx` / `QA` / `Retail-Sales`,
linked *relates to* its story: ALF-RS-08 → **LFRDN-338**, ALF-RS-10 → **LFRDN-340**,
ALF-RS-11 → **LFRDN-341**, ALF-RS-12 → **LFRDN-342**.

## Summary

The retail journey works cleanly from Select Vehicle through the reservation contract and full
payment. It breaks in three places after that. **No Sales Representative can generate a Sales
Order** (BUG-RS10-12). **No Sales Representative can close a deal as Won through the documented
path**, because two of the eight handover checks can never become true from the UI
(BUG-RS12-01, BUG-RS12-02) — the only way through is for the rep to tick those checks by hand,
which the system allows and then trusts (BUG-RS11-11). Once a deal *is* closed, **the sold car is
offered to the next customer** (BUG-RS08-01).

| ID | Jira | Title | Priority | Affects |
|---|---|---|---|---|
| BUG-RS10-12 | LFRDN-696 | Generate Sales Order fails for every Sales Representative with an Apex error | Highest | Persona-specific — every persona without Read on the Account buyer fields; System Administrator unaffected |
| BUG-RS12-01 | LFRDN-697 | Uploading the Traffic Form or Insurance Form never marks it as uploaded, so no deal can close | Highest | General |
| BUG-RS08-01 | LFRDN-698 | A sold and delivered vehicle is offered again for reservation | Highest | General |
| BUG-RS12-02 | LFRDN-699 | The Delivery Note can never be generated from the handover | High | General |
| BUG-RS11-10 | LFRDN-700 | Completing a handover fails with a raw system error instead of closing the deal | High | General |
| BUG-RS11-11 | LFRDN-701 | A Sales Representative can tick the handover documents as done and close the deal without them | High | Persona-specific — Sales Representative (`AF_PSG_Sales_Rep` grants Edit) |
| BUG-RS08-02 | LFRDN-702 | An auto-approved reservation still demands a manager Approval Reference document | Medium | General |
| BUG-RS08-03 | LFRDN-703 | The reservation contract block does not say which document is missing | Medium | General |
| BUG-RS12-03 | LFRDN-704 | Sales Order Status is set to Delivered on deals that never had a Sales Order | Medium | General |
| BUG-RS08-04 | LFRDN-705 | The Reservation Contract does not print the vehicle trim | Low | General |
| BUG-RS12-04 | LFRDN-706 | The automatically created Handover has no Vehicle, Contact or Invoice | Low | General |

### Screenshots to attach in Jira

| Ticket | Jira | Relates to | Attach (all in `screenshots/DEMO-CYCLE/`) |
|---|---|---|---|
| BUG-RS10-12 | LFRDN-696 | LFRDN-340, LFRDN-674 | `20-sales-order-result.png`, `19-generate-sales-order.png` |
| BUG-RS12-01 | LFRDN-697 | LFRDN-342, LFRDN-341, LFRDN-692 | `27-handover-after-refresh.png`, `28-closed-won-attempt.png` |
| BUG-RS08-01 | LFRDN-698 | LFRDN-338 | `32-sold-vehicle-offered-for-reservation.png`, `33-so-status-delivered-no-sales-order.png` |
| BUG-RS12-02 | LFRDN-699 | LFRDN-342 | `23-handover-generate-docs.png`, `27-handover-after-refresh.png` |
| BUG-RS11-10 | LFRDN-700 | LFRDN-341, LFRDN-342 | `29-manual-tick-attempt.png`, `30-all-flags-ticked-save.png` |
| BUG-RS11-11 | LFRDN-701 | LFRDN-341, LFRDN-342 | `33-so-status-delivered-no-sales-order.png` |
| BUG-RS08-02 | LFRDN-702 | LFRDN-338 | `12-reservation-required-docs.png`, `10-reservation-record.png` |
| BUG-RS08-03 | LFRDN-703 | LFRDN-338 | `11-contract-gate-before-payment.png` |
| BUG-RS12-03 | LFRDN-704 | LFRDN-342, LFRDN-340 | `33-so-status-delivered-no-sales-order.png` |
| BUG-RS08-04 | LFRDN-705 | LFRDN-338 | `18-reservation-contract-pdf.png`, `03-select-vehicle-detail.png` |
| BUG-RS12-04 | LFRDN-706 | LFRDN-342 | `24-handover-details.png` |

---

## BUG-RS10-12 (LFRDN-696) — Generate Sales Order fails for every Sales Representative with an Apex error (Highest)

**Module:** Retail Sales — Sales Order
**Applies to:** Persona-specific — reproduced as the Sales Representative. Every persona without Read access on the Account fields listed below is affected; System Administrator is not.

### Description

When the customer has paid in full and the Sales Representative clicks **Generate Sales Order**,
confirms that full payment was collected and clicks **Next**, the screen shows *"Something went
wrong"* with a technical database error. No Sales Order is produced, so the deal cannot move on to
order processing. This worked on 22 September; it stopped working with the deployment of
23 September, which added the buyer's phone, email and address to the Sales Order document.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO Cycle 01 - Ferrari Roma end-to-end**
   (`006FV00Bq30GjbQYES`) at stage **Commit** — invoice **INVM-00080 Fully Paid**, reservation
   **RES-00178 Reserved**, selected vehicle **Ferrari Roma - Blu Pozzi Blue In Stock**. Any
   Opportunity that meets these three conditions reproduces it.
2. Header → **Show more actions** (▾) → **Generate Sales Order**.
3. The confirmation screen shows the invoice total, amount received and outstanding balance.
   Select **Yes, full payment has been collected** → **Next**.

### Expected Result

A Sales Order document is generated and linked to the Opportunity; Sales Order Status becomes
**Generated** and the reservation moves to **Converted**.

### Actual Result

> Something went wrong
> We couldn't generate the Sales Order. Please try again, or contact your administrator if the
> problem continues.
> An Apex error occurred: System.QueryException: No such column 'Phone' on entity 'Account'. If you
> are attempting to use a custom field, be sure to append the '__c' after the custom field name.
> Please reference your WSDL or the describe call for the appropriate names.

Sales Order Status stays **Not Generated**. Reproduced in the UI; the field access behind it was
then confirmed three times directly as the rep (see Root Cause).

### Root Cause

**Confirmed.** `AF_SalesOrderService` was redeployed on **2026-09-23 14:45 UTC** (class
`LastModifiedDate`). The new version's main query selects `Account.Phone`, `Account.AF_Email__c`
and `Account.BillingAddress` to print the buyer block, and the query runs **`WITH USER_MODE`**. In
user mode a single field the running user cannot read fails the entire query with *"No such column"*.

Confirmed by querying as the Sales Representative through the API:

| Field | Result as the rep |
|---|---|
| `Account.Phone` | `No such column 'Phone' on entity 'Account'` |
| `Account.AF_Email__c` | `No such column 'AF_Email__c' on entity 'Account'` |
| `Account.BillingStreet` (component of `BillingAddress`) | `No such column 'BillingStreet' on entity 'Account'` |
| `Contact.Phone`, `Contact.Email`, `Contact.MailingStreet` | readable |

A `FieldPermissions` check across the rep's seven assigned permission sets also shows no Read grant
on `Vehicle.ChassisNumber`, which the same query selects; it is likely to fail next once the
Account fields are granted.

### Proposed Solution

1. Grant **Read** on `Account.Phone`, `Account.AF_Email__c`, `Account.BillingAddress` and
   `Vehicle.ChassisNumber` to the `AF_PSG_*` permission set groups that generate Sales Orders.
2. Or, because the buyer block is document content rather than something the user chooses to view,
   read those fields in a separate `SYSTEM_MODE` query and keep `USER_MODE` for the record-access check.
3. Add an Apex test that runs `System.runAs` a Sales Representative user, so a field added to this
   query without persona access fails the deployment rather than the user.

### Reference

- **BRD** §10.10 ALF-RS-10, p.52, FR1 — *"The system should support order placement once the required payment and reservation conditions are met."*
- **BRD** §10.10 ALF-RS-10, p.52, AC1 — *"Given required payment and reservation conditions are met, When the Sales Representative initiates order placement, Then a sales order record is created and linked to the opportunity."*

---

## BUG-RS12-01 (LFRDN-697) — Uploading the Traffic Form or Insurance Form never marks it as uploaded, so no deal can close (Highest)

**Module:** Retail Sales — Vehicle Handover / Deal Completion
**Applies to:** General — the mechanism does not depend on persona.

### Description

The rep uploads the customer's Traffic Form and Insurance Form in the Handover's **Required
Documents** panel. The panel shows both as **Uploaded**, but the Handover's own **Traffic Form
Uploaded?** and **Insurance Form Uploaded?** checkboxes stay empty — and those checkboxes are what
Closed Won checks. The deal is refused with *"the Traffic Form must be uploaded"* even though it
plainly has been. Refreshing the page does not change it.

### Steps to Reproduce

1. As the Sales Representative, take an Opportunity to **Take the Keys**, which creates its Handover.
   On DEMO Cycle 01 this is **HO-00037** (`a0SFV001PomVg8q2IC`).
2. Open the Handover → **Related** tab → **Required Documents**.
3. Under **Traffic Form** click **Upload Files**, choose a PDF, wait for *1 of 1 file uploaded* → **Done**.
   Repeat under **Insurance Form**.
4. Reload the page. **Related** tab: both rows read **Uploaded**.
5. **Details** tab → *Required Documents Checklist*: read **Traffic Form Uploaded?** and **Insurance Form Uploaded?**.
6. **Edit** → Customer Sign-Off **Physically Signed** → **Save**.
7. Open the Opportunity → **Path** → **Closed** → **Mark Stage as Complete** → Stage **Closed Won** → **Save**.

### Expected Result

Uploading a file tagged *Traffic Form* / *Insurance Form* ticks the matching checkbox, and once the
remaining conditions are met the deal can be closed.

### Actual Result

Step 4 shows both documents **Uploaded**; step 5 shows both checkboxes **unticked**, after a full
reload. The files are correctly tagged (`AF_FileUpload__c` = `Traffic Form` / `Insurance Form`,
created by QA SalesRep2). Step 7 is refused:

> Closed Won requires registration and delivery confirmation on the linked Handover (ALF-RS-11
> FR1): the Traffic Form must be uploaded and Customer Sign-Off must be Physically Signed.

### Root Cause

**Confirmed from the code and the live record.** The checkboxes are set only by
`AF_HandoverUploadSyncService.syncFromLinks`, called from `trigger AF_ContentDocumentLink on
ContentDocumentLink (after insert)`. It reads `ContentVersion.AF_FileUpload__c` to decide which
checkbox to tick.

The Required Documents upload happens in two steps. The standard file uploader creates the file
**and its link to the Handover** in one step — the trigger fires at that moment, while
`AF_FileUpload__c` is still blank, and does nothing. The component then calls
`AF_DocumentController.processDocumentUpload` → `AF_DocumentService.renameUploadedDocuments`, which
finds the link already exists (no insert) and **updates** `ContentVersion.AF_FileUpload__c`. There is
no trigger or flow on `ContentVersion`, so nothing runs the sync after the tag is written.

### Proposed Solution

1. Call `AF_HandoverUploadSyncService` at the end of `renameUploadedDocuments` for the records it has
   just tagged; or
2. Add an after-update trigger on `ContentVersion` that runs the sync when `AF_FileUpload__c`
   changes to *Traffic Form* or *Insurance Form*.
3. Keep the existing link trigger for files attached by other paths.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR6 — *"…the system should prompt the Sales Representative to upload the completed Traffic Form as an attachment against the opportunity."*
- **BRD** §10.12 ALF-RS-12, p.55–56, FR7 — *"…prompt the Sales Representative to upload the Insurance Form as an attachment against the opportunity."*
- **BRD** §10.11 ALF-RS-11, p.53, FR1 — *"The system should enforce that an Opportunity cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."*

---

## BUG-RS08-01 (LFRDN-698) — A sold and delivered vehicle is offered again for reservation (Highest)

**Module:** Retail Sales — Vehicle Reservation / Inventory control
**Applies to:** General.

### Description

After a deal is Closed Won and the car handed over, the car goes back to showing **In Stock** and
**Available**. The Vehicle Finder correctly hides it, but the vehicle list inside **Create
Reservation** (*"No, let me pick a different one"*) still offers it. A second customer can be
reserved a car that has already been sold and delivered.

### Steps to Reproduce

1. As the Sales Representative, take an Opportunity to **Closed Won** for a specific vehicle. On
   DEMO Cycle 01 the car is **Ferrari Roma - Blu Pozzi Blue** (`0vLFV00057JQdOe2AL`, VIN
   ZFF98RNA000ROMA31), closed 24/09/2026 with Sales Order Status *Delivered*.
2. Open another Opportunity's synced quote — used here: **DEMO RS11 21 - Quoted but never
   reserved, keys gate**, Quote **00000185** (`0Q0FV004Ugd1sWC0IY`).
3. Header → **Create Reservation** → select **No, let me pick a different one** → leave Vehicle
   Source **In Stock** → **Next**.

### Expected Result

A vehicle whose sale is complete does not appear as available for reservation.

### Actual Result

The list (*"Pick from the vehicles currently available for sale"*, 5 of 5 items) includes **Ferrari
Roma - Blu Pozzi Blue — STK-ROMA-031 — In Stock**, selectable like any other unit. (The flow was
cancelled at this screen; no reservation was created.) The vehicle record reads *Inventory Status*
**In Stock**, *Reservation Status* **Available**, *Availability for Sale* **Available for Sale**.

### Root Cause

**Confirmed from the code.** On Closed Won, `AF_FL_Opp_ConvertReservationOnClosedWon` sets the
reservation to **Converted**. `AF_VehicleReservationStatusSync` then recomputes the vehicle's
`AF_ReservationStatus__c`, counting only *Requested*, *Pending Approval* and *Reserved* as live — so a
Converted reservation sets the vehicle back to **Available**. Nothing marks the vehicle sold:
`AF_InventoryStatus__c` has no *Sold* value and `AF_AvailabilityForSale__c` stays *Available for Sale*.

The two pickers disagree about the same car. `AF_VehicleExplorerController`
(`BLOCKING_RESERVATION_STATUSES` includes *Converted*) hides it. `AF_FL_Quote_CreateReservation`'s
`Get_Available_Vehicles` filters only on `AF_ReservationStatus__c = 'Available'` and
`AF_AvailabilityForSale__c = 'Available for Sale'`, so it shows it.

### Proposed Solution

1. In `AF_VehicleReservationStatusSync`, treat **Converted** as holding the vehicle (target a *Sold*
   status, not *Available*), and set `AF_AvailabilityForSale__c` to not-available on Closed Won.
2. Make `Get_Available_Vehicles` apply the same reservation exclusion as the Vehicle Finder, so the
   two cannot disagree again.
3. Add *Sold* (or the Keyloop equivalent for delivered stock) to `AF_InventoryStatus__c`.

### Reference

- **BRD** §10.8 ALF-RS-08, p.45, Requirement Overview — *"…we should be able to reserve vehicles in a governed manner so that stock can be held for customers without losing inventory control."*
- **BRD** §10.8 ALF-RS-08, p.47–48, FR17 — *"The system should automatically release the vehicle stock hold back to Keyloop inventory when a reservation status moves to Expired or Cancelled, ensuring the vehicle becomes available again for other Opportunities."* Release is defined for Expired and Cancelled only, not for Converted.

---

## BUG-RS12-02 (LFRDN-699) — The Delivery Note can never be generated from the handover (High)

**Module:** Retail Sales — Vehicle Handover
**Applies to:** General.

### Description

The Delivery Note is one of the eight handover documents and must exist before the deal can close.
The only button for handover documents, **Generate Documents**, never produces it — even after the
handover date and location are set, which is exactly what its own message tells the rep to do. No
other button generates it.

### Steps to Reproduce

1. Open Handover **HO-00037** (`a0SFV001PomVg8q2IC`) as the Sales Representative.
2. Header → **Generate Documents**. Result: *"Handover documents generated … Delivery Note only
   generates once Handover Date and Location are set - run this action again after scheduling to
   pick it up."* → **Finish**.
3. **Edit** → Handover Date **24/09/2026**, Handover Location **Doha Showroom - Automobiles** → **Save**.
4. Header → **Generate Documents** again → **Finish**.
5. **Related** tab → *Required Documents*; **Details** tab → **Delivery Note Generated?**.

### Expected Result

After step 4 a *Delivery Note - HO-00037* PDF is attached and **Delivery Note Generated?** is ticked.

### Actual Result

Step 4 shows the same success message, but no Delivery Note is created. The panel reads **Delivery
Note — Missing** and **Delivery Note Generated?** stays unticked. The Handover holds only the five
agreements: Vehicle Sale, Warranty, Service Contract, Vehicle Repair Disclaimer, Buyer Acknowledgement.

### Root Cause

**Confirmed from the code.** The Quick Action `AF_Handover__c.AF_Generate_Documents` runs
`AF_FL_Handover_GenerateDocuments`, which calls `AF_HandoverDocumentService` with a **blank**
Document Name. For a blank name the service generates `SEQUENCE_DOCUMENTS` — the five agreements —
and its own comment states the Delivery Note is *"never as part of the automated 5-document
sequence."* The Delivery Note branch (`DOC_DELIVERY_NOTE`, gated on `AF_HandoverDate__c` and
`AF_Location__c`) runs only when a caller passes the name *"Delivery Note"*, and no UI does. The
flow's description (*"5 agreements, then Delivery Note once the handover is scheduled"*) and its
success message describe behaviour the service does not have.

### Proposed Solution

1. In `AF_FL_Handover_GenerateDocuments`, after the blank-name call, call the service again with
   Document Name *Delivery Note* when `AF_HandoverDate__c` and `AF_Location__c` are set; or
2. Add a **Generate Delivery Note** action — which also provides the per-document option FR5 asks for.
3. Show the "run this action again" line only when the date or location is actually missing.

### Reference

- **BRD** §10.12 ALF-RS-12, p.56, FR8 — *"The system should generate the Delivery Note after the delivery schedule has been booked and confirmed, as the final document in the handover sequence."*
- **BRD** §10.12 ALF-RS-12, p.55, FR5 — *"The system should provide a manual document generation option allowing the Sales Representative to generate any individual handover document outside of the standard automation sequence at their discretion."*

---

## BUG-RS11-10 (LFRDN-700) — Completing a handover fails with a raw system error instead of closing the deal (High)

**Module:** Retail Sales — Deal Completion
**Applies to:** General.

### Description

When the Handover is Completed with the Traffic Form confirmed and the customer's sign-off
recorded, the system tries to close the Opportunity as Won automatically. The Closed Won rules
refuse that attempt, and the rep's whole Handover save fails with a long technical error naming a
"process" and an exception code. Nothing the rep entered is saved.

### Steps to Reproduce

1. Open Handover **HO-00037** (`a0SFV001PomVg8q2IC`) as the Sales Representative, with Handover
   Status **Completed** and Customer Sign-Off **Physically Signed**, and the Delivery Note not
   generated (BUG-RS12-02).
2. **Edit** → tick **Traffic Form Uploaded?** and **Insurance Form Uploaded?** → **Save**.

### Expected Result

Either the deal closes, or — if a condition is still outstanding — the save succeeds and the rep is
told in plain language which condition remains.

### Actual Result

> We can't save this record because the "Handover Auto Close Won" process failed. Give your
> Salesforce admin these details. CANNOT_EXECUTE_FLOW_TRIGGER: The flow tried to update these
> records: 006FV00Bq30GjbQYES. This error occurred: FIELD_CUSTOM_VALIDATION_EXCEPTION: Closed Won
> requires Handover Complete, Delivery Confirmation, full payment (Invoice Balance = 0), the Traffic
> Form (registration) uploaded, and Customer Sign-Off (signed delivery note) on the linked Handover..
> You can look up ExceptionCode values in the <a href='https://developer.salesforce.com/docs/atlas.en-us.api.meta/api/sforce_api_calls_concepts_core_data_objects.htm#'>SOAP API Developer Guide</a>.

Neither checkbox is saved. Reproduced twice.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Handover_AutoCloseWon` (after-save on `AF_Handover__c`)
runs when `AF_Status__c = 'Completed'`, asks the Apex gate `AF_Opportunity_ClosedWonPaymentGate`
whether the deal may close, and if **allowed** updates the Opportunity to *Closed Won* with
`AF_DeliveryConfirmation__c = true`. That gate checks payment, the Traffic Form flag and sign-off —
not `AF_HandoverComplete__c`.

The validation rule `AF_VR_Opp_ClosedWonGate` also requires `AF_HandoverComplete__c`, which is set
from `AF_ClosedWonGatePassed__c` = all **eight** checklist flags plus sign-off
(`AF_FL_Handover_UpdateChecklistGate`). With the Delivery Note unticked, the Apex gate says
*allowed* and the validation rule says *no*. The flow has no fault path, so the rule's error rolls
back the Handover save and surfaces raw. The Apex gate and the validation rule implement Closed Won
differently.

Handover Status can also be set to **Completed** by hand while the checklist is incomplete, which
starts the flow before the deal is ready.

### Proposed Solution

1. Make `AF_Opportunity_ClosedWonPaymentGate` apply the same conditions as `AF_VR_Opp_ClosedWonGate`
   — in particular `AF_HandoverComplete__c` — so the flow only attempts a close that will succeed.
2. Add a fault path to `AF_FL_Handover_AutoCloseWon`, so a refused close leaves the Handover saved
   and tells the rep what is missing.
3. Allow Handover Status *Completed* only once `AF_ChecklistComplete__c` is true.

### Reference

- **BRD** §10.11 ALF-RS-11, p.54, AC1 — *"Given a Sales Representative attempts to close an opportunity as Won before payment is confirmed, When they submit, Then the system blocks the action and prompts for completion of outstanding conditions."*
- **BRD** §10.11 ALF-RS-11, p.54, AC2 — *"Given all completion conditions are met, When the Sales Representative sets the opportunity to Closed Won, Then the stage is accepted and the Closed Won date is stamped."*

---

## BUG-RS11-11 (LFRDN-701) — A Sales Representative can tick the handover documents as done and close the deal without them (High)

**Module:** Retail Sales — Deal Completion controls
**Applies to:** Persona-specific — Sales Representative (`AF_PSG_Sales_Rep` grants Edit); any other persona holding the same grant can do the same.

### Description

The Handover checkboxes that record whether a document exists — **Delivery Note Generated?**,
**Traffic Form Uploaded?**, **Insurance Form Uploaded?** — are meant to be set by the system when
the document is produced or uploaded. The rep can simply tick them on the Edit screen, and that is
enough for the system to close the deal as Won and mark the order Delivered, whether or not the
documents exist. DEMO Cycle 01 closed with **no Delivery Note anywhere in the system**.

### Steps to Reproduce

1. Open Handover **HO-00037** (`a0SFV001PomVg8q2IC`) as the Sales Representative. No Delivery Note
   file is attached (see BUG-RS12-02).
2. **Edit** → tick **Delivery Note Generated?**, **Traffic Form Uploaded?** and **Insurance Form Uploaded?** → **Save**.
3. Open **DEMO Cycle 01 - Ferrari Roma end-to-end** → **Details**: Stage, Handover Complete, Delivery Confirmation, Sales Order Status.

### Expected Result

The rep cannot declare that a document exists; these checkboxes are set only by the generation and
upload automation, and a deal without a Delivery Note cannot close.

### Actual Result

The save succeeds (Last Modified By: QA SalesRep2). The Opportunity becomes **Closed Won**, Close
Date 24/09/2026, **Handover Complete** ✓, **Delivery Confirmation** ✓, **Sales Order Status
Delivered**. The Handover's files are the five agreements, the Traffic Form and the Insurance Form —
**no Delivery Note**.

### Root Cause

**Confirmed.** `FieldPermissions` for the rep's assigned permission sets show **`AF_PSG_Sales_Rep`
has Edit** on `AF_Handover__c.AF_DeliveryNoteGenerated__c`, `AF_TrafficFormUploaded__c` and
`AF_InsuranceFormUploaded__c`, and all three are editable on the Handover layout.
`AF_FL_Handover_UpdateChecklistGate` derives `AF_ChecklistComplete__c` and `AF_ClosedWonGatePassed__c`
from those flags alone and never checks for the file, so a hand-ticked flag counts the same as a
real document.

### Proposed Solution

1. Remove **Edit** on these three fields from the business `AF_PSG_*` groups (keep Read) and make
   them read-only on the layout; the automation that sets them runs in system context.
2. Optionally, have `AF_FL_Handover_UpdateChecklistGate` confirm a tagged file exists before treating
   a flag as true.

### Reference

- **BRD** §10.11 ALF-RS-11, p.53, FR1 — *"The system should enforce that an Opportunity cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."*
- **BRD** §10.12 ALF-RS-12, p.56, FR8 — *"The system should generate the Delivery Note after the delivery schedule has been booked and confirmed, as the final document in the handover sequence."*

---

## BUG-RS08-02 (LFRDN-702) — An auto-approved reservation still demands a manager Approval Reference document (Medium)

**Module:** Retail Sales — Vehicle Reservation / Reservation Contract
**Applies to:** General.

### Description

A 7-day reservation whose deposit meets the threshold is approved automatically — no manager is
involved. Its Required Documents checklist still lists **Approval Reference** as required, and the
contract cannot be generated until something is uploaded against it. The rep has no approval to
attach, so the only way forward is to upload a placeholder.

### Steps to Reproduce

1. As the Sales Representative, open Quote **00000189** on DEMO Cycle 01 (`0Q0FV004Xp29WYO0I2`) → **Create Reservation**.
2. **Yes, reserve the same vehicle**; Contract Type **7-Day (Deposit)**; Deposit Amount **30000**; Vehicle Source **In Stock** → **Next** → **Finish**.
3. Open the new reservation **RES-00178** (`a0WFV000g00AQ0m2AG`). **Details** tab: Approval Status **Not Required**.
4. **Related** tab → **Required Documents**.

### Expected Result

Approval Reference is not required, because the request did not go through manager approval.

### Actual Result

The checklist lists **Approval Reference — Missing** alongside Customer ID, Payment Receipt,
Quotation and Vehicle Stock / VIN. **Generate Reservation Contract** is refused until it is uploaded.

### Root Cause

**Confirmed from the custom metadata.** `AF_Document__mdt` record `VR_4_7Day_ApprRef` (*Approval
Reference*, `AF_Required__c = true`) sits under the 7-Day condition with no condition on approval
status; `VR_3_7DayTI_ApprRef` does the same for trade-in deposits. Every 7-day reservation requires
it regardless of `AF_ApprovalStatus__c`.

### Proposed Solution

Add an `AF_DocumentCondition__mdt` so the Approval Reference rows apply only when
`AF_ApprovalStatus__c = 'Approved'` (a manager approved it), and not when it is *Not Required*.

### Reference

- **BRD** §10.8 ALF-RS-08, p.47, FR13 — *"…the Approval reference (where the request went through manager approval)…"*
- **BRD** §10.8 ALF-RS-08, p.49, AC10 — *"Given any one of the Required Documents (linked Quote, Payment Receipt, Customer Identification, Approval reference where applicable, Vehicle stock record) is missing…"*

---

## BUG-RS08-03 (LFRDN-703) — The reservation contract block does not say which document is missing (Medium)

**Module:** Retail Sales — Reservation Contract
**Applies to:** General.

### Description

While documents are missing, **Generate Reservation Contract** is correctly refused — but the
message only says documents are "not fully uploaded". It does not name which of the five is
missing, so the rep has to go and inspect the checklist.

### Steps to Reproduce

1. Open reservation **RES-00178** (`a0WFV000g00AQ0m2AG`) before any documents are uploaded — or any new reservation.
2. Header → **Generate Reservation Contract**.

### Expected Result

The message names each missing document, e.g. *"Missing: Customer ID, Payment Receipt."*

### Actual Result

> Not ready yet
> Required Documents are not fully uploaded on this reservation (FR13). Attach the required customer
> documents (see the Required Documents Checklist) before generating the contract.

### Root Cause

**Confirmed from the code.** `AF_ReservationContractService` calls
`AF_DocumentService.areRequiredDocumentsUploaded(resv.Id)`, which returns a single Boolean, and
returns a fixed message when it is false. The names of the missing documents are never built.

### Proposed Solution

Have the check return the missing document names (the Required Documents component already computes
them for its *Missing* badges) and include them in the message.

### Reference

- **BRD** §10.8 ALF-RS-08, p.49, AC10 — *"…When the user attempts to generate the Reservation Contract, Then the system blocks generation and surfaces a validation message naming the missing document."*

---

## BUG-RS12-03 (LFRDN-704) — Sales Order Status is set to Delivered on deals that never had a Sales Order (Medium)

**Module:** Retail Sales — Sales Order / Handover
**Applies to:** General.

### Description

When the handover checklist completes, the Opportunity's Sales Order Status is set to
**Delivered**. It does this even when no Sales Order was ever generated, so the record reports a
delivered order that does not exist — Sales Order Document Reference and Generated Date are blank
beside it.

### Steps to Reproduce

1. Use an Opportunity on which **Generate Sales Order** never completed — DEMO Cycle 01 (see BUG-RS10-12).
2. Complete its Handover checklist — on DEMO Cycle 01, HO-00037 as in BUG-RS11-11.
3. Opportunity → **Details** → *Sales Order* section.

### Expected Result

Sales Order Status moves to Delivered only from *Generated* or later — never from *Not Generated*.

### Actual Result

**Sales Order Status: Delivered**; **Sales Order Document Reference:** blank; **Sales Order Generated Date:** blank.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Handover_SyncOpportunityGate` (after-save on
`AF_Handover__c`) runs `Update_Opportunity_Delivered` (`AF_SOStatus__c = 'Delivered'`) whenever
`AF_ClosedWonGatePassed__c = true`, without checking the current `AF_SOStatus__c`.

### Proposed Solution

Set *Delivered* only when `AF_SOStatus__c` is *Generated*, *Sent to Customer* or *Signed*. Whether a
Handover may be completed at all without a Sales Order is a separate BA question, raised in the report.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR3 — *"The system should update the sales order to Delivered upon completion of the handover checklist."*
- **BRD** §10.12 ALF-RS-12, p.55, FR6 — *"Following Sales Order generation with full payment confirmed, the system should prompt the Sales Representative to upload the completed Traffic Form…"*

---

## BUG-RS08-04 (LFRDN-705) — The Reservation Contract does not print the vehicle trim (Low)

**Module:** Retail Sales — Reservation Contract
**Applies to:** General.

### Description

DEMO Cycle 01 is a Ferrari Roma with the **Spider Package** line, chosen in Select Vehicle and priced
at +AED 32,000. The contract's Vehicle Details table shows the vehicle name, VIN, colours and stock
scenario, and the Financial Summary shows one combined "Vehicle + Add-Ons" figure. The trim does not
appear anywhere on the contract.

### Steps to Reproduce

1. On DEMO Cycle 01, **Select Vehicle** → Ferrari Roma → Blu Pozzi Blue → *Choose a Line for Ferrari Roma*: **Spider Package** → **Confirm Line**.
2. Complete the reservation, payment and documents, then **Generate Reservation Contract** on RES-00178.
3. Open **Reservation Contract - RES-00178** (`069FV007TZItZoyYYF`) from Notes & Attachments.

### Expected Result

Vehicle details include the trim (*Spider Package*) alongside make, model, colour, VIN and price.

### Actual Result

Vehicle Details: *Ferrari Roma - Blu Pozzi Blue*; VIN *ZFF98RNA000ROMA31*; Exterior *Blu Pozzi
Blue*; Interior *Cuoio Tan Leather*; Stock Scenario *In Stock*; Keyloop Reference *-*. Financial
Summary: *Vehicle + Add-Ons: 279,308*. No trim.

### Root Cause

**Not isolated.** The contract body is built in `AF_ReservationContractService`; the trim exists as
the *Spider Package* quote line (`QuoteLineItem`) on Quote 00000189, which the vehicle section does
not print. The exact field the builder would read was not confirmed.

### Proposed Solution

Read the quote's line items and print the trim / package lines (name and price) in Vehicle Details.

### Reference

- **BRD** §10.8 ALF-RS-08, p.47, FR14 — *"…vehicle details (make, model, trim, colour, VIN where assigned, price)…"*

---

## BUG-RS12-04 (LFRDN-706) — The automatically created Handover has no Vehicle, Contact or Invoice (Low)

**Module:** Retail Sales — Vehicle Handover
**Applies to:** General.

### Description

When the deal reaches Take the Keys a Handover is created automatically, but its **Vehicle**,
**Contact** and **Invoice Summary** fields are empty although the Opportunity holds all three. The
rep has to look them up and fill them in; otherwise the handover record does not say which car is
being handed to whom.

### Steps to Reproduce

1. As the Sales Representative, move an Opportunity with a selected vehicle and an Invoice Summary to **Take the Keys** — DEMO Cycle 01.
2. Open the Handover created (**HO-00037**) → **Details**.

### Expected Result

Vehicle, Contact and Invoice Summary are copied from the Opportunity.

### Actual Result

Only Opportunity, Account, Owner and Status *Pending* are set; **Vehicle**, **Contact** and
**Invoice Summary** are blank.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Opp_CreateHandoverOnTakeTheKeys` creates the record with
only `AF_Opportunity__c = $Record.Id` and `AF_Status__c = 'Pending'`.

### Proposed Solution

Also set `AF_Vehicle__c = $Record.AF_SelectedVehicle__c`, `AF_Contact__c = $Record.ContactId` and
`AF_InvoiceSummary__c = $Record.AF_InvoiceSummary__c` in the create.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR1 — *"The system should support a vehicle handover checklist capturing date, time, location, and required handover items."*
- **BRD** §10.12 ALF-RS-12, p.56, AC1 — *"Given a Sales Representative opens the handover checklist, When they complete all items, Then the checklist is saved against the opportunity and sales order."*
