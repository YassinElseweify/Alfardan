---
name: new-salesforce-qa-project
description: Scaffold a new Salesforce QA/testing project directory from scratch for any org — persona MCP connections, browser harness, qa-notes memory file, source-doc intake, test-case/ticket/report folders. Use when starting QA on a new Salesforce org or client, when asked to "set up a testing project/directory" for Salesforce, or when onboarding onto an org that has no QA scaffold yet.
---

# Setting up a new Salesforce QA project

This builds the directory a QA engagement runs out of: one repo per org,
with a persona-per-connection API harness, a browser harness, and a
living memory file. Once it exists, testing itself is driven by the
companion skill **`test-salesforce-personas`** (the method) — this skill
is only about getting from "here is an org and some documents" to "I can
start testing" without rediscovering the same access problems every time.

**Budget expectation:** the scaffold takes minutes. *Access* — getting
every persona actually able to log in via both API and UI — is where the
hours go, and it is the entire point of doing it up front. See
`references/org-access-troubleshooting.md`; work through it before
writing a single test case, not while executing one.

## What gets built

```
<project>/
├── .mcp.json               one Salesforce MCP server per persona + browser
├── .claude/
│   ├── qa-notes.md         ⭐ the living memory file — personas, gotchas, findings
│   └── settings.local.json enables the MCP servers for this project
├── source-docs/            BRD / solution design / integration docs — PDFs, not exports
├── test-cases/             one .md sheet per story batch
├── tickets/                one README.md per story, holding all its bug tickets
├── reports/                per-story 5-section reports
├── screenshots/            UI evidence, named <story>-<tc>-<what>.png
└── QA-README.md            what this repo is, for a human opening it cold
```

If the org's metadata is also wanted locally (usually yes — validation
rules, flows and record types are **not** visible through the MCP layer),
the same directory doubles as a Salesforce DX project: `sfdx-project.json`,
`force-app/`, `.forceignore`. Create that with `sf project generate` first
and scaffold on top of it, rather than the other way around.

## Workflow

### 0. Get the instance URL before anything else — this is a gate

**The first thing to ask for, before scaffolding, before personas,
before any other question.** Nothing downstream works without it and
nothing else is worth doing until it is in hand:

> What's the org's My Domain URL? It looks like
> `https://<org>--<sandbox>.sandbox.my.salesforce.com`.

Why it is the gate, not just the first field:

- It goes into `.mcp.json`, `qa-notes.md`, the `sf` login and every
  script — a wrong value means redoing all of them.
- It is **not** `test.salesforce.com` or `login.salesforce.com`. Those
  are login hosts. The instance URL is the org's own My Domain.
- It cannot be derived. A sandbox name is not guessable from the client
  name, and a refreshed sandbox gets a new host.
- Everything else in setup can proceed with placeholders and be
  corrected later. This cannot.

**Never invent or construct it.** If the user does not have it, stop and
wait — do not scaffold with a guessed host "to be fixed later," because
every artifact written from it then has to be found and corrected.

Also confirm at this point that the org is a **disposable sandbox**
(credentials land in `.mcp.json` in plaintext) and that an **admin
login** exists for the Setup-side work in § 3 and § 3b.

### 0b. Ask for the source documents next — the personas are in them

**Do not ask the user to list personas.** The BRD names them, along with
the roles each requirement belongs to. Asking for a typed list produces a
worse answer than the document already contains, and it invites a
half-remembered set that then has to be reconciled against the BRD
anyway.

So the second ask is for the documents, not the people:

> Drop the source documents into `source-docs/` — the BRD, the solution
> design, any integration design, as the **original PDFs** (not exports).
> I'll read the personas out of the BRD rather than have you list them.
> Tell me when they're in.

Then read them and **propose** the persona set back for confirmation —
which roles the first test batch touches, plus a System Administrator as
the control (`persona-provisioning.md` § 1). The user corrects the
proposal; they don't author it.

If the documents genuinely aren't ready, you can scaffold and authorize
the CLI (§ 1, § 2) meanwhile, but **do not provision personas from
guesswork** — that work gets redone once the BRD arrives. Note the
missing documents in `qa-notes.md` and stop there.

