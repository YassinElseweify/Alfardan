# Retest — LFRDN bugs in "DEPLOYED TO QA" (2026-09-26)

**Scope:** the 25 LFRDN bugs in status *DEPLOYED TO QA* on 26-Sep-2026.
**How:** Lightning UI as the Sales Representative (QA SalesRep2) on fresh deals. Admin was used only for setup, for access checks (`UserRecordAccess`) and to read PDF text. The persona API login is blocked by LOGIN_MUST_USE_SECURITY_TOKEN.
**Retest records:** customer *QA RT26 Customer - Hamad Al-Marri*.
- D1 `006FV00Bz976rqOYEQ`, with HO-00065 `a0SFV001RU7AlNc2YK`, now Closed Won.
- D2 `006FV00Bz97B3zQYES`, with HO-00066 `a0SFV001RVQNqCK2Y1`.
- D3 `006FV00Bz972fhMYEQ`, with Quote 00000225.

**Screenshots:** `screenshots/RETEST-2026-09-26/`

## Verdicts

| Ticket | Verdict | Evidence |
|---|---|---|
| LFRDN-672 Vehicle order status not shown | **Fixed** | Vehicle Order State and Brand Sub-status are on the Vehicle page for the rep. `672-…` |
| LFRDN-674 Sales Order missing year/chassis | **Fixed** | Model Year and Chassis now fall back to other fields. Which source is correct is still a BA decision. |
| LFRDN-697 Traffic/Insurance upload never ticks its flag | **Fixed** | The rep uploads both files, both rows tick, and there is no error. `697-…` |
| LFRDN-698 Sold vehicle offered again | **Fixed** (verified 24/25-Sep) | — |
| LFRDN-699 Delivery Note never generated | **Fixed** | The rep's Generate Documents run produces the Delivery Note. `699-…` |
| LFRDN-700 Completion raw error | **Fixed** | — |
| LFRDN-701 Rep can tick document flags | **Fixed** | The flags are read-only in the rep's edit form, and 697/699 still set them. `701-…` |
| LFRDN-702 / 703 / 704 / 705 / 707 | **Fixed** (verified 24-Sep) | — |
| LFRDN-706 Handover missing Account/Contact/Vehicle/Invoice | **Fixed** | HO-00065 and HO-00066 have all four filled. |
| LFRDN-709 Other BU can read handover/invoice/payment/reservation | **Fixed** | UserRecordAccess for the other-BU user returns no access on all four objects. Credit Note is still Public R/W, tracked in LFRDN-741. |
| LFRDN-710 Handover set Completed by hand | **Fixed** | Setting Completed manually is refused, and an unsigned handover stays Pending. `710-…` |
| LFRDN-713 No post-delivery follow-up task | **Fixed** | The task goes to the Customer Experience queue with the contact. Edge case: a handover date entered retroactively before completion creates no task. |
| LFRDN-714 In Progress with no handover date | **Fixed** | Saving without a date shows a date-required error. `714-…` |
| LFRDN-715 No field history on handover | **Fixed** | History is tracked. |
| LFRDN-716 No task to upload the signed documents | **Fixed** | The Upload task is created. |
| LFRDN-717 Repair remarks not printed | **Fixed** | Remarks appear on the Vehicle Repair Disclaimer. |
| LFRDN-718 Request Closure button label | **Fixed** | The button reads "Submit". `718-…` |
| LFRDN-711 Sign-off without a signed document | **Not fixed → To Do** | Sign-off is accepted when the handover holds only the system-generated tagged PDFs, with no signed scan, and D1 closed Won. `711-…` |
| LFRDN-708 Agreements blank and not regenerable | **Partially fixed → To Do** | Vehicle and customer now print. The agreements are not regenerated after date and location are set, so they still read "Handover: - Location: -". A duplicate disclaimer is created after the remarks change. |
| LFRDN-712 No auto-generation / single-document generate | **Partially fixed → To Do** | Documents now generate automatically at Take the Keys. Generating a single document is not built. |
| LFRDN-695 Vehicle change keeps old quote pricing | **Partially fixed, with a regression → To Do** | The "pick a different one" option has been removed (`695-…`), but Create Reservation is now broken for the rep (`671-…`, a regression of LFRDN-671). 7-Day: the deposit field never appears, because it depends on the hidden TradeInAsDepositField = false. 3-Day: fails for the rep only (works as admin); cause not yet isolated. |

**Totals:** 21 fixed · 4 moved back to To Do (695, 708, 711, 712). Each of the four has a comment and went DEPLOYED TO QA → WAITING FOR CUSTOMER INPUT → To Do.

## Moved to Done (26-Sep)

15 clean fixes went DEPLOYED TO QA → QA IN PROGRESS → Done: 672, 697, 699, 700, 701, 702, 703, 705, 706, 710, 714, 715, 716, 717, 718.
Six fixed tickets were left in DEPLOYED TO QA because each has an open point:
- 674: Model Year / Chassis source still needs a BA decision.
- 713: retroactive-date edge case.
- 709: credit notes are tracked separately in LFRDN-741.
- 704: Closed Won is still possible without a Sales Order (BA question).
- 707: Showroom Manager → Brand Manager routing crosses branches (LFRDN-728).
- 698: vehicles sold before the fix were not backfilled.
