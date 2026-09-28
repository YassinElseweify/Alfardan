# Deliverable formats

What comes out of a testing session. Two artifacts — a five-section
story report and a single tickets README — each with a fixed shape so
they stay comparable across stories, sessions and engagements.

---

## A. The 5-section story report

One per user story, written to `reports/<STORY-ID>-report.md`. Always
these five sections, in this order, never collapsed or reordered.

Bugs are **not** a standalone section of the report. They are surfaced
in Section 4 at the requirement they break, and written up in full in
the tickets README (§ B).

### Section 1 — Summary of what was done

What was tested, which personas, which harness (API / UI / both), how
many test cases ran, how many were added during execution, and the
headline verdict. Short — this is the section someone reads if they
read nothing else.

### Section 2 — Test cases executed

Every test case in the batch, including the ones that passed, saying
what each was testing and what happened.

| TC | What it tests | Result | Finding |
|---|---|---|---|
| TC-001 | … | PASS | … |
| TC-004 | … | FAIL | … |

Verdicts: `PASS` / `FAIL` / `PARTIAL` / `Not verified`. **Every row
carries concrete evidence** — record id, exact error text, screenshot
filename. "Works as expected" is not a finding. Test cases added during
execution are marked as added.

Close the section with a **Not independently verified** list naming
*why* each item could not be checked (Dashboard component, Profile
access, real mailbox delivery, persona blocked from UI), so the user
knows exactly what still needs a human.

### Section 3 — BA / requirement gaps

Things that are **not specified**: the build cannot be called wrong
because the documents never said what right was. Ambiguities,
contradictions between BRD and solution design, scenarios neither
document addresses, placeholder values awaiting business confirmation.

These are not bugs and must never be mixed in with them — they need a
business decision, not a developer. Each entry names what is undefined,
where the documents fall silent or disagree (with quotes), and what
decision is needed from whom.

### Section 4 — Walkthrough by functional requirement and acceptance criterion

Organised by **requirement**, not by test case id. This is what lets
the user connect defects back to the BRD, and follow the same path in
their own UI. For each FR and AC:

- the **steps performed** — a click path (menu → action → option), and
  the API calls made where the check was API-side;
- the **records created or touched**, by name and id, so the user can
  open the same ones;
- **what happened**, and whether that FR/AC passes;
- **the bug stated at the point it is hit** — "at this step you will
  see `<literal error>`; this is `BUG-<STORY>-NN`" — so each defect is
  tied to the requirement it breaks.

### Section 5 — Hands-on

Explain the story and how it was implemented, so the user understands
the flow and not just the verdict. Then **build a fresh set of records
so they can run the story themselves from the beginning**, and script
the clicks.

The record set:
- **one record per scenario**, covering every FR and AC — happy path,
  each negative/edge case, and each known defect;
- **genuinely clean** — no child records (quotes, approvals) already
  created, so the user starts where a real user would;
- **owned by the correct persona**, at whatever stage/status makes the
  entry point actually visible (watch for stage-gated actions and
  validation rules that block the setup);
- **obviously named** — e.g. `DEMO <STORY-ID> NN - <purpose>` so one
  search returns them all;