> Ordering matters: instance URL → documents → personas. Each one is
> required to do the next properly, and doing them out of order means
> redoing work rather than merely waiting.

### 1. Scaffold the directory

```bash
node .claude/skills/new-salesforce-qa-project/scripts/init-sf-qa-project.mjs \
  --org-name "Acme Motors" \
  --instance-url https://acme--qa.sandbox.my.salesforce.com \
  --dir .
```

Idempotent — it never overwrites an existing file, so it is safe to
re-run on a partially built project. It writes the folder skeleton, a
`.mcp.json` with only the `browser` server (personas get added next), a
seeded `.claude/qa-notes.md`, `QA-README.md`, and appends the QA entries
to `.gitignore`.

Add `--dx` if this is also a DX project and you want `.forceignore` /
`sfdx-project.json` checked and reported on.

### 2. Authorize the `sf` CLI against the org

```bash
sf org login web --alias <OrgAlias> --instance-url <instance-url>
sf config set target-org <OrgAlias>
```

**Do this even though the MCP connections exist.** The CLI is the only
harness that reliably sees Industries/Automotive Cloud objects, metadata
(flows, validation rules, record types, profiles), and Setup Audit Trail.
The MCP connections are for persona-scoped DML and permission testing —
they are not a schema tool. See `references/org-access-troubleshooting.md`
§ "The API-version blind spot."

#### Always pass `--api-version` — and never hardcode it

The CLI's own default can be older than the objects you are looking for,
which makes them report as non-existent
(`org-access-troubleshooting.md` § 8). But a version written into a
command or a doc goes stale at the next Salesforce release and
reintroduces the same bug — so **ask the org** and reuse the answer:

```bash
# discover the newest API version THIS org supports
API_V=$(sf api request rest '/services/data/' --target-org <alias> \
  | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).map(v=>v.version).sort((a,b)=>a-b).pop()")
echo "$API_V"
```

Then pass `--api-version "$API_V"` on every `sf` command in the session.
Record the discovered value and the date in `qa-notes.md` alongside the
metadata retrieve stamp.

Two consequences worth applying consistently:

- **`check-personas.mjs` already does this itself** — it reads
  `<instance>/services/data/` (no auth needed) and uses the newest
  version returned. `--api-version` there is an override for pinning an
  older one deliberately, not something to pass routinely.
- **`sfdx-project.json`'s `sourceApiVersion`** is written by
  `sf project generate` at whatever the CLI shipped with. Check it
  against `$API_V` and update it if the org is newer — otherwise
  retrieves silently run at the older version.

> Do not "fix" a version problem by editing a number in these docs to a
> newer one. If a hardcoded version appears anywhere in this skill, that
> is the bug — replace it with discovery.

### 2b. Retrieve the org's metadata into the project

**Do this during setup, not when a test case has already failed.** The
artifacts QA reasons about hardest — flows, validation rules, permission
sets — are invisible to the MCP layer entirely. Retrieved to disk they
become greppable files, which turns "why was this save blocked / what
does this flow actually do" from an inference exercise into a file read.

```bash
sf project retrieve start --target-org <alias> --api-version "$API_V" \
  --metadata Flow ValidationRule PermissionSet PermissionSetGroup \
             Profile RecordType CustomObject
```

They land under `force-app/main/default/` — `flows/*.flow-meta.xml`,
`objects/<Object>/validationRules/*.validationRule-meta.xml`,
`permissionsets/`, `objects/<Object>/fields/`.

What this directly buys, referenced elsewhere in these skills:

| Question | Without local metadata | With it |
|---|---|---|
| What does this flow really do? | `FlowDefinitionView.Description` — the author's summary, often stale | Read the flow XML: actual decisions, criteria, assignments |
| Which rule blocked this save? | Isolate empirically, one condition at a time | Grep `errorConditionFormula` across the object's rules |
| Is this a permissions gap or a build defect? | Re-test as Admin and infer | Read the PSG/permission set XML directly |
| Is this field genuinely read-only? | `describe_object` says `Type: string` either way | Read the field XML |

Useful greps once it is on disk:

```bash
# every validation rule mentioning a field
grep -rl "Trade_In_Value__c" force-app/main/default/objects/*/validationRules/

# which flows are active and what object they trigger on
grep -rE "<status>|<object>" force-app/main/default/flows/
```

