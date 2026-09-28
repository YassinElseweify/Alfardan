# Jira filing and retesting

The project's own conventions (project key, issue type, assignee account id,
parent epic, labels, link type, story → ticket map, transition ids) belong
in `qa-notes.md` under a **Jira conventions** heading. Read them there;
if they're missing, ask once and record the answer.

## The approval gate

- Nothing is created, commented, transitioned or linked in Jira without the
  user's explicit approval **for that action**. Approval to file tickets is
  not approval to post a comment on another ticket, and approval in one
  story doesn't carry over to the next.
- Present the draft README (or the list of comments/transitions) and wait.
  The user answers by id: file all, drop 03, reword 05.
- Screenshots are usually attached by the user by hand; list the filenames
  at the bottom of each ticket so they know what to attach.

## Filing a ticket

Before creating, fetch one existing ticket the team filed from QA to copy
its shape (description format, labels, parent, priority names).

Per ticket:
- **Summary**: the plain-language title, without the BUG id.
- **Description**: the ticket section from the README, from **Module**
  down to **Screenshots**, as markdown (headings one level up: `##`).
- **Type / parent / assignee / priority / labels**: per project
  conventions. Typical labels: the story id, `QA`, the stream, plus a
  category (`Security`, `Integration`) where relevant.
- **Links**: *Relates* to the story's ticket (look the keys up and verify
  the summary matches before linking); *Relates* to related bugs (same root
  cause family, a ticket it blocks, the existing ticket it extends).
- Create independent tickets in parallel; then create links.

Afterwards: update the README (status line, `Jira` column, keys in
headings), the workbook's Ticket column, and `qa-notes.md`.

## New evidence on an existing ticket

If a finding is already tracked, don't open a duplicate. Draft a comment:
what was seen (records, dates), the new or corrected root cause, and the
proposed fix. Post it only when approved.

## Retesting deployed fixes

1. **Scope**: JQL for the project's "deployed to QA" status (and any
   explicit list from the user). Read each ticket fully — description and
   comments — to know exactly what "fixed" means.
2. **Plan fresh records** for the retest, driven through the real cycle, as
   the persona the ticket names. Build them in one setup pass.
3. **Retest each ticket** in the UI as the persona; check side effects via
   read-back; re-run the original repro and the obvious neighbours (a fix
   often breaks the step next to it).
4. **Verdict per ticket**: Fixed / Partially fixed / Not fixed / Fixed with
   a regression / Could not retest.
5. **Write the retest report** (`deliverables.md` § E).
6. **Jira**, per the team's standing rule (record it in qa-notes). A common
   rule:
   - *Not fixed or partially fixed* → comment with what was retested, on
     which records, what still fails (literal message, screenshot name),
     then transition back to **To Do**.
   - *Fixed with nothing to watch* → transition to **Done** (only when the
     user has said to close clean fixes).
   - *Fixed but with an open point* (BA question, edge case, backfill) →
     leave it where it is and say why in the report.
   Workflows often need an intermediate transition; look up the ids with
   `getTransitionsForJiraIssue` once and record the path in qa-notes
   (e.g. `DEPLOYED TO QA → QA IN PROGRESS → Done`).
7. A regression found during retest is a new ticket (or a comment on the
   ticket whose fix caused it), linked to the original.

## After a standing rule is given

When the user states a rule about Jira ("always link to the subtask",
"move back to To Do when partially fixed", "attach screenshots myself"),
write it into qa-notes' Jira conventions immediately so the next session
follows it without being told.
