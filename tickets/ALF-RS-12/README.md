# [ALF-RS-12] Vehicle Handover Checklist and Delivery — bug tickets

**Found during:** ALF-RS-12 story test, 2026-09-24
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/ALF-RS-12-report.md`
**Screenshots:** `screenshots/ALF-RS-12/`
**Status:** **Filed in Jira 2026-09-24 — LFRDN-708 to LFRDN-717** (Bug, assignee Yassin, parent LFRDN-317, *relates to* LFRDN-342).

> **Every ticket below is reproducible in the Lightning UI.** Log in as
> `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!` (dismiss *Change Your Password*
> with **Cancel**), open the **Automotive** app, and use the records named in each ticket.
> BUG-RS12-06 also needs `alfardan.qa.showroommanager2@alfardan.com.qa.qa` / `Arcsen@2026!`.
> API calls and SOQL appear only under **Root Cause**, where a developer needs them.

Numbering continues from the four ALF-RS-12 tickets already filed from the demo cycle
(BUG-RS12-01 → LFRDN-697, BUG-RS12-02 → LFRDN-699, BUG-RS12-03 → LFRDN-704, BUG-RS12-04 →
LFRDN-706). Each is raised in **LFRDN** as a Bug, assigned to **Yassin**, parent
**LFRDN-317 (Build)**, labels `ALF-RS-12` / `QA` / `Retail-Sales` (+ `Security` on BUG-RS12-06),
linked *relates to* the story **LFRDN-342**.

## Summary

The handover can be started, documented and closed — but not in a way that proves anything.
The five agreements the customer signs **do not name the car** and cannot be regenerated once
the data is corrected (BUG-RS12-05). Those agreements, and the handover itself, are **open to
every business unit** (BUG-RS12-06). A handover shows **Completed** before the customer has
signed, or with nothing done at all (BUG-RS12-07), and customer sign-off is a picklist value that
needs **no signed document** behind it (BUG-RS12-08). Nothing generates the documents when the
deal reaches the handover stage, and the rep cannot generate a single document on its own — only
all of them at once (BUG-RS12-09). The follow-up task goes to the rep rather than the CRM queue
(BUG-RS12-10), a handover can be saved with no handover date (BUG-RS12-11), and nothing records who
confirmed the delivery (BUG-RS12-12). The rep is never prompted for the Traffic and Insurance
Forms (BUG-RS12-13), and the Vehicle Repair Disclaimer has no way to carry the vehicle's repair
remarks (BUG-RS12-14).

Still reproducing from earlier filings, and re-confirmed in this run: **LFRDN-697** (uploaded
Traffic/Insurance Forms never tick their checkboxes), **LFRDN-699** (Delivery Note never
generated), **LFRDN-701** (document checkboxes can be ticked by hand), **LFRDN-706** (handover
created without Vehicle/Contact/Invoice — root cause needs correcting, see the report §4), and
**LFRDN-700** (setting *Completed* on a signed handover with the Traffic Form flag fails with the raw
*"Handover Auto Close Won" process failed* error — HO-00039, as System Administrator).
**LFRDN-696 is fixed** — the Sales Representative generated a Sales Order in the UI.

| ID | Jira | Title | Priority | Affects |
|---|---|---|---|---|
| BUG-RS12-05 | LFRDN-708 | The handover agreements the customer signs do not name the vehicle, and cannot be regenerated | Highest | General |
| BUG-RS12-06 | LFRDN-709 | Any business unit can open, edit and download another unit's handover documents, invoices and payments | Highest | General — every persona with Handover access (Sales Rep, Sales Manager, Showroom Manager groups) |
| BUG-RS12-07 | LFRDN-710 | A handover can show Completed before the customer signs, or with nothing done | High | General |
| BUG-RS12-08 | LFRDN-711 | Customer sign-off is recorded without any signed document, and the deal closes on it | High | General |
| BUG-RS12-09 | LFRDN-712 | Handover documents are not generated at the handover stage, and the rep cannot generate a single document | Medium | General |
| BUG-RS12-10 | LFRDN-713 | The post-handover follow-up task goes to the rep, not the CRM queue, and names no customer | Medium | General |
| BUG-RS12-11 | LFRDN-714 | A handover can be saved with no handover date | Medium | General |
| BUG-RS12-12 | LFRDN-715 | Nothing records who confirmed the delivery or when | Low | General |
| BUG-RS12-13 | LFRDN-716 | The rep is not prompted to upload the Traffic and Insurance Forms after a fully paid Sales Order | Medium | General |
| BUG-RS12-14 | LFRDN-717 | The Vehicle Repair Disclaimer cannot carry the vehicle's repair remarks | Medium | General |

### Screenshots to attach in Jira

| Ticket | Jira | Attach (all in `screenshots/ALF-RS-12/`) |
|---|---|---|
| BUG-RS12-05 | LFRDN-708 | `12-alsadd-manager-previews-customer-agreement.png`, `04-generate-documents-second-run.png` |
| BUG-RS12-06 | LFRDN-709 | `10-alsadd-manager-cannot-open-opportunity.png`, `11-alsadd-manager-opens-sportsmotors-handover.png`, `12-alsadd-manager-previews-customer-agreement.png` |
| BUG-RS12-07 | LFRDN-710 | `13-handover-completed-with-nothing-done.png`, `14-followup-task-on-unsigned-handover.png` |
| BUG-RS12-08 | LFRDN-711 | `06-handover-signed-still-pending.png`, `07-opportunity-closed-won-after-hand-ticks.png` |
| BUG-RS12-09 | LFRDN-712 | `16-generate-documents-button-location.png`, `03-generate-documents-result.png`, `05-required-documents-after-uploads.png` |
| BUG-RS12-10 | LFRDN-713 | `14-followup-task-on-unsigned-handover.png` |
| BUG-RS12-11 | LFRDN-714 | `13-handover-completed-with-nothing-done.png` |
| BUG-RS12-12 | LFRDN-715 | `11-alsadd-manager-opens-sportsmotors-handover.png` |
| BUG-RS12-13 | LFRDN-716 | `01-sales-order-generated-as-rep.png` |
| BUG-RS12-14 | LFRDN-717 | `15-repair-disclaimer-no-remarks.png` |

---

## BUG-RS12-05 (LFRDN-708) — The handover agreements the customer signs do not name the vehicle, and cannot be regenerated (Highest)

**Module:** Retail Sales — Vehicle Handover documents
**Applies to:** General — reproduced as the Sales Representative and as System Administrator (HO-00043's documents were generated by an administrator and print the same blanks), and on the fully UI-built deal DEMO Cycle 01 (HO-00037, 23-Sep): *Vehicle: - VIN: -*.

### Description

**Generate Documents** produces the five agreements the customer signs at handover — Vehicle
Sale Agreement, Warranty, Service Contract, Vehicle Repair Disclaimer and Buyer
Acknowledgement. Every one prints **Vehicle: -** and **VIN: -**, and the customer's email and
phone as **-**. A customer is asked to sign a sale agreement that does not say which car is being
sold. If the rep then fills in the vehicle, date and location and runs Generate Documents again,
nothing is regenerated — the screen still says *"Handover documents generated"* — so the blank
agreements are the only ones the system will ever produce for that handover.

### Steps to Reproduce

1. As the Sales Representative open **DEMO RS12 01 - Handover happy path to Delivered and Closed
   Won** (`006FV00Bqe0PU3wYEG`) — or any Opportunity at **Take the Keys** — and open its Handover
   (**HO-00046**, `a0SFV001Pteoktw2IA`) from the *Handover* field.
2. Handover header, top right next to **Edit** → **Generate Documents** → **Finish**.
3. **Related** → *Notes & Attachments* → open **Vehicle Sale Agreement - HO-00046**.
4. **Edit** → Vehicle **Ferrari 296 GTB - Rosso Scuderia RS12-01**, Handover Date **24/09/2026
   2:30 PM**, Handover Location **Doha Showroom - Sports Motors** → **Save**.
5. Handover header, top right next to **Edit** → **Generate Documents** → read the message → **Finish**. Re-open the agreement.

### Expected Result

Each agreement names the customer, the vehicle (make, model, VIN) and the handover date and
location. When those details change, the rep can regenerate the agreements before the customer
signs.

### Actual Result

Step 3:

> Vehicle Sale Agreement
> Opportunity: DEMO RS12 01 - Handover happy path to Delivered and Closed Won
> Brand: Ferrari   Business Unit: Alfardan Sports Motors
> Customer: DEMO RS12 Customer - Maryam Al-Kaabi
> Email: -   Phone: -
> Vehicle: -   VIN: -
> …
> Handover: -   Location: -

Step 5 shows *"Handover documents generated — Every not-yet-complete document in the standard
sequence was generated as a PDF and attached below."* No file is created; the five PDFs keep
their 08:37 creation time and their blank vehicle, VIN and date. Same result on HO-00043, whose
documents were generated as System Administrator.

### Root Cause

**Confirmed from the code.** `AF_HandoverDocumentService.buildDocumentHtml` reads the vehicle,
VIN and contact from the **Handover's own** `AF_Vehicle__c` and `AF_Contact__c`, which
`AF_FL_Opp_CreateHandoverOnTakeTheKeys` never fills from the deal (LFRDN-706): it copies
`Opportunity.ContactId`, which the retail cycle leaves blank, and does not map the vehicle at
all. The Opportunity itself holds `AF_SelectedVehicle__c` and `AF_PrimaryBrandContact__c`.

Regeneration is blocked by the idempotency guard: `findBlocker` returns *"… has already been
generated."* for any document whose `…Complete__c` flag is true, and the only override,
`bypassGates`, is not exposed by the Quick Action. `AF_FL_Handover_GenerateDocuments` shows its
fixed success screen whatever the per-document results were.

### Proposed Solution

1. In `buildDocumentHtml`, fall back to `AF_Opportunity__r.AF_SelectedVehicle__c` and
   `AF_Opportunity__r.AF_PrimaryBrandContact__c` when the Handover's own lookups are blank — and
   fix the creation flow as proposed in LFRDN-706.
2. Block generation (with a message naming the missing field) while the vehicle is blank.
3. Offer a **Regenerate** option for documents not yet signed, and have the flow's result screen
   list what was generated and what was skipped and why.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR4 — *"The system should support automated generation of the following handover documents in the agreed sequence at the handover stage: Vehicle Sale Agreement, Warranty Agreement, Service Contract Agreement, Vehicle Repair Disclaimer, and Buyer Acknowledgement. Each document requires physical customer signature…"*
- **SD** §10 Handover, Delivery, Cancellation & Credit Note, p.75, Exception handling — *"Missed delivery schedules re-plan without regenerating signed agreements"* — i.e. regeneration is expected to be possible before signature.

---

## BUG-RS12-06 (LFRDN-709) — Any business unit can open, edit and download another unit's handover documents, invoices and payments (Highest)

**Module:** Retail Sales — Vehicle Handover / Security model
**Applies to:** General — every persona holding Handover object access. Reproduced as the
Showroom Manager of **Alsadd (Automobiles)** against a **Sports Motors** deal; the Sales Rep, Sales
Manager and Showroom Manager permission-set groups all grant Read/Create/Edit on Handover.

### Description

The Alsadd (Automobiles) Showroom Manager cannot open a Sports Motors Opportunity — correctly.
But the same person can open that deal's **Handover**, edit it, and open, download or share the
customer's Vehicle Sale Agreement and the other handover documents. In the API the same user
sees all 30 Handovers in the org. Customer contracts are readable across brands and business
units — and so are the deal's **Invoice Summary, Payments and Reservation**, which the same user
can also edit.

### Steps to Reproduce

1. Log in as `alfardan.qa.showroommanager2@alfardan.com.qa.qa` (role *Showroom Manager - Alsadd*,
   under *Sales Manager - Automobiles*).
2. Open **DEMO RS12 07 - Business-unit access to the handover** (`006FV00Bqe0oew8YEA`, owner QA
   SalesRep2, Alfardan Sports Motors) — result: *Unable to load*.
3. Open its Handover **HO-00043** (`a0SFV001PruXJoK2IW`) — search or direct link.
4. **Related** → *Notes & Attachments* → click **Vehicle Sale Agreement - HO-00043**.
5. **Edit** → change *Handover Location* → **Save**.

### Expected Result

A user outside the deal's business unit and role hierarchy cannot see the Handover or its files,
exactly as they cannot see the Opportunity.

### Actual Result

Step 2 is refused (*Unable to load*). Steps 3–5 succeed: the Handover opens with **Edit** and
**Generate Documents** available, each agreement has a **Remove** button in *Required Documents*,
the PDF previews with **Download** and **Share**, and the edit saves. Through the REST API as the
same user: `SELECT COUNT() FROM AF_Handover__c` → **30**; `GET …/ContentVersion/{id}/VersionData`
returns the PDF; `PATCH` on the Handover → **HTTP 204**. Also confirmed for the Sports Motors Sales
Manager (in the chain — expected). CRM Agent and Used Car Team have no Handover access.

The same user, through the API: `SELECT COUNT()` → **66** Invoice Summaries, **35** Vehicle
Reservations, **50** Payments org-wide; on DEMO RS12 07 reads **INVM-00087** (369,300, Fully Paid),
**PAY-00057** (payee *DEMO RS12 Customer - Maryam Al-Kaabi*, Bank LPO attached and listable) and
**RES-00185**, and a no-change `PATCH` on each returns **HTTP 204** (PAY-00057 *Last Modified By*:
QA ShowroomManager2, 10:28 UTC).

### Root Cause

**Confirmed from the metadata and org settings.** `AF_Handover__c` is deployed with
`<sharingModel>ReadWrite</sharingModel>`; `EntityDefinition.InternalSharingModel` = **ReadWrite**
(Public Read/Write), while Opportunity is **Private**. Files attached to a Handover inherit the
Handover's access. The same org-wide default is set on `AF_InvoiceSummary__c`,
`AF_VehicleReservation__c` and `AF_Payment__c`.

### Proposed Solution

1. Make `AF_Handover__c` **Controlled by Parent** (master-detail to Opportunity) or **Private** with
   the same sharing rules the Opportunity uses.
2. Apply the same to Invoice Summary, Vehicle Reservation and Payment — confirmed readable and
   editable across business units above.

### Reference

- **BRD** §7 Cross-Cutting Requirements, p.10, item 1 — *"Customer profile visibility is shared at account level, while opportunities, cases, service appointments, quotations, and other transactional records remain segregated by business unit, brand and department as per the security model."*
- **SD** §10 Handover, Delivery, Cancellation & Credit Note, p.75, Security and access impact — *"Handover and credit-note records are segregated to the deal's business unit."*

---

## BUG-RS12-07 (LFRDN-710) — A handover can show Completed before the customer signs, or with nothing done (High)

**Module:** Retail Sales — Vehicle Handover / Delivery confirmation
**Applies to:** General — also reproduced as System Administrator (HO-00041 set to *Completed*, unsigned and incomplete: saved).

### Description

Handover Status is what tells everyone the car has been delivered. It turns **Completed** as soon
as the eight document checkboxes are ticked, whether or not the customer has signed. A rep can
also simply pick **Completed** on a handover with no documents, no date and no signature, and it
saves. Two things follow: the customer-experience **follow-up task is created** for a handover
that never happened, and **Generate Documents disappears** from the handover, so its documents
can no longer be produced.

### Steps to Reproduce

1. **Checklist without signature** — Handover **HO-00038** on **DEMO RS12 02 - Checklist complete,
   customer sign-off still Pending** (`006FV00Bqe0TgCyYEK`): **Edit** → tick all eight
   *Required Documents Checklist* boxes, set Handover Date **20/09/2026 10:00**, leave *Customer
   Sign-Off* empty → **Save**. Open the Opportunity → **Activity**.
2. **Nothing done** — Handover **HO-00040** on **DEMO RS12 04 - Handover date and time
   boundaries** (`006FV00Bqe0c4V2YEI`), no documents, no date, no sign-off: **Edit** → *Handover
   Status* **Completed** → **Save**. Look at the header actions.

### Expected Result

A handover cannot be Completed until the customer's sign-off is recorded and the checklist is
complete; no follow-up task is created for an unsigned or undelivered handover.

### Actual Result

Step 1: *Handover Status* **Completed**, *Customer Sign-Off* blank, *Closed Won Gate Passed?*
unticked; the Opportunity stays at Take the Keys with Sales Order **Generated** — and a Task
**Post-Handover Customer Experience Follow-Up** appears on the Opportunity (created 08:33:47 UTC,
owner QA SalesRep2).
Step 2: *Handover "HO-00040" was saved.* Status **Completed**, *Checklist Complete?* unticked; the
header now shows only **Edit** — **Generate Documents** is gone.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Handover_UpdateChecklistGate` (before-save) sets
`AF_Status__c = 'Completed'` when `AF_Formula_ChecklistComplete` is true — the eight flags only;
sign-off is checked only in `AF_Formula_ClosedWonGatePassed`. `AF_Handover__c` has **no validation
rules**, so a manual *Completed* is also accepted. `AF_FL_Handover_FollowUpTask` creates the Task
when `AF_Status__c = 'Completed'` at its scheduled time, with no sign-off condition. The Generate
Documents action's visibility rule on `Handover_Record_Page` allows only *Pending* / *In Progress*.

