# Persona provisioning

How to get from "the BRD names these roles" to "each role is a working
login with the right permissions, reachable by both API and browser."

Everything here assumes a **disposable QA sandbox**. Credentials end up in
`.mcp.json` and `qa-notes.md` in plaintext. If the target org is
production or holds real customer data, stop and raise it — this approach
is not appropriate there.

---

## 1. Scope the persona set

A BRD may name dozens of personas. Do not provision all of them.

- Provision the personas the **current test-case batch** actually names.
- Add rows later as new stories pull in new roles.
- Always include a **System Administrator** connection. It is the control
  in every persona-vs-general comparison (see § 6) and the fallback when
  a persona is genuinely blocked.

Record the scoping decision in `qa-notes.md` so the next session knows
the table is deliberately partial, not incomplete by accident.

## 2. Prefer repurposing existing users over creating new ones

Sandboxes are usually full of demo/dummy users that already carry working
profile assignments, permission sets and roles. Renaming one
("Jeff Ross Service" → "CRM Agent") is faster and less error-prone than
building a user from scratch and rediscovering which of a dozen platform
permission sets it needs.

Keep a note of what each persona was repurposed *from* — when something
behaves oddly later, "this user was originally a Service demo account"
is frequently the explanation.

Leave unmapped dummy users alone and note them as untouched, so a later
session does not wonder whether they were part of the setup.

## 3. Set a known password

Existing dummy users' passwords are unknown. Set them with anonymous Apex:

```apex
System.setPassword('005XXXXXXXXXXXXXXX', 'Passw0rd2026!');
```

Run via `sf apex run --file <script> --target-org <alias>`.

Conventions worth keeping:
- One shared password across personas unless a forced reset splits them.
- When a forced reset *does* change one, update **three** places at once:
  `.mcp.json`, the `qa-notes.md` persona table, and the test-case sheet's
  execution-harness header. They drift otherwise, and a stale password in
  the test sheet gets copied forward into the next batch.

## 4. Route email with `+tag` aliasing

Point every persona at one shared team inbox using plus-addressing:

```
team-delivery+crmagent@company.com
team-delivery+salesrep@company.com
team-delivery+salesmanager@company.com
```

Mail stays visible to the whole team while remaining attributable per
persona. This matters for any test case whose expected result is an
email — and note that **absence of a logged `EmailMessage` is not proof a
send failed** (see the method skill), so a real inbox is sometimes the
only evidence available.

If a persona has to be replaced (see § 5), retire its tag and use a new
one (`+receptionist2@`) rather than reusing it, so old mail stays
attributable to the retired user.

## 5. When a user is unfixably broken

If a user rejects correct credentials through every mechanism and has
**zero `LoginHistory` rows**, do not keep diagnosing. Create a fresh User
with the same profile, permission sets, name and role; it works
immediately. Deactivate the broken one, and write it into `qa-notes.md`
as permanently retired with the list of things already ruled out — the
point of that note is to stop a future session from re-running the same
eight-hour elimination.

Full elimination list, for reference:
`references/org-access-troubleshooting.md` § 5.

## 6. Assign the *real* permissions

### ⭐ The standard access model — use this on every project

**One near-empty profile for everyone, and all real access granted
through permission set groups, with muting to subtract.**

```
Profile:  Minimum Access - Salesforce   (or a clone of it)
              ↓  same profile for every persona — grants nothing
PSG:      X_PSG_Sales_Rep, X_PSG_CRM_Agent, …   one per business role
              ↓  built from reusable permission sets
Muting:   one muting permission set per PSG, subtracting anything a
          shared permission set over-grants for that role
```

Assign via `PermissionSetAssignment` using **`PermissionSetGroupId`**,
not `PermissionSetId`.

**Why this is the standard:**

- **Roles become readable.** A persona's access is one PSG you can open
  and diff, instead of a profile plus a scattering of directly-assigned
  permission sets nobody can reconstruct.
- **Permission sets stay reusable.** A shared set can be slightly too
  generous for one role without needing to be forked — the muting
  permission set subtracts the excess for that PSG only.
- **It matches where Salesforce is going.** Permissions on profiles are
  being wound down; building on profiles now is building on a deprecated
  layer.
- **It collapses the profile sprawl that breaks logins.** When every
  persona shares one profile, profile-only settings (see below) live in
  exactly one place — which removes the "we patched two profiles and
  missed the third" failure mode entirely (see
  `org-access-troubleshooting.md` § 2).

**Do not forget `API Enabled`.** It is a user permission, and
**Minimum Access - Salesforce does not grant it**. A persona without it
logs into Lightning perfectly and fails every call on its MCP
connection — which reads exactly like a wrong password. Grant it in the
role's PSG, not on the shared profile. See
`org-access-troubleshooting.md` § 1b.

**What still lives on the profile,** and therefore still has to be
managed even under this model: session/password policies, default record
types, and app/tab visibility defaults. These are not grantable by
permission set. It is the reason the profile does not disappear entirely.