> ⚠️ **Stamp the retrieve date into `qa-notes.md`, and re-retrieve before
> citing metadata as a root cause.** Local metadata goes stale silently —
> a sandbox refresh or someone else's deploy leaves the files looking
> perfectly valid. A root cause confidently sourced from three-week-old
> flow XML is worse than admitting the cause is not isolated, because it
> reads as verified. `deliverable-formats.md` § B requires root cause to
> be a *verified mechanism*; metadata of unknown age does not meet that
> bar.

This does **not** replace the `sf` CLI for live queries or the persona
connections for permission testing. It is the static picture — what is
built. The connections show what happens at runtime. Findings come from
the gap between them, and between both and the BRD.

### 3. Provision the personas

This is the real work. Read `references/persona-provisioning.md` in full
before starting. The short version:

1. **Map BRD personas → actual org users.** The persona list comes from
   the BRD (§ 0b) — read it out of the document rather than asking the
   user to recite it. A BRD may name 28 personas; scope to the ones the
   current test batch touches, propose that subset for confirmation, and
   add more later.
   Prefer repurposing existing dummy/demo users (rename them) over
   creating new ones — they already carry working profile and permission
   set assignments.
2. **Set a known password** on each via anonymous Apex
   (`System.setPassword`), since existing dummy users' passwords are
   unknown.
3. **Route every persona's email** to one shared team inbox using `+tag`
   aliasing (`team+salesrep@company.com`) so mail is both visible to the
   team and attributable per persona.
4. **Assign access using the standard model** — every persona on the
   **Minimum Access - Salesforce** profile (or a clone), all real access
   granted by **one permission set group per business role**, with a
   **muting permission set** subtracting anything a shared permission set
   over-grants. Assign via `PermissionSetAssignment` using
   `PermissionSetGroupId`. On an inherited org that doesn't follow this,
   check `PermissionSetGroup` before concluding none exist — orgs
   frequently have per-persona PSGs that were never assigned to anyone —
   and raise the migration as a recommendation.
5. **Register each persona** in `.mcp.json` and the qa-notes table:

```bash
node .claude/skills/new-salesforce-qa-project/scripts/add-persona.mjs \
  --key salesrep-sales-representative \
  --label "Sales Representative" \
  --username jstev@acme.com.qa \
  --password 'Passw0rd!' \
  --instance-url https://acme--qa.sandbox.my.salesforce.com
```

It updates `.mcp.json`, `.claude/settings.local.json`, and appends a row
to the qa-notes persona table in one step, so the three never drift apart.

For an admin account behind an MFA/passkey wall, use
`--auth client-credentials --client-id ... --client-secret ...` instead of
`--password`. That flow has no interactive login step, so it sidesteps
MFA entirely — at the cost of always running as one fixed user, which
means it can stand in for an admin connection but never for real
persona-level permission testing.

### 3b. Ask whether to add the org-wide exploration connectors

The persona connections answer *"can this role do X?"*. They deliberately
cannot answer *"what exists in this org at all?"* — each one is scoped to
one user's visibility. Two optional connectors cover that gap, and the
user should be **asked** whether they want either:

- **Sobject All** — schema-wide access across every object, unscoped by
  persona. Use it to map the object model, confirm whether a field,
  object or automation exists anywhere, and find gaps between what the
  BRD describes and what is actually built.
- **headless 360** — the broader headless org-exploration connector, for
  whole-org investigation beyond object-level schema.

They complement the harnesses already described, they do not replace
them: the `sf` CLI remains the metadata tool, the persona connections
remain the only honest way to test as a named role, and the local
`force-app/` metadata is the static picture against which these show the
live org.

**The setup is the user's to do in Setup, not the agent's:**

- Each connector is added by creating an **External App (Connected App)**
  in the org, under the admin authorized in step 2.
- If the same org serves **multiple QA projects** that each want Sobject
  All, do not create an External App per project. Create **one custom MCP
  server in the Salesforce org** and add the Sobject All MCP server's
  tools to it; every project's `.mcp.json` then points at that one server.