### Proposed Solution

1. Set *Completed* only when `AF_ClosedWonGatePassed__c` is true (checklist **and** sign-off).
2. Add a validation rule: `ISPICKVAL(AF_Status__c,'Completed') && NOT(AF_ClosedWonGatePassed__c)`.
3. Condition the follow-up task on `AF_ClosedWonGatePassed__c`, not on Status alone.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR2 — *"The system should require digital or physical customer sign-off on the delivery / handover documents before the delivery can be confirmed as complete."*
- **BRD** §10.12 ALF-RS-12, p.56, FR9 — *"The system should generate a CRM follow-up task two days after confirmed vehicle handover for customer experience follow-up."*

---

## BUG-RS12-08 (LFRDN-711) — Customer sign-off is recorded without any signed document, and the deal closes on it (High)

**Module:** Retail Sales — Vehicle Handover / Customer sign-off
**Applies to:** General — the Sales Representative can do it in the UI and through the API.

### Description

Customer sign-off is a dropdown on the handover: *Pending* or *Physically Signed*. Choosing
*Physically Signed* requires nothing — no scan of the signed agreements, no signed Delivery Note.
Together with LFRDN-701 (document checkboxes tickable by hand), a rep can take a deal to **Closed
Won** with the order marked **Delivered** while the handover holds **no file at all**.