**Login IP Ranges and Login Hours also live on the profile, and the
standard is that both are empty.** Neither is used on these projects. A
profile carrying either is a defect in the org setup, not a
configuration to tune — remove it (Setup UI only; the Metadata API
cannot delete ranges). IP relaxation, where it's actually needed, is
org-wide Trusted IP Ranges under Network Access, which is also what
removes the API security-token requirement. Full reasoning:
`org-access-troubleshooting.md` § 2 and § 2b.

### Muting — the part that is easy to get wrong

A muting permission set **only mutes within its own permission set
group.** It does not revoke:

- anything granted by the **profile**,
- anything granted by a permission set assigned **directly** to the user,
- anything granted by a **different** PSG the same user also holds.

So a permission that "should be muted" but is still in effect is usually
not a broken mute — it is being granted from one of those other three
places. Check all four layers before writing that up as a defect. For QA
specifically: this is a real and recurring source of false findings, and
also of false passes when a stray direct assignment silently restores
access a test case expects to be denied.

Verify a mute by testing the **negative** — confirm the restricted action
actually fails — not by reading configuration.

### When you inherit an org that does not follow this

Most in-flight implementations will not. Two rules:

1. **Check `PermissionSetGroup` before concluding none exist.**

   ```bash
   sf org list metadata --metadata-type PermissionSetGroup --target-org <alias>
   ```

   Orgs very often already contain per-persona PSGs
   (`X_PSG_Sales_Rep`, `X_PSG_CRM_Agent`, …) that were built during the
   implementation and never assigned to anyone. That is the fix — not
   building something new.

2. **Do not shortcut with blanket `*_FullAccess` permission sets.** They
   grant edit on every field they cover, including fields deliberately
   designed read-only-except-flow. That silently masks real defects and
   manufactures false passes on precisely the access-control test cases
   the engagement exists to check.

A persona sitting on a generic profile (`Standard User`,
`Standard User Custom`) while carrying a real per-persona PSG is a normal
mid-implementation state, not necessarily a defect — but it *is* worth
raising as a migration recommendation toward the model above. Record both
layers in the persona table so a later access finding can be attributed
to the right one.

### Always verify the negative

Check a field that is *supposed* to be restricted, not only one that is
supposed to work — e.g. confirm a read-only field still rejects a direct
update with `INVALID_FIELD_FOR_INSERT_UPDATE`. A permission fix that
quietly over-grants looks identical to a correct one until a test case
depends on the difference.

## 7. Register the persona in all three places

```bash
node .claude/skills/new-salesforce-qa-project/scripts/add-persona.mjs \
  --key salesrep-sales-representative \
  --label "Sales Representative" \
  --username jstev@acme.com.qa \
  --password 'Passw0rd2026!' \
  --instance-url https://acme--qa.sandbox.my.salesforce.com \
  --notes "Repurposed from demo user 'Joshua Stevens'. Standard User Sales profile + X_PSG_Sales_Rep."
```

This writes `.mcp.json`, `.claude/settings.local.json`, and the qa-notes
persona table together so they cannot drift.

Naming convention for the connection key:
`<orgprefix>-<shortrole>-<full-role-slug>` → `af-salesrep-sales-representative`.
The prefix keeps multiple orgs distinguishable if connections are ever
enabled side by side; the full role slug makes the tool name readable in
a session's tool list.

## 8. Verify, then restart

```bash
node .claude/skills/new-salesforce-qa-project/scripts/check-personas.mjs
```

Fix every failure before proceeding — `references/org-access-troubleshooting.md`
maps each error to its cause. Then **restart the Claude Code session**, or
the servers keep running with the config they started with.

Confirm the personas actually appear as tools (`ToolSearch`) before
starting the first test case. A persona that is in `.mcp.json` but not in
the session is a fallback decision to make deliberately and report — not
something to discover halfway through a test.

## 9. Do a UI login for each persona once, during setup

Not as part of a test case — just log in, get past whatever interstitial
appears, and land on Home. This is where forced password changes,
"Scheduled Improvements" screens, MFA enrollment walls and IP blocks
surface. Finding them now costs minutes; finding them mid-test-case costs
a session and contaminates the result.

Record per persona in the qa-notes table:
- whether UI login works at all,
- what interstitial appeared and how it was cleared,
- any MFA/TOTP secret registered,
- if UI login is impossible, **say so** — that persona's test cases get an
  API-only verdict, explicitly flagged, never a silent admin substitution.

## 10. The persona table

Keep it in `qa-notes.md` as the single source of truth:

| Persona | MCP connection (API) | Username | Notes |
|---|---|---|---|
| System Administrator | `af-admin-system-administrator` | `admin@…` | Full CRUD. Auth: OAuth Client Credentials (passkey wall blocks UI). API only — fallback of last resort, always report when used. |
| Sales Representative | `af-salesrep-sales-representative` | `jstev@…` | Repurposed from "Joshua Stevens". Password `…`. Standard User Sales profile + `X_PSG_Sales_Rep`. UI login OK (forced-password screen → Cancel). |

The `Notes` column is the valuable one. It should carry: what the user
was repurposed from, current password, profile + permission set groups,
UI login status and any interstitial, and any known blocker. That column
is what makes a cold session productive in minutes.
