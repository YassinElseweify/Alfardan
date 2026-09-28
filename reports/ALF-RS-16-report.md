# ALF-RS-16 — Internal Requisition Form and PDI Management — test report

**Date:** 2026-09-26 · **Org:** Al-Fardan QA sandbox · **Tickets:** `tickets/ALF-RS-16/README.md` (BUG-RS16-01 … 10, filed as LFRDN-742 … 751)
**Screenshots:** `screenshots/ALF-RS-16/`

---

## Section 1 — Summary of what was done

**Story.** After accessories or PDI work are chosen on a deal, the Sales Representative generates an
Internal Requisition Form. The Sales Manager approves it, the form is attached to the Opportunity and
emailed to After Sales, and After Sales does the job in Autoline with the cost kept internal.

**How it is built.**

| Step | What the user does | What the org does |
|---|---|---|
| Choose the work | **Add Products** (stage Consider/Explore/Select) → pick accessories, tint, PDI service | Creates Opportunity Products. No requisition flag or job spec is asked for. |
| Flag it | Opportunity → Products → **Edit** each line → tick **Requires Internal Requisition?**, type **Customization Description** | Line-level flag and spec are the requisition data (no requisition object — SD DEC-010). |
| Quote | **Create Quotation** (stage Select) | Quote + lines, flags copied. |
| Request | **Show more actions ▾ → Request Internal Requisition** (stage **Select only**) → *Requested Completion Date* | Blocks if no flagged line or no quote; sets status *Pending Approval*; submits approval `AF_AP_Opp_InternalRequisition` to the owner's **Manager**; emails + notifies the manager. |
| Approve / reject | Manager: **Items to Approve** → Approve / Reject | Approve: status *Approved* → `AF_InternalRequisitionFormService` renders a PDF and attaches it to the Opportunity; rep emailed + notified. Reject: status *Rejected*; rep notified. |
| Distribute | Rep emails the form to After Sales **manually** (agreed for now) | Nothing automated. The rep's approval email says to use *Send Email* with the *Internal Requisition Form - After Sales* template. |
| Job cost (AC3) | — | `Vehicle.AF_PDIAccessoryCost__c` exists as a stub; no automation or Keyloop integration. |

**Personas.** Sales Representative = QA SalesRep2 (Sales Rep – SportsMotors). Sales Manager =
QA SalesBrandManager2 (the rep's Manager). Other business unit = QA ShowroomManager2 (Alsadd,
Automobiles). The persona API logins worked again today once the IP was trusted.

**Harnesses.** Lightning UI as each persona for the user journey: Add Products, line edits, Create
Quotation, Request Internal Requisition, Items to Approve, the PDF preview. The persona REST API was
used for the access checks and for three approvals (T05, T06, T07), which use the same Approve action.
The admin CLI was used for setup and read-back only.

**Records.** Eleven execution deals **QA RS16 T01–T10, T12**, owned by QA SalesRep2, for customer
*QA RS16 Customer - Khalid Al-Sulaiti*, each with its own Ferrari 296 GTB. Plus a clean hands-on set
**DEMO RS16 H01–H07** (Section 5).

**Counts.** 10 written TCs + 6 added = **16 executed** → 3 Pass · 8 Fail · 2 Partial · 3 Blocked
(BA decision needed). **10 bugs** (2 High, 4 Medium, 4 Low) and **6 BA gaps**.

**Headline verdict.** Requesting, approving, generating and attaching the form works, and the gates,
pricing and business-unit segregation hold. Distribution to After Sales is manual for now, as agreed.
The form itself is not fit to send:
- It names the vehicle as "null null" (BUG-RS16-01).
- It loses parts of the job specification (BUG-RS16-04).