- **headless 360 does not allow its tools to be added to a custom MCP
  server.** Across multiple projects only **one** headless 360 connection
  can be active at a time. Say this up front rather than wiring a second
  one that will silently not work, and record in `qa-notes.md` which
  project currently holds it.

### 4. Verify every connection before writing anything

```bash
node .claude/skills/new-salesforce-qa-project/scripts/check-personas.mjs
```

Logs in as each persona in `.mcp.json` and reports PASS/FAIL with the
*interpreted* cause — it specifically distinguishes the errors that look
identical from the UI:

| Reported | Actual cause |
|---|---|
| `LOGIN_DURING_RESTRICTED_DOMAIN` | Profile **Login IP Ranges** blocks this machine — not a bad password |
| `INVALID_OPERATION ... SOAP API login() is disabled` | Org-wide SOAP toggle is off; one Setup change fixes every persona |
| `INVALID_LOGIN` | Genuinely wrong credentials, *or* a stale MCP process holding an old password |

A suite built on unverified logins wastes the whole session. Fix every
FAIL here, then restart the Claude Code session so the MCP servers
respawn with current config (editing `.mcp.json` alone does **not**
reload an already-running server).

### 5. Intake the source documents

`source-docs/` exists after step 1 but nothing fills it on its own.
**Stop and ask the user to put the documents in**, naming what is
wanted, rather than scaffolding an empty folder they never notice:

> `source-docs/` is ready. Please drop in the **original PDFs** — the
> BRD, the solution design, any integration design, plus anything else
> useful (Jira exports, process flows, meeting notes). Tell me when
> they're in, or say "continue without them" and I'll note the gap.

If they say continue, record in `qa-notes.md` which documents are still
missing, so a later session knows the baseline was built blind.

Put the **original PDFs** in `source-docs/` — the BRD, the solution
design, any integration design. Extract with `pdftotext -layout`.

**Never work from a Markdown/HTML export of these documents.** Exports
silently drop whole rows: in one project an export was missing an entire
story's User Story, Requirement Overview, Related Personas, FR1 and FR2,
plus acceptance criteria and assumptions from two other stories — and
several "contradictions in the BRD" filed as findings turned out to be
conversion artifacts that did not exist in the source. Record in
qa-notes.md which file is authoritative.

Then write the test-case sheet into `test-cases/` from the template in
`assets/test-cases.template.md`. Show the extracted test-case list to the
user before executing anything — if intake misreads the requirements,
every result after it is confidently wrong.

### 6. Record the baseline in qa-notes.md, then start testing

Before the first test case, write a schema/access baseline section into
`.claude/qa-notes.md`: which objects exist and their record counts, which
personas can reach which objects, which tools see what, **and the date
the metadata in `force-app/` was retrieved** (step 2b). That baseline is
what later sessions diff against, and it is what stops a tooling artifact
from being reported as an org defect.

Hand off to **`test-salesforce-personas`** for execution method, and
`references/deliverable-formats.md` for what the reports and tickets look
like.

## The two rules that make this scaffold worth anything

**1. `qa-notes.md` is the deliverable that outlives the session.**
Everything learned goes in it, dated: new gotchas, resolved mysteries,
retracted findings, records left in the org as evidence, credential
changes. It is read at the start of every session and appended to
throughout. A finding that only exists in a chat transcript is lost.
Write corrections as new dated entries that say what was wrong and why —
do not silently edit history, because a later reader needs to know a
claim was once believed.

**2. Credentials live in `.mcp.json` in plaintext, so the org must be
disposable.** This scaffold is for QA sandboxes. If the target is
production or holds real customer data, stop and use a different
credential strategy — do not scaffold personas this way, and say so.

## References

- `references/persona-provisioning.md` — mapping BRD personas to users, passwords, permission sets, email aliasing
- `references/org-access-troubleshooting.md` — every login/visibility wall hit so far, with the fix and how to tell them apart
- `references/deliverable-formats.md` — the 5-section report, the tickets README format, the priority scheme

## Assets

- `assets/qa-notes.template.md` — seeded memory file
- `assets/test-cases.template.md` — test-case sheet with execution-harness header
- `assets/tickets-readme.template.md` — the per-story tickets README (all bugs in one file)
- `assets/report.template.md` — the 5-section story report
- `assets/QA-README.template.md` — the new repo's own README
