# Deliverables

Every testing session ends with a fixed set of artefacts, each with a fixed
shape, so they stay comparable across stories, sessions and projects.

| Artefact | Path | Mode |
|---|---|---|
| Test-case workbook (results written in) | `test-cases/<file>.xlsx` or `.md` | Story |
| Story report (5 sections) | `reports/<STORY>-report.md` | Story |
| Cycle report | `reports/<CYCLE>-report.md` | Cycle |
| Tickets README | `tickets/<STORY or CYCLE>/README.md` | Story, Cycle, Single bug |
| Retest report | `reports/RETEST-<YYYY-MM-DD>-<scope>.md` | Retest |
| Demo run-book (on request) | `reports/<CYCLE>-runbook.html` (+ published page) | Cycle |
| Screenshots | `screenshots/<STORY>/NN-<what>.png` | All |
| QA notes entry | `.claude/qa-notes.md` | All |

---

## A. Test-case workbook

Write results into the client's own test-case document; don't create a
parallel one.

- **Actual Result**: what happened, with record name + id, literal message,
  and screenshot filename. Start with the verdict word.
- **Status**: `Pass` / `Fail` / `Partial` / `Blocked` / `Not verified`.
- **Ticket** column: `BUG-<STORY>-NN` while drafts; after filing,
  `BUG-<STORY>-NN / <JIRA-KEY>`.
- **Added test cases**: append with the next id, mark "Added during
  execution" and why.
- Extend any coverage/summary formulas to include the new rows; keep the
  sheet's existing styles (copy the style of the row above).
- Edit with `openpyxl` (keep formulas; never round-trip through pandas).

---

## B. Story report — five sections, always in this order

Bugs are not a standalone section. They are named in Section 4 at the
requirement they break, and written up in full in the tickets README.

**Header**: story, date, org, personas, tickets README path, screenshots
folder.

### 1 — Summary of what was done
What was tested, which personas, which harness (API / UI / both), how many
test cases ran and how many were added, headline verdict, and every
substitution (steps done as admin / via API because the persona was
blocked). Short — the section someone reads if they read nothing else.

### 2 — Test cases executed

| TC | What it tests | Result | Evidence / finding |
|---|---|---|---|
| TC-001 | … | **PASS** | Record, value, screenshot |
| TC-004 | … | **FAIL** | Literal error, record id (**BUG-XX-01**) |