- **never shared between two scenarios** where one mutates state the
  other depends on (e.g. a vehicle's stock status).

Then give the user:
- which **app** and which **persona login**, and any login friction to
  expect;
- the exact **click path** (menu → action → option), not just a URL;
- for each FR/AC: which record to use, what to do, **what they should
  see**, and **what they will actually see** when a defect is present;
- expected figures (totals, field values) so they can confirm without
  guessing;
- a short **scorecard table** at the end to fill in as they go.

---

## B. The bug tickets README

**All of a story's tickets live in one `README.md`** under the story's
`tickets/` folder — not one file per defect. Written for someone who
was not in the session and needs to **reproduce it themselves**.

### Shape

**1. Quick summary table at the top**, so the whole defect set is
readable in one screen:

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-RS10-01 | Sales Order is created before payment is confirmed | Highest | General |
| BUG-RS10-02 | Sales Rep cannot open the Sales Order related list | High | Persona-specific — Sales Representative |

**2. One section per ticket below it**, each headed by its ticket id:

```markdown
## BUG-RS10-01 — Sales Order is created before payment is confirmed (Highest)

**Module:** Retail Sales — Sales Order
**Status:** Open
**Found during:** QA testing of [ALF-RS-10], 2026-09-22
**Applies to:** General — reproduced as System Administrator

### Description
Plain-language paragraph. What a business reader needs to understand the
problem and its consequence, with no Salesforce jargon and no field API
names.

### Steps to Reproduce
1. Log in as …
2. Open …
3. Click …
4. Save.

### Expected Result
What the documents say should happen.

### Actual Result
What happens, with the literal on-screen message quoted verbatim, the
record id it was observed on, and how many times / in how many ways it
was reproduced.

### Root Cause
The mechanism, verified — and how it was verified ("confirmed via the
flow XML retrieved 2026-09-22", not "approvals seem misconfigured"). If
it is not isolated, say so and list what was ruled out.

### Proposed Solution
A concrete fix, where there is enough information to responsibly
propose one.

### Reference
- **BRD**, p. 84, §10.10 Sales Order Creation — *"<direct quote>"*
- **Solution Design**, p. 31, HLD 09 Order Management — *"<direct quote>"*

### Evidence
- Record: `9ALFV0000X4e63U4QQ`
- Screenshot: `screenshots/rs10-tc004-order-created-early.png`
```

### Ticket rules

- **Every ticket has a stable id** (`BUG-<STORY>-NN`) that appears in
  both the summary table and its own heading, so the user can say
  "drop 03, add one for X" unambiguously.
- **No test case ids inside a ticket.** Traceability lives in the
  report's Section 2 table and in `qa-notes.md`.
- **Cite the source with an actual quote**, plus document and page
  number. A reference to "§10.4" without the sentence is not
  verifiable by the reader, and the exercise of finding the sentence
  is what catches findings that turn out not to be requirements at all.
- **Root cause is mandatory.** If it is not known, say "root cause not
  isolated" and describe what was ruled out — never present a
  hypothesis as a mechanism. When the mechanism is sourced from
  retrieved metadata (flow XML, validation rule, permission set),
  **confirm the retrieve is current first** — see `SKILL.md` § 2b.
  Stale metadata does not fail loudly; it produces a wrong root cause
  that reads as verified.
- **Steps must be independently runnable.** The user reproduces these
  by hand; a step that depends on state only the session had is a
  broken ticket.
- **Merge related defects.** Two or more bugs sharing a root cause
  belong in one ticket with numbered sub-issues, not scattered across
  several. A reader fixing the shared cause needs to see everything it
  breaks.
- **Say which persona.** Per § C, every ticket states whether it is
  General or persona-specific. Persona-specific blockers are raised as
  tickets too — "an admin can do it" is irrelevant when admins are not
  the people who perform the process.

### Approval gate — before Jira

The README is a **draft for review**. Hand it over and stop: the user
says which tickets to remove, reword or add. **Nothing is created in
Jira until they approve explicitly.**

On approval, create each ticket in the project's Jira with that
project's field conventions — priority, assignee, parent epic, and the
link back to the user story. Record those conventions (project key,
default assignee, epic, priority scheme) in `qa-notes.md` so the next
story does not re-ask.

---

## C. General vs persona-specific classification

**Every persona-found bug gets re-tested as System Administrator.** No
exceptions — this is what separates "the build is broken" from "this
persona's permissions are wrong," and they go to different people.

| Persona result | Admin result | Classification | Ticket says |
|---|---|---|---|
| FAIL | FAIL | **General** | Affects everyone including System Administrator |
| FAIL | PASS | **Persona-specific** | Name the persona; state that Admin can do it |

**A ticket is raised either way** — the classification changes the
framing, never whether it gets reported.

Two things this discipline protects against:
- Reporting an org-wide defect as a permissions problem, so it gets
  routed to the wrong team and closed as "works for admin."
- Reporting a permissions gap as a build defect, so a developer spends a
  day looking at working code.

When an engagement is explicitly scoped to Admin-reproducible defects
only, still note the excluded persona-specific findings by name so
nothing silently disappears from the record.

---

## D. Priority scheme

Default to the standard Jira scheme unless the client uses their own —
confirm at engagement start and record the answer in `qa-notes.md`.

| Priority | Means |
|---|---|
| **Critical** | Blocks a core business flow entirely, or lets a financial/compliance control be bypassed. No workaround. |
| **High** | A requirement is not met and the workaround is costly, manual, or error-prone. |
| **Medium** | Requirement partially met, or met with a usability/data-quality defect. Reasonable workaround exists. |
| **Low** | Cosmetic, labelling, or affects a rare edge case. |

Calibration notes:
- A **missing validation** that permits bad financial data is Critical even
  though nothing visibly breaks — silent wrong data outranks a loud crash.
- A **crash** with a clean workaround is High, not automatically Critical.
- **Placeholder/demo data left in production-bound picklists** is High —
  it looks harmless and reliably reaches end users.

---

## E. Discipline that keeps reports trustworthy

**Verify; do not infer from the test sheet's own hypothesis.** A test case
document often states the *suspected* mechanism. Read the actual flow
XML, validation rule, or permission set before repeating it. A real
example: a sheet attributed an escalation to a named permission set; the
flow's own description showed it actually resolved off the user's Manager
field, and the permission set was irrelevant. The correct finding was
several times more serious than the documented guess.

**Retract in writing.** When a previous finding turns out to be wrong —
a tooling artifact, a doc-conversion error, a misread — write a dated
correction entry in `qa-notes.md` saying what was claimed, what is
actually true, and why the original was believed. Never silently delete
it: a later reader needs to know the claim was once made, especially if
it already reached a ticket or a client report. Update or withdraw the
ticket too.

**Distinguish rendering from data.** Check underlying field values before
writing up anything visual. Two real near-misses: currency rendering in
Arabic-Indic numerals looked like corrupted data at screenshot
resolution; a related list that appeared to be "hiding" its contents was
in fact showing the wrong columns for records whose values were genuinely
blank. Both would have been wrong tickets.

**Report what a pass does not prove.** An admin passing something does
not prove the named persona can. An API pass does not prove the UI works.
Say which harness produced each result.
