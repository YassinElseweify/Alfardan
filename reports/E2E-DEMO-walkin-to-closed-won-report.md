# Retail cycle end to end — walk-in to Closed Won — mock demo report

**Date:** 2026-09-26 · **Org:** Al-Fardan QA sandbox · **Tickets:** `tickets/E2E-DEMO/README.md` (draft, BUG-E2E-01 … 05)
**Screenshots:** `screenshots/E2E-DEMO/` · **Purpose:** rehearse the demo and find what will not go smoothly.

---

## Section 1 — Summary of what was done

### Who starts the deal: Sales Walk-In vs Service Walk-In

Both are actions on the customer's **Contact** (**Show more actions ▾**). Neither is run by the CRM
agent; CRM creates deals from leads (ALF-RS-01 FR2).

| | **Sales Walk-In** | **Service Walk-In** |
|---|---|---|
| Situation | Customer walks into the **showroom** | Customer is at **service reception** and shows interest in a new car |
| Run by | **Sales Receptionist** (permission group `AF_PSG_Receptionist_Sales`) | **Service Receptionist** (`AF_PSG_Receptionist_Service`). No such user exists in QA. |
| Captures | Brand, Showroom, Source of Business, **Sales Representative** | Brand of Interest, **Preferred Dealership**, Source of Business |
| Deal goes to | The chosen **Sales Rep**, with a task and a notification | The **Showroom Manager** of that dealership, with a *"contact within 15 minutes"* task. The manager then hands it to a rep. |
| Today | Creates the deal but shows an **error** (BUG-E2E-01) | **Fails**, and no deal is created (BUG-E2E-02) |

BRD §10.1 ALF-RS-01 FR4 and FR5, p.30–31.

### The cycle as the users run it

| # | Step | Persona | Where |
|---|---|---|---|
| 1 | Walk-in → deal at *Consider* | Receptionist | Contact → Sales / Service Walk-In |
| 2 | Pick the car (and line package) | Rep | Opportunity → **Select Vehicle** |
| 3 | *Consider → Explore*: a test drive and an empty trade-in are created automatically | Rep | Path → Mark Stage as Complete |
| 4 | Book and complete (or refuse) the test drive | Rep | Test Drive → **Select Demo Vehicle** → then Edit (Status / Result / Feedback) |
| 5 | Trade-in: add the vehicle and a 360° photo → **Submit for Evaluation** | Rep | Trade In → Related → *Trade In Items* **New** |
| 6 | Value the car | Used Car Team | Trade In Item → Edit → *Initial Value* |
| 7 | Approve the valuation | Used Car Team queue | Items to Approve |
| 8 | Record the customer's acceptance | Rep | Trade In Item → *Trade-In Outcome* **Accepted** |
| 9 | *Explore → Select*, add accessories, **Create Quotation** | Rep | Opportunity |
| 10 | Discount (optional) → approval chain | Rep → managers | Quote → Edit → *Discount Amount* |
| 11 | **Start Sync** the quote (needed for Commit) | Rep | Quote → Show more actions ▾ → Start Sync |
| 12 | **Create Reservation** (3-Day / 7-Day with deposit) | Rep | Quote → Create Reservation |
| 13 | Deposit below threshold → manager approves | Sales/Brand Manager | Items to Approve |
| 14 | **Get Payment** | Rep | Invoice → Get Payment |
| 15 | Payment documents (Bank LPO for a bank transfer) | Rep | Payment → Related → Required Documents |
| 16 | Reservation documents → **Generate Reservation Contract** | Rep | Reservation → Related / header |
| 17 | *Select → Commit* | Rep | Path |
| 18 | **Generate Sales Order** | Rep | Opportunity → Show more actions ▾ |
| 19 | *Commit → Take the Keys*: the Handover is created and the 5 agreements generated | Rep | Path |
| 20 | Handover: date, time, location, remarks → **Generate Documents** (Delivery Note) → Traffic and Insurance forms → sign-off | Rep | Handover |
| 21 | **Closed Won** automatically on sign-off | System | — |

### Deals run

