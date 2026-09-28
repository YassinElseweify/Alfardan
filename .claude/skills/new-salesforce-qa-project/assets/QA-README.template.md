# {{ORG_NAME}} — Salesforce QA project

QA/testing workspace for `{{INSTANCE_URL}}`.
Scaffolded with the `new-salesforce-qa-project` skill.

## Start here

**`.claude/qa-notes.md`** — the living memory file. Personas and their
credentials, every gotcha discovered in this org, tickets filed, and a
dated log of every testing session. Read it before touching anything;
append to it whenever you learn something.

## Layout

| Path | What's in it |
|---|---|
| `.mcp.json` | One Salesforce MCP server per persona, plus the `browser` (Playwright) server |
| `.claude/qa-notes.md` | ⭐ Living memory — read first, always update |
| `.claude/settings.local.json` | Enables the MCP servers for this project |
| `source-docs/` | BRD, solution design, integration docs — **PDFs are authoritative** |
| `test-cases/` | Test-case sheets, one per story batch |
| `tickets/` | One `README.md` per story, holding all of that story's bug tickets |
| `reports/` | Per-story 5-section reports (summary / test cases / BA gaps / FR-AC walkthrough / hands-on) |
| `screenshots/` | UI evidence, named `<story>-<tc>-<what>.png` |

If this is also a Salesforce DX project, `force-app/` holds retrieved
metadata — flows, validation rules and record types are **not** visible
through the MCP layer, so retrieve them locally before reasoning about
them.

## Harnesses

**API** — the per-persona Salesforce MCP connections. The only way to
test *as a named persona*. Use for persona-scoped DML and permission
testing.

**UI** — the `browser` (Playwright) MCP server. Every test case gets a
real click-through as the persona would do it; never mark a test case
PASS from API evidence alone.

**`sf` CLI** — schema, metadata retrieval, Setup Audit Trail, and any
object the MCP connections cannot see. Pass `--api-version` explicitly;
the default can be older than the objects you need.

```bash
sf org login web --alias {{ORG_ALIAS}} --instance-url {{INSTANCE_URL}}
sf config set target-org {{ORG_ALIAS}}
```

## Before each session

```bash
# confirm every persona can still log in, and why not if they can't
node .claude/skills/new-salesforce-qa-project/scripts/check-personas.mjs
```

If a password changed, update **`.mcp.json`**, the persona table in
**`qa-notes.md`**, and the test-case sheet's harness header — then
**restart Claude Code**. An already-running MCP server keeps the config
it started with; editing `.mcp.json` alone does not reload it.

## Method

Driven by two global skills:

- **`test-salesforce-personas`** — how to execute a test case (API pass,
  then UI pass, per persona)
- **`new-salesforce-qa-project`** — how this directory was built, plus
  `references/org-access-troubleshooting.md` for every login and
  visibility wall seen so far

## ⚠️ Credentials

Persona passwords are stored in plaintext in `.mcp.json` and
`qa-notes.md`. This is acceptable only because the target is a
**disposable QA sandbox**. Never point this setup at production or any
org holding real customer data.
