# Test Cases — {{STORY_RANGE}}

**Scope:** {{STORY_LIST}}

**Sources:** BRD `source-docs/<file>.pdf` §… · Solution Design
`source-docs/<file>.pdf` (…) — **PDFs, not exports.**

**Org:** `{{INSTANCE_URL}}` (UI: `{{LIGHTNING_URL}}`)

**Generated:** {{DATE}}

---

## Execution harness

| Persona | MCP connection (API) | UI login notes |
|---|---|---|
| System Administrator | `{{PREFIX}}-admin-system-administrator` | … |

UI harness = `browser` (Playwright) MCP.
Method = **API pass first, then UI pass**, per the `test-salesforce-personas`
skill. **Never mark PASS from API evidence alone.**

---

## Environment baseline — read before executing

> Any tooling caveat that changes how these test cases must be run goes
> here, in a callout, at the top. Examples worth flagging loudly:
> objects invisible below a certain API version; a persona with no UI
> login; metadata types not queryable through MCP.

**Objects confirmed present (record counts as of {{DATE}}):** …

---

## Test cases

| TC | Story | Persona(s) | Preconditions | Steps | Expected result | Priority | Source |
|---|---|---|---|---|---|---|---|
| TC-001 | {{STORY}} | Sales Representative | … | 1. … 2. … | … | High | BRD §… / SD … |

---

## Notes on writing these

- **Extract from the PDF, not an export.** Confirm every FR and AC is
  present — exports have been observed dropping entire User Story,
  Requirement Overview, FR and AC rows silently.
- **Show the extracted list to the user before executing anything.** If
  intake misreads a requirement, every result after it is confidently
  wrong.
- Flag up front any test case that is **inherently API-invisible** — a
  Lightning dashboard component, real mailbox delivery, profile access —
  rather than discovering it mid-execution. Those get a
  "Not independently verifiable" verdict, not a guess.
- One row per test case, and the id is the traceability key used by
  reports, tickets and screenshot filenames alike.