| Deal | Scenario | Result |
|---|---|---|
| **C1** Faisal Al-Thani `006FV00BzGl6wCKYUY` | Sales Walk-In · test drive booked and completed · no trade-in · tint added · 7-Day, **AED 40,000 deposit (≥10%) → auto-approved** · Bank Transfer | **Closed Won**, after a workaround (BUG-E2E-03) |
| **C2** Mariam Al-Sada `006FV00Bzwt3cmKYEQ` | Sales Walk-In · test drive completed · **trade-in** Range Rover Sport valued at 135,000 · **discount AED 16,000** → SBM → GM → CEO · 7-Day, **AED 10,000 deposit (below 10%) → manager approval** | **Closed Won**, but the price is wrong (BUG-E2E-04) |
| **C3** Omar Al-Kubaisi `006FV00BzvT99XQYEZ` | Sales Walk-In (source *Referral*) · **test drive refused** · **3-Day reservation, no deposit** | **Closed Won** |
| **C4** Hessa Al-Mannai `006FV00C05Ovd5wYEB` | **Service Walk-In** | Walk-in failed (BUG-E2E-02). An admin stand-in deal was created as the flow would; the Showroom Manager's **Change Owner** to the rep works. Left at *Consider*. |
| **C5** Jassim Al-Obaidly `006FV00BzRzy6HUYUY` | Sales Walk-In → customer chose another brand → **Request Closure** → manager approves | **Closed Lost** |

**Personas.** Everything was done in the Lightning UI as the persona, except for three substitutions:
- **Reservations.** Created by the rep's own API session with exactly the fields the Create
  Reservation flow sends, because the action fails for the rep (LFRDN-695).
- **C4's deal.** Created by an administrator, because Service Walk-In fails.
- **Service Walk-In attempt.** Made after temporarily adding `AF_PSG_Receptionist_Service` to the
  Sales Receptionist. No Service Receptionist exists, and all 10 licences are used. Removed afterwards.

Read-back, debug logs and metadata were used to confirm and root-cause each failure.

### Demo verdict

**Not smooth yet.** The sale can be completed, but a live demo would hit these:
1. **The very first click errors.** Sales Walk-In shows *"Something went wrong"* (BUG-E2E-01).
   Service Walk-In cannot be demonstrated at all (BUG-E2E-02).
2. **Create Reservation fails for the rep** with or without a trade-in (LFRDN-695, root cause now
   identified). There is no in-UI workaround for a rep.
3. **The deal may not close** after the handover if a payment document was forgotten, with no message
   (BUG-E2E-03).
4. **Discount + trade-in gives the wrong price** (BUG-E2E-04). Anyone checking the numbers on screen
   will see it.

Everything else ran cleanly on the first try:
- Select Vehicle, test drive booking and completion, the trade-in evaluation and approval chain
- Create Quotation, Start Sync, reservation approval, Get Payment, required-document checklists
- Reservation Contract, Sales Order, automatic Handover with all five agreements, Delivery Note,
  Closed Won on sign-off, Closed Lost via approval

