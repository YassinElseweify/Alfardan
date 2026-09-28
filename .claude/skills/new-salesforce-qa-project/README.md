# Setting up a Salesforce QA project from scratch

A step-by-step walkthrough for standing up a testing directory like the
Al-Fardan one, against any Salesforce org. Follow it top to bottom when
you get assigned to a new project.

Two skills do the work:

| Skill | What it's for |
|---|---|
| **`new-salesforce-qa-project`** (this one) | Building the directory and getting access working |
| **`test-salesforce-personas`** | Executing test cases once the directory exists |

Ask Claude to *"set up a QA project for \<org\>"* and it will invoke this
skill. Everything below is what it does — and what you'd do by hand.

---

## What you need before you start

- **The org URL** — `https://<org>--<sandbox>.sandbox.my.salesforce.com`
- **Admin access to that org**, or an org owner who can make Setup changes
  for you. You *will* need them (SOAP toggle, IP ranges, MFA).
- **The source documents as PDFs** — BRD, solution design, integration
  design. Not exports. This matters more than it sounds; see step 6.
- **Node 18+** and the **Salesforce CLI** (`sf`) installed.
- Confirmation that the org is a **disposable sandbox**. Persona
  passwords end up in plaintext in `.mcp.json`. If it's production or
  holds real customer data, stop — this setup is not appropriate.

---

## Step 1 — Create the directory

If you also want the org's metadata locally (you do — flows, validation
rules and record types are invisible to the MCP layer), start with a
Salesforce DX project and scaffold on top:

```bash
sf project generate --name "Acme-Motors"
cd Acme-Motors
```

Then scaffold the QA layer:

```bash
node .claude/skills/new-salesforce-qa-project/scripts/init-sf-qa-project.mjs \
  --org-name "Acme Motors" \
  --instance-url https://acme--qa.sandbox.my.salesforce.com \
  --dx
```

You get:

```
.mcp.json                  browser server; personas added in step 3
.claude/qa-notes.md        ⭐ the living memory file
.claude/settings.local.json
source-docs/               BRD / SD PDFs go here
test-cases/                one sheet per story batch
tickets/                   one README.md per story, holding all its bug tickets
reports/                   per-story 5-section reports
screenshots/               UI evidence
QA-README.md               what this repo is, for a human opening it cold
```

The script never overwrites anything, so re-running it on a
half-built project is safe.

---

## Step 2 — Connect the `sf` CLI

```bash
sf org login web --alias Acme --instance-url https://acme--qa.sandbox.my.salesforce.com
sf config set target-org Acme
```

Do this **even though** you're about to set up MCP connections. They do
different jobs:

- **`sf` CLI** → schema, metadata (flows, validation rules, profiles),
  Setup Audit Trail, and any Industries/Automotive Cloud object. Always
  pass `--api-version` explicitly — the CLI default can be older than the
  objects you're looking for, which makes them report as non-existent.
  **Don't hardcode the number**; discover it once per session (step 2½)
  and reuse it. A version typed into a doc is stale at the next release.
- **MCP connections** → testing *as a named persona*. That's the one
  thing the CLI can't do, and the only reason they exist.

---

## Step 2½ — Pull the org's metadata down

Do this now, while you're set up — not when a test case has already
failed and you're trying to work out why.

```bash
# discover the newest API version this org supports, then use it
API_V=$(sf api request rest '/services/data/' --target-org Acme \
  | node -pe "JSON.parse(require('fs').readFileSync(0,'utf8')).map(v=>v.version).sort((a,b)=>a-b).pop()")

sf project retrieve start --target-org Acme --api-version "$API_V" \
  --metadata Flow ValidationRule PermissionSet PermissionSetGroup \
             Profile RecordType CustomObject
```

Flows, validation rules and permission sets are **completely invisible**
to the MCP connections. On disk they're just files you can grep, which
is the difference between *"something blocked this save"* and *"this
named rule blocked it, here's the formula."*

```bash
# which validation rules touch a field
grep -rl "Trade_In_Value__c" force-app/main/default/objects/*/validationRules/
```

⚠️ **Write the retrieve date into `qa-notes.md`, and re-pull before you
cite metadata as a root cause in a ticket.** Stale metadata looks exactly
like current metadata. A sandbox refresh or a colleague's deploy is
enough to make a confidently-worded root cause wrong.

---

## Step 3 — Set up the personas

This is the part that actually takes time. Read
`references/persona-provisioning.md` before starting.

**3a. Pick which personas you need — from the BRD, not from memory.** The
BRD lists the personas and which requirements belong to each, so the list
is read out of the document rather than typed up front. A BRD may name
28. Provision the ones your first test batch touches, plus a System
Administrator — you need Admin as the control for every "is this a bug or
a permissions problem?" comparison.

This is why the documents go into `source-docs/` *before* persona setup
starts: provisioning from a half-remembered list means redoing it once
the BRD is read.

**3b. Repurpose existing demo users** rather than creating new ones.
Sandboxes are full of them, and they already have working profile and
permission set assignments. Rename them to the persona name and note
what each one used to be.

**3c. Set known passwords** with anonymous Apex — you won't know the
existing ones:

