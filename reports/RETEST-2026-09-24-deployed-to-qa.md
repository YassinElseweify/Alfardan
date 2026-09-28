# Retest — LFRDN bugs in "DEPLOYED TO QA" (2026-09-24)

**Scope:** the 20 LFRDN bugs in status *DEPLOYED TO QA* on 24-Sep-2026 (671–674, 677–679, 685, 696–707).
**How:** Lightning UI as the Sales Representative (QA SalesRep2) on fresh deals built for the retest; admin only for setup, cashier stand-in payments, and control runs.
**Retest records:** QA RETEST R1 `006FV00BrFEI060YUD` (reservation, RES-00207), R2 `006FV00BrFEMCF2YUP` (Sales Order + handover HO-00057), R3 `006FV00BrFEQOO4YUP` (handover HO-00058, no Sales Order). Customer *QA RETEST Customer - Noor Al-Mannai*.
**Screenshots:** `screenshots/RETEST-2026-09-24/`

## Verdicts

| Ticket | Verdict | Evidence |
|---|---|---|
| LFRDN-671 Create Reservation fails for the rep | **Fixed** | Rep created RES-00207 (7-Day, 45,000) from Quote 00000213; Reserved, auto-approved; INVM-00107 created. `671-…` |
| LFRDN-672 Vehicle order status not shown; sync writes the wrong field | **Partially fixed** | Sync fixed: `AF_VehicleOrderStatusSync` now sets Inventory Status (In Transit → In Transit, In Stock-Arrived → In Stock) and Brand Sub-status. Still broken: *Vehicle Order State* and *Brand Sub-status* are not visible to the rep — they were added to the classic "Vehicle Layout", but the live page `Vehicle_Record_Page` is a Dynamic Forms page that does not include them. `672-…` |
| LFRDN-673 Rep reads every BU's opportunities (View All) | **Fixed** | View All = false on `AF_PSG_Sales_Rep`; DEMO RS10 09 (Automobiles, other owner) no longer readable. RS10 10 is visible through the rep's own Sports Motors sharing group (correct); RS10 08 is visible because the rep owns its Account (standard account-owner access). |
| LFRDN-674 Sales Order prints no make/model/year/chassis | **Partially fixed** | Sales Order on R2 prints Type *Ferrari*, Model *296 GTB*, Manufacturing Date, VIN, colours. *Model Year* and *Chassis No.* still "-": read from Vehicle `ModelYear` / `ChassisNumber`, which are blank on all 66 inventory vehicles. |
| LFRDN-677 Keyloop vehicle order status sync | **Not fixed** (closed by dev as unbuilt scope) | No Keyloop Named Credential, no callout, no scheduled job. Needs BA scoping; should not sit in DEPLOYED TO QA. |
| LFRDN-678 AED vs QAR | **Not fixed** (deferred by dev) | R2 Amount *AED 369,300.00*; Generate Sales Order screen *QAR 369,300*. `678-…` |
| LFRDN-679 Components fail on Account/Vehicle pages | **Fixed** | Account, Vehicle and Contact pages render for the rep with no module/permission errors. |
| LFRDN-685 Keyloop invoicing event | **Not fixed** (closed by dev as unbuilt scope) | 0 Invoice Summaries carry a Keyloop invoice reference; no integration. |
| LFRDN-696 Generate Sales Order fails for the rep | **Fixed** | *"Sales Order generated"* on R2 as the rep. `696-…` |
| LFRDN-697 Traffic/Insurance upload never ticks its checkbox | **Not fixed for the rep — new failure** | Rep uploads Traffic Form on HO-00057 → toast *"Upload failed — Operation failed due to fields being inaccessible on Sobject AF_Handover__c"*; row stays *Missing*, file left untagged (twice). Admin running the same service call: Insurance Form ticks. Cause: `AF_HandoverUploadSyncService` does `update as user`, and LFRDN-701 removed the rep's Edit on those checkboxes. `697-…` |
| LFRDN-698 Sold vehicle offered for reservation again | **Fixed going forward; old data not corrected** | R2's vehicle (Converted) is *Reserved* and absent from the Create Reservation picker; the original Ferrari Roma Blu Pozzi Blue is absent. Vehicles sold before the fix still read *Available* and are pickable: RS12-01, RS12-06, RS12-08 (all Closed Won), SF90 Grigio Silverstone Grey, 296 GTB In Transit. `698-…` |
| LFRDN-699 Delivery Note never generated | **Not fixed for the rep — new failure** | Rep runs Generate Documents on HO-00057 (date + location set) → five agreements created, then *"Something went wrong … System.DmlException: Operation failed due to fields being inaccessible on Sobject AF_Handover__c"*; no Delivery Note. Admin control: Delivery Note generates. Cause: `AF_HandoverDocumentService` does `update as user` on `AF_DeliveryNoteGenerated__c`, which LFRDN-701 made read-only for the rep. `699-…` |
| LFRDN-700 Completing a handover fails with a raw error | **Fixed** | Rep sets *Physically Signed* on the fully ticked HO-00057 → saved; R2 **Closed Won**, SO **Delivered**, no error. `700-704-…` |
| LFRDN-701 Rep can tick handover documents by hand | **Fixed — but breaks 697 and 699** | Rep's edit form no longer offers Delivery Note Generated / Traffic Form Uploaded / Insurance Form Uploaded. Side effect: the rep's own automation can no longer set them either, so **a rep cannot complete any handover without an admin**. `701-…` |
| LFRDN-702 Auto-approved reservation demands Approval Reference | **Fixed** | RES-00207 (Not Required) lists Customer ID, Payment Receipt, Quotation, Vehicle Stock / VIN — no Approval Reference. `702-…` |
| LFRDN-703 Contract block doesn't name missing documents | **Fixed** | *"Missing: Customer ID, Payment Receipt, Quotation, Vehicle Stock / VIN."* `703-…` |
| LFRDN-704 Delivered on deals with no Sales Order | **Fixed as specified** | HO-00058 completed on R3 (SO Not Generated) → SO stays *Not Generated*; R2 (SO Generated) → *Delivered*. Note: R3 still went **Closed Won with no Sales Order** — the Closed Won gate does not require one (BA question the dev flagged). |
| LFRDN-705 Reservation Contract has no trim | **Fixed** | RES-00207 contract: *Trim: Assetto Fiorano Package*. |
| LFRDN-706 Handover created without Vehicle/Contact/Invoice | **Partially fixed, with a regression** | HO-00057/58: Vehicle ✓, Invoice Summary ✓, **Contact blank** (flow maps `Opportunity.ContactId`, which the retail cycle never fills — the customer is in `AF_PrimaryBrandContact__c`), and **Account now blank**: every Handover created up to 11:02 UTC has an Account, every one since the redeploy (~12:08, HO-00056/57/58) has none. The dev's own proof record HO-00056 (on DEMO RS12 H01) also has no Contact or Account. |
| LFRDN-707 Showroom Manager can't access Closed Lost approval | **Fixed** (test-data fix) | QA SalesRep2's Manager is now QA SalesBrandManager2. Rep submitted Request Closure on R1 → routed to QA SalesBrandManager2, who can read the deal and approved it → R1 **Closed Lost**. QA ShowroomManager2 → SalesBrandManager2 still crosses branches (dev flagged). |

**Totals:** Fixed 11 (671, 673, 679, 696, 700, 701, 702, 703, 704, 705, 707 — 701 with a side effect) · Partially fixed 4 (672, 674, 698, 706) · Not fixed 5 (677, 678, 685, 697, 699).

## Side effects on today's other work

- **Handover completion now needs an admin.** With LFRDN-701 in place and 697/699 saving as the user, the rep cannot register the Traffic Form, Insurance Form or Delivery Note — the three checkboxes the checklist needs. Fix direction: run the two flag updates in system mode (`update as system` / `without sharing` + `AccessLevel.SYSTEM_MODE`) so the rep's automation can set what the rep cannot type.
- **DEMO RS12 H01 (hands-on record)** was moved to Take the Keys by the developer while verifying LFRDN-706 (HO-00056). Start its walkthrough from the Handover.
- **ALF-RS-13 draft BUG-RS13-01:** the rep's Manager is now QA SalesBrandManager2 (LFRDN-707), so the "approver can't see the deal" symptom no longer reproduces for this rep. The draft needs rewording before filing.
