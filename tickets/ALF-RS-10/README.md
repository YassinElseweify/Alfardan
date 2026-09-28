# [ALF-RS-10] Sales Order and Customer-Order Lifecycle Management — bug tickets

**Found during:** QA testing of [ALF-RS-10], 2026-09-22
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/ALF-RS-10-report.md`
**Status:** **CREATED IN JIRA, 2026-09-22.** All eleven are in **LFRDN** as Bugs, assigned to **Yassin**, parent **LFRDN-317 (Build)**, linked *relates to* the story **LFRDN-340**, labels `ALF-RS-10` / `QA` / `Retail-Sales`.

> **Every ticket below is reproducible entirely in the Lightning UI.** Log in as
> `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` (dismiss the *Change Your Password*
> screen with **Cancel**), open the **Automotive** app, and use the `DEMO RS10 …` records named in
> each ticket — search the prefix `DEMO RS10` in the global search box and they all come back.
> API calls and SOQL appear only under **Root Cause**, where a developer needs them.

> **Re-verified through the real retail cycle on 2026-09-22.** The findings below were first
> found on records built by direct data entry, so every blocker was re-tested on a deal driven
> through the actual journey — **Select Vehicle → Test Drive → Create Quotation → Create
> Reservation** — on **DEMO RS10 13 – Real retail cycle end to end** (`006FV00Bhdn1CVAYE2`).
> BUG-RS10-01 and BUG-RS10-03 both reproduce on that record; what changed is that BUG-RS10-03 is
> worse than first written (the real *Create Reservation* Quick Action fails outright for the rep,
> not just a direct record insert). See each ticket's **Steps to Reproduce**.


## Jira keys

| Local ID | Jira | Priority | Notes |
|---|---|---|---|
| BUG-RS10-01 | **LFRDN-669** | Highest | Regression of LFRDN-661's fix — linked |
| BUG-RS10-02 | **LFRDN-670** | Highest | Regression of LFRDN-662's fix — linked |
| BUG-RS10-03 | **LFRDN-671** | High | Related to LFRDN-659 — linked |
| BUG-RS10-04 | **LFRDN-672** | High | |
| BUG-RS10-05 | **LFRDN-673** | High | |
| BUG-RS10-06 | **LFRDN-674** | High | Related to LFRDN-661 — linked |
| BUG-RS10-07 | **LFRDN-675** | Medium | Consequence of LFRDN-660's fix — linked |
| BUG-RS10-08 | **LFRDN-676** | Medium | |
| BUG-RS10-09 | **LFRDN-677** | High | |
| BUG-RS10-10 | **LFRDN-679** | Low | |
| BUG-RS10-11 | **LFRDN-678** | Medium | |

### Existing tickets checked before filing — no duplicates raised

| Jira | Subject | QA verdict 2026-09-22 |
|---|---|---|
| LFRDN-659 | Sales Order cannot be created or cancelled by any business persona | **Partially fixed — left open.** Cancel Sales Order verified working end to end (Credit Note CN-00001 created). Generation still fails for personas, but on field-level security, not permission sets → LFRDN-670 / LFRDN-671. |
| LFRDN-660 | Apex payment gate not aligned with the validation rule | **Verified fixed → Done.** Both gates require Fully Paid; the message names the outstanding balance. |
| LFRDN-661 | Sales Order can be generated with no vehicle / no reservation | **Verified fixed → Done.** Both now blocked. Fix over-corrected → LFRDN-669. |
| LFRDN-662 | No payment-confirmation prompt, and no record of who confirmed | **Verified fixed → Done.** Prompt works with live figures; declining creates nothing. Audit field unwritable → LFRDN-670. |
| LFRDN-663 | Vehicle order status can regress on a late message | **Verified fixed → Done.** Backwards transition ignored with a clear message. |
| LFRDN-664 | Arrival notifications go to the wrong people | **Verified fixed → Done.** Inclusion list, consent check and contact fallback all in place; no duplicate on re-sync. |

## Summary

ALF-RS-10 is not shippable in its current state. Two defects stop the story completely: the Sales Order generation gate requires a field that nothing in the org ever fills in (**BUG-RS10-01**, affects everyone including System Administrator), and once past that, generation fails for every business persona on a permission gap (**BUG-RS10-02**). A third permission gap (**BUG-RS10-03**) stops the Sales Representative even creating the reservation that ALF-RS-10 depends on, so the story cannot be reached from its own starting point.

Behind those, the story's functional core is genuinely well built — the gate logic, the payment-confirmation prompt, the duplicate guard, out-of-order sync protection and bulk handling all behave correctly. What is missing is the integration itself (**BUG-RS10-09**, FR2 is a stub), any user-facing view of the vehicle's order status (**BUG-RS10-04**), and a set of document-quality defects on what is, in practice, a customer-signable sale contract (**BUG-RS10-06/07/08/11**). One finding is a data-access issue rather than a functional one: every Sales Representative can read every business unit's opportunities (**BUG-RS10-05**).

| ID | Title | Priority | Affects | Check it on |
|---|---|---|---|---|
| BUG-RS10-01 | Sales Order can never be generated — the gate requires an Opportunity field that no automation fills in | Highest | General — reproduced as System Administrator | DEMO RS10 01 |
| BUG-RS10-02 | Sales Order generation fails with an Apex field-access error for every business persona | Highest | Persona-specific — all `AF_PSG_*` personas; System Administrator unaffected | DEMO RS10 12 |
| BUG-RS10-03 | The Sales Representative cannot create a Vehicle Reservation, the precondition ALF-RS-10 is built on | High | Persona-specific — all `AF_PSG_*` personas; System Administrator unaffected | any Opportunity |
| BUG-RS10-04 | The vehicle's order status is invisible to users and disconnected from the field the Sales Order gate reads | High | General | DEMO RS10 07 vehicle |
| BUG-RS10-05 | Every Sales Representative can read every business unit's opportunities | High | General — all Sales Rep, Sales Manager, Showroom Manager and Marketing users | DEMO RS10 10 |
| BUG-RS10-06 | The Sales Order contract prints no make, model, year or chassis number for the vehicle being sold | High | General | DEMO RS10 06 |
| BUG-RS10-07 | The Sales Order contract tells a fully-paid customer the balance is due at delivery | Medium | General | DEMO RS10 06 |
| BUG-RS10-08 | The Sales Order is produced as a plain text file, not a PDF | Medium | General | DEMO RS10 07 |
| BUG-RS10-09 | FR2 Keyloop vehicle order status synchronisation is not implemented | High | General | Setup |
| BUG-RS10-10 | Two components fail to render on Account and Vehicle pages for the Sales Representative | Low | Persona-specific — Sales Representative; System Administrator unaffected | any Account/Vehicle |
| BUG-RS10-11 | Amounts are displayed in AED while every Sales Order document and prompt says QAR | Medium | General | DEMO RS10 01 |

---

## BUG-RS10-01 — Sales Order can never be generated, because the gate requires a field nothing fills in (Highest)

**Module:** Retail Sales — Sales Order
**Status:** Open
**Applies to:** General — reproduced as System Administrator

### Description

A Sales Representative cannot produce a Sales Order for any deal, no matter how correct the deal is. Even when the customer has paid in full, the car is in stock, and the reservation for that exact car is active, the system refuses and tells the representative there is no reservation. The message is misleading: the reservation exists and is correct, and you can see it on the same record. The system is looking for the link in a second, hidden place that nothing in the build ever writes to, so the check can never pass — for anyone. This stops ALF-RS-10 at its first step, and with it everything downstream that depends on a Sales Order existing (arrival notifications, handover, invoicing).

### Steps to Reproduce

1. Log in as the Sales Representative and open the **Automotive** app.
2. Search **DEMO RS10 01** in the global search box and open **DEMO RS10 01 – Sales Order happy path**.
3. On the **Details** tab, scroll to **Vehicle & Order** and confirm the deal is complete:
   - **Selected Vehicle** = *DEMO RS10 01 – Vehicle happy path*
   - **Invoice Summary** = *INVM-00056* — click it: **Invoice Status = Fully Paid**, Paid 500,000 of 500,000, **Balance 0**
   - **Invoice Balance** on the Opportunity = 0.00
   - **Vehicle Reservation** — note this field is **blank**
4. Go back and open the **Related** tab → **Vehicle Reservations**. The reservation **RES-00123 is there, Status = Reserved**, and its Vehicle is the same *DEMO RS10 01 – Vehicle happy path*. So the reservation exists; only the field on the Details tab is empty.
5. Back on the record, click the **▾ (Show more actions)** arrow at the top right → **Generate Sales Order**.
6. Choose **"Yes, full payment has been collected"** → **Next**.
7. To prove the two are connected: on the **Details** tab click the pencil next to **Vehicle Reservation**, pick **RES-00123**, **Save**, then run **Generate Sales Order** again. The reservation message is gone (you will then hit BUG-RS10-02).
8. Repeat steps 5–6 while logged in as a System Administrator — the result is identical.
9. **Same result through the full retail cycle, on a deal built the proper way.** Open
   **DEMO RS10 13 – Real retail cycle end to end** (`006FV00Bhdn1CVAYE2`), which was driven entirely
   through the real journey: **Select Vehicle** (Vehicle Finder → Ferrari 296 GTB → Confirm Line) →
   test drive completed → **Create Quotation** (Quote 00000183) → **Create Reservation** from that
   Quote. Its reservation **RES-00137 is Reserved** and appears in the Related tab, and its
   **Invoice Summary was linked automatically** by the same journey — but the **Vehicle Reservation**
   field on the Details tab is still **blank**. The reservation mirror is the one link the cycle
   never fills in.

### Expected Result

A Sales Order document is generated and attached to the Opportunity, the **Sales Order Status** on the Details tab becomes *Generated*, and the reservation moves to *Converted*.

### Actual Result

Step 6 ends on a screen titled **"Not ready yet"**:

```
A Sales Order cannot be generated: there is no active Reserved reservation on this Opportunity for the selected vehicle.
```

Nothing is created. Reproduced on four separate opportunities, through the Quick Action and through the API, as the Sales Representative and as System Administrator — identical refusal every time. Screenshot: `rs10-tc001-blocked-no-reservation-despite-reserved.png`; the contradiction between the blank field and the live reservation is visible in `rs10-bug01-related-list-shows-reserved-reservation.png`.

### Root Cause

**Confirmed.** Both the validation rule `AF_VR_Opp_SOGenerationGate` and `AF_SalesOrderService.findBlocker()` evaluate the reservation through **`Opportunity.AF_VehicleReservation__c`** — the *Vehicle Reservation* lookup on the Details tab — and not through the reservation's own `AF_Opportunity__c` link, which is what the related list shows.

Nothing in the org ever populates that lookup. Verified three ways:

1. `SELECT … FROM Opportunity WHERE AF_VehicleReservation__c != null` returns **zero rows across the whole org**, including the opportunities the build team's own RS-08 testing created.
2. A grep of all 156 retrieved Flows and 118 Apex classes finds exactly one reference in a write context, and it is a read (`AF_SalesOrderService.cls:221`). The reservation-creation Quick Action `AF_FL_Quote_CreateReservation` assigns thirteen fields on the reservation and none on the Opportunity. The two flows that touch the field (`AF_FL_Opp_CancellationReleaseReservation`, `AF_FL_Opp_ConvertReservationOnClosedWon`) update reservation records found by query, not the lookup.
3. Filling the lookup by hand (step 7 above) makes the gate pass immediately — isolating this field as the sole blocker.
4. Driving a deal through the complete retail cycle (step 9 above) produces the same result: the reservation reaches `Reserved` and `Opportunity.AF_InvoiceSummary__c` **is** populated automatically by `AF_InvoiceSummaryService`, while `Opportunity.AF_VehicleReservation__c` stays `null`. The mirror pattern exists and works for the Invoice Summary; the equivalent for the reservation was never built.

The reservation clause is recent: the validation rule's own description records it as *"a Reserved reservation for that vehicle (LFRDN-661, confirmed 2026-09-21)"*. The opportunities that reached *Generated* on 2026-09-21 (`QATEST RS10 A_FullyPaid_InStock`, `QATEST RS10 H_FullyPaid_InStock_NoReservation`) predate it — so this is a regression introduced with LFRDN-661, not a long-standing gap.

### Proposed Solution

Populate the lookup at the moment the reservation becomes live. The cleanest fit with the existing pattern is to extend `AF_FL_Reservation_AutoConfirmed` and `AF_FL_Reservation_Approved` — both already fire exactly when a reservation reaches `Reserved`, and both already call Apex that writes back to the Opportunity — to also set `Opportunity.AF_VehicleReservation__c` to the reservation's Id, and clear it on Expired/Cancelled. `AF_InvoiceSummaryService.ensureForApprovedReservations` is the natural place, since it already updates the Opportunity in that same transaction for the Invoice Summary lookup.

Alternatively, change the gate to evaluate the reservation through the child relationship rather than the lookup — but that needs Apex in the validation path, so populating the lookup is the smaller change.

Either way, a data fix is needed for existing opportunities that already have a live reservation but a blank lookup.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR1 — *"The system should support order placement once the required payment and reservation conditions are met."*
- **BRD**, p. 53, §10.10 ALF-RS-10 AC1 — *"Given required payment and reservation conditions are met, When the Sales Representative initiates order placement, Then a sales order record is created and linked to the opportunity."*
- **Solution Design**, p. 50 — *"Sales Order — a generated document on the opportunity (AF_SOStatus__c tracks its state); never sent to the manufacturer; vehicle ordering stays with ordering/planning in Keyloop."*

### Evidence

- Records: Opportunity `006FV00Bh7usybEYEQ`, reservation `a0WFV000eqiwH0K2AU` (RES-00123), invoice `a0TFV00FrWdaqT62UI` (INVM-00056); cycle-built control: Opportunity `006FV00Bhdn1CVAYE2` (DEMO RS10 13) with reservation RES-00137
- Screenshots: `rs10-tc001-blocked-no-reservation-despite-reserved.png`, `rs10-bug01-related-list-shows-reserved-reservation.png`
- Harness: Lightning UI as QA SalesRep2 **and** REST API v68.0 as QA SalesRep2 and as System Administrator

---

## BUG-RS10-02 — Sales Order generation fails with an Apex field-access error for every business persona (Highest)

**Module:** Retail Sales — Sales Order
**Status:** Open
**Applies to:** Persona-specific — every persona permission set group (Sales Rep, Sales Manager, Showroom Manager, CRM Agent, both Receptionists). System Administrator can generate successfully.

### Description

Once the previous problem is worked around, the Sales Representative still cannot produce a Sales Order. The action runs, the representative confirms that payment has been collected, and then the screen shows a technical error and nothing is created. The cause is a permission gap: as the final step of generating the Sales Order, the system stamps *who* confirmed the payment onto the record — and no business role has permission to write to that field. Because the stamp fails, the whole generation is rolled back. The very control FR4 asks for is what breaks the process. System Administrator is unaffected, which is why this does not show up in admin testing.

### Steps to Reproduce

1. Log in as the Sales Representative, open the **Automotive** app, search **DEMO RS10 12** and open **DEMO RS10 12 – Sales Order gate met, generation still fails**.
   *(This record has the **Vehicle Reservation** field on the Details tab already filled in by hand, so BUG-RS10-01 does not get in the way. To set one up yourself on any other record: Details tab → **Vehicle & Order** → pencil next to **Vehicle Reservation** → pick the record's Reserved reservation → Save.)*
2. On the **Details** tab confirm the deal is complete: **Invoice Summary** is *Fully Paid* with Balance 0, **Selected Vehicle** is *In Stock* (click through to the vehicle to see its Inventory Status), and **Vehicle Reservation** is populated.
3. Click the **▾ (Show more actions)** arrow → **Generate Sales Order**.
4. Choose **"Yes, full payment has been collected"** → **Next**.
5. To see which field causes it: on the **Details** tab, in the **Sales Order** section, try to edit **Sales Order Payment Confirmed By** — there is no edit pencil on that field for this persona, while **Sales Order Document Reference** immediately above it is editable.
6. Repeat steps 3–4 as a System Administrator — it succeeds and the document appears under **Notes & Attachments**.

### Expected Result

The Sales Order is generated, the document attached, the **Sales Order Status** set to *Generated*, and the confirming user recorded.

### Actual Result

Step 4 ends on a screen titled **"Something went wrong"**:

```
We couldn't generate the Sales Order. Please try again, or contact your administrator if the problem continues.
An Apex error occurred: System.DmlException: Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result!
```

Nothing is created — no document, no status change. Reproduced on two separate opportunities (`006FV00Bh7usybEYEQ` with the lookup filled by hand, and the clean `006FV00BhA6Iy6mYUC`). Step 6 as System Administrator succeeds: *"Sales Order generated."* Screenshot: `rs10-tc001-apex-dml-inaccessible-fields.png`.

### Root Cause

**Confirmed.** `AF_SalesOrderService.generate()` finishes with `update as user opportunityUpdates`, and that update includes `AF_SOPaymentConfirmedBy__c = UserInfo.getUserId()`. `update as user` enforces field-level security, so the running user must have edit access to every field in the update.

A `FieldPermissions` query for `Opportunity.AF_SOPaymentConfirmedBy__c` returns `PermissionsEdit = false` for **every** permission set group in the org — `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager`, `AF_PSG_Showroom_Manager`, `AF_PSG_CRM_Agent`, `AF_PSG_Receptionist_Sales`, `AF_PSG_Receptionist_Service`, `AF_PS_Opportunity_FullAccess` and even `AF_System_Admin`. Only the System Administrator *profile* can write it, which is why the admin path works. Isolated directly: a field update of `AF_SOPaymentConfirmedBy__c` as the rep returns `INVALID_FIELD_FOR_INSERT_UPDATE`, while `AF_SODocumentReference__c` on the same record saves normally — that is the difference you can see in step 5.

The other three Sales Order fields in the same update (`AF_SOStatus__c`, `AF_SODocumentReference__c`, `AF_SOGeneratedDate__c`) all have `PermissionsEdit = true` on those same groups — so this one field was missed when field-level security was granted.

### Proposed Solution

Grant `Edit` on `Opportunity.AF_SOPaymentConfirmedBy__c` to the permission set groups that already hold edit on the other three Sales Order fields — at minimum `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager` and `AF_PSG_Showroom_Manager`.

If the intent is that the field must not be editable by hand (reasonable for an audit stamp), keep it read-only on the page layout but still writable at the permission level, or have the service perform that one stamp in system context — the current combination gives neither protection nor function.

While this is being fixed, please also add a **confirmation timestamp** field: FR4's control currently records who, but never when.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR4 — *"The system should prompt the Sales Representative to confirm full payment collection before allowing the generation of the Sales Order document."*
- **BRD**, p. 52, §10.10 ALF-RS-10 FR1 — *"The system should support order placement once the required payment and reservation conditions are met."*

### Evidence

- Records: Opportunity `006FV00BhA6Iy6mYUC` (clean repro), `006FV00Bh7usybEYEQ`
- Screenshot: `rs10-tc001-apex-dml-inaccessible-fields.png`
- Harness: Lightning UI as QA SalesRep2, REST API v68.0 as QA SalesRep2, Apex as System Administrator

---

## BUG-RS10-03 — The Sales Representative cannot create a Vehicle Reservation, the precondition ALF-RS-10 is built on (High)

**Module:** Retail Sales — Vehicle Reservation (blocks Sales Order)
**Status:** Open
**Applies to:** Persona-specific — all `AF_PSG_*` personas. System Administrator can create reservations normally.

### Description

ALF-RS-10 requires a live reservation before a Sales Order can be produced. The Sales Representative cannot create one — and this is not an edge case reached by unusual means: the standard **Create Reservation** button on the Quote, the step that follows the quotation in the normal retail journey, simply fails with "Something went wrong" and nothing is created. The cause is again a permission gap on a single Opportunity field that a background process writes to while running as the representative. This means the representative cannot even reach the starting line of ALF-RS-10, and it blocks ALF-RS-08 in the same way.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS10 13 – Real retail cycle end to end**
   (`006FV00Bhdn1CVAYE2`) → **Related** tab → **Quotes** → open Quote **00000183**.
   *(To build one from scratch instead: new Opportunity → **Select Vehicle** → pick a model and a
   vehicle → **Confirm Line** → complete the test drive that appears at Explore → **Create
   Quotation**.)*
2. On the Quote click the **Create Reservation** button in the highlights panel.
3. Answer the screen: **"Yes, reserve the same vehicle"**, Contract Type **3-Day (No Deposit)**,
   Vehicle Source to match the vehicle, then **Next**.
4. Repeat exactly the same steps logged in as a System Administrator.
5. To see which field causes it: as the Sales Representative open any Opportunity's **Details** tab
   → **Vehicle & Order** and try to edit **Invoice Balance** — there is no edit pencil for this
   persona, while **Invoice Summary** beside it is editable.

### Expected Result

The reservation is created by the persona the BRD names as its owner, auto-confirms to *Reserved*, and an Invoice Summary appears on the Opportunity.

### Actual Result

Step 3 ends on a screen titled **"Something went wrong"**:

```
We couldn't create the reservation. Please try again, or contact your administrator if the problem continues.
```

No reservation is created — the Opportunity's **Vehicle Reservations** related list stays empty.
Screenshot: `rs10-bug03-create-reservation-action-fails-for-rep.png`.

Creating the same reservation as a record (rather than through the Quick Action) surfaces the
underlying cause verbatim:

```
We can't save this record because the "Reservation Auto Confirmed" process failed. Give your Salesforce admin these details. CANNOT_EXECUTE_FLOW_TRIGGER: An Apex error occurred: System.DmlException: Operation failed due to fields being inaccessible on Sobject Opportunity, check errors on Exception or Result!
Error ID: 1411077257-16501 (-871995846)
```

Step 4 as System Administrator succeeds — the reservation saves, auto-confirms to *Reserved*, and
its Invoice Summary is created and linked onto the Opportunity (this is how RES-00137 on
DEMO RS10 13, and RES-00123 / INVM-00056 on DEMO RS10 01, were made).

### Root Cause

**Confirmed.** Inserting a reservation fires the before-save routing and then `AF_FL_Reservation_AutoConfirmed`, which calls `AF_InvoiceSummary_EnsureOnResv` → `AF_InvoiceSummaryService.ensureForApprovedReservations`. That method performs `update as user oppUpdates`, writing both `Opportunity.AF_InvoiceSummary__c` and `Opportunity.AF_InvoiceBalance__c` (`AF_InvoiceSummaryService.cls`, lines 107–115).

`FieldPermissions` shows `Opportunity.AF_InvoiceBalance__c` with `PermissionsEdit = false` for every business permission set group — `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager`, `AF_PSG_Showroom_Manager`, `AF_PSG_CRM_Agent`, both Receptionist groups — and `true` only for `AF_System_Admin`, `AF_PS_Integration_MuleSoft` and `AF_PS_Opportunity_FullAccess`. The companion field in the same update, `Opportunity.AF_InvoiceSummary__c`, is `true` for all of them, so again a single field was missed. That is the difference you can see in step 5.

### Proposed Solution

Grant `Edit` on `Opportunity.AF_InvoiceBalance__c` to the same permission set groups that already hold edit on `Opportunity.AF_InvoiceSummary__c`.

If the field is meant to be system-maintained only (its own description says *"Rollup from linked Payments — lookup-based, maintained by automation"*), keep it read-only on the page layout while granting the permission, so the automation can write it in the user's context.

This is the same class of defect as BUG-RS10-02; both should be fixed together with a review of every field written by `update as user` in the `AF_*` service classes against the persona permission set groups.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR1 — *"The system should support order placement once the required payment and reservation conditions are met."*
- **BRD**, §10.8 ALF-RS-08 FR1 — reservation creation is the Sales Representative's own action.

### Evidence

- Records: Opportunity `006FV00Bhdn1CVAYE2` (DEMO RS10 13, built through the real cycle), Quote `0Q0FV004UZQMx1I0YT` (00000183), reservation RES-00137 (admin-created), RES-00123 (`a0WFV000eqiwH0K2AU`)
- Screenshot: `rs10-bug03-create-reservation-action-fails-for-rep.png`
- Harness: Lightning UI as QA SalesRep2 (real Create Reservation Quick Action); root cause read from `AF_InvoiceSummaryService.cls` (metadata retrieved 2026-09-22)

---

## BUG-RS10-04 — The vehicle's order status is invisible to users and disconnected from the Sales Order gate (High)

**Module:** Retail Sales — Vehicle Order Status
**Status:** Open
**Applies to:** General

### Description

FR3 asks for the vehicle's high-level order status — On Order, In Transit, In Stock / Arrived — to be visible in Salesforce so the Sales team knows where a customer's car is. The data is captured correctly, but **no user can see it**: the field is on no page anywhere in the application. What users do see is a different field with different values that the synchronisation never updates.

This is not only a visibility problem. The Sales Order gate checks the field users see, while the synchronisation writes the field they cannot see. The result is that a car arriving in stock does not unlock the Sales Order — the deal stays blocked even though the vehicle is physically there.

### Steps to Reproduce

1. Log in as the Sales Representative, open the **Automotive** app → **Vehicles** tab.
2. Search **DEMO RS10 07** and open **DEMO RS10 07 – Vehicle order status sync**. This vehicle has been synced to *In Stock-Arrived* with the brand sub-status *"BMW: At Port Hamad"*.
3. Look at the **Overview** tab, then the **Details** tab, for a **Vehicle Order State** or **Brand Sub-status** field.
4. Note the one status field that *is* shown — **Inventory Status** — and its value.
5. Open **DEMO RS10 05 – Vehicle in transit** and compare: the only status a user can see is the same *Inventory Status* field, whose values are In Stock / In Transit / **Ordered** — not FR3's *On Order* / *In Transit* / *In Stock / Arrived*.
6. Now open **DEMO RS10 05 – Sales Order blocked vehicle in transit** (the Opportunity) → **▾ → Generate Sales Order** → confirm payment. It is refused because the vehicle is not *In Stock* — and nothing a Keyloop arrival does will ever change that field.

### Expected Result

Per FR3, the three high-level order states are surfaced in Salesforce with brand sub-statuses where available, and a vehicle that has arrived can proceed to a Sales Order.

### Actual Result

Steps 3 and 5: **neither Vehicle Order State nor Brand Sub-status appears anywhere** on the Vehicle record — not on the Overview tab, not on the Details tab. Only *Inventory Status* is shown. Screenshot: `rs10-tc004-vehicle-page-no-order-state.png`.

The data is stored correctly — after a sync the vehicle holds `order = In Stock-Arrived`, `sub = BMW: At Port Hamad` — but `Inventory Status` stays at whatever it was (on DEMO RS10 07 it read *Ordered* while the order state said *In Transit*).

### Root Cause

**Confirmed.** The org holds two parallel vehicle status fields that nothing reconciles:

| Field | Values | Written by | Read by | On a page? |
|---|---|---|---|---|
| `Vehicle.AF_VehicleOrderState__c` | On Order / In Transit / In Stock-Arrived | `AF_VehicleOrderStatusSync` only | nothing else | **no** |
| `Vehicle.AF_InventoryStatus__c` | In Stock / In Transit / Ordered | manual entry, `AF_VehicleExplorerController` | `AF_SalesOrderService`, `AF_VR_Opp_SOGenerationGate` | yes |

Searching `Vehicle_Record_Page.flexipage-meta.xml` and `Vehicle-Vehicle Layout.layout-meta.xml` returns **0 occurrences** of `AF_VehicleOrderState__c` and `AF_BrandSubStatus__c`, and 1 of `AF_InventoryStatus__c`. There is one Vehicle layout and one Vehicle Lightning record page in the org, so there is no other page these fields could be on. A grep across all 156 Flows and 118 Apex classes shows `AF_VehicleOrderState__c` referenced only by `AF_VehicleOrderStatusSync`, two Vehicle record types and one permission set — nothing maps it to `AF_InventoryStatus__c` in either direction.

### Proposed Solution

Decide which field is the Keyloop-mastered vehicle status and keep one (see GAP-RS10-05 in the report — the BRD names the states inconsistently, which is probably how two fields appeared).

If `AF_VehicleOrderState__c` stays: add it and `AF_BrandSubStatus__c` to the Vehicle Lightning record page, and have `AF_VehicleOrderStatusSync` also set `AF_InventoryStatus__c` (In Stock-Arrived → In Stock, In Transit → In Transit, On Order → Ordered) — or point the Sales Order gate at the order-state field instead.

If `AF_InventoryStatus__c` stays: retire `AF_VehicleOrderState__c`, have the sync write the inventory field, and add the *On Order* / *In Stock / Arrived* labels FR3 asks for.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR3 — *"The system should surface high-level order states of On Order, In Transit, and In Stock / Arrived in Salesforce, with brand-specific sub-statuses where available."*
- **BRD**, p. 52, §10.10 ALF-RS-10 FR5 — *"The system should prevent Sales Order generation for opportunities linked to non-stock, on-order, or in-transit vehicles, consistent with the Keyloop Sales Order logic."*
- **BRD**, p. 53, §10.10 ALF-RS-10 AC2 — *"Given a vehicle status changes to In Transit in Keyloop, When the synchronization runs, Then the Salesforce order record reflects the In Transit state."*

### Evidence

- Records: Vehicle `0vLFV0004wwVbQC2A0` (DEMO RS10 07), Vehicle `0vLFV0004wiyQHk2AM` (DEMO RS10 05)
- Screenshot: `rs10-tc004-vehicle-page-no-order-state.png`
- Harness: Lightning UI as QA SalesRep2, Apex as System Administrator, metadata retrieved 2026-09-22

---

## BUG-RS10-05 — Every Sales Representative can read every business unit's opportunities (High)

**Module:** Cross-cutting — data access
**Status:** Open
**Applies to:** General — affects all users holding `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager`, `AF_PSG_Showroom_Manager`, `AF_PSG_Marketing` or `AF_PSG_Marketing_Manager`

### Description

The org is set up so that opportunities are private and are shared deliberately: by business unit, by showroom, and up a 44-role management hierarchy. That design is bypassed. A Sales Representative in one business unit can open, read and report on any opportunity in the company — including deals belonging to another showroom and another owner — with full commercial detail: customer, amount, stage. They cannot change those records, so this is a confidentiality problem rather than a data-integrity one, but commercial information is not contained within the business unit that owns it.

### Steps to Reproduce

1. Log in as the Sales Representative (**QA SalesRep2**, role *Sales Rep – SportsMotors*).
2. Type **DEMO RS10 10** into the global search box and open **DEMO RS10 10 – SportsMotors deal owned by another user**.
   This record is owned by **QA ShowroomManager2**, sits on an Account owned by that same user, and is in a business unit whose sharing group this rep does **not** belong to.
3. Read the record: Account, **Amount**, Stage, Close Date are all visible in full.
4. Open the **Opportunities** tab → list view **All Opportunities** and scroll: deals belonging to other owners and other business units are listed.
5. Try to change something — edit the **Description** and Save.
6. Optional cross-check for an administrator: Setup → **Sharing Settings** shows Opportunity org-wide default = **Private**, and Setup → **Permission Sets → Sales Rep → Object Settings → Opportunities** shows **View All Records** ticked.

### Expected Result

Access denied by both search and direct link, per the Private org-wide default and the business-unit sharing model.

### Actual Result

Steps 2–4 succeed and the record is fully readable, including the Amount. Step 5 is correctly refused:

```
insufficient access rights on object id
```

Screenshot: `rs10-tc011-salesrep-sees-other-bu-opportunity.png`.

### Root Cause

**Confirmed.** `ObjectPermissions` for `SobjectType = 'Opportunity'` shows `PermissionsViewAllRecords = true` on `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager`, `AF_PSG_Showroom_Manager`, `AF_PSG_Marketing` and `AF_PSG_Marketing_Manager`. *View All Records* grants read on every record of the object regardless of sharing, overriding the Private org-wide default, the eleven criteria-based business-unit and showroom sharing rules, and the role hierarchy.

That the edit is still blocked confirms the diagnosis: `PermissionsModifyAllRecords` is `false`, so writes still go through sharing while reads do not. The test record was chosen so that no `OpportunityShare` row grants the rep anything — only the owner's row exists — which is why the read can only be coming from View All.

The sharing model itself is correctly built: `AF_SR_Opportunity_SportsMotors`, `AF_SR_Opportunity_Automobiles`, `AF_SR_Opportunity_PremierMotors` and eight per-showroom rules share on `AF_BusinessUnit__c` / `AF_Showroom__c` into per-BU public groups with Edit access. *View All* simply makes the read half of it redundant.

### Proposed Solution

Remove **View All Records** on Opportunity from `AF_PSG_Sales_Rep`, `AF_PSG_Showroom_Manager` and `AF_PSG_Sales_Manager`, and let the existing sharing rules and role hierarchy do the work they were built for. Managers already gain visibility over their own branch through the hierarchy.

Where a genuinely org-wide view is needed (Marketing reporting is the plausible case), keep it on that group alone and record the decision as a deliberate exception.

Worth confirming in the same fix: `AF_PSG_Sales_Rep` also has `PermissionsEdit = true` on Opportunity, which combined with the BU sharing rules' Edit access means a representative can edit any opportunity in their own business unit, not only their own. That may well be intended; it is not written down anywhere.

### Reference

- **BRD**, §7 Cross-Cutting 1 — data access and visibility must respect business-unit boundaries.
- **BRD**, p. 52, §10.10 ALF-RS-10 Related Personas — *"Sales Representative, Ordering / Planning / Admin Team, System"*.

### Evidence

- Records: Opportunity `006FV00BhE8daz6YUA` (isolation test), `006FV00BhCwC6jcYUC`
- Screenshot: `rs10-tc011-salesrep-sees-other-bu-opportunity.png`
- Harness: Lightning UI and REST API v68.0 as QA SalesRep2; permissions read via `ObjectPermissions` / `OpportunityShare` / `GroupMember` as System Administrator

---

## BUG-RS10-06 — The Sales Order contract prints no make, model, year or chassis number (High)

**Module:** Retail Sales — Sales Order document
**Status:** Open
**Applies to:** General

### Description

The generated Sales Order is laid out as a vehicle sale contract with a *"Description of the Vehicle"* section. On every generated document that section is almost entirely blank: type of vehicle, model, model year, manufacturing date, chassis number and interior colour all print as a dash. Only the VIN and exterior colour appear. A sale contract that does not say which car is being sold is not usable as a commercial document.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS10 06 – Sales Order API bypass attempt** — it already has a generated Sales Order.
2. Go to the **Related** tab → **Notes & Attachments** → open **"Sales Order – DEMO RS10 06 …"**.
3. Read section **2. DESCRIPTION OF THE VEHICLE**.
4. To see where the data should come from: open the **Vehicles** tab and open any inventory vehicle → **Details**. The **Make**, **Model**, **Model Year** and **Chassis Number** fields are empty on every one of them; the make and model are held on the linked **Vehicle Definition** instead (open it from the vehicle — e.g. *VD: Ferrari 296 GTB*, Variant *296 GTB*, Brand *Ferrari*).

### Expected Result

The contract identifies the vehicle: make, model, model year, manufacturing date, chassis number, VIN and colours.

### Actual Result

```
2. DESCRIPTION OF THE VEHICLE
------------------------------------------------------------
Type of Vehicle    : -
Vehicle Model      : -
Model Year         : -
Manufacturing Date : -
Chassis No.        : -
VIN                : ZFF95FLA000RS1006
Exterior Color     : Rosso Corsa Red
Interior Color     : -
Inventory Status   : In Stock
Brand Sub-Status   : -
```

This is not test-data specific: of the **26 inventory vehicles in the org, 0 have Make, 0 have Model, 0 have Model Year and 0 have Chassis Number** (9 of 26 have an interior colour). Every Sales Order generated today will print the same blanks.

### Root Cause

**Confirmed.** `AF_SalesOrderService.buildSalesOrderBody()` reads `AF_SelectedVehicle__r.MakeName`, `.ModelName`, `.ModelYear`, `.ManufacturedDate` and `.ChassisNumber` from the **Vehicle** record. Those standard Automotive Cloud fields are empty on every vehicle in the org, because the make/model data is held on the linked **VehicleDefinition** — e.g. `1PqFV0002sT3hsa0AB` carries `Name = "VD: Ferrari 296 GTB"`, `VariantName = "296 GTB"`, `AF_Brand__c = "Ferrari"`, `BodyType = "Coupe"`, `FuelType = "Hybrid"`.

So this is a wiring problem, not missing data: the document reads one object, the data lives on its parent.

### Proposed Solution

Change the query in `AF_SalesOrderService` to read the vehicle description through `AF_SelectedVehicle__r.VehicleDefinition.*` (`Name`, `VariantName`, `AF_Brand__c`, `BodyType`) with the Vehicle's own fields as a fallback. `AF_ReservationContractService` and `AF_HandoverDocumentService` build the same vehicle block and should be checked and corrected together.

Chassis number and manufacturing date are genuinely per-vehicle and are simply not being captured — either they should come across from Keyloop with the inventory record, or the fields should be dropped from the contract template until they are.

### Reference

- **BRD**, p. 53, §10.10 ALF-RS-10 AC1 — *"…Then a sales order record is created and linked to the opportunity."*
- **Solution Design**, p. 50 — *"Sales Order — a generated document on the opportunity (AF_SOStatus__c tracks its state); never sent to the manufacturer…"*

### Evidence

- Records: Opportunity `006FV00Bh88Q9jgYEC`, document `069FV007NaVQzmuYID`, vehicle `0vLFV0004wpk0qy2AA`, vehicle definition `1PqFV0002sT3hsa0AB`
- Harness: Lightning UI as QA SalesRep2 (document opened from Notes & Attachments); source read from `AF_SalesOrderService.cls` (retrieved 2026-09-22)

---

## BUG-RS10-07 — The Sales Order contract tells a fully-paid customer the balance is due at delivery (Medium)

**Module:** Retail Sales — Sales Order document
**Status:** Open
**Applies to:** General

### Description

The Sales Order can only be produced once the customer has paid in full — the system enforces that. Yet the document it produces states that only a deposit has been taken and that the remaining price is due when the car is delivered. On a document laid out as a sale contract with a signature block, that is a contradiction a customer could reasonably rely on.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS10 06 – Sales Order API bypass attempt**.
2. On the **Details** tab confirm the money position: **Invoice Summary** *INVM-00060* is **Fully Paid**, 500,000 of 500,000, **Balance 0**.
3. **Related** tab → **Notes & Attachments** → open **"Sales Order – DEMO RS10 06 …"**.
4. Read section **3. PURCHASE PRICE & TERMS OF PAYMENT** — compare the figures with the two sentences underneath them.

### Expected Result

The document reflects the commercial position it was generated from: paid in full, nothing outstanding.

### Actual Result

```
3. PURCHASE PRICE & TERMS OF PAYMENT
------------------------------------------------------------
Total Purchase Price (QAR) : 500,000
  Down-payment (QAR)       : 500,000
  Remaining Price (QAR)    : 0