The sold cars are no longer offered in the Vehicle Finder.

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Evidence / finding |
|---|---|---|---|
| E2E-01 | Receptionist creates a showroom walk-in and assigns a rep | **FAIL** | Deal created and assigned, but error screen, unlinked task, no notification. 4 of 4 (**BUG-E2E-01**). |
| E2E-02 | Service walk-in routed to the dealership's Showroom Manager | **FAIL** | Unhandled fault, no deal (**BUG-E2E-02**). Sales Receptionist without the permission sees *"not enabled for your Business Unit"* (correct). |
| E2E-03 | Showroom Manager hands a service walk-in to a rep | **PASS** | C4: Change Owner → QA SalesRep2; rep got an *"Opportunity Assigned to You"* task. |
| E2E-04 | Select Vehicle with line package | **PASS** | C1: E2E-01 + GTS Package → AED 398,300. |
| E2E-05 | Explore creates a test drive; booking a demo car; completing it | **PASS** | TD-00201 auto-created; booked 26 Sep 5:00 PM Lusail; completed with feedback. The 12 demo cars are indistinguishable (all *"Ferrari 296 GTB, Rosso Corsa Red"*). |
| E2E-06 | Refused test drive releases the stage | **PASS** | C3: TD-00203 *Refused* + remarks → moved to Select. |
| E2E-07 | Trade-in: vehicle details + 360° photo gate, submit for evaluation | **PASS** | Submit refused until an item and photo exist; then *"Submitted"*. |
| E2E-08 | Used Car Team valuation and approval | **PASS** | Initial Value 135,000 → approval to the *AF Used Car Team* queue → approved. |
| E2E-09 | Accepted trade-in appears on the quote as a deduction | **PARTIAL** | Only after the rep separately accepts the vehicle line; header auto-*Accepted*, stays *Under Approval* (**BUG-E2E-05**). |
| E2E-10 | Create Quotation carries vehicle and lines | **PASS** | Quotes 00000242–244 with the specific vehicle on the line. |
| E2E-11 | Discount routed per DoA tiers | **PARTIAL** | Routed and approved, but the % is computed after the trade-in (Tier 3 instead of 2), and each step goes one level higher than the tier's label (Tier 3 reached the CEO). See §3. |
| E2E-12 | Approved discount applied to the price | **FAIL** | 16,000 approved, 24,216.64 applied (**BUG-E2E-04**). |
| E2E-13 | Commit needs a synced quote; Start Sync | **PASS** | Refused with *"Commit stage requires a synced Quote."*; after Start Sync, Commit works. Start Sync is in the Quote's overflow menu. |
| E2E-14 | Create Reservation, 7-Day with deposit | **FAIL** | No deposit field; *"We couldn't create the reservation."* Also with an approved trade-in (**LFRDN-695**). |
| E2E-15 | Create Reservation, 3-Day | **FAIL** | Same failure (**LFRDN-695**). |
| E2E-16 | Deposit ≥ threshold auto-approves; below threshold goes to the manager | **PASS** | C1 40,000 on 399,500 → *Reserved / Not Required*. C2 10,000 on 239,083 → *Pending Approval* → approved by QA SalesBrandManager2 → *Reserved*. Ferrari threshold is 10% (`AF_IsPercentage__c`). |
| E2E-17 | Reservation Required Documents and contract | **PASS** | C1: 4 docs. C2 (manager-approved): 5 docs incl. Approval Reference. C3 (3-Day): 3 docs. Contracts generated. |
| E2E-18 | Get Payment → invoice Fully Paid | **PASS** | PAY-00093/94/95 *Paid / Verified*, Bank Transfer; invoices Fully Paid. Pulls the full balance, not the deposit (known). |
| E2E-19 | Generate Sales Order | **PASS** | All three generated. The confirmation screen and PDF show **QAR** (LFRDN-678). The Sales Order prints only the total, with no line, trade-in or discount breakdown, and *Quote Number "-"*. |
| E2E-20 | Take the Keys → Handover with all links and 5 agreements | **PASS** | HO-00067/68/69 with Vehicle, Contact, Account, Invoice; 5 agreements auto-generated. |
| E2E-21 | Delivery Note, Traffic and Insurance uploads, sign-off → Closed Won | **PASS** (C2, C3) / **FAIL** (C1) | C2/C3 closed Won on sign-off. C1 stayed open because the Bank LPO was missing, with no message and no manual close (**BUG-E2E-03**). The repair disclaimer is duplicated after remarks are added (LFRDN-708). |
| E2E-22 | Request Closure → Closed Lost | **PASS** | C5: reason *Chose a Different Brand* → QA SalesBrandManager2 approved → *Closed Lost*. |
| E2E-23 | A sold car is not offered again | **PASS** | E2E-01/02/03 absent from the Vehicle Finder; E2E-04/05 listed. Inventory fields still read *In Stock / Available for Sale* (§3). |

**Not verified:**
- Time-based items: reservation expiry, the 2-day follow-up task, trade-in escalation.
- Keyloop integrations.
- Email delivery of every notification (spot-checked only).

---

## Section 3 — BA gaps and demo risks to raise

1. **No Service Receptionist user, and only Alsadd has a Showroom Manager.** Even once BUG-E2E-02 is
   fixed, a Service Walk-In to any other dealership stops at *"No Showroom Manager is currently
   assigned for this dealership"*. Also, a Ferrari service walk-in is routed to the Alsadd
   (Automobiles) manager. Decide the dealership-to-brand mapping and create the users.
