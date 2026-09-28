---
name: test-salesforce-personas
description: Test Salesforce user stories, full business cycles and deployed bug fixes as the real business personas — map the journey, build data through the product's own actions, execute API-first, confirm every bug in the Lightning UI as the persona — then produce the standard deliverables (5-section story report, one tickets README with BUG ids, updated test-case workbook, hands-on record set, retest report, demo run-book) and file approved tickets in Jira. Use when asked to test or verify a story, acceptance criteria, an end-to-end cycle or a demo path in a Salesforce org; to retest tickets that were deployed to QA; to reproduce a defect as a specific persona; or to write up / file QA findings.
---

# Testing Salesforce as the personas

A portable method for QA on any Salesforce org. It covers **how to test**
(as the persona, through the real journey) and **what to hand over
afterwards** (a fixed set of deliverables, then Jira only after approval).

The method lives here. Everything specific to one org — persona logins,
object quirks, the Jira project's conventions, the business cycle, known
bugs — lives in that project's **`.claude/qa-notes.md`**. Read it before
you start, and append to it whenever you learn something. If the project
has no `qa-notes.md`, create one from `assets/qa-notes.template.md`
before doing anything else.

| Read when you need it | File |
|---|---|
| Exact shapes of every deliverable | `references/deliverables.md` |
| Filing in Jira, retesting deployed fixes, transitions | `references/jira-and-retest.md` |
| Persona API sessions, UI login scripts, debug logs, flow reading | `references/tooling.md` |
| Traps that produced wrong findings before | `references/gotchas.md` |
| Starting templates | `assets/*.template.md` |
| Helper scripts | `scripts/` |

## The rules that never bend

1. **Test as the persona the requirement names, in the Lightning UI, the
   way they would do it.** API, Apex and direct inserts are for *setting
   up* the starting state and *reading back* what happened, never for
   performing the step under test. Reach records the way a user does (App
   Launcher → tab → list view, related list, the record's own action
   button), not by pasting the URL of the record under test.
2. **Use the product's own actions.** Before touching a standard New/Edit
   button, inventory the org's custom Quick Actions and buttons and what
   the Lightning record page actually exposes. A standard button is a last
   resort and a warning sign; findings made through it are often artefacts.
3. **Every bug is confirmed in a UI cycle as the persona before it goes in
   a ticket.** A finding seen only through API/Apex is a candidate. If it
   does not reproduce in the UI, drop it (say so in the report, not the
   ticket).
4. **Every persona failure is re-run as System Administrator** and
   classified *General* (admin fails too) or *Persona-specific* (admin
   passes). A ticket is raised **either way**; the classification only
   changes the framing. "An admin can do it" is irrelevant when admins are
   not the people who do the job.
5. **Root causes are verified, never guessed.** Read the flow XML,
   validation rule, Apex or sharing that actually runs; say how it was
   confirmed. If not isolated, say so and list what was ruled out.
6. **Never claim something is missing** until you have ruled out: wrong
   app, conditional visibility (Dynamic Actions, stage gates, record
   types), the wrong metadata (layout vs FlexiPage), a truncated search,
   and API-version quirks. State the exact conditions under which it was
   not visible.
7. **Nothing goes to Jira — or any other external system — without the
   user's explicit approval.** Drafts first, then wait.
8. **Say which user did what.** Any step performed as admin, via API, or
   through a workaround because the persona was blocked is named as such
   in the report. Any temporary org change (a permission set assigned, a
   debug level raised) is logged and reverted, and the report says so.

## Pick the mode

| The user asks for… | Mode | Deliverables |
|---|---|---|
| Test story X / these test cases | **Story** | Workbook results · 5-section report · tickets README · hands-on records |
| Walk the whole process / rehearse a demo / "from creation to closed" | **Cycle (E2E)** | Cycle report · tickets README · hands-on records · (on request) demo run-book |
| Retest what was deployed / check the fixes | **Retest** | Retest report · Jira comments + transitions (after approval rules in `jira-and-retest.md`) |
| Reproduce / investigate one defect | **Single bug** | Ticket (added to the story's README) with verified root cause |

All modes share the same four phases.

## The four phases

### Phase 1 — Map the cycle as the user performs it

Before reading a test case, write down how a real user does this journey,
end to end.

1. **Inventory the entry points**: `sf org list metadata -m QuickAction -m WebLink`,
   then the Lightning page's (FlexiPage) `actionNames` and their
   `visibilityRule`s. When Dynamic Actions are on, the page layout's
   action list is meaningless — only the FlexiPage counts.
2. **Note the gates**: stage-gated actions, validation rules, required
   documents, approvals. A missing action usually means the wrong stage.
3. **Follow the journey across objects** — the next step often lives on a
   child record (quote, reservation, invoice, payment, handover).
4. **Note who does each step** (which persona, which queue approves) and
   which **app** they use.
5. **Read enough code behind each action** to know what it creates, what
   it sets, and what it deliberately doesn't.
6. **Write the cycle into `qa-notes.md`** as a numbered table: step ·
   persona · object · action · gate. Re-verify an existing one rather than
   trusting it — builds change.

A step with no real UI entry point is a finding in itself. Record it; do
not invent a workaround and then test the workaround.

### Phase 2 — Ground the test cases and build the data

1. **Ground every test case** against the cycle and the implementation.
   Test cases that name steps, buttons or orders the product doesn't have
   become BA gaps; restate the test case in terms of what the product
   actually does before running it. Add test cases for gaps you find and
   mark them *added*.
2. **Derive the full scenario matrix** up front: happy path, each
   negative/edge case, each persona, each threshold on both sides (e.g.
   below / above a deposit threshold, each approval tier), with/without
   optional branches (e.g. with and without a trade-in), each lost/cancel
   path, and a repro record for each known defect.
3. **Create the whole matrix in one setup pass** via the APIs, named so
   one search returns it: `QA <STORY> NN - <purpose>` for execution
   records. **Mimic the cycle**: same order and same field values the real
   actions set, owned by the persona who would own them, using records the
   application would actually offer (right record type, right status).
   Print the ids and keep the script (scratch folder) until the story is
   closed.
4. Only the **starting point** is built this way (e.g. customer, stock,
   an Opportunity at the stage where the test begins, if the test does not
   start at creation). The steps under test are driven through the UI.

### Phase 3 — Execute, API first where it genuinely helps

- Use the API pass to prove the object model / automation / validation
  exists and to cover bulk and negative cases quickly: describe, query
  `FlowDefinitionView` / read the flow XML, empirically try the blank
  save, **isolate multi-rule saves** (satisfy everything else, fail only
  the target condition, then flip it), and **read results back** —
  including side-effect records (Task, EmailMessage, child records,
  generated files).
- Run the persona's API calls **as the persona** (see `tooling.md` —
  per-persona MCP connection or a persona REST session). Admin passing
  proves nothing about the persona.