Payment Status     : First payment/deposit confirmed (DEC-014 gate passed).
                     Remaining Price is due at delivery of the Vehicle to the Buyer.
```

The figures are right; the two sentences beneath them are wrong. The same text is printed on every Sales Order.

### Root Cause

**Confirmed.** The two lines are hard-coded literals in `AF_SalesOrderService.buildSalesOrderBody()`. They were written when the Solution Design's DEC-014 rule applied (*"the Sales Order document is produced after the first payment/deposit"*). The gate was later changed to require full payment — the validation rule's description records it: *"Sales Order requires: Invoice Summary Fully Paid (supersedes DEC-014 first-payment-only, 2026-09-19)"* — but the document text was not updated with it.

### Proposed Solution

Replace both lines with text derived from the actual figures: *"Payment Status: Paid in full. No balance outstanding."* when the balance is zero, and a real outstanding-balance sentence otherwise — so the document stays correct whichever way GAP-RS10-01 is resolved. The Solution Design's DEC-014 should be amended in the same pass so document and design agree.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR4 — *"The system should prompt the Sales Representative to confirm full payment collection before allowing the generation of the Sales Order document."*
- **Solution Design**, p. 47, DEC-014 *Sales Order timing* — *"the Sales Order document is produced after the first payment/deposit; full payment is required before handover, not before the Sales Order."*

### Evidence

- Record: Opportunity `006FV00Bh88Q9jgYEC`, document `069FV007NaVQzmuYID`
- Harness: Lightning UI as QA SalesRep2; source and validation rule read from metadata retrieved 2026-09-22

---

## BUG-RS10-08 — The Sales Order is produced as a plain text file, not a PDF (Medium)

**Module:** Retail Sales — Sales Order document
**Status:** Open
**Applies to:** General

### Description

The Sales Order is a sale contract with a signature block for both parties, but it is generated as a `.txt` file — unformatted, unbranded and not suitable for printing or signing. The Sales Transaction Summary generated on the very same opportunity is a proper PDF, so the capability exists and is already in use.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS10 07 – Vehicle order status sync and arrival notification**.
2. Go to the **Related** tab → **Notes & Attachments**.
3. Compare the two documents listed there — their file-type icons and what happens when you open each:
   - *Sales Transaction Summary – DEMO RS10 07 …* → **PDF**
   - *Sales Order – DEMO RS10 07 …* → **TXT**

### Expected Result

The Sales Order is a formatted, printable document, consistent with the other generated documents on the same record.

### Actual Result

The Sales Order opens as unformatted plain text; the Transaction Summary beside it opens as a rendered PDF.

### Root Cause

**Confirmed.** `AF_SalesOrderService` builds the body as a joined `List<String>` and writes `cv.VersionData = Blob.valueOf(...)` with `cv.PathOnClient = 'Sales_Order_<name>.txt'`. Its header comment gives the reason: *"the document itself is a plain-text ContentVersion (no PDF rendering available from Apex without a Visualforce/OmniStudio template)."*

That reason is now out of date. `AF_PdfGenerationService` exists in the org and does exactly this, and its own description says so: *"Renders an HTML body to PDF via Blob.toPdf() (Spring 26+)… Replaces the Visualforce-renderAs-pdf pattern originally planned for this org."* `AF_TransactionSummaryService` already uses it — `cv.VersionData = Blob.toPdf(buildHtml(opp, payments))`.

### Proposed Solution

Convert `AF_SalesOrderService.buildSalesOrderBody()` to emit HTML and render it with `Blob.toPdf()`, exactly as `AF_TransactionSummaryService` does, and set the file name to `.pdf`. `AF_ReservationContractService` carries the same stale comment and the same plain-text output, and should be converted in the same change.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 Requirement Overview — *"the Sales Representative generates the Sales Order -- an internal document that succeeds the quotation stage and is stored against the opportunity for internal processing."*

### Evidence

- Records: Opportunity `006FV00Bh8FBkIuYEL`, the two documents on that record
- Harness: Lightning UI as QA SalesRep2; source read from `AF_SalesOrderService.cls`, `AF_TransactionSummaryService.cls`, `AF_PdfGenerationService.cls` (retrieved 2026-09-22)

---

## BUG-RS10-09 — FR2 Keyloop vehicle order status synchronisation is not implemented (High)

**Module:** Retail Sales — Keyloop integration
**Status:** Open
**Applies to:** General

### Description

FR2 requires vehicle order statuses to be synchronised from Keyloop into Salesforce, and the acceptance criteria are written around "when the synchronization runs". There is no synchronisation. What exists is a Salesforce-side entry point that a future integration could call, invoked by hand. Nothing brings status in from Keyloop, nothing runs on a schedule, nothing raises an alert when a message fails or cannot be mapped, and there is no way to replay a missed message. In practice the Sales team has no automatic visibility of where a customer's car is, and nobody is told when that information goes stale.

### Steps to Reproduce

As a System Administrator, in **Setup**:

1. **Named Credentials** — look for any Keyloop endpoint. There are four credentials and none of them is Keyloop.
2. **Apex Jobs** / **Scheduled Jobs** — look for a scheduled vehicle-status sync. There is none.
3. **Apex Classes** → open `AF_VehicleOrderStatusSync` and read the header comment.
4. **Platform Events** — the org has one (`AF_LeadChange__e`), unrelated to vehicle status.
5. As the Sales Representative, open any vehicle: there is no *Last Sync* / *Integration Status* field for order status (contrast the Payment and Reservation records, which do carry Keyloop reference and integration-status fields).

### Expected Result

Vehicle order statuses arrive from Keyloop automatically; a failed run leaves statuses at their last known values and raises an alert to a monitored recipient; statuses catch up on the next successful run; duplicate messages are ignored.

### Actual Result

None of it exists. The class header states the position plainly:

```
No live Keyloop/MuleSoft integration exists yet for vehicle order status (unlike Payments and
Reservations, which already carry AF_KeyloopPaymentReference__c / AF_KeyloopReservationReference__c
and an AF_IntegrationStatus__c field wired to real sync flows). This class is the Salesforce-side
entry point a future inbound integration user/Platform Event would call - for now it is invoked
manually (data-fix / Ordering-Planning-Admin Quick Action)...
```

What *is* built works well when called: an unmapped status value is rejected cleanly (*"Invalid Vehicle Order State 'Customs Clearance' — must be On Order, In Transit, or In Stock-Arrived"*), an unknown vehicle returns *"Vehicle not found, or you do not have access to it"*, a late out-of-sequence message is ignored rather than regressing the record, and 20 vehicles sync in a single call using 1 query and 1 update. But **no alert is raised to anyone** in any of those cases.

### Root Cause

**Confirmed — the integration was never built.** `AF_VehicleOrderStatusSync` is an invocable stub by its author's own description, and there is no scheduler, endpoint or monitoring around it. This is scope not yet delivered rather than code behaving incorrectly.

### Proposed Solution

Build the FR2 touchpoint to the same pattern the org already uses for payments and reservations: an inbound MuleSoft call (or Platform Event) into `AF_VehicleOrderStatusSync`, a Keyloop reference and an integration-status field on Vehicle for matching and replay, and an alert to a named recipient on failure or on an unmapped value.

The alert recipient, channel and threshold are not defined anywhere in the BRD — see GAP-RS10-09 in the report; that decision is needed before this can be specified.

If FR2 is not in the Release 1 delivery scope, the story's acceptance criteria AC2 and AC3 should be deferred with it, since neither can be met without it.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 FR2 — *"The system should synchronize vehicle order statuses from Keyloop into Salesforce."*
- **BRD**, p. 53, §10.10 ALF-RS-10 AC2 — *"Given a vehicle status changes to In Transit in Keyloop, When the synchronization runs, Then the Salesforce order record reflects the In Transit state."*
- **BRD**, p. 53, §10.10 ALF-RS-10 Assumption 3 — *"Order state integration scope depends on Keyloop and, for some brands, principal system touchpoints to be validated per brand."*
- **Solution Design**, p. 50, Integration design — the vehicle touchpoints are listed as *"MuleSoft-owned detailed design (integration-design item)"*.

### Evidence

- Record: Vehicle `0vLFV0004wwVbQC2A0`
- Harness: Setup inspection and `sf` CLI metadata listing; source read from `AF_VehicleOrderStatusSync.cls` (retrieved 2026-09-22)

---

## BUG-RS10-10 — Two components fail to render on Account and Vehicle pages for the Sales Representative (Low)

**Module:** Platform — Lightning record pages
**Status:** Open
**Applies to:** Persona-specific — Sales Representative; System Administrator unaffected

### Description

On both the Account and the Vehicle record pages, a Sales Representative sees two visible error messages where components should be: a red permissions error in place of the Tags component, and a raw technical error at the top of the page. They do not block any ALF-RS-10 task, but they appear on pages the representative uses constantly and they look like something is broken.

### Steps to Reproduce

1. Log in as the Sales Representative.
2. Open any Account — e.g. **DEMO RS10 Fleet – Qatar Foundation Fleet Services**.
3. Look at the top of the page body, and at the **Tags** panel on the left.
4. Open any Vehicle — e.g. **DEMO RS10 07 – Vehicle order status sync** — and look at the same two places (**Vehicle Interest Tags**).
5. Open the same two records as a System Administrator and compare.

### Expected Result

The page renders without errors for the persona the page is designed for.

### Actual Result

```
Error: Failed to get generated module for forceGenerated:flexCard_ServiceExcellenceGenericAlertCard__salesforce__1__false: ui.services.exceptions.NoAccessException: You don't have access to this record. Ask your administrator for help or to request access.
```

and, in the Tags component:

```
Looks like you don't have the right permissions to view this component. Contact your Salesforce admin for help.
```

Both appear on the Account page and the Vehicle page. Screenshots: `rs10-tc012-fleet-account-150-opportunities.png`, `rs10-tc004-vehicle-page-no-order-state.png`.

### Root Cause

**Not fully isolated.** The first is an OmniStudio FlexCard (`ServiceExcellenceGenericAlertCard`) that the persona lacks access to — most likely a missing OmniStudio permission or FlexCard access for `AF_PSG_Sales_Rep`. The second is a Tags/Topics component whose underlying permission the persona does not hold. Neither was traced further because neither affects ALF-RS-10 functionality.

### Proposed Solution

Either grant the persona access to the FlexCard and Topics, or remove both components from the Account and Vehicle Lightning pages for the profiles that cannot use them. Worth confirming whether the FlexCard is intended for this persona at all — it is a Service Excellence card on a Sales-facing page.

### Reference

- **BRD**, §7 Cross-Cutting 1 — persona-appropriate access and usability of the standard record pages.

### Evidence

- Records: Account `001FV00L3NRO3COYU1`, Vehicle `0vLFV0004wwVbQC2A0`
- Screenshots: `rs10-tc012-fleet-account-150-opportunities.png`, `rs10-tc004-vehicle-page-no-order-state.png`
- Harness: Lightning UI as QA SalesRep2

---

## BUG-RS10-11 — Amounts are displayed in AED while every Sales Order document and prompt says QAR (Medium)

**Module:** Platform — currency configuration
**Status:** Open
**Applies to:** General

### Description

Alfardan Automobiles is a Qatar business and every figure in this story is quoted in Qatari Riyals — the payment-confirmation prompt says QAR, the Sales Order contract says QAR. But the org itself is configured in **AED**: opportunity amounts display as "AED 500,000.00" on every record page and list view. The same number is labelled with two different currencies depending on where the user looks, and on a signed sale contract that is a commercial exposure.

### Steps to Reproduce

1. Log in as the Sales Representative and open **DEMO RS10 01 – Sales Order happy path**.
2. Read the **Amount** field in the highlights panel at the top of the record, and again on the **Details** tab — both read **AED 500,000.00**.
3. Click **▾ → Generate Sales Order** and read the figures on the confirmation screen — *"Invoice total: QAR 500,000 Received: QAR 500,000 Outstanding: QAR 0"*.
4. Open **DEMO RS10 06** → **Related** → **Notes & Attachments** → the Sales Order document → section 3 reads *"Total Purchase Price (QAR)"*.
5. For an administrator: Setup → **Company Information** shows the org's default currency.

### Expected Result

One currency throughout, and the correct one for a Qatar business.

### Actual Result

The record shows `AED 500,000.00`; the flow screen and the contract for the same amount both say `QAR`. Screenshots: `rs10-tc001-blocked-no-reservation-despite-reserved.png` (AED in the highlights panel) and `rs10-tc010-payment-confirmation-prompt.png` (QAR in the prompt).

### Root Cause

**Confirmed as an inconsistency; the intended value is a business decision.** The org's default currency renders as AED on all currency fields, and the org is single-currency (`CurrencyIsoCode` does not exist on any object, so there is no per-record currency to explain the difference). "QAR" is hard-coded as literal text in the flow screen `Screen_ConfirmPayment` of `AF_FL_Opp_GenerateSalesOrder`, in the `money()` output lines of `AF_SalesOrderService`, and in `AF_SalesOrderService.findBlocker()`'s outstanding-balance message. Neither reads the org or record currency.

### Proposed Solution

Set the org's default currency to QAR (the correct value for this business), then have the documents and flow screens render the currency from the field rather than as literal text, so the two can never diverge again. The same hard-coded "QAR" appears in `AF_ReservationContractService`, `AF_TransactionSummaryService` and the discount-approval messages and should be corrected together.

If AED is deliberate for some part of the group, the decision needs stating and the documents need to follow the record.

### Reference

- **BRD**, p. 52, §10.10 ALF-RS-10 Requirement Overview — the Sales Order is *"an internal document that succeeds the quotation stage and is stored against the opportunity"*; the quotation and payment figures it carries come from ALF-RS-06 and ALF-RS-09 and are quoted in QAR throughout the BRD.

### Evidence

- Records: Opportunity `006FV00Bh7usybEYEQ` (AED display), `006FV00Bh88Q9jgYEC` (QAR document)
- Screenshots: `rs10-tc001-blocked-no-reservation-despite-reserved.png`, `rs10-tc010-payment-confirmation-prompt.png`
- Harness: Lightning UI as QA SalesRep2; org confirmed single-currency via `sf data query`