Pending requisitions lock the whole deal (BUG-RS16-02).

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Evidence / finding |
|---|---|---|---|
| RS-16-TC-001 | Form only after items are selected; vehicle, specs and date on the form; stored on the Opportunity | **PARTIAL** | T02 blocked: *"No accessories or PDI requirements are selected on this Opportunity…"* ✓. T01 form generated and attached ✓, both job specs and the date printed ✓. Vehicle prints **"null null"**, quote "-", no make/model/year/trim (**BUG-RS16-01**). |
| RS-16-TC-002 | Routed for approval; nothing reaches After Sales before approval; After Sales notified after approval | **PASS** | Status *Pending Approval*, work item assigned to QA SalesBrandManager2 ✓; approval recorded with approver, time and comment ✓; nothing sent before approval ✓. Sending to After Sales after approval is manual by agreement; the rep is told how in the approval email ✓. |
| RS-16-TC-003 | Which role approves | **BLOCKED** (GAP-RS16-04) | Observed: the rep's **Manager** field (QA SalesBrandManager2). No delegation (`allowDelegate` false), no escalation. |
| RS-16-TC-004 | After Sales distribution route | **BLOCKED** (GAP-RS16-02) | Manual send by the rep, agreed for now. No After Sales recipient is defined in the org. Note: the Opportunity page has no Email / Send Email action, so the rep has no way to send it from Salesforce today. |
| RS-16-TC-005 | Completion date validation | **FAIL** | 01 Sep 2026 accepted on 26 Sep (**BUG-RS16-08**). No rule against the handover date (GAP-RS16-05). |
| RS-16-TC-006 | Changes after approval | **FAIL** | Spec changed and a new line flagged: status stays *Approved*, the form is stale; re-request gives a second "APPROVED" file (**BUG-RS16-03**). |
| RS-16-TC-007 | Rejection path | **PARTIAL** | T04 rejected: status *Rejected* ✓, no form ✓, nothing to After Sales ✓, reason in Approval History ✓, resubmit works with history kept ✓. Notification has no reason; rejection email never arrived (**BUG-RS16-09**). |
| RS-16-TC-008 | Internal cost vs customer price | **BLOCKED** (GAP-RS16-03) | Customer price unchanged: Amount and Quote Grand Total stay **371,700** before and after approval ✓. Internal cost not captured anywhere (stub field, no integration). |
| RS-16-TC-009 | Visibility limited to owning BU | **PASS** | QA ShowroomManager2 (Automobiles): the Sports Motors Opportunity and its form return 0 rows / NOT_FOUND. No After Sales profile exists to test (GAP-RS16-02). |
| RS-16-TC-010 | Special characters and Arabic in the form | **FAIL** | `&`, em dash and quotes fine; `<front + rear>` and the Arabic text missing (**BUG-RS16-04**). |
| RS-16-TC-011 *(added)* | Rep can keep working the deal while a requisition is pending | **FAIL** | Opportunity edit and product edit both: *"This record is locked…"*; no recall (**BUG-RS16-02**). |
| RS-16-TC-012 *(added)* | Second request while one is pending | **FAIL** | Action still offered → raw `ENTITY_IS_LOCKED` (**BUG-RS16-07**). |
| RS-16-TC-013 *(added)* | Internal Provider Items can be added to a branded deal | **FAIL** | *Dealer Prep & Registration* not offered by Add Products (**BUG-RS16-06**). |
| RS-16-TC-014 *(added)* | Approver can see what they approve | **FAIL** | Approval page and email: name, owner, date only; no form yet (**BUG-RS16-05**). |
| RS-16-TC-015 *(added)* | No-quote gate; stage window | **PASS** | T03: *"No Quote has been created on this Opportunity yet…"* ✓. T08 at Commit: action not offered, as the SD places it at Select (question in GAP-RS16-01). |
| RS-16-TC-016 *(added)* | Rep can see the requisition status on the deal | **FAIL** | Status and date on no part of the Opportunity page (**BUG-RS16-10**). |

**Also passed:**
- Manager-only approval: the approval routes only to the Manager.
- The file is attached as `InternalUsers` and follows the Opportunity's sharing.
- One "Approval Needed" email per request, with no duplicates.

