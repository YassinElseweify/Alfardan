# Tooling

Two harnesses drive the org; nothing is built or launched locally.

| Harness | What | Use for |
|---|---|---|
| **API as the persona** | Per-persona Salesforce MCP connections (`.mcp.json`), or `scripts/sfp.sh` (a REST session logged in as the persona) | Setup in the persona's name, read-back, persona-scoped access checks, carrying a blocked step forward with the exact values the action would send |
| **API as admin** | `sf` CLI (org alias in qa-notes), `scripts/sfa.sh` | Metadata, Tooling API, debug logs, file content, cleanup |
| **UI** | Playwright browser MCP (`browser_*`) | Every step under test, and every bug confirmation |

## Persona API sessions

- Prefer the project's per-persona MCP connection. Confirm it's actually
  loaded this session (search for its tools) before relying on it.
- Otherwise `scripts/sfp.sh <persona> query|get|post|patch|del …`. It logs
  in with SOAP `login` using the persona's username/password from a
  git-ignored `personas.conf` and caches the session. Failure modes:
  - `LOGIN_MUST_USE_SECURITY_TOKEN` / `INVALID_LOGIN` from a new network →
    the caller's IP isn't trusted. Ask the user to add it to Network Access
    (get it with `curl -s https://api.ipify.org`), or append the persona's
    security token to the password.
  - `INVALID_SESSION_ID` → the script re-logs automatically.
- Check what the persona can see: `SELECT RecordId, HasReadAccess,
  HasEditAccess FROM UserRecordAccess WHERE UserId='005…' AND RecordId='…'`
  (as admin). This is how "the receptionist can't read the deal it just
  created" was proven.

## UI login scripts

Login is the slowest UI step. Keep one small script per persona in a
git-ignored folder (e.g. `.playwright-login/<persona>.js`) and run it with
the browser tool's run-code action. Template: `scripts/login.template.js`
(logs out, fills username → Next → password → Log In, clicks **Cancel** on
*Change Your Password*). After any navigate, snapshot and check the page
title — an expired session silently lands on `/login`.

Switching persona = run that persona's script; don't keep more than one
browser session per tool unless the tool supports isolated contexts.

## Lightning UI mechanics

- Native `<select>` (common in Screen Flows): select the option directly;
  clicking opens an OS dropdown that blocks the page.
- Lightning comboboxes: click the combobox by its label, then the option
  by role/name.
- Buttons not found in a modal: use the element reference from a
  find/snapshot, or resize the viewport taller.
- Pre-filled fields (time, date): clear fully before typing, or the text is
  appended.
- File uploads: wait for the upload dialog to show **Done** and the row to
  read *Uploaded* before navigating away; when several upload inputs sit on
  one page, upload bottom-up (indexes shift as rows change).
- *Items to Approve* on Home: the record link may not open the approval;
  use the row's action menu → Approve/Reject.
- A related-list card's **New** and the page header's **New** can create
  different objects/record types — use the one inside the card you mean.

## Reading the implementation

- Retrieve metadata into `force-app/` (`sf project retrieve start -m Flow
  -m ApexClass -m ValidationRule -m FlexiPage -m QuickAction …`) and note
  the retrieve date in qa-notes; re-retrieve before citing it if it's old.
- `scripts/flowsum.py <flow-meta.xml>` prints a flow compactly: trigger,
  run mode, variables, formulas, every element with filters, field
  assignments, connectors (including fault connectors), and screen-field
  visibility rules. Look especially for: `runInMode` (user vs system
  context), lookups that re-query a record the user can't read, missing
  fault connectors, visibility rules that hide an input that is then
  written as null.
- Validation rules: grep `objects/<Object>/validationRules/` for the field.
- Apex: read the class the action calls; check `with sharing`, FLS
  enforcement (`WITH USER_MODE`, `stripInaccessible`) and hard-coded
  values.

## Debug logs

For a failure you can't explain from metadata:
1. Raise (or create) a DebugLevel to FINEST for Apex/Workflow/DB.
2. Create a `TraceFlag` (Tooling API) on the **persona's user id**,
   `LogType=USER_DEBUG`, expiring within an hour or two.
3. Reproduce in the UI as the persona.
4. `sf apex list log` / `sf apex get log -i <id>`; grep for
   `FLOW_ELEMENT_ERROR`, `EXCEPTION`, `VALIDATION_FAIL`, `FATAL`.
5. Quote the key line in the ticket's Actual Result with the log id.
6. Note the trace flag / debug-level change in the report.

Interactive Flow Builder *Debug* runs don't automate reliably — describe
exactly what to run and ask the user to do it and paste the result.

## Generated documents

Read PDF text to verify generated documents instead of trusting a preview:
`scripts/pdftext.py <ContentVersionId> [search text]` downloads through the
admin CLI and prints the text. Check both values (did the data print?) and
labels (currency, language, placeholders like `null`).

## Source documents

Extract BRD/SD PDFs to text once (`pdftotext -layout brd.pdf brd_full.txt`)
and grep them for citations; page numbers come from the page-break markers
in the extraction.

## Temporary org changes

Sometimes a test needs a change (assign a permission set group to try a
persona that doesn't exist, raise a debug level). Rules: ask first if it
affects other users; record the change with ids; revert it in the same
session; list it in the report under *Org configuration changed during
testing*.