Every row carries concrete evidence. Added TCs marked. Close with **Not
independently verified**: each item and why (time-based automation,
real mailbox delivery, external integrations, persona that doesn't exist).

### 3 — BA gaps to raise
Things the documents never specified or contradict, placeholder values,
routing/approver models that need a named decision. Each: what is
undefined, where the documents fall silent or disagree (quote), the
decision needed and from whom. Also demo/UX risks that are not defects.

### 4 — Walkthrough by FR / AC
Organised by requirement, not test case. For each FR and AC: the click
path performed (and API calls where the check was API-side), the records
created or touched (name + id), what happened, pass/fail, and **the bug at
the point it is hit** — "at this step you will see `<literal error>`; this
is BUG-XX-NN".

### 5 — Hands-on
Explain the story and how it is implemented, then give the user a **fresh
record set** to run it themselves.

Record set rules:
- one record per scenario, covering every FR/AC, each negative/edge case
  and each known defect;
- genuinely clean — no child records already created; the user starts
  where a real user starts;
- owned by the right persona, at the stage/status where the entry point is
  visible;
- named `DEMO <STORY> Hn - <purpose>` so one search returns them all;
- never shared between scenarios where one mutates state the other needs
  (e.g. a vehicle's stock status) — give each its own.

Then: logins (app + persona; passwords only in local files), the click path
per scenario, what they should see, what they will actually see where a
bug exists, expected figures, and a **scorecard** table
(`# | Step | Expected | You saw | Ticket`).

End the report with **Records left in the org** and **Org configuration
changed during testing** (what was changed, and that it was reverted).

---

## C. Cycle (end-to-end) report

Same five sections, adapted:
1. **Summary** — who starts the process (explain each entry path and the
   persona who runs it), the cycle as users run it (table: `# | Step |
   Persona | Where`), the deals run (table: deal · scenario · result), all
   substitutions, and a **demo verdict**: what will break on screen, what
   ran cleanly.
2. **Test cases executed** — one row per cycle checkpoint (E2E-01…).
3. **BA gaps and demo risks.**
4. **Walkthrough by process step**, each bug at the step it is hit.
5. **Hands-on / rehearsal** — fresh customers and stock, no deals (the
   rehearsal starts at the entry point), a run-sheet with the safe order
   and workarounds, and a scorecard.

Design the deal set to cover every branch: each entry path; with/without
optional sub-processes (trade-in, test drive completed/refused); each side
of every threshold (deposit below/above, each discount tier); each
reservation/contract type; a won and a lost outcome; one deal per known
risk. Name them `<CYCLE> C1…Cn - <customer>`.

---

## D. Tickets README

One `README.md` per story/cycle holding every ticket.

```markdown
# <Story / cycle> — bug tickets

**Found during:** <what was run>, <date>
**Org:** <url> · **Report:** reports/… · **Screenshots:** screenshots/…
**Status:** Draft — not yet in Jira. Review by id; nothing is filed until approved.

> **Reproducible in the Lightning UI.** Persona usernames (passwords in qa-notes), login notes.

When approved, each is raised in <PROJECT> as a Bug, assignee <…>, parent <…>,
labels <…>, linked *relates to* <story ticket>.

## Summary
Two or three short paragraphs: what the defect set means for the business.

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-XX-01 | … | Highest | Sales Representative (persona-specific) |
| BUG-XX-02 | … | High | General — reproduced as System Administrator |

### Already tracked — new evidence, no new ticket
| Jira | What we saw | New evidence to add as a comment |

---

## BUG-XX-01 — <plain-language title> (<Priority>)

**Module:** <area — sub-area>
**Applies to:** <General / persona-specific: who; how many times reproduced>

### Description
Plain language, no field API names: what is broken and why it matters.

### Steps to Reproduce
1. Log in as <persona> → <app> → <record name (`id`)>.
2. <menu> → <action> → <values> → <button>.
3. …

### Expected Result
What the requirement says should happen.

### Actual Result
> literal on-screen message

- Records affected, field values read back, count of reproductions.

### Root Cause
**Confirmed from <flow XML / validation rule / Apex / debug log / sharing check>.**
- Mechanism, element names, why it fails for this persona.
(or **Not isolated** — what was ruled out.)

### Proposed Solution
Concrete fix(es), numbered if several.

### Reference
- **BRD** §X.Y, p.NN, FRn — *"exact quote"*
- **SD**, p.NN, "<page>" page, "<section>" section — *"exact quote"*

**Screenshots:** `NN-….png`, `NN-….png`
```

Rules:
- **Stable ids** (`BUG-<STORY>-NN`) in the table and each heading, so the
  user can say "drop 03, reword 05".
- **Titles state the failure in plain language** — the symptom a user sees,
  not the field name.
- **Priority** uses the project's scheme (default Highest / High / Medium /
  Low / Lowest). Blocks a core flow or corrupts money/compliance with no
  workaround → Highest; requirement unmet with a costly workaround → High;
  partial / reasonable workaround → Medium; cosmetic / rare → Low. Silent
  wrong numbers outrank loud crashes.
- **No test-case ids** inside tickets.
- **Merge** defects with one root cause into one ticket with numbered
  sub-issues.
- **Steps must be runnable by someone else** on records they can open.
- **Clean drafts**: until filed, no "corrected", "dropped", "replaces"
  notes and no numbering gaps — renumber. After filing, the rule inverts:
  changes become Jira comments or new linked tickets, never silent edits.
- **Citations** are verified against a text extraction of the source PDF
  (`pdftotext -layout` or `pypdf`), page number read from the page-break
  marker above the quote. Never reuse a citation from memory.

After filing: change the status line to "Filed in Jira <date> as KEY-a …
KEY-b", add a `Jira` column to the table, and put the key in each heading
(`## BUG-XX-01 (KEY-123) — …`).

---

## E. Retest report

For tickets deployed to QA. One file per retest round.

```markdown
# Retest — <project> bugs in "<status>" (<date>)

**Scope:** <n> tickets in <status> on <date>.
**How:** Lightning UI as <persona> on fresh records; admin used only for <setup / access checks / reading files>.
**Retest records:** <names + ids>. **Screenshots:** screenshots/RETEST-<date>/

## Verdicts
| Ticket | Verdict | Evidence |
| KEY-1 <short title> | **Fixed** | What you did and saw; screenshot |
| KEY-2 … | **Not fixed → To Do** | … |
| KEY-3 … | **Partially fixed → To Do** | What works now, what still fails |
| KEY-4 … | **Fixed, with a regression** | … and the new ticket/regression reference |

**Totals:** n fixed · n back to To Do.

## Moved to Done
Which tickets were closed, and which fixed ones were deliberately left open and why (open BA question, edge case, backfill not done).
```

Verdict words: **Fixed**, **Partially fixed**, **Not fixed**, **Fixed with a
regression**, **Could not retest** (and why). Retest on **fresh records**
driven through the real cycle, never on the record the bug was found on.

---

## F. Demo run-book (cycle mode, on request)

Written for the person presenting (often a developer). Publish as a page
if the environment supports it and keep the source HTML in `reports/`.
Structure:

1. **Before the demo** — table of known bugs on the path:
   *Must fix* (breaks on screen, no workaround), *Avoid* (dodged by the
   steps' order), *Leave out* (feature not demoable). Plus "rehearse on a
   spare record set; the named records are consumed by the live run".
2. **Logins & windows** — one browser window per persona, usernames
   (no passwords), app per persona, how approvals are found, where upload
   files are, and the record → scenario table.
3. **One block per deal**, each step with: persona chip, where to click,
   what to type (exact values), **Expect:** result, and a warning where a
   bug can surface with the recovery move. The main storyline in full; the
   others reference its steps ("repeat Deal 1 steps 13–22").
4. **Features to describe, not click** — with the conditions that must be
   true before they can be clicked.
5. **If something goes wrong** — table: *You see* · *Why* · *Do this*.

Before writing it, re-check that the named records are still unused.

---

## G. qa-notes entry

Append, dated, per session:
- what was run and on which records (ids);
- findings with their draft ids, and the Jira keys once filed;
- links made, comments posted, transitions done;
- config changed and reverted;
- anything learned about the org, the cycle, personas, or tooling (new
  gotchas, working click paths, where an action lives);
- corrections: if an earlier claim was wrong, a dated entry saying what
  was claimed, what is true, and why — never silently delete.