### Steps to Reproduce

1. **UI** — Handover **HO-00046** (DEMO RS12 01): **Edit** → *Customer Sign-Off* **Physically
   Signed** → **Save**. No signed document has been uploaded anywhere.
2. **API** (the same rep's session) — Handover **HO-00044** on **DEMO RS12 08 - Direct API edit of
   sign-off and document flags** (`006FV00Bqe0sr5AYEQ`), with **zero** files attached:
   `PATCH /services/data/v68.0/sobjects/AF_Handover__c/a0SFV001Ps1IuNY2I0` setting the eight
   checklist flags true, `AF_CustomerSignOff__c = "Physically Signed"`, date and location.
3. Read the Opportunity.

### Expected Result

*Physically Signed* can only be recorded once the signed document is uploaded to the handover,
and delivery cannot be confirmed without it.

### Actual Result

Step 1 saves (*Handover "HO-00046" was saved.*). Step 2 returns **HTTP 204**; the Opportunity is
**Closed Won**, *Sales Order Status* **Delivered**, *Delivery Confirmation* ✓, Close Date
24/09/2026. `SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = 'a0SFV001Ps1IuNY2I0'`
→ **0**.

### Root Cause

**Confirmed from the metadata.** `AF_CustomerSignOff__c` is a free picklist the rep can edit
(`AF_PSG_Sales_Rep` has Edit); no validation rule, flow or Apex checks for a signed file.
`AF_FL_Handover_UpdateChecklistGate` treats the picklist value as proof of signature, and
`AF_Opportunity_ClosedWonPaymentGate` / `AF_VR_Opp_ClosedWonGate` read only the flags.

### Proposed Solution

1. Add a *Signed Handover Documents* (or *Signed Delivery Note*) row to the Handover's
   `AF_Document__mdt` checklist and set *Physically Signed* automatically when it is uploaded — or
   block the picklist value by validation unless such a tagged file exists.
2. Remove Edit on `AF_CustomerSignOff__c` from the business groups once it is system-set.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR2 — *"The system should require digital or physical customer sign-off on the delivery / handover documents before the delivery can be confirmed as complete."*
- **BRD** §10.12 ALF-RS-12, p.56, AC2 — *"Given the customer signs the delivery document, When the signature is captured, Then the handover is confirmed and the sales order status updates to Delivered."*
- **SD** §10, p.74, Data design — *"All generated documents and uploads live as Files on the handover/opportunity; retention is total (audit requirement)."*

---

## BUG-RS12-09 (LFRDN-712) — Handover documents are not generated at the handover stage, and the rep cannot generate a single document (Medium)

**Module:** Retail Sales — Vehicle Handover documents
**Applies to:** General — the Handover page and the Generate Documents screen are the same for every persona with Handover access.

### Description

The agreed design has two parts. The handover documents are generated **automatically when the
deal reaches the handover stage**, and before that the rep can **generate any single document on
its own**, which the automatic run then skips so nothing is produced twice.

Neither part is available. Moving the deal to *Take the Keys* creates the Handover but no
documents — they appear only when the rep presses **Generate Documents**. That button has no
choice of document: it always produces every agreement not yet marked complete. The *Required
Documents* panel offers only **Upload Files** on each row. The rep therefore cannot prepare, for
example, the Warranty Agreement early and leave the rest for the handover.

### Steps to Reproduce

1. As the Sales Representative open **DEMO RS12 01 - Handover happy path to Delivered and Closed
   Won** (`006FV00Bqe0PU3wYEG`) at **Commit** — or any fully paid deal after **Generate Sales
   Order** — and **Path → Mark Stage as Complete** to *Take the Keys*.
2. Open the new Handover from the *Handover* field → **Related** → *Notes & Attachments*.
3. **Related** → *Required Documents* — look at the actions on each agreement row.
4. Handover header, top right next to **Edit** → **Generate Documents**.

### Expected Result

Step 2: the five handover agreements have been generated for the deal, in the agreed order,
without any further action. Before the handover stage (or before the automatic run), the rep can
choose one agreement and generate just that one; the automatic run then produces only the others.

### Actual Result

Step 2: *Notes & Attachments* is empty. **HO-00039** (DEMO RS12 03), created this way on 24-Sep and still *Pending*, holds **0 files** — *Notes & Attachments (0)*. Step 3: each row shows only **Upload Files**. Step 4: the screen offers no choice; it
generates every not-yet-complete document and reports *"Handover documents generated — Every
not-yet-complete document in the standard sequence was generated as a PDF…"*.

### Root Cause

**Confirmed from the code and flow metadata.** `AF_FL_Opp_CreateHandoverOnTakeTheKeys` creates the
Handover record only; no flow or trigger calls `AF_HandoverDocumentService` at the handover stage.
The only caller is the screen flow `AF_FL_Handover_GenerateDocuments` behind the **Generate
Documents** Quick Action. The service already supports single-document generation — its
`documentName` input generates one document and ticks that document's `…Complete__c` flag, and the
full run skips any document whose flag is true (`findBlocker` → `isAlreadyComplete`). But the
screen flow never passes `documentName` for an agreement (only for the Delivery Note), and no
other component exposes it.

### Proposed Solution

1. Call `AF_HandoverDocumentService` with a blank `documentName` from
   `AF_FL_Opp_CreateHandoverOnTakeTheKeys` (or a follow-on after-save flow on Handover create), so
   the five agreements are generated at the handover stage.
2. Add a document picker to `AF_FL_Handover_GenerateDocuments` (the five agreements plus *All
   remaining*), or a **Generate** button on each agreement row of the *Required Documents* panel,
   passing `documentName`. The existing completion flags already keep the automatic run from
   duplicating what the rep generated.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR4 — *"The system should support automated generation of the following handover documents in the agreed sequence at the handover stage: Vehicle Sale Agreement, Warranty Agreement, Service Contract Agreement, Vehicle Repair Disclaimer, and Buyer Acknowledgement."*
- **BRD** §10.12 ALF-RS-12, p.55, FR5 — *"The system should provide a manual document generation option allowing the Sales Representative to generate any individual handover document outside of the standard automation sequence at their discretion. Documents generated manually prior to the handover stage will be excluded from the automated trigger at handover to prevent duplication."*
- **Alfardan Document Register** (client clarification sheet, received 24-Sep-2026), document list, row *Warranty Agreement*, column *Questions* — *"NOTE: Manual override can be placed to generate any of the documents at earlier stages of the handover. Generated documents will be eliminated in the original automation trigger during the handover stage."*

---

## BUG-RS12-10 (LFRDN-713) — The post-handover follow-up task goes to the rep, not the CRM queue, and names no customer (Medium)

**Module:** Retail Sales — Post-handover customer experience
**Applies to:** General.

### Description

Two days after the handover date the system creates a **Post-Handover Customer Experience
Follow-Up** task — at the right time and only once. But it is assigned to the sales rep who owns
the handover, not placed in the CRM team's queue, and its *Name* (contact) is empty, so whoever
picks it up has to look up who to call.

### Steps to Reproduce

1. Handover **HO-00042** on **DEMO RS12 06 - Post-handover follow-up task** (`006FV00Bqe0kSn6YEE`):
   complete the handover with *Handover Date* **21/09/2026 10:00** (more than two days ago, so the
   scheduled path fires at once).
2. Wait one minute → Opportunity → **Activity**, or
   `SELECT Owner.Name, Owner.Type, WhoId FROM Task WHERE Subject = 'Post-Handover Customer Experience Follow-Up'`.

### Expected Result

One task, in the CRM queue for customer experience outreach, naming the customer contact.

### Actual Result

One task (08:33:47 UTC), **Owner QA SalesRep2 (User)**, **WhoId blank**, ActivityDate 24/09/2026.
No duplicate after re-saving the handover or unticking *Follow-Up Task Created?* — that part works.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Handover_FollowUpTask` → `Create_Follow_Up_Task` sets
`OwnerId = $Record.OwnerId` and `WhoId = $Record.AF_Contact__c` (blank on every auto-created
Handover, LFRDN-706). No CRM queue exists in its logic.

### Proposed Solution

Assign the task to the CRM customer-experience queue (per business unit, from custom metadata),
and set `WhoId` from `AF_Opportunity__r.AF_PrimaryBrandContact__c` when the Handover contact is
blank.

### Reference

- **BRD** §10.12 ALF-RS-12, p.56, AC3 — *"Given the handover is completed, When the CRM trigger fires, Then a follow-up task is created in the CRM queue for customer experience outreach."*

---

## BUG-RS12-11 (LFRDN-714) — A handover can be saved with no handover date (Medium)

**Module:** Retail Sales — Vehicle Handover checklist
**Applies to:** General.

### Description

The handover date is the only record of when the car was delivered, and it starts the two-day
follow-up clock and gates the Delivery Note. It is optional: a handover can be saved — including
as **Completed** — with the date left blank.

### Steps to Reproduce

1. As the Sales Representative open Handover **HO-00040** on **DEMO RS12 04 - Handover date and
   time boundaries** (`006FV00Bqe0c4V2YEI`).
2. **Edit** → clear *Handover Date* → set *Handover Status* **Completed** → **Save**.

### Expected Result

The save is refused with a message asking for the handover date, once the handover is in progress
or completed.

### Actual Result

*Handover "HO-00040" was saved.* Status **Completed**, *Handover Date* blank.

### Root Cause

**Confirmed from the metadata.** `AF_HandoverDate__c` is an optional DateTime and `AF_Handover__c`
has no validation rules.

### Proposed Solution

Validation rule on `AF_Handover__c`: `AND(NOT(ISPICKVAL(AF_Status__c, 'Pending')), ISBLANK(AF_HandoverDate__c))`
→ *"Enter the handover date before progressing or completing the handover."*

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR1 — *"The system should support a vehicle handover checklist capturing date, time, location, and required handover items."*

---

## BUG-RS12-12 (LFRDN-715) — Nothing records who confirmed the delivery or when (Low)

**Module:** Retail Sales — Vehicle Handover / Audit
**Applies to:** General.

### Description

History tracking is switched on for the Handover, but no field is tracked. The *Handover
History* list shows only *Created.* — there is no record of who changed the status to Completed,
who recorded the customer's signature, or who ticked each document as done.

### Steps to Reproduce

Open Handover **HO-00046** (DEMO RS12 01), which went through sign-off, three manual flag changes
and completion. **Related** → *Handover History*.

### Expected Result

Status, Customer Sign-Off, Handover Date and each checklist flag are tracked, showing the user and
time of every change.

### Actual Result

One row: *Created.* by QA SalesRep2. None of the later changes appear.

### Root Cause

**Confirmed from the metadata.** `AF_Handover__c.object-meta.xml` has `enableHistory = true`; none
of its 20 field files has `trackHistory = true`.

### Proposed Solution

Track `AF_Status__c`, `AF_CustomerSignOff__c`, `AF_HandoverDate__c`, `AF_Location__c` and the eight
checklist flags.

### Reference

- **SD** §10, p.74, Data design — *"…retention is total (audit requirement)."*
- **BRD** §10.11 ALF-RS-11, p.53, FR1 — *"…an Opportunity cannot be set to Closed Won until the agreed business conditions are met, including payment, registration, and delivery confirmation."* — the delivery confirmation that closes the deal is not attributable.

---

## BUG-RS12-13 (LFRDN-716) — The rep is not prompted to upload the Traffic and Insurance Forms after a fully paid Sales Order (Medium)

**Module:** Retail Sales — Vehicle Handover documents / Sales Order
**Applies to:** General.

### Description

Once the Sales Order is generated with full payment, the rep should be prompted to upload the
customer's Traffic Form (for registration) and Insurance Form. Nothing prompts them. Generate
Sales Order ends on its own success screen, the Opportunity shows no reminder, task or
notification, and the forms only surface later as two *Missing* rows in the Handover's *Required
Documents* panel — a record that does not exist until the deal reaches *Take the Keys*.

### Steps to Reproduce

1. As the Sales Representative open **DEMO RS12 01 - Handover happy path to Delivered and Closed
   Won** (`006FV00Bqe0PU3wYEG`) at **Commit**, invoice **INVM-00081 Fully Paid**.
2. **Show more actions ▾ → Generate Sales Order** → *Yes, full payment has been collected* →
   **Next** → **Finish**.
3. Look at the Opportunity: highlights, *Activity*, notifications, related lists.

### Expected Result

After step 2 the rep is prompted to upload the Traffic Form and the Insurance Form (for example a
screen step in Generate Sales Order, or a task on the Opportunity), and the upload place is
reachable from the Opportunity.

### Actual Result

Step 2 ends with *"Sales Order generated — Find it under Notes & Attachments"*. Step 3: no prompt,
task or notification about either form. The forms can only be uploaded on the Handover, after
*Take the Keys*.

### Root Cause

**Confirmed from the code and flow metadata.** Neither `AF_SalesOrderService` nor the Generate
Sales Order action has a step for the two forms. The only components that reference them read or
set the Handover checklist flags — `AF_FL_Handover_UpdateChecklistGate`,
`AF_FL_Handover_SyncOpportunityGate`, `AF_HandoverUploadSyncService` and the Closed Won payment
gate (`AF_FL_Opp_ClosedWonPaymentGate` / `AF_Opportunity_ClosedWonPaymentGate`). None creates a
prompt, task or notification.

### Proposed Solution

1. Add a final screen to Generate Sales Order asking for both uploads (skippable), and create an
   Opportunity task *"Upload Traffic Form and Insurance Form"* for the rep when either is still
   missing.
2. Allow the two uploads on the Opportunity and carry them to the Handover when it is created, or
   show the Handover's *Required Documents* rows on the Opportunity.

### Reference

- **BRD** §10.12 ALF-RS-12, p.55, FR6 — *"Following Sales Order generation with full payment confirmed, the system should prompt the Sales Representative to upload the completed Traffic Form as an attachment against the opportunity."* FR7 (p.55–56) says the same for the Insurance Form.
- **Alfardan Document Register** (client clarification sheet, received 24-Sep-2026), document list, rows *Traffic Form* and *Insurance Form*, column *Clarification* — *"After Sales order is generated with full payment. Prompt required."*

---

## BUG-RS12-14 (LFRDN-717) — The Vehicle Repair Disclaimer cannot carry the vehicle's repair remarks (Medium)

**Module:** Retail Sales — Vehicle Handover documents
**Applies to:** General.

### Description

The Vehicle Repair Disclaimer exists to record what the customer was told about repairs done to
the car. The generated disclaimer is the same fixed sentence for every vehicle — *"…has been
informed of the vehicle's pre-delivery inspection and repair history, where applicable"* — and
there is nowhere to enter the remarks it should state: no remarks field on the Handover, the
Vehicle or the Opportunity. The customer signs a disclaimer that does not say what was repaired.

### Steps to Reproduce

1. As the Sales Representative open Handover **HO-00046** (DEMO RS12 01) → **Related** → *Notes &
   Attachments* → **Vehicle Repair Disclaimer - HO-00046**.
2. **Edit** the Handover, and open its Vehicle — look for a field to record repair remarks.

### Expected Result

The rep can record repair remarks for the vehicle, and the disclaimer prints them (or states that
there are none).

### Actual Result

Step 1: the disclaimer shows the standard sentence only, with no remarks section. Step 2: no
remarks field on either record.

### Root Cause

**Confirmed from the code and object metadata.** `AF_HandoverDocumentService.bodyFor('Vehicle Repair
Disclaimer')` returns a fixed string. `AF_Handover__c`, `Vehicle` and `Opportunity` have no
remarks, repair or damage field (object describe, 24-Sep).

### Proposed Solution

Add a long-text *Repair Remarks* field (on the Handover, or on the Vehicle if remarks belong to the
car), editable by the rep before generation, and print it in the disclaimer body — *"No repair
remarks"* when blank.

### Reference

- **Alfardan Document Register** (client clarification sheet, received 24-Sep-2026), document list, row *Vehicle Repair Disclaimer*, column *Rule* — *"Mention remarks if available"*.
- **BRD** §10.12 ALF-RS-12, p.55, FR4 — lists the Vehicle Repair Disclaimer among the handover documents that require physical customer signature.