2. **One Manager field drives every approval.** Closed Lost, cancellation, requisition, reservation
   and the first discount step all go to the submitter's Manager. The discount chain then climbs each
   approver's Manager. With the QA hierarchy (Rep → Sales/Brand Manager → GM → CEO), every discount
   tier lands **one level higher** than its label: a Tier 3 discount needed the **CEO**. With Rep →
   Showroom Manager, the discount chain is right but other approvals go to the Showroom Manager.
   Decide the approver model per process; the DoA matrix needs named roles, not "Manager of Manager".
3. **The discount % base.** Should the percentage (and tier) be measured on the car price or on the
   net after trade-in? Today it uses the net (see BUG-E2E-04 for the pricing error).
4. **Every deal gets a trade-in.** Moving to Explore creates an empty trade-in and a task, and **emails
   the customer "You Could Trade In Your Current Car"**, even when they have none. Confirm this is
   wanted.
5. **The Used Car Team approves its own valuation.** The trade-in value is approved by the same queue
   that entered it. BRD ALF-RS-04 FR6 (p.38) says only *"route the trade-in valuation through an
   approval workflow"*. Confirm who approves.
6. **Delivered cars keep *In Stock / Available for Sale*.** They are correctly hidden from the Vehicle
   Finder, but inventory reports will count them. Decide the post-delivery status (Keyloop-mastered?).
7. **The Sales Order shows only the total.** The customer-signed contract does not list the vehicle
   price, package, trade-in credit or discount.
8. **Demo vehicles cannot be told apart** in the booking screen (12 identical cards).
9. **Get Payment always records the full balance** (known). A deposit-only payment cannot be shown.

---

## Section 4 — Walkthrough by process step

1. **Walk-in (ALF-RS-01).** Receptionist → Contact → Sales Walk-In → Ferrari / Lusail / Showroom
   Walk-in → QA SalesRep2 → error screen, but the deal exists (**BUG-E2E-01**). Service Walk-In →
   Ferrari / Alsadd → unhandled fault (**BUG-E2E-02**).
2. **Select Vehicle (RS-05).** Rep → Select Vehicle → Ferrari 296 GTB → STK-E2E-01 → GTS Package →
   Confirm Line → AED 398,300 ✓.
3. **Test drive (RS-03).** Explore → TD auto-created → Select Demo Vehicle → Lusail 5:00 PM → Confirm
   Booking → *Scheduled*; Edit → *Completed* + feedback ✓. C3: *Refused* + remarks ✓.
4. **Trade-in (RS-04).** Trade In → Related → Trade In Items → New (VIN, make, model, year, plate,
   condition, mileage, inspection, asking 150,000) → Files: 360° photo → Submit for Evaluation ✓.
   Used Car Team → Initial Value 135,000 → approve ✓. The rep must accept the vehicle line before the
   deduction appears (**BUG-E2E-05**).
5. **Quotation and discount (RS-06/07).** Create Quotation ✓. Discount Amount 16,000 → 6.08% Tier 3 →
   SBM → GM → CEO approve → **24,216.64 applied** (**BUG-E2E-04**).
6. **Commit gate.** Refused until **Start Sync** ✓.
7. **Reservation (RS-08).** Create Reservation fails for every deal (**LFRDN-695**). Workaround used:
   the same record from the rep's API session. Above threshold → Reserved; below → manager approval ✓.
   Documents and contract ✓.
8. **Payment (RS-09/11).** Get Payment → Paid / Verified, invoice Fully Paid ✓. A Bank Transfer needs
   a **Bank LPO** on the Payment before the deal can close.
9. **Sales Order (RS-10).** Generate Sales Order ✓ (QAR label; total only).
10. **Handover and close (RS-11/12).** Take the Keys → HO created with 5 agreements ✓ → schedule →
    Delivery Note ✓ → Traffic/Insurance ✓ → Physically Signed → **Closed Won** ✓ (C2, C3). C1 stayed
    open because the LPO was missing, until the handover was re-saved (**BUG-E2E-03**).
