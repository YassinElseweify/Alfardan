# QA notes — <Client / org>

The project's memory for the `test-salesforce-personas` skill. Read it before
testing; append to it after every session.

## Org

- **URL:** https://<mydomain>--<sandbox>.sandbox.my.salesforce.com
- **sf CLI alias:** `<alias>` · **API version:** <nn.0>
- **Metadata retrieved into force-app/:** <date> (re-retrieve before citing if old)
- **Source documents:** BRD `<file>` (text: `docs/brd_full.txt`), SD `<file>` (text: `docs/sd_full.txt`)
- **Licences:** <n used / n total> — can new personas be created?

## Personas

| Persona | Username | App | MCP connection / sfp key | UI login script | Known friction |
|---|---|---|---|---|---|
| Sales Representative | … | Automotive | `sf-salesrep` / `salesrep` | `.playwright-login/rep.js` | Change Your Password → Cancel |
| … | | | | | |

Passwords live in `.claude/personas.conf` and the login scripts (both git-ignored).
Manager hierarchy (who approves whom): <rep → manager → …>.

## Jira conventions

- **Site / cloudId:** <site>.atlassian.net · `<cloudId>`
- **Project:** `<KEY>` · **Type:** Bug · **Parent:** `<EPIC>` · **Assignee:** <name> (`<accountId>`)
- **Priority scheme:** Highest / High / Medium / Low / Lowest
- **Labels:** `<story id>`, `QA`, `<stream>`, plus `Security` / `Integration` where relevant
- **Links:** *Relates* to the story's ticket — map: <STORY-01 → KEY-101, …>
- **Screenshots:** attached by <user> manually
- **Retest rule:** not fixed / partially fixed → comment + back to To Do; clean fix → Done (when told)
- **Transitions:** <DEPLOYED TO QA → (id) QA IN PROGRESS → (id) Done> · <… → To Do>

## The business cycle

| # | Step | Persona | Object | Action (where) | Gate |
|---|---|---|---|---|---|
| 1 | | | | | |

## Working click paths

- <What> — <App Launcher → … → …>

## Org-specific gotchas

1. …

## Sessions

### <YYYY-MM-DD> — <story / cycle / retest>
- Ran: …
- Records: …
- Findings: BUG-…-01 … (→ KEY-… once filed)
- Config changed / reverted: …
- Learned: …