```apex
System.setPassword('005XXXXXXXXXXXXXXX', 'Passw0rd2026!');
```

**3d. Route their emails** to one team inbox with `+tag` aliasing
(`team+salesrep@company.com`), so mail is both visible to the team and
attributable per persona.

**3e. Assign access using the standard model.**

> **The standard, on every project from here on:** put every persona on
> the **Minimum Access - Salesforce** profile (or a clone of it), grant
> all real access through **one permission set group per business role**,
> and use a **muting permission set** inside each group to subtract
> anything a shared permission set over-grants for that role.

Assign with `PermissionSetAssignment` using `PermissionSetGroupId`.

Why: roles become one readable, diffable object instead of a profile plus
scattered direct assignments; permission sets stay reusable because
muting subtracts instead of forcing a fork; it's where Salesforce is
taking the platform; and it collapses profile sprawl so profile-only
settings live in one place.

**What still lives on the profile** (not grantable by permission set):
session/password policies, default record types, app/tab visibility
defaults. Login IP Ranges and Login Hours also live there, but the
standard is that both are **empty** — see the traps in step 4.

**Muting gotcha:** a muting permission set only mutes *within its own
group*. It cannot revoke anything granted by the profile, by a directly
assigned permission set, or by a different PSG the user also holds. A
permission that "should be muted" but still works is usually being
granted from one of those — check all four layers before calling it a
defect. Verify mutes by testing the negative, not by reading config.

On an **inherited org** that doesn't follow this, check for existing
permission set groups before building anything — orgs are full of
per-persona PSGs that were built during implementation and never assigned
to anyone:

```bash
sf org list metadata --metadata-type PermissionSetGroup --target-org Acme
```

> ⚠️ Don't shortcut this with blanket `*_FullAccess` permission sets.
> They grant edit on fields deliberately designed read-only, which
> silently masks defects and produces false passes on exactly the
> access-control test cases you're there to check.

**3f. Register each persona:**

```bash
node .claude/skills/new-salesforce-qa-project/scripts/add-persona.mjs \
  --key acme-salesrep-sales-representative \
  --label "Sales Representative" \
  --username jstev@acme.com.qa \
  --password 'Passw0rd2026!' \
  --instance-url https://acme--qa.sandbox.my.salesforce.com \
  --notes "Repurposed from demo user 'Joshua Stevens'. Standard User Sales + X_PSG_Sales_Rep."
```

Updates `.mcp.json`, `settings.local.json` and the qa-notes persona table
together, so they can't drift apart.

