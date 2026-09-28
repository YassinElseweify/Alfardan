# {{ORG_NAME}} QA notes

Org: `{{INSTANCE_URL}}`
(UI My Domain host: `{{LIGHTNING_URL}}`)
`sf` CLI alias: `{{ORG_ALIAS}}` — always pass `--api-version` explicitly,
and **discover it from the org rather than hardcoding** (the CLI default
can be older than this org's objects):

```bash
API_V=$(sf api request rest '/services/data/' --target-org {{ORG_ALIAS}} \
  | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).map(v=>v.version).sort((a,b)=>a-b).pop()")
```

API version last discovered: _(fill in, with date)_

Read this before testing anything in this project. Read alongside the
global skills `test-salesforce-personas` (method) and
`new-salesforce-qa-project` (how this directory was scaffolded).
**Update this file — don't let discoveries evaporate at the end of a
session.**

Source documents: `source-docs/` — the **PDFs are authoritative**, never
a Markdown/HTML export (exports silently drop whole requirement rows).
Extract with `pdftotext -layout`.

Priority scheme in use: _(confirm with the client — default is the
standard Jira Critical/High/Medium/Low, defined in the
`new-salesforce-qa-project` skill's `deliverable-formats.md`)_

---

## Personas

Scoped to the current test-case batch — add rows as more stories pull in
more roles.

| Persona | MCP connection (API) | Username | Notes |
|---|---|---|---|
| System Administrator | `{{PREFIX}}-admin-system-administrator` | `…` | Full CRUD. Fallback of last resort — always report explicitly when used in place of a named persona. |

> The **Notes** column is the valuable one. For each persona record:
> what user it was repurposed from · current password · profile +
> permission set groups · UI login status and any interstitial hit ·
> any known blocker.

**Email convention:** all personas route to `team+<tag>@company.com` via
plus-addressing so mail is team-visible but attributable per persona.

**Password note:** stored in plaintext here and in `.mcp.json`. This is a
disposable QA sandbox; that tradeoff is deliberate and must not be
carried into any org holding real data.

---

## Gotchas discovered in this project

Project-specific only. Generic Salesforce/tooling walls live in the
`new-salesforce-qa-project` skill's `org-access-troubleshooting.md` —
add here only what is true of *this* org.

- _(none yet — add as found, newest first)_

---

## Tickets filed

- _(none yet — one line per ticket: filename, what it covers, and
  "read this before re-deriving any of those findings")_

---

## Baseline — verified {{DATE}}

Written before the first test case, and diffed against in later sessions.

**Objects confirmed present (record counts):** _(fill in)_

**Local metadata retrieved:** _(date)_ — `force-app/main/default/`, via
`sf project retrieve start --metadata Flow ValidationRule PermissionSet
PermissionSetGroup Profile RecordType CustomObject`. **Re-retrieve before
citing any of it as a root cause**; a sandbox refresh or someone else's
deploy makes it stale without making it look stale.

**Tooling notes:** which harness sees what — MCP connections vs `sf` CLI
vs browser. Note any object visible to one and not another *here*, so a
tooling artifact is never re-reported as an org defect.

**Persona access matrix:** which personas can reach which objects.

---

## Session log

Newest sections at the bottom. One dated `##` heading per session or
pass. Include, every time:

- what was tested and how (API, UI, or both; which persona)
- findings, with record ids and literal error text
- **corrections and retractions** of earlier claims — dated, stating
  what was believed, what is actually true, and why. Never silently
  edit history; a later reader needs to know a claim was once made,
  especially if it reached a ticket.
- records deliberately left in the org as evidence
- credential/config changes made to the org

### {{DATE}}: Project scaffolded

- Directory created via the `new-salesforce-qa-project` skill.
- Personas provisioned: _(list)_
- Access walls hit during setup and how they were cleared: _(list)_
