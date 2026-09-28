# {{[STORY-ID]}} {{Story Name}} — bug tickets

**Found during:** QA testing of {{[STORY-ID]}}, {{DATE}}
**Org:** `{{INSTANCE_URL}}`
**Report:** `reports/{{STORY-ID}}-report.md`
**Status:** DRAFT — awaiting review. Nothing is created in Jira until
the user approves this list.

## Summary

{{Two or three sentences: what the defect set means for the story as a
whole — is it shippable, what is the worst of it, is anything a
permissions problem rather than a build problem.}}

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-{{STORY}}-01 | {{one-line title}} | {{Highest/High/Medium/Low/Lowest}} | General |
| BUG-{{STORY}}-02 | {{one-line title}} | {{…}} | Persona-specific — {{Persona}} |
| BUG-{{STORY}}-03 | {{one-line title}} | {{…}} | General |

---

## BUG-{{STORY}}-01 — {{One-line title in plain business language}} ({{Priority}})

**Module:** {{Business module, e.g. Retail Sales — Sales Order}}
**Status:** Open
**Applies to:** {{General — reproduced as System Administrator | Persona-specific — <Persona>; System Administrator can perform this successfully}}

### Description

One plain-language paragraph for a business reader. What is wrong and
what it costs. No Salesforce jargon, no field API names, no
jargon-first framing.

### Steps to Reproduce

1. Log in as {{persona}}.
2. Navigate to …
3. …
4. Save.

> Must be independently runnable by someone who was not in the testing
> session. Any step depending on state only the session had is a broken
> ticket.

### Expected Result

What the documents say should happen.

### Actual Result

What happens, with the **literal** on-screen or API message, the record
it was observed on, and how many times / in how many ways it was
reproduced.

```
<exact error text>
```

### Root Cause

The verified mechanism, and **how** it was verified ("confirmed via the
flow XML retrieved {{DATE}}", "confirmed via debug log"). If it is not
isolated, say "root cause not isolated" and list what was ruled out.
Never present a guess as a mechanism.

### Proposed Solution

A concrete fix, where there is enough information to responsibly
propose one.

### Reference

- **BRD**, p. {{n}}, {{§section}} — *"{{direct quote}}"*
- **Solution Design**, p. {{n}}, {{§section}} — *"{{direct quote}}"*

> Quote the actual sentence, with the page number. A bare section
> reference is not verifiable by the reader, and hunting the sentence is
> what catches "findings" that turn out not to be requirements at all.

### Evidence

- Record: `{{Id}}`
- Screenshot: `screenshots/{{file}}.png`
- Harness: {{API via <connection> | Lightning UI as <persona> | both}}

---

## BUG-{{STORY}}-02 — {{…}} ({{Priority}})

{{Same structure.}}

---

<!--
RULES

- No test case ids anywhere in a ticket. Traceability lives in the
  report's Section 2 table and in qa-notes.md.
- Every ticket id appears both in the summary table and in its own
  heading, so the user can say "drop 03, add one for X" unambiguously.
- Persona-specific blockers are raised as tickets too — "an admin can do
  it" is irrelevant when admins are not the people who perform the
  process. Name the persona and say plainly whether Admin is unaffected.
- MERGING: two or more defects sharing a root cause belong in ONE ticket
  as numbered sub-issues, not scattered across several. A reader fixing
  the shared cause needs to see everything it breaks. Use:

  #### 1. [Highest] <sub-issue title>
  **Steps to Reproduce:** …
  **Expected Result:** …
  **Actual Result:** …
  **Reference:** …

- APPROVAL GATE: hand this file over and stop. The user removes,
  rewords or adds tickets. Only after explicit approval, create them in
  Jira with the project's field conventions (project key, priority,
  assignee, parent epic, link to the user story) — recorded in
  qa-notes.md.
-->