**For an admin behind an MFA/passkey wall** (very common — the admin
often can't log in at all), create a Connected App with Client
Credentials Flow, `Run As` the admin, then:

```bash
node .../add-persona.mjs --key acme-admin-system-administrator \
  --label "System Administrator" --auth client-credentials \
  --client-id <id> --client-secret <secret> \
  --instance-url https://acme--qa.sandbox.my.salesforce.com
```

No interactive login step, so it sidesteps MFA permanently. The catch:
it always runs as one fixed user, so it's an admin connection — never a
substitute for real persona permission testing.

**3g. Grant `API Enabled`.** Minimum Access - Salesforce doesn't include
it. Without it a persona logs into Lightning fine and fails every single
API call — which looks identical to a wrong password. Grant it in the
role's permission set group.

---

## Step 3½ — Optional: the org-wide exploration connectors

Ask whether you also want **Sobject All** (schema-wide access across
every object, unscoped by persona) or **headless 360** (broader
whole-org investigation). They're what let Claude survey the org as a
whole — find gaps between the BRD and what's actually built — rather
than only testing what one persona can see.

Both are set up by creating an **External App (Connected App)** in the
org, as the admin.

Two things worth knowing before you build them:

- **Sobject All across several projects:** don't make an External App
  per project. Create **one custom MCP server in the org** and add the
  Sobject All tools to it — every project points at that one server.
- **headless 360 can't do that.** Its tools cannot be added to a custom
  MCP server, so across multiple projects **only one** headless 360
  connection is active at a time. Note in `qa-notes.md` which project
  currently holds it.

---

## Step 4 — Verify every login before writing anything

```bash
node .claude/skills/new-salesforce-qa-project/scripts/check-personas.mjs
```

This is the highest-value five minutes in the whole setup. It logs in as
every persona and tells you *why* each failure happened — because
Salesforce shows the same generic "check your username and password"
message in Lightning for causes that are completely different:

| What you get back | What it actually means |
|---|---|
| `LOGIN_DURING_RESTRICTED_DOMAIN` | Profile **Login IP Ranges** block this machine. Not a bad password. |
| `SOAP API login() is disabled` | Org-wide toggle is off — one Setup change fixes every persona at once. |
| `INVALID_LOGIN` | Genuinely wrong credentials, *or* a stale MCP process holding an old password. |

Fix every failure now. `references/org-access-troubleshooting.md` has all
ten walls seen so far with their fixes.

**Three traps worth knowing up front:**

- **Profiles must carry NO Login IP Ranges and NO Login Hours.** That's
  the standard on every project — not "set them wide," remove them. They
  are a hard block whose failure mode is a generic "check your username
  and password," and they re-break on every new machine, office, VPN or
  DHCP lease. Removal must be done in the Setup UI: the Metadata API can
  *add* ranges but **silently cannot remove them** (a deploy reports
  "Succeeded" having changed nothing). Enumerate the affected profiles
  with SOQL rather than guessing — patching "the obvious two" leaves
  personas silently blocked. Standard profiles use API names, not
  labels: `Standard User` → `Standard`, `System Administrator` → `Admin`.
- **You still need Network Access — for a different reason.** Trusted IP
  Ranges (`Setup → Security → Network Access`) don't override a profile
  block, but they're what removes the **security token** requirement on
  API logins. Without a range covering your machine, every persona's
  `SALESFORCE_PASSWORD` has to be `password+securitytoken` or the API
  login fails with `INVALID_LOGIN` while the UI login works fine. Add
  the range — it fixes every persona at once and survives password
  resets, which tokens don't.
- **Editing `.mcp.json` doesn't reload a running server.** The process
  reads its env vars once at startup. You need a full Claude Code
  restart. Symptom: the identical error before and after your edit.

---

## Step 5 — Log into the UI once per persona

Not as a test — just log in and get to Home. This is where forced
password screens, "Scheduled Improvements" interstitials and MFA
enrollment walls appear. Finding them now costs minutes; finding them
mid-test-case costs a session.

Two forced-password-change triggers look identical:

- **First login from a new machine/network** → click **Cancel**. Login
  completes normally, password unchanged. *Always try this first.*
- **A genuine mandatory reset** → Cancel won't work. Set a new password,
  then update `.mcp.json`, the qa-notes persona table, *and* the
  test-case sheet header — and restart Claude Code.

Record per persona in qa-notes.md whether UI login works. If a persona
genuinely can't log into the UI, that's not a blocker — it means those
test cases get an explicitly-flagged API-only verdict, never a silent
admin substitution.

---

## Step 6 — Load the source documents

Put the **original PDFs** in `source-docs/`. Extract with
`pdftotext -layout`.

**Never work from a Markdown or HTML export of a BRD.** On the Al-Fardan
project the exports were silently missing an entire story's User Story,
Requirement Overview, Related Personas, FR1 and FR2, plus acceptance
criteria and assumptions from two other stories. Several "contradictions
in the BRD" that got written up as findings turned out to be conversion
artifacts that didn't exist in the source at all. Note in qa-notes.md
which file is authoritative.

---

## Step 7 — Write the baseline, then start testing

Before the first test case, record a baseline section in
`.claude/qa-notes.md`:

- which objects exist and their record counts
- which harness can see what (MCP vs `sf` CLI vs browser)
- which personas can reach which objects

That last point catches the single most expensive class of false finding.
The MCP connections are pinned to an older API version that **cannot see
Industries/Automotive Cloud objects at all** — they report as
non-existent, Apex won't compile against them, and custom lookup fields
pointing at them vanish from describe too (the "ghost field" effect).
None of it is an org defect. Write down which tool sees what, once, and
you'll never re-report a tooling artifact as a bug.

Then generate the test-case sheet into `test-cases/` and start executing
per the `test-salesforce-personas` skill.

---

## How the project runs day to day

**Every session starts by reading `.claude/qa-notes.md`** and ends by
appending to it. It holds the persona table, every gotcha found in this
org, tickets filed, and a dated log of each pass. A finding that only
exists in a chat transcript is lost.

**Every test case gets tested twice** — once through the API (proving the
functionality and validation genuinely exist) and once by clicking
through Lightning as the named persona. Never mark PASS from API
evidence alone.

**Every persona-found bug gets re-tested as System Administrator:**

| Persona | Admin | Classification |
|---|---|---|
| FAIL | FAIL | **General** — affects everyone |
| FAIL | PASS | **Persona-specific** — name the persona, state that Admin can do it |

A ticket is raised either way; the classification changes the framing,
not whether it's reported. This is what stops an org-wide defect being
routed to the permissions team and closed as "works for admin."

**Deliverables** are the 5-section report (summary of what was done /
test cases executed / BA gaps / walkthrough by FR and AC / hands-on with
fresh records) and one tickets README per story holding every defect,
each with a `BUG-<STORY>-NN` id, citing the BRD and solution design with
**direct quotes** and stating a **verified root cause**. The README is
reviewed and approved before anything is created in Jira. Templates are in `assets/`; the rules are in
`references/deliverable-formats.md`.

---

## Reference index

| File | Read it when |
|---|---|
| `SKILL.md` | The workflow Claude follows |
| `references/persona-provisioning.md` | Setting up users, passwords, permission sets |
| `references/org-access-troubleshooting.md` | Anything won't log in, or an object "doesn't exist" |
| `references/deliverable-formats.md` | Writing a report, a ticket, or setting priority |
| `assets/*.template.md` | Starting a qa-notes, test-case sheet, ticket or report |
| `scripts/init-sf-qa-project.mjs` | Creating the directory |
| `scripts/add-persona.mjs` | Adding a persona |
| `scripts/check-personas.mjs` | Verifying logins — run at the start of every session |