**Not independently verified:**
- **AC3 inside Autoline:** the Keyloop repair-order integration is not built.
- **Rejection email delivery root cause:** not isolated.
- **API-only observation, not raised:** the rep can set *Internal Requisition Status* to *Pending
  Approval* directly through the API (T12). That emails the manager "Approval Needed" with no approval
  behind it. The field is not on any page the rep uses, so it cannot be done in the UI, and it is not
  ticketed.

---

## Section 3 — BA gaps to raise

### GAP-RS16-01 — When in the deal can a requisition be raised?
The action is available only at stage **Select** (SD process map places it there). Once the deal
reaches **Commit** (reservation/deposit) no requisition can be raised, and a requisition rejected at
Commit cannot be resubmitted. PDI normally happens close to delivery. Confirm the window — Select
only, or Select through Take the Keys.

### GAP-RS16-02 — Who is "After Sales", and how do they receive the form?
BRD FR3 says email from Salesforce; BRD Assumption 1 (p.62) leaves the routing (email, MuleSoft or
other) to be agreed; SD OPN-037 keeps it open. There is no After Sales user, queue, mailbox or
persona in the org (the persona is also missing from BRD §6). Needed: the mailbox per brand /
business unit, and whether After Sales must see the form inside Salesforce.

### GAP-RS16-03 — Job cost capture (AC3) and the Keyloop repair order
AC3 expects the job to be actioned in Autoline with the cost captured against the vehicle. BRD
Assumptions 1–2 (p.62) leave the integration and the cost-confirmation process open, yet SD p.575
("Flow 3 -- Log Internal Requisition") states the Keyloop `POST /repair-orders` endpoint is
*"Confirmed"*. Only a stub field exists (`Vehicle.AF_PDIAccessoryCost__c`, "no automation writes to
it yet"). Decide whether R1 includes the repair-order push and cost write-back.

### GAP-RS16-04 — Approver and fallback
FR2 names the Sales Manager; Related Personas name "Sales Manager / Showroom Manager". The build
routes to the submitter's **Manager** field, with no delegation or escalation — a requisition stalls
if the manager is away. Confirm the role and the fallback.

### GAP-RS16-05 — Completion-date rules
Beyond "not in the past" (BUG-RS16-08): must it fall before the handover date, and should a
same-day or next-day request warn about workshop capacity?

### GAP-RS16-06 — What is "internal"? Flagging and customer price
The PDI service line (*Ferrari Pre-Delivery Inspection Service*, AED 350) is a **customer-charged**
line, while the Requirement Overview says the job cost is internal and does not affect the customer
price. The rep must flag every line by hand after adding it (Add Products asks for neither the flag
nor the spec). SD OPN-050 (provider/source model) and OPN-049 (quotation inclusion) are open. Decide
which items are requisitioned, who sets the flag, and whether requisitioned items appear on the
customer quote.

---

## Section 4 — Walkthrough by functional requirement and acceptance criterion

### FR1 / AC1 — Generate the form after items are selected, with vehicle, specs and date — **Partial**
1. **QA RS16 T01** (Select, vehicle only). Rep: **Add Products** → *Ferrari Roma Car Cover*,
   *Ferrari Window Tint - Premium 20%*, *Ferrari Pre-Delivery Inspection Service* → quantities →
   *"Products added"*. The screen never asks which items need a requisition. *Dealer Prep &
   Registration* is not offered (**BUG-RS16-06**).
2. Products → **View All** → Tint → **Edit** → tick *Requires Internal Requisition?*, spec
   *"Premium 20% tint on all side and rear glass; windscreen strip 10 cm"* → Save. Same for the PDI
   line (*"Full PDI per Ferrari checklist; fluids, tyre pressures, software update, road test 15 km"*).
3. **Create Quotation** → Customer Quotation → *"Quotation created."* (00000236).
4. **Request Internal Requisition** → *Requested Completion Date* 10 Oct 2026 → *"…submitted to your
   Sales Manager for approval."* A past date is also accepted (**BUG-RS16-08**, T05).
5. Gates: T02 (lines not flagged) → *"No accessories or PDI requirements are selected…"*; T03 (no
   quote) → *"No Quote has been created on this Opportunity yet."* ✓
6. After approval the form **Internal Requisition Form - QA RS16 T01 - …** is in Notes & Attachments ✓.
   It lists both jobs, quantities, specs and 10 Oct 2026 ✓ — but **Vehicle: null null** and **Quote
   Number: -** (**BUG-RS16-01**); specs containing `<…>` or Arabic lose text (**BUG-RS16-04**, T07).

### FR2 — Sales Manager approval before issue — **Pass, with defects around it**
1. On submission the status becomes *Pending Approval*, a work item goes to QA SalesBrandManager2 and
   an "Approval Needed" email + bell notification are sent ✓.
2. The approval page shows only name, owner and date (**BUG-RS16-05**).
3. While pending, the rep cannot edit the deal or its products — *"This record is locked…"* — and
   cannot recall (**BUG-RS16-02**). Requesting again gives a raw error (**BUG-RS16-07**).
4. Reject (T04) with a reason → *Rejected*, no form, reason in Approval History ✓; notification
   without reason and no email (**BUG-RS16-09**). Resubmit works ✓.
5. The status is not visible on the deal (**BUG-RS16-10**).

### FR3 / AC2 — Distribute the approved form to After Sales by email — **Manual for now (agreed)**
1. Approve (T01) → status *Approved*, PDF generated as the approver ✓.
2. Emails logged: *Approval Needed* (manager) and *Approved* (rep). The rep's email says to send the
   form to After Sales with *Send Email* and the *Internal Requisition Form - After Sales* template.
3. Observed: the Opportunity page has no Email / Send Email action (Activity publisher offers New
   Task and Log a Call only). Recipient undefined (GAP-RS16-02).

### FR4 — Attach the approved form to the Opportunity — **Pass**
The PDF is attached automatically (`FirstPublishLocationId` = the Opportunity), visible to the rep in
Notes & Attachments, hidden from another business unit ✓. After later changes the form goes stale and
a second "APPROVED" copy appears on re-request (**BUG-RS16-03**).

### AC3 — Job actioned in Autoline, cost captured on the vehicle — **Blocked**
No integration, no cost write-back; customer price is unaffected (371,700 before and after) ✓.
See GAP-RS16-03.

---

## Section 5 — Hands-on: run ALF-RS-16 yourself

### What this story is, and how it is built
The requisition has no record of its own. The data lives in the Opportunity's **product lines**: the
*Requires Internal Requisition?* tick and the *Customization Description* text. The **Internal
Requisition Status** field on the Opportunity (not visible on the page) moves Not Requested →
Pending Approval → Approved / Rejected. The **form** is a PDF file created only on approval.

### Logins
- **Rep:** `alfardan.qa.salesrep2@alfardan.com.qa.qa` / `Arcsen@2026!`
- **Manager:** `alfardan.qa.salesbrandmanager2@alfardan.com.qa.qa` / `Arcsen@2026!`

Login is two-step: username, then **Log In to Sandbox**, then password. On *Change Your Password*,
click **Cancel**. Use the **Automotive** app. Search *DEMO RS16* to find every record.

### Records created for you
Customer *DEMO RS16 Customer - Noora Al-Kuwari*. Each deal is a Ferrari 296 GTB (Rosso Corsa
RS16H-0n), owned by QA SalesRep2. Every deal except H01 carries Tint 1,200 + Car Cover 850 + PDI 350,
so the Amount is **AED 371,700**.

| Record | State | Use it for |
|---|---|---|
| DEMO RS16 H01 - Happy path from Add Products to approved form | Select, vehicle line only, no quote | Full cycle FR1–FR4 |
| DEMO RS16 H02 - Accessories not flagged (blocked) | Select, 3 add-ons **not** flagged, quote 00000237 | "No items" gate |
| DEMO RS16 H03 - Flagged but no quote (blocked) | Select, Tint + PDI flagged, no quote | "No quote" gate |
| DEMO RS16 H04 - Pending lock, double submit, reject | Select, flagged, quote 00000238 | Lock, second request, past date, reject + resubmit |
| DEMO RS16 H05 - Special characters and Arabic in the form | Select, flagged, Tint spec with `& — <front + rear> "OEM"` + Arabic, quote 00000239 | Form text |
| DEMO RS16 H06 - Change after approval | Select, flagged, quote 00000240 | Stale form / duplicate form |
| DEMO RS16 H07 - Deal at Commit (no action) | Commit, flagged, quote 00000241 | Stage window |

### What to do, step by step

**H01 — the main path (FR1, FR2, FR3, FR4)**
1. Rep → H01 → header **Add Products** → tick *Ferrari Roma Car Cover*, *Ferrari Window Tint -
   Premium 20%*, *Ferrari Pre-Delivery Inspection Service* → **Next** → **Next** → **Finish**.
   *Also look:* is *Ferrari Dealer Prep & Registration* offered? *Expect:* yes. *You will see:* no
   (BUG-RS16-06).
2. Opportunity → **Products** (right-hand column) → **View All** → Tint row ▾ → **Edit** → tick
   **Requires Internal Requisition?**, type a spec in **Customization Description** → **Save**.
   Do the same for the PDI row. Amount should read **AED 371,700.00**.
3. **Show more actions ▾ → Create Quotation** → *Customer Quotation* → **Next** → **Finish**.
4. **Show more actions ▾ → Request Internal Requisition** → a date two weeks ahead → **Next**.
   *See:* "…submitted to your Sales Manager for approval."
5. Try **Edit** → change *Next Step* → **Save**. *Expect:* saved. *You will see:* "This record is
   locked…" (BUG-RS16-02).
6. Log in as the Manager → **Items to Approve** (App Launcher) → open H01. *Expect:* the vehicle and
   the jobs. *You will see:* only name, owner and date (BUG-RS16-05). **Approve**.
7. Back as the Rep → H01 → **Notes & Attachments** → open the form.
   - *Expect:* Vehicle "Ferrari 296 GTB …" and quote 000002xx. *You will see:* **Vehicle: null null**
     and **Quote Number: -** (BUG-RS16-01).
   - Both specs and your date are printed ✓.
8. Sending the form to After Sales is manual for now. Read the rep's *Approved* email, which gives
   the instruction. Then look for **Send Email** on the Activity tab and in the header menu. It is
   not on the page.
9. Details tab → look for *Internal Requisition Status*. *You will see:* not there (BUG-RS16-10).
   The Approval History list shows the approval.

**H02 / H03 — the gates.** Rep → **Request Internal Requisition**.
- H02: *"No accessories or PDI requirements are selected on this Opportunity."*
- H03: *"No Quote has been created on this Opportunity yet."*

**H04 — while pending, and rejection**
1. Rep → **Request Internal Requisition** → date **01 Sep 2026** (in the past) → **Next**.
   *Expect:* refused. *You will see:* submitted (BUG-RS16-08).
2. Run **Request Internal Requisition** again → any date → **Next**. *You will see:* "Something went
   wrong … ENTITY_IS_LOCKED" (BUG-RS16-07).
3. Products → **Edit** any line → **Save**: "This record is locked" (BUG-RS16-02).
4. Manager → **Reject** with a reason. Rep → bell icon: "…was rejected." without the reason, and no
   email (BUG-RS16-09). The reason is in the deal's **Approval History** ✓.
5. Rep → request again → submitted ✓ (history keeps the rejection).

**H05 — form text.** Request → Manager approves → Rep opens the form. The Tint line reads
*"Roof Rails & Cross-Bars — M Sport "OEM" /"*: `<front + rear>` and the Arabic are missing
(BUG-RS16-04).

**H06 — change after approval**
1. Request → Manager approves → the form is attached.
2. Rep → edit the Tint spec and flag the Car Cover. The status stays Approved and the form is
   unchanged (BUG-RS16-03).
3. Request again → Manager approves → Notes & Attachments now holds **two** identical "APPROVED"
   forms.

**H07 — stage window.** Rep → **Show more actions ▾**: only *Generate Sales Order* and *Cancel Sales
Order*; no *Request Internal Requisition* (GAP-RS16-01).

**Also:** log in as `alfardan.qa.showroommanager2@…` and search *DEMO RS16*. Nothing should be found,
and nothing is ✓.

### Scorecard — fill in as you go

| # | Check | Expected | You saw | Ticket |
|---|---|---|---|---|
| 1 | Dealer Prep offered by Add Products | Offered | | BUG-RS16-06 |
| 2 | No-items and no-quote gates block | Blocked with message | | — |
| 3 | Request submits, manager notified | Pending Approval | | — |
| 4 | Deal editable while pending | Saves | | BUG-RS16-02 |
| 5 | Manager sees vehicle and jobs | Shown | | BUG-RS16-05 |
| 6 | Form attached on approval | In Notes & Attachments | | — |
| 7 | Form names the vehicle and quote | Make/model, quote no. | | BUG-RS16-01 |
| 8 | Form prints the full spec (H05) | Exact text | | BUG-RS16-04 |
| 9 | Manual send route (Send Email) available | Available | | — (manual, agreed) |
| 10 | Status visible on the deal | Shown | | BUG-RS16-10 |
| 11 | Past date refused (H04) | Refused | | BUG-RS16-08 |
| 12 | Second request while pending (H04) | Plain message | | BUG-RS16-07 |
| 13 | Rejection reason reaches the rep (H04) | Email + notification with reason | | BUG-RS16-09 |
| 14 | Change after approval (H06) | Re-approval required, one current form | | BUG-RS16-03 |
| 15 | Action at Commit (H07) | Per BA decision | | GAP-RS16-01 |
| 16 | Other BU cannot see the deal or form | No access | | — |

---

## Records left in the org as evidence

| Record | State | Evidence for |
|---|---|---|
| QA RS16 T01 `006FV00BzHIbuJIYUZ` | Approved, form `069FV007cT5PEjcYQG` | BUG-RS16-01, -02, -05, -10 |
| QA RS16 T02 `006FV00BzHIg6SKYUZ` | Not flagged | gate |
| QA RS16 T03 `006FV00BzHIkIbMYUV` | No quote | gate |
| QA RS16 T04 `006FV00BzHIoUkOYUV` | Rejected, resubmitted (Pending) | BUG-RS16-09 |
| QA RS16 T05 `006FV00BzHIsgtQYUR` | Approved with 01 Sep 2026 | BUG-RS16-07, -09 |
| QA RS16 T06 `006FV00BzHIwt2SYUR` | Approved twice, two forms | BUG-RS16-03 |
| QA RS16 T07 `006FV00BzHJ15BUYUZ` | Approved, form `069FV007caVKYmqYAH` | BUG-RS16-04 |
| QA RS16 T08 `006FV00BzHJ5HKWYU3` | Commit | GAP-RS16-01 |
| QA RS16 T09 `006FV00BzHJ9TTYYU3` | Untouched spare | — |
| QA RS16 T10 `006FV00BzHJDfcaYUD` | Vehicle only | BUG-RS16-06 |
| QA RS16 T12 `006FV00BzHJHrlcYUD` | Status set to Pending Approval by rep API, no approval | API-only note |

## Org configuration changed during testing
None. Records were created through admin Apex, mirroring what Add Products and Create Quotation
stamp; T01 was built fully through the UI. Three approvals (T05, T06, T07) were made through the
Sales Manager's own API session.