11. **Lost deal.** Request Closure → approve → Closed Lost ✓.

---

## Section 5 — Hands-on: rehearse the demo yourself

### Logins (Automotive app for all except the receptionist)
- **Receptionist:** `salesreceptionist.v2.20260823@alfardan.com.qa.qa` / `Arcsen@2030!`. This user
  lands in the *Sales* app.
- **Rep:** `alfardan.qa.salesrep2@…`
- **Sales/Brand Manager:** `alfardan.qa.salesbrandmanager2@…`
- **GM:** `alfardan.qa.generalmanager2@…`
- **CEO:** `alfardan.qa.ceo2@…`
- **Used Car Team:** `alfardan.qa.usedcarteam2@…`

All passwords except the receptionist's are `Arcsen@2026!`. Two-step login; *Change Your Password* →
**Cancel**. Sample PDFs to upload: `demo-docs/e2e/`.

### Records created for you (no deals yet — your demo starts at the walk-in)

| Customer (search "DEMO E2E") | Contact | Use it for | Car to pick |
|---|---|---|---|
| DEMO E2E H1 Customer - Nasser Al-Attiyah | Nasser Al-Attiyah | Cash deal, deposit **above** 10% | STK-DEMO-E2E-01 (Rosso Imola) |
| DEMO E2E H2 Customer - Aisha Al-Marri | Aisha Al-Marri | Trade-in + discount + deposit **below** 10% | STK-DEMO-E2E-02 (Giallo Modena) |
| DEMO E2E H3 Customer - Yousef Al-Hajri | Yousef Al-Hajri | Test drive refused, 3-Day reservation | STK-DEMO-E2E-03 (Argento Nurburgring) |
| DEMO E2E H4 Customer - Latifa Al-Kuwari | Latifa Al-Kuwari | Service Walk-In (to see the failure) | — |
| DEMO E2E H5 Customer - Khalifa Al-Naimi | Khalifa Al-Naimi | Lost deal via Request Closure | STK-DEMO-E2E-04 (Blu Corsa) |

### Demo run-sheet — the safe path and what to expect

1. **Receptionist → Contact → Show more actions ▾ → Sales Walk-In** → Ferrari, a showroom, Showroom
   Walk-in → **Next** → QA SalesRep2 → **Next**. *You will see an error screen* (BUG-E2E-01). The deal
   **was** created. **Do not run it again.** Switch to the rep and open *Opportunities*.
2. **Rep → Select Vehicle** → Ferrari 296 GTB → your car → **Confirm Line**.
3. **Path → Mark Stage as Complete** (Explore). Open the new **Test Drive** → **Select Demo Vehicle** →
   slot → **Confirm Booking**. Then **Edit** → Status/Result *Completed* + Product Feedback. For H3,
   use *Refused* + Refused Remarks.
4. **H2 only — trade-in.**
   - Opportunity → **Trade Ins** → open the APL record → **Related** → *Trade In Items* **New**. Enter
     Type *Vehicle*, VIN, Make, Model, Year, Plate, Condition, Usage, Inspection Done ✓ + notes,
     Source, Asking Value → Save.
   - Open the item → **Related** → upload any image (the 360° photo).
   - Trade In → **Submit for Evaluation**.
   - As **Used Car Team**: open the item → Edit → *Initial Value* → Save → **Items to Approve** →
     Approve.
   - As the **rep**: item → Edit → **Trade-In Outcome = Accepted** → Save. *Do this before step 5*,
     or the quote will have no deduction until you do (BUG-E2E-05).
5. **Path** → Select → **Add Products** (e.g. tint) → **Show more actions ▾ → Create Quotation** →
   Customer Quotation.
6. **H2 only — discount.** Quote → **Edit** → *Discount Amount* (try **8,000**, which lands in Tier 2
   on a 263,300 net) → Save → approve in **Items to Approve** as each approver in turn. *Check the
   Grand Total:* it comes off by more than you entered (BUG-E2E-04). **Avoid showing a discount on a
   trade-in deal.**