- Then the UI pass for every test case: log in as the persona, click the
  real path, screenshot the moment that matters (filled form, error,
  result), and compare with the API pass. The UI message is what the user
  sees; API validation text is only a lower bound.
- When the persona is blocked mid-journey, record the blocker, then carry
  the cycle forward by the least-distorting route — preferably the
  persona's **own API session with exactly the values the blocked action
  would send**; admin only if that fails — and name the substitution.
- Write results into the test-case workbook as you go (see
  `deliverables.md` § Workbook).

**Parallelism:** never across a producer/consumer on the same record
(API setup → UI step). Fine across independent test cases or read-only
UI checks.

### Phase 4 — Confirm and root-cause every bug

For each candidate:
1. Reproduce it in the UI **as the persona** on a record driven through
   the real actions; screenshot the failure (literal message visible).
2. Re-run as System Administrator → General or Persona-specific.
3. Find the mechanism: flow XML (who runs it — user or system context,
   fault connectors), validation rule formula, Apex, sharing
   (`UserRecordAccess`), field permissions, debug log with a trace flag
   on the persona. Record *how* it was confirmed.
4. Check it isn't already tracked (search Jira for the object/symptom). If
   it is, it becomes **new evidence** for that ticket, not a new ticket.
5. Write the Steps to Reproduce as the exact click path you just
   performed, on named records someone else can open.

## Deliverables, in order — produce them without being asked

Full shapes, rules and examples: `references/deliverables.md`.

1. **Test-case workbook updated** — Actual Result, Status, Ticket column
   (`BUG-<STORY>-NN`, later `BUG-… / <JIRA-KEY>`), added test cases, coverage
   formulas extended.
2. **Report** — `reports/<STORY>-report.md`, five sections, always in
   this order:
   1. Summary of what was done
   2. Test cases executed (every TC, what it tests, verdict, evidence; then
      *Not independently verified* and why)
   3. BA gaps to raise (never mixed with bugs)
   4. Walkthrough by functional requirement / acceptance criterion, with
      each bug named at the step where it is hit
   5. Hands-on: explain the story, create a fresh clean record set
      (`DEMO <STORY> Hn - <purpose>`), give click paths, expected vs actual,
      expected figures, and a scorecard.
3. **Tickets README** — `tickets/<STORY>/README.md`: summary, table of all
   tickets (`ID | Title | Priority | Affects`), an *Already tracked* table
   for new evidence on existing tickets, then one section per ticket in
   the standing format (Module/Applies to · Description · Steps to
   Reproduce · Expected · Actual · Root Cause · Proposed Solution ·
   Reference with document + page + section + exact quote · Screenshots).
   No test-case ids inside tickets. A draft reads as a clean first draft:
   no correction notes, no numbering gaps.
4. **`qa-notes.md` entry** — what was run, records, findings, ticket
   mapping, config changes, anything learned about the org or tooling.
5. **Stop and hand over** — a short summary in chat: verdict, blockers,
   where the files are, and what needs the user's decision (which tickets
   to file, comments to post). Then wait.
6. **On approval → Jira** (see `jira-and-retest.md`), then update the
   README (status line, Jira column, keys in headings) and `qa-notes.md`.

Cycle mode adds, on request, a **demo run-book** for the person who will
present (see `deliverables.md` § Run-book). Retest mode produces the
**retest report** instead of the 5-section report.

## Writing for the reader

- Tickets are read by developers who weren't in the session: plain
  Description first, precise technical Steps, literal error text quoted,
  record names and ids they can open.
- Reports are read by the QA lead / BA: verdicts with evidence, not
  adjectives. "Works as expected" is not evidence.
- Hands-on sections and run-books are read by someone clicking along:
  every step names the persona, the place, the values, and what they
  should see — plus what they will see where a bug exists.
- Cite requirements as `BRD §X.Y, p.NN, FRn — "<exact quote>"` /
  `SD, p.NN, "<page>" page, "<section>" section — "<exact quote>"`,
  verified against a text extraction of the source document.
- Don't put credentials in anything that leaves the repo (Jira, shared
  pages). Keep them in `qa-notes.md` / git-ignored config.

## Housekeeping

- Screenshots: `screenshots/<STORY>/NN-<what>.png`, referenced by
  filename in the report and tickets; the user attaches them to Jira.
- Scratch scripts go in the session scratchpad, not the repo; delete the
  ones that only served the session when the story is delivered.
- Test side effects (records, invoices, status changes created while
  isolating a bug) are cleaned up and the cleanup is noted.
- Temporary configuration (permission set assignments, trace flags,
  debug levels) is reverted and listed in the report under *Org
  configuration changed during testing*.
