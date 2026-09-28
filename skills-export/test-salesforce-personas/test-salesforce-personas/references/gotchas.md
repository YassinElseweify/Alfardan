# Gotchas that produced wrong findings (or nearly did)

Generic to Salesforce. Add the project's own to `qa-notes.md`.

## Wrong setup → fake bugs

1. **Data built by direct insert.** Records the application would never
   create (missing the quote link, price totals, record type the finder
   excludes) produce "bugs" that are setup artefacts. Build through the
   real actions, or mimic their exact field values; re-verify any blocker
   on a record driven through the UI.
2. **Standard New button instead of the custom action.** The custom action
   often sets fields, creates children and enforces rules the standard
   button skips. Inventory Quick Actions + FlexiPage first.
3. **Wrong app.** Record pages and actions are assigned per app; the same
   record looks different in *Sales* and in the industry app.
4. **Wrong stage.** A missing action usually means the record isn't at the
   stage the action's visibility rule requires.
5. **Admin instead of the persona.** Admin bypasses sharing, FLS and
   validation bypass permissions; a pass as admin proves nothing about the
   persona, and vice versa.

## Wrong conclusion from true observations

6. **"It doesn't exist."** Check Dynamic Actions (`enableActionsConfiguration`
   on the FlexiPage makes the layout's action list irrelevant), component
   visibility, record types, truncated greps, and API-version quirks
   (industry-cloud objects invisible to older-API connections, "ghost"
   lookup fields). State the exact conditions, not an absolute.
7. **The test sheet's hypothesis.** A suspected cause in a test case is not
   a root cause. Read the flow/rule/Apex that runs.
8. **Stale metadata.** A months-old retrieve gives a confident, wrong root
   cause. Check the retrieve date.
9. **API error text ≠ what the user sees.** The Quick Action or Screen Flow
   may show a different (better or worse) message. Confirm the UI message
   before filing a wording bug.
10. **Rendering vs data.** Check the field value before filing a visual
    bug (localised numerals, related lists showing other columns, blank
    values that are genuinely blank).
11. **`describe` Required=false** doesn't mean optional — validation rules
    enforce more. Try the blank save.
12. **No `EmailMessage` ≠ email not sent** — logging needs a person record;
    check the automation's own status field or ask for a real inbox check.

## Classic real defects worth checking on every story

13. **Flows running in user context under Private sharing.** A flow that
    creates a record owned by someone else and then re-queries it gets
    null; downstream tasks get a null `WhatId`, notifications fail on a null
    target. Fix is to use the created record's id or run in system context.
14. **Hidden screen inputs written as null.** A checkbox/field hidden by a
    visibility rule is passed as null into a record create →
    `INVALID_TYPE_ON_FIELD_IN_RECORD` or a wrong default. Check every
    visibility rule on inputs that are later written.
15. **Missing fault connectors** → the generic "An unhandled fault has
    occurred" screen. Note which element has none.
16. **Automation that ends silently.** An after-save flow that calls a gate
    and has no branch for "refused" leaves the user with no message and a
    half-finished state; check what else only that flow sets.
17. **Percentages computed on one base, applied to another** (net after a
    deduction vs gross), and two-decimal rounding of a derived percentage.
    Re-compute every money figure by hand.
18. **Approval chains built on the Manager field** climb one level per
    step from the submitter; tier labels and real approvers drift apart
    depending on the hierarchy. Record the real chain per persona.
19. **Rollups filtered on a child field** that no step sets, while the
    parent shows a similar-looking status set by approval.
20. **Side effects of your own test runs.** Creating records to isolate a
    bug can create invoices, reserve stock or send emails. Clean up and
    reset statuses; note it.

## Access and sessions

21. **Forced *Change Your Password*** on UI login → click **Cancel**; it
    usually continues with the old password. If a password really changes,
    update every place it's stored (MCP config, personas.conf) — running
    MCP servers keep the old one until restarted.
22. **2FA/passkey walls** can't be completed by an agent; ask the user.
23. **Sessions expire** after idle time (and always after a long break):
    re-run the login script; snapshot after each navigate.
24. **Persona MCP connections may be missing** in a given session;
    check before assuming, and fall back to `sfp.sh`.
25. **New network / IP** → persona SOAP logins fail with
    `LOGIN_MUST_USE_SECURITY_TOKEN` until the IP is trusted.
26. **Licence ceilings**: creating a missing persona may be impossible;
    say which persona doesn't exist and what that blocks.
27. **`Profile`, `PermissionSet`, `TraceFlag`, `ApexLog`** are often not
    queryable through community MCP servers — use the `sf` CLI / Tooling
    API.