7. **Quote → Show more actions ▾ → Start Sync** → Sync. *Needed before Commit.*
8. **Quote → Create Reservation.** *Expect: contract type plus a deposit field. You will see: no
   deposit field, and "We couldn't create the reservation"* (LFRDN-695). **This blocks the live
   demo** until the fix is deployed. To continue a rehearsal, ask me to create the reservation from
   the rep's session, as I did for C1–C3.
9. **Invoice** (Opportunity → Invoice Summary) → **Get Payment** → any ID (e.g. `KL-PAY-DEMO-01`) →
   *No, I'm done*. Then **open the Payment → Related → Bank LPO → Upload**. *Do this now* (BUG-E2E-03).
10. **Reservation → Related → Required Documents** → upload each → header **Generate Reservation
    Contract**.
11. **Path** → Commit → **Show more actions ▾ → Generate Sales Order** → *Yes, full payment…* → Next.
12. **Path** → Take the Keys → open the **Handover** → **Edit**: Location, Status *In Progress*,
    Date/Time (clear the pre-filled time first), Repair Remarks → Save → **Generate Documents** →
    Related → upload **Traffic Form** and **Insurance Form** → Edit → *Customer Sign-Off* **Physically
    Signed** → Save.
    - *Expect:* Opportunity **Closed Won**.
    - If it is still *Take the Keys*, check the Bank LPO, then re-save the handover (BUG-E2E-03).
13. **H5:** after Select Vehicle, **Request Closure** → reason → Submit → as Sales/Brand Manager
    approve → **Closed Lost**.
14. **H4:** as the receptionist, **Service Walk-In** → *"not enabled for your Business Unit"*. The
    Service Receptionist persona doesn't exist, and the flow fails even when enabled (BUG-E2E-02).

### Scorecard

| # | Step | Expected | You saw | Ticket |
|---|---|---|---|---|
| 1 | Sales Walk-In | Confirmation screen | | BUG-E2E-01 |
| 2 | Service Walk-In | Deal to Showroom Manager | | BUG-E2E-02 |
| 3 | Select Vehicle + test drive | Works | | — |
| 4 | Trade-in → quote deduction | Deduction on quote | | BUG-E2E-05 |
| 5 | Discount with trade-in | Exactly the approved amount off | | BUG-E2E-04 |
| 6 | Start Sync → Commit | Works after sync | | — |
| 7 | Create Reservation | Reservation created | | LFRDN-695 |
| 8 | Deposit ≥10% / <10% | Auto / manager approval | | — |
| 9 | Get Payment → Fully Paid | Works | | — |
| 10 | Sales Order | Generated | | LFRDN-678 (QAR) |
| 11 | Handover → Closed Won | Closes on sign-off | | BUG-E2E-03 |
| 12 | Request Closure → Closed Lost | Works | | — |

---

## Records left in the org

| Record | State |
|---|---|
| E2E C1 `006FV00BzGl6wCKYUY` — TD-00201, Quote 00000242, RES-00227, INVM-00124, PAY-00093, HO-00067 | Closed Won |
| E2E C2 `006FV00Bzwt3cmKYEQ` — TD-00202, APL-000000133 / APLI-000000095, Quote 00000243, RES-00228, INVM-00126, PAY-00094, HO-00068 | Closed Won (239,083.36, over-discounted) |
| E2E C3 `006FV00BzvT99XQYEZ` — TD-00203 (Refused), Quote 00000244, RES-00229, INVM-00125, PAY-00095, HO-00069 | Closed Won |
| E2E C4 `006FV00C05Ovd5wYEB` | Admin stand-in for Service Walk-In, reassigned to the rep, *Consider* |
| E2E C5 `006FV00BzRzy6HUYUY` | Closed Lost |
| Vehicles E2E-01…05 | 01–03 sold; 04–05 available |

## Org configuration changed during testing

- `AF_PSG_Receptionist_Service` was temporarily assigned to the Sales Receptionist to attempt Service
  Walk-In. **Removed** the same session (0 assignments remain).
- The debug level `7dla3000JWPwBZ2AYN` was raised to FINEST for diagnosis.
- Trace flags were added for the rep and the receptionist; both expire after 1 hour.
- Test reservations created and deleted while isolating LFRDN-695: two reservations and one invoice
  on C1, with the vehicle status reset.
