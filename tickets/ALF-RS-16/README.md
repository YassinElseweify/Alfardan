# [ALF-RS-16] Internal Requisition Form and PDI Management — bug tickets

**Found during:** ALF-RS-16 story test, 2026-09-26
**Org:** `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
**Report:** `reports/ALF-RS-16-report.md`
**Screenshots:** `screenshots/ALF-RS-16/`
**Status:** **Filed in Jira 2026-09-26 — LFRDN-742 to LFRDN-751** (Bug, assignee Yassin, parent LFRDN-317, *relates to* LFRDN-346). Screenshots to be attached manually.

> **Reproducible in the Lightning UI.** Sales Representative: `alfardan.qa.salesrep2@alfardan.com.qa.qa`
> / `Arcsen@2026!`. Approver (the rep's Manager): `alfardan.qa.salesbrandmanager2@alfardan.com.qa.qa`
> (Sales Manager – SportsMotors), same password. Login is two-step (username, then password); dismiss
> *Change Your Password* with **Cancel**. Automotive app. The entry point is the Opportunity header
> **Show more actions ▾ → Request Internal Requisition**, shown only while the Opportunity is at stage **Select**.

Each is raised in **LFRDN** as a Bug, assigned to **Yassin**, parent **LFRDN-317
(Build)**, labels `ALF-RS-16` / `QA` / `Retail-Sales`, linked *relates to* the ALF-RS-16 story subtask
(LFRDN-346). Items that need a business decision rather than a fix are in
the report's Section 3, not here.

## Summary

The core of the story works. The rep flags accessory and PDI lines, creates the quote, and requests
the form with a completion date. The rep's Sales Manager approves or rejects it. On approval a styled
PDF listing each flagged job is attached to the Opportunity. Both entry gates (no flagged lines, no
quote) block with clear messages, customer pricing is untouched, and another business unit cannot see
the form.

The form itself has problems. It prints **"Vehicle: null null"** and a blank quote number for every
vehicle in the org (BUG-RS16-01). It also **drops parts of the rep's job specification**: anything in
angle brackets, and all Arabic text (BUG-RS16-04).

While a requisition is pending, the **whole deal is locked** for the rep, including its product
lines, with no way to recall the request (BUG-RS16-02). The Sales Manager approves **without seeing
the vehicle, the jobs or the form** (BUG-RS16-05). Changes made after approval **leave the approved
form stale**, and re-requesting produces a second, identical "APPROVED" form (BUG-RS16-03). The
"Internal Provider Item" products, the line type built for internal jobs, **can never be added** to
a branded deal (BUG-RS16-06).

Smaller issues:
- Requesting again while a request is pending ends in a raw lock error (BUG-RS16-07).
- Past completion dates are accepted (BUG-RS16-08).
- The rejection email never arrives, and the notification carries no reason (BUG-RS16-09).
- The requisition status is shown nowhere on the deal (BUG-RS16-10).

| ID | Jira | Title | Priority | Affects |
|---|---|---|---|---|
| BUG-RS16-01 | LFRDN-742 | The form prints "Vehicle: null null" and no quote number | High | General — every vehicle in the org |
| BUG-RS16-02 | LFRDN-743 | The whole deal is locked while a requisition waits for approval, and the request cannot be recalled | High | Sales Representative (and anyone who is not an administrator or the approver) |
| BUG-RS16-03 | LFRDN-744 | Changing the accessories or PDI jobs after approval leaves the approved form stale; re-requesting creates a second "APPROVED" form | Medium | General |
| BUG-RS16-04 | LFRDN-745 | Parts of the job specification are missing from the form: anything in angle brackets, and all Arabic text | Medium | General |
| BUG-RS16-05 | LFRDN-746 | The Sales Manager approves without seeing the vehicle, the jobs or the form | Medium | Sales Manager (approver) |
| BUG-RS16-06 | LFRDN-747 | Internal Provider Items (e.g. Dealer Prep & Registration) can never be added to a branded deal | Medium | General — every Opportunity with a Brand |
| BUG-RS16-07 | LFRDN-748 | Requesting again while a request is pending ends in a raw "ENTITY_IS_LOCKED" error | Low | Sales Representative |
| BUG-RS16-08 | LFRDN-749 | A requested completion date in the past is accepted | Low | General |
| BUG-RS16-09 | LFRDN-750 | The rejection email never reaches the rep, and the rejection notification carries no reason | Low | Sales Representative |
| BUG-RS16-10 | LFRDN-751 | The requisition status and requested completion date are shown nowhere on the Opportunity | Low | General |

---

## BUG-RS16-01 — The form prints "Vehicle: null null" and no quote number (High)

**Module:** Retail Sales — Internal Requisition Form (PDF)
**Applies to:** General. All 91 vehicles in the org have a blank Make and Model.

### Description

The requisition tells the workshop which car to work on. The generated form prints the vehicle as
the words **"null null"**. It also shows no make, model, model year or trim, and prints the quote
number as **"-"** even though the deal has a quote. Only the VIN and colour identify the car.

### Steps to Reproduce

1. As the Sales Representative, run the full cycle on **QA RS16 T01**: Add Products, flag the
   lines, Create Quotation (quote **00000236**), then Request Internal Requisition. As the Sales
   Manager, approve it.
2. Opportunity → **Notes & Attachments** → open **Internal Requisition Form - QA RS16 T01 - Happy
   path (UI end to end)**.

### Expected Result

The form names the vehicle: make, model, model year and trim, alongside the VIN and colour. It also
shows the number of the deal's quote.

### Actual Result

> Quote Number   -
> Vehicle        null null
> VIN            ZFF99SLA000RS1601
> Exterior Colour Blu Tour de France

Reproduced on all five forms generated in this test (T01, T05, T06 ×2, T07).
`SELECT COUNT(Id), COUNT(MakeName), COUNT(ModelName), COUNT(ModelYear) FROM Vehicle` → **91 / 0 / 0 / 0**.
For T01, `AF_PrimaryQuote__c` = null and `SyncedQuoteId` = null, while quote 00000236 exists.

### Root Cause

**Confirmed from the code and data.**

- `AF_InternalRequisitionFormService.buildBody` prints
  `opp.AF_SelectedVehicle__r.MakeName + ' ' + opp.AF_SelectedVehicle__r.ModelName`. Concatenating
  two nulls gives the string `"null null"`, which is not blank, so `nv()` does not replace it with
  "-". `MakeName`, `ModelName` and `ModelYear` are read-only standard fields that are empty on
  every vehicle.
- The quote number is read from `AF_PrimaryQuote__c`, which **Create Quotation** never sets.

### Proposed Solution

1. Build the vehicle line from data that is populated. Use the Vehicle Definition name, or
   `AF_Brand__c` plus the vehicle's model from its Vehicle Definition. Add the trim from the deal's
   *Trim/Line Variant* line, and the model year using the same fallback LFRDN-674 added for the
   Sales Order.
2. Guard each part so a missing value prints "-", never "null".
3. Take the quote number from the Opportunity's quote (Create Quotation allows only one per deal),
   or set `AF_PrimaryQuote__c` in Create Quotation.

### Reference

- **BRD** §10.16 ALF-RS-16, p.61, FR1 — *"… generate an Internal Requisition Form from Salesforce after accessories or PDI requirements have been selected against the opportunity, capturing vehicle details, accessory or PDI specifications, and requested completion date."*
- **BRD** §10.16 ALF-RS-16, p.61–62, AC1 — *"… Then the form is created and stored against the opportunity with vehicle details and job specifications populated."*
- **SD**, p.69, "09 -- Internal Requisition (Document-Only)" page, "End-to-end process design" section — *"2. The Internal Requisition document generates from the deal data: vehicle details, accessory/pre-delivery-inspection specifications, requested completion date."*

**Screenshots:** `15-pdf-preview-069FV007caVKYmqYAH.png`

---

## BUG-RS16-02 — The whole deal is locked while a requisition waits for approval, and the request cannot be recalled (High)

**Module:** Retail Sales — Internal Requisition approval
**Applies to:** Sales Representative, and every user other than a System Administrator or the
assigned approver.

### Description

Asking for accessory fitting or a PDI should not freeze the sale. The moment the rep submits a
requisition, the entire Opportunity is locked until the Sales Manager acts. The rep cannot edit the
deal, move its stage or change its products. There is no **Recall** option, so the rep has to wait
for the manager, however long that takes.

### Steps to Reproduce

1. As the Sales Representative, on **QA RS16 T01** (at Select, lines flagged, quote created):
   **Show more actions ▾ → Request Internal Requisition** → date **10 Oct 2026** → **Next**.
2. **Edit** on the Opportunity → change *Next Step* → **Save**.
3. Opportunity → **Products** → **View All** → *Ferrari Roma Car Cover* row → **Edit** → change
   *Customization Description* → **Save**.
4. Path → click **Commit** → **Mark as Current Stage** (reproduced on **QA RS16 T04**, pending).
5. Open the approval request's **Approval History** row → look for **Recall**.

### Expected Result

The deal stays workable while the requisition is pending: the rep can progress the sale and edit
lines not under review. If the request needs to change, the rep can recall it.

### Actual Result

- **Steps 2 and 3:** *"We hit a snag. Review the errors on this page. This record is locked. If you
  need to edit it, contact your admin."* Nothing is saved.
- **Step 4:** *"You encountered some errors when trying to save this record. This record is locked.
  If you need to edit it, contact your admin."* The stage stays at Select.
- **Step 5:** no Recall option exists.

The lock stays until the Sales Manager approves or rejects the request. Reproduced on T01, T04 and T05.

### Root Cause

**Confirmed from the approval process metadata.** `AF_AP_Opp_InternalRequisition` runs on the
**Opportunity** record itself. Submission locks the record (standard approval behaviour, with
`recordEditability` = `AdminOrCurrentApprover`), and the lock extends to its Opportunity Products.
`allowRecall` = `false`.

### Proposed Solution

Use one of the following:
- Unlock the Opportunity straight after submission (`Approval.unlock` from an invocable in
  `AF_FL_Opp_RequestInternalRequisition`, with Apex record locking enabled), keeping
  `AF_RequisitionStatus__c` and the flagged lines protected by validation while pending.
- Run the approval against a lightweight requisition record, so the deal itself is never locked.

In either case, set `allowRecall` = `true` so the rep can withdraw a request.

### Reference

- **BRD** §10.16 ALF-RS-16, p.61, Requirement Overview — *"It is routed for Sales Manager approval before being issued to the After Sales team for action. The cost of the job is estimated internally and does not affect the customer-facing price, which is agreed at quotation stage."* The approval covers the requisition, not the whole deal.
- **SD**, p.69, "09 -- Internal Requisition (Document-Only)" page, "End-to-end process design" section — *"3. Sales Manager approval before issue (approval process as design direction; the authority matrix is Pending customer confirmation)."*

**Screenshots:** `05-save-while-pending.png`, `06-product-edit-while-pending.png`, `19-stage-move-while-pending.png`

---

## BUG-RS16-03 — Changing the accessories or PDI jobs after approval leaves the approved form stale; re-requesting creates a second "APPROVED" form (Medium)

**Module:** Retail Sales — Internal Requisition Form lifecycle
**Applies to:** General.

### Description

After a requisition is approved, the rep can still change the flagged jobs: rewrite a
specification, or flag a new item. Nothing reacts to these changes:
- The status stays **Approved**.
- The approved form keeps the old specification.
- Nobody is told that it no longer matches the deal.

If the rep requests again, the system produces a **second** form with the same title, also stamped
**APPROVED**, next to the first. Nothing shows which one is current, so the workshop may fit the
old specification or do the job twice.

### Steps to Reproduce

1. **QA RS16 T06 - Change after approval** (`006FV00BzHIwt2SYUR`) is approved. Its form lists the
   tint as *"Premium 20% tint on all side and rear glass; windscreen strip 10 cm"*.
2. As the Sales Representative, go to **Products** → **View All** → *Ferrari Window Tint* → **Edit**.
   Set *Customization Description* to *"CHANGED AFTER APPROVAL: 5% limo tint all round"* and **Save**.
3. *Ferrari Roma Car Cover* → **Edit** → tick **Requires Internal Requisition?** → enter a spec →
   **Save**.
4. Check the Opportunity's requisition status and its Notes & Attachments.
5. **Show more actions ▾ → Request Internal Requisition** → **25 Oct 2026** → **Next**. Approve it as
   the Sales Manager.
6. Check Notes & Attachments again.

### Expected Result

A change to a flagged line after approval invalidates the approved form: status back to *Not
Requested* or *Changes Pending*, and the rep is prompted to re-request. The regenerated form replaces
the old one as a new **version** of the same file, so only one current form exists.

### Actual Result

- **Steps 2 and 3:** both saves succeed.
- **Step 4:** status is still **Approved**, and the one form still shows the old tint specification
  without the car cover.
- **Step 6:** there are now **two** files, both titled *"Internal Requisition Form - QA RS16 T06 -
  Change after approval"* and both stamped *APPROVED*: `068FV007e9XZpcSYAT` (11:46 UTC) and
  `068FV007e9l70kuYAA` (11:49 UTC). Neither has a version history.

### Root Cause

**Confirmed from the metadata.**
- No trigger or flow on `OpportunityLineItem` reacts to changes in `AF_RequiresInternalRequisition__c`
  or `AF_CustomizationDescription__c`.
- `AF_FL_Opp_RequestInternalRequisition` does not check the current status.
- `AF_InternalRequisitionFormService` always inserts a new `ContentVersion` with
  `FirstPublishLocationId`, which creates a new document, instead of adding a version to the
  existing requisition file.

### Proposed Solution

1. Add a record-triggered flow on `OpportunityLineItem` (after update/insert/delete). When a flagged
   line changes, or a line's flag changes, on an Opportunity whose `AF_RequisitionStatus__c` is
   *Approved*, reset the status to *Not Requested* (or a new *Changes Pending*) and notify the owner.
2. In the service, look up the Opportunity's existing requisition file and insert the new PDF as a
   new version of that `ContentDocument`, so only one current form exists.

### Reference

- **SD**, p.70, "09 -- Internal Requisition (Document-Only)" page, "Exception handling" section — *"Rejected approvals return to the consultant with the reason; changes after approval require regeneration and re-approval; distribution failures surface for manual re-send."*
- **SD**, p.70, same page, "Salesforce solution design" section — *"stored as a File with category "Internal Requisition Form"; regeneration replaces with version history via Files."*

---

## BUG-RS16-04 — Parts of the job specification are missing from the form: anything in angle brackets, and all Arabic text (Medium)

**Module:** Retail Sales — Internal Requisition Form (PDF)
**Applies to:** General.

### Description

The job specification is what the workshop works from. When the rep's specification contains text
in angle brackets (for example *<front + rear>*) or Arabic, those parts disappear from the form. The
rest of the line prints, so nothing on the form shows that text is missing.

### Steps to Reproduce

1. **QA RS16 T07 - Special characters and Arabic** (`006FV00BzHJ15BUYUZ`). The tint line's
   *Customization Description* is:
   `Roof Rails & Cross-Bars — M Sport <front + rear> "OEM" / فحص ما قبل التسليم`
2. Request the requisition as the Sales Representative, and approve it as the Sales Manager.
3. Open the form from Notes & Attachments, section *Accessory / PDI Job Specifications*.

### Expected Result

The specification prints exactly as entered, including `<front + rear>` and the Arabic text
(right-to-left).

### Actual Result

The line reads *"Roof Rails & Cross-Bars — M Sport "OEM" /"*.
- `<front + rear>` is gone.
- The Arabic *فحص ما قبل التسليم* is gone.
- `&`, the em dash and the quotes render correctly.

Seen in the Salesforce file preview and in the extracted PDF text (`068FV007e5OXoJwYAL`).

### Root Cause

**Confirmed from the code.**
- `buildBody` inserts `AF_CustomizationDescription__c` (and every other value) into the HTML without
  escaping it, so `<front + rear>` is parsed as an HTML tag and dropped.
- The page is rendered by `Blob.toPdf` in Helvetica/Arial, which has no Arabic glyphs, so the Arabic
  text is not drawn.

### Proposed Solution

1. HTML-escape every value in `nv()` with `String.escapeHtml4()` before inserting it into the body.
2. Render with a font that has Arabic glyphs (for example `font-family: 'Arial Unicode MS'`, which
   `Blob.toPdf` supports), and set `dir="auto"` on the specification cells.

### Reference

- **BRD** §10.16 ALF-RS-16, p.61–62, AC1 — *"… Then the form is created and stored against the opportunity with vehicle details and job specifications populated."*
- **BRD** §10.16 ALF-RS-16, p.61, FR1 — *"… capturing vehicle details, accessory or PDI specifications, and requested completion date."*

**Screenshots:** `16-T07-pdf-jobspecs.png`

---

## BUG-RS16-05 — The Sales Manager approves without seeing the vehicle, the jobs or the form (Medium)

**Module:** Retail Sales — Internal Requisition approval
**Applies to:** Sales Manager (approver).

### Description

The Sales Manager is asked to approve internal work on a car, but is not shown the work:
- The approval request and the "Approval Needed" email show only the deal name, the owner and the
  requested date.
- There is no vehicle, no list of accessories or PDI jobs, and no form. The form is created only
  after approval.

The manager has to open the deal and read its product lines to know what is being approved.

### Steps to Reproduce

1. As the Sales Representative, submit a requisition on **QA RS16 T01**.
2. Log in as the Sales Manager → **Items to Approve** → open *QA RS16 T01 - Happy path (UI end to
   end)*.
3. Read the manager's email *"Approval Needed: Internal Requisition Form for …"*.
4. Check the Opportunity's Notes & Attachments before approving.

### Expected Result

The form is generated when the rep requests it and is available to the approver, or the approval
request shows the vehicle and each flagged job with its specification. The manager can then review
what they approve.

### Actual Result

- **Step 2:** *Approval Details* shows only the Opportunity Name, the Opportunity Owner (QA
  SalesRep2) and the Requisition Requested Completion Date (10/10/2026).
- **Step 3:** the email lists the same three facts, plus a link.
- **Step 4:** no file exists (0 ContentDocumentLinks). The form appears only after approval.
- In *Items to Approve*, the request shows only *Type: Opportunity*, the same as cancellation and
  closure requests.

### Root Cause

**Confirmed from the metadata.**
- `AF_AP_Opp_InternalRequisition` `approvalPageFields` = Name, Owner,
  `AF_RequisitionCompletionDate__c`.
- The `EmailBody` formula in `AF_FL_Opp_RequisitionApprovalRequested` holds the same three values.
- `AF_InternalRequisitionFormService` runs only from `AF_FL_Opp_RequisitionApproved`.

### Proposed Solution

Generate a draft form (status pill *Pending Approval*) on submission, and link it in the approval
email. On approval, regenerate it as *Approved* as a new version of the same file (see
BUG-RS16-03). At a minimum, add the vehicle and a job summary to the approval email and page
fields.

### Reference

- **BRD** §10.16 ALF-RS-16, p.62, AC2 — *"Given an Internal Requisition Form is generated, When the Sales Manager reviews and approves it, Then the form is marked as approved and distributed to the After Sales team for action."*
- **BRD** §10.16 ALF-RS-16, p.61, FR2 — *"The system should route the Internal Requisition Form for approval by the Sales Manager before it is issued to the After Sales team."*

**Screenshots:** `07-approval-request-page.png`

---

## BUG-RS16-06 — Internal Provider Items (e.g. Dealer Prep & Registration) can never be added to a branded deal (Medium)

**Module:** Retail Sales — Add Products / Internal Requisition line type
**Applies to:** General. Every Opportunity with a Brand, which is every retail deal.

### Description

The product catalogue has an *Internal Provider Item* category for work done internally with no
charge to the customer: *Ferrari Dealer Prep & Registration*, *Rolls-Royce Dealer Prep &
Registration* and *Dealer Prep & Registration*. When one is added, the line type becomes *Internal
Requisition*. The **Add Products** screen never offers these products on a deal that has a brand, so
the line type built for internal requisitions cannot be used.

### Steps to Reproduce

1. As the Sales Representative, open **QA RS16 T10 - Internal provider item on branded deal**
   (`006FV00BzHJDfcaYUD`) or **QA RS16 T01**. Brand is Ferrari, stage Select.
2. Header → **Add Products**.

### Expected Result

The brand's internal provider items (*Ferrari Dealer Prep & Registration*) are offered, and are
added as *Internal Requisition* lines that are not customer-facing, ready to flag for the requisition.

### Actual Result

Nine products are listed: Ferrari Roma Car Cover, Ferrari Ceramic Paint Protection Package, Ferrari
Window Tint - Premium 20%, Ferrari Pre-Delivery Inspection Service, Ferrari Extended Warranty -
5 Year, GTS Package, Spider Package, Assetto Fiorano Package and a second Spider Package. No *Dealer
Prep & Registration* product is offered.

### Root Cause

**Confirmed from the flow metadata.** In `AF_Add_Products_To_Opporunity`:
- `Get_Products_For_Brand` (used whenever the Opportunity has a Brand) filters
  `AF_ProductCategory__c NotEqualTo "Internal Provider Item"`.
- `Get_Products` (no brand) does not filter it.
- The flow's own formulas (`Formula_LineItemType`, `Formula_DefaultCustomerFacing`) are written to
  handle this category, so it was meant to be addable.

### Proposed Solution

Remove the `Internal Provider Item` exclusion from `Get_Products_For_Brand`. The existing formulas
already set such lines to *Internal Requisition* and not customer-facing. Optionally default
`AF_RequiresInternalRequisition__c` = true for that category.

### Reference

- **SD**, p.69, "09 -- Internal Requisition (Document-Only)" page, "Design decisions" table, IR-1 Line classification — *"R1 Solution Design: line items carry a requires-internal-requisition flag and a line-type classification; the provider/source indicator model (which items are OEM vs internally provided, who sets it) is TBP"*
- **BRD** §10.16 ALF-RS-16, p.61, Requirement Overview — *"The cost of the job is estimated internally and does not affect the customer-facing price, which is agreed at quotation stage."*

**Screenshots:** `01-add-products-no-internal-provider-item.png`

---

## BUG-RS16-07 — Requesting again while a request is pending ends in a raw "ENTITY_IS_LOCKED" error (Low)

**Module:** Retail Sales — Request Internal Requisition
**Applies to:** Sales Representative.

### Description

While a requisition is waiting for approval, **Request Internal Requisition** is still offered. The
rep fills in the date, clicks Next, and gets a technical error instead of being told a request is
already pending.

### Steps to Reproduce

1. **QA RS16 T05** (`006FV00BzHIsgtQYUR`) with a requisition pending approval.
2. As the Sales Representative: **Show more actions ▾ → Request Internal Requisition** → date
   **30 Nov 2026** → **Next**.

### Expected Result

The action says a request is already pending approval (with the date submitted), and offers nothing
further, or is hidden while one is pending.

### Actual Result

> Something went wrong — We couldn't complete this action. Please try again, or contact your administrator if the problem continues. The flow tried to update these records: null. This error occurred: ENTITY_IS_LOCKED: This record is locked. If you need to edit it, contact your admin.. You can look up ExceptionCode values in the SOAP API Developer Guide.

### Root Cause

**Confirmed from the flow metadata.** `AF_FL_Opp_RequestInternalRequisition` checks for flagged
lines, a quote and a manager, but never reads `AF_RequisitionStatus__c`. `Update_Opportunity` then
fails on the approval lock, and the fault screen shows `$Flow.FaultMessage`.

### Proposed Solution

Add a decision at the start: if `AF_RequisitionStatus__c` = *Pending Approval*, show a plain message
screen. Also add `AF_RequisitionStatus__c != "Pending Approval"` to the action's visibility rule on
`Opportunity_Record_Page`.

### Reference

- **BRD** §10.16 ALF-RS-16, p.61, FR2 — *"The system should route the Internal Requisition Form for approval by the Sales Manager before it is issued to the After Sales team."*

**Screenshots:** `12-T05-second-request-while-pending.png`

---

## BUG-RS16-08 — A requested completion date in the past is accepted (Low)

**Module:** Retail Sales — Request Internal Requisition
**Applies to:** General.

### Description

The rep can ask After Sales to complete the job by a date that has already passed. The request is
submitted and approved, and the form prints the past date.

### Steps to Reproduce

1. On **QA RS16 T05** (26 Sep 2026), as the Sales Representative: **Request Internal Requisition** →
   *Requested Completion Date* **01 Sep 2026** → **Next**.
2. Approve it as the Sales Manager and open the form.

### Expected Result

A date before today is refused with a clear message.

### Actual Result

*"The Internal Requisition Form request has been submitted to your Sales Manager for approval."* The
approved form reads *Requested Completion Date 01 Sep 2026*.

### Root Cause

**Confirmed from the flow metadata.** `CompletionDateField` on `Screen_RequestRequisition` has no
validation rule, and the Opportunity has none on `AF_RequisitionCompletionDate__c`.

### Proposed Solution

Add input validation on the screen field: `{!CompletionDateField} >= TODAY()`, with the message
"The completion date cannot be in the past."

### Reference

- **BRD** §10.16 ALF-RS-16, p.61, FR1 — *"… capturing vehicle details, accessory or PDI specifications, and requested completion date."*

**Screenshots:** `11-T05-past-date-accepted.png`

---

## BUG-RS16-09 — The rejection email never reaches the rep, and the rejection notification carries no reason (Low)

**Module:** Retail Sales — Internal Requisition rejection
**Applies to:** Sales Representative.

### Description

When the Sales Manager rejects a requisition:
- The rep gets an in-app notification that says only *"… was rejected."*
- The rejection email never arrives.
- The manager's reason is visible only in the deal's Approval History, so the rep must go looking
  for it.

### Steps to Reproduce

1. **QA RS16 T04** (`006FV00BzHIoUkOYUV`): the rep requests a requisition.
2. As the Sales Manager, **Reject** it with the comment *"Rejected: tint spec not allowed on 296 GTB
   windscreen - remove windscreen strip and resubmit"*.
3. Check the rep's notifications (bell) and the rep's mailbox (`alfardan.qa.salesrep@yopmail.com`).

### Expected Result

The rep receives the rejection by email and notification, each with the manager's reason.

### Actual Result

- **Notification:** *"Requisition Rejected: QA RS16 T04 - Reject then resubmit — Your Internal
  Requisition Form request for QA RS16 T04 - Reject then resubmit was rejected."*
- **Email:** after 6 minutes, no rejection email in the rep's mailbox, while every *Approved* email
  from the same test arrived.
- No email is logged on the Opportunity. The reason appears only in Approval History.

### Root Cause

**Partly confirmed.**
- `AF_FL_Opp_RequisitionRejected` builds a fixed notification body and a fixed plain-text email with
  no approval comment (confirmed from metadata).
- The email step `Send_Owner_Rejection`, unlike the Approved and Approval-Needed emails, has no
  `senderType` / org-wide *No Reply* sender and no `logEmailOnSend`. Why it is not delivered was not
  isolated.

### Proposed Solution

Send the rejection email the same way as the approval email: org-wide *No Reply* sender,
`logEmailOnSend` = true, HTML body. Include the latest `ProcessInstanceStep.Comments` in both the
email and the notification.

### Reference

- **SD**, p.70, "09 -- Internal Requisition (Document-Only)" page, "Exception handling" section — *"Rejected approvals return to the consultant with the reason"*

**Screenshots:** `17-rep-inbox-no-rejection-email.png`, `18-T04-rejected-history.png`

---

## BUG-RS16-10 — The requisition status and requested completion date are shown nowhere on the Opportunity (Low)

**Module:** Retail Sales — Opportunity record page
**Applies to:** General.

### Description

The deal holds an *Internal Requisition Status* (Not Requested / Pending Approval / Approved /
Rejected) and the requested completion date, but neither appears on the Opportunity page. Neither
the rep nor the manager can see from the deal whether a requisition is pending, approved or rejected.
They have to read the Approval History, where requisition approvals look the same as closure and
cancellation approvals.

### Steps to Reproduce

As the Sales Representative, open **QA RS16 T01** (Approved) or **QA RS16 T04** (Pending Approval)
and search the Details tab and the page for *Requisition*.

### Expected Result

The Details tab shows *Internal Requisition Status* and *Requisition Requested Completion Date*,
read-only.

### Actual Result

Neither field appears anywhere on the page. `AF_RequisitionStatus__c` = *Approved* / *Pending
Approval* in the database.

### Root Cause

**Confirmed from the page metadata.** Neither field is on `Opportunity_Record_Page` (Dynamic Forms)
or on the Opportunity page layout used by the rep.

### Proposed Solution

Add both fields, read-only, to a *Requisition* section of `Opportunity_Record_Page`.

### Reference

- **BRD** §10.16 ALF-RS-16, p.61, FR4 — *"The system should allow attachment of the approved Internal Requisition Form to the opportunity record for traceability."*
- **BRD** §10.16 ALF-RS-16, p.62, AC2 — *"… Then the form is marked as approved and distributed to the After Sales team for action."*
