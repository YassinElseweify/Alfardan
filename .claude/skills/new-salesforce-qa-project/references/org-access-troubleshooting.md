# Org access troubleshooting

Every wall hit so far getting personas logged in and objects visible, with
the fix and — more importantly — how to tell them apart, because several
of them produce identical symptoms.

Work through this **during setup**, not during test execution. Diagnosing
a login wall mid-test-case is how a session gets burned.

> ## Run this first, every session
>
> ```bash
> node .claude/skills/new-salesforce-qa-project/scripts/check-personas.mjs
> ```
>
> It logs in as every persona and names the actual cause of each failure.
> Access breaks on its own between sessions — IPs change, passwords get
> reset, sandboxes refresh — so a green run yesterday proves nothing
> today. Thirty seconds here saves the session.

---

## Login walls

### 1. SOAP API login disabled org-wide

**Symptom:** every `User_Password` MCP connection fails, including the
admin's, with:

```
INVALID_OPERATION: SOAP API login() is disabled by default in this org.
```

**Fix:** an org-wide Setup toggle, not per-profile. The org owner enables
SOAP API login once and every persona starts working.

**Tell it apart:** it names itself explicitly. But note that after the fix
you may *still* see it from one connection — that is a stale MCP server
process (see #6), not a per-user restriction. Confirm by testing bogus
credentials against a different user: if that returns a normal
`INVALID_LOGIN`, the org-wide setting is already fixed.

### 1b. Persona has no "API Enabled" permission

**Symptom:** credentials are correct and the persona logs into Lightning
fine, but every API call on that connection fails —
`API_DISABLED_FOR_ORG`, or a login/query rejection that reads like bad
credentials.

**Cause:** `API Enabled` is a **user permission**, granted by profile or
permission set. Under the standard access model (§ `persona-provisioning.md`
§ 6) every persona sits on **Minimum Access - Salesforce**, which does
**not** grant it — so a persona can be perfectly provisioned for UI work
and still be unusable through its MCP connection.

**Fix:** grant `API Enabled` in the persona's permission set group (not
by editing the shared profile, which would grant it to everyone on that
profile). Check before assuming a bad password:

```bash
sf data query --target-org <alias> --api-version "$API_V" \
  --query "SELECT Name, Username, Profile.Name, Profile.PermissionsApiEnabled FROM User WHERE IsActive = true"
```

**Tell it apart:** UI login works, API does not. A wrong password fails
at *both*. An IP block (§ 2) fails at both too, with
`LOGIN_DURING_RESTRICTED_DOMAIN`.

### 2. Profile Login IP Ranges — the one that looks like a wrong password

**Symptom, API/SOAP:** `LOGIN_DURING_RESTRICTED_DOMAIN`.
**Symptom, Lightning UI:** a *generic* "check your username and password"
error — **indistinguishable from a real bad password by the text alone.**

**Cause:** `Setup → Profiles → [profile] → Login IP Ranges` is a hard
block on login from outside the listed ranges. Orgs commonly have ranges
scoped to whatever network the org owner happened to be on when they set
it up, which breaks the moment anyone tests from a new machine, office or
VPN.

**Network Access is a different control — and it is the one that
matters.** These are not two places to configure the same thing:

| Control | Where | What it does |
|---|---|---|
| **Trusted IP Ranges** | Setup → Security → Network Access | **Relaxation.** Exempts listed IPs from identity verification **and from the API security-token requirement.** Blocks nobody. |
| **Login IP Ranges** | Setup → Profiles → [profile] | **Hard block.** Login from outside the range is denied outright. |

Trusted IP Ranges do **not** override a Profile's Login IP Ranges, so
they will not unblock a profile-blocked login. But do not dismiss them
either: per Salesforce's own SOAP documentation, *"if your organization
does not have a range of trusted IP addresses configured, you must append
a security token to your password."* Network Access is therefore
load-bearing for every API connection in this scaffold — see § 2b.

> ### ✅ DECIDED — profiles carry NO Login IP Ranges and NO Login Hours
>
> **This is the standard on every project. Neither control is used at
> all.** A profile in one of these orgs should have zero
> `loginIpRanges` entries and no Login Hours restriction.
>
> Why, rather than "set them wide":
>
> - They are a **hard block** whose failure mode is a generic
>   "check your username and password" — the single most expensive
>   diagnostic dead end in this whole reference.
> - They break on every new machine, tester, office, VPN and DHCP lease,
>   forever. There is no configuration of them that is stable.
> - They live on the profile, which is the layer the standard access
>   model (`persona-provisioning.md` § 6) is deliberately emptying.
> - IP relaxation is still available where it is actually needed —
>   Trusted IP Ranges, org-wide, which is also what removes the
>   security-token requirement.
>
> **If you inherit an org that has them, remove them.** Note that the
> **Metadata API can add ranges but silently cannot remove them** (see
> below) — removal must be done by hand in
> `Setup → Profiles → [profile] → Login IP Ranges`, using the `Del` link
> on each range. Confirm via `SetupAuditTrail`, not the deploy result.
>
> Record the removal in `qa-notes.md` as a deliberate org change.
>
> **Related standard — `Session Settings → Enforce login IP ranges on
> every request` must be UNCHECKED.** This is a standing standard, not a
> per-project choice. When checked, profile login IP ranges are enforced
> on *every* request rather than only at login, which drops active
> sessions mid-request the moment an address changes and makes API and
> browser harnesses fail unpredictably part-way through a test run.
> Verify it is off during setup:
>
> ```bash
> sf org list metadata --metadata-type Settings --target-org <alias>
> # or retrieve and inspect:
> sf project retrieve start --metadata "Settings:Security" --target-org <alias>
> # look for: <enforceIpRangesEveryRequest>false</enforceIpRangesEveryRequest>
> ```
>
> Practical note under the standard access model (see
> `persona-provisioning.md` § 6): once every persona shares one
> Minimum-Access-based profile, profile-level Login IP Ranges collapse to
> a **single** place to manage. That removes the "we patched two profiles
> and missed the third" failure mode, but it does not by itself answer
> whether the restriction should exist.

**Fix: delete the ranges.** Per the standard above, these profiles
should carry none at all. `Setup → Profiles → [profile] → Login IP
Ranges` → `Del` on each entry. This must be done in the Setup UI; the
Metadata API cannot do it (see the warning below).

Do **not** "fix" it by adding your current address, and do not add a
catch-all `0.0.0.0`–`255.255.255.255` range either. Both leave the
restriction in place to break again on the next network change, and the
catch-all additionally makes a profile *look* restricted to anyone
auditing it while enforcing nothing.

> ⚠️ **The Metadata API can ADD ranges but silently cannot REMOVE them.**
> A deploy that omits existing `loginIpRanges` entries reports
> "Succeeded" with zero actual change and produces no new Setup Audit
> Trail entry. Removal must be done by hand in the Setup UI. Confirm any
> profile deploy landed by querying `SetupAuditTrail`, not by trusting
> the deploy result.

#### Why removal, not adjustment

Client IPs change constantly: a new machine, a second tester joining, a
different office, a VPN, or just a DHCP lease renewal. Each one
re-breaks every persona login with that same generic error. Any range
you set is a restriction you will be re-patching indefinitely — which is
the reasoning behind the no-ranges standard above. Remove them once and
the recurring hazard is gone, rather than managed.

**Enumerate the profiles from the org, never from memory or notes.**
Personas usually span more profiles than expected, and patching "the two
obvious ones" leaves personas silently blocked:

```bash
sf data query --target-org <alias> --api-version "$API_V" \
  --query "SELECT Name, Username, Profile.Name FROM User WHERE IsActive = true AND Profile.Name != null"
```

#### Standard profiles have a Metadata API name ≠ their UI label

This bites every time. `--metadata "Profile:Standard User"` fails with
*"Entity of type 'Profile' named 'Standard User' cannot be found"*:

| UI label | Metadata API name |
|---|---|
| Standard User | `Standard` |
| System Administrator | `Admin` |
| *(custom profiles)* | same as the label |

**Profile name quirks:** a label containing a **tab** (e.g.
`Standard User<TAB>Sales`) must be written with a **literal tab** in a
`package.xml` — the XML entity `&#9;` is *not* decoded for member-name
matching and the retrieve fails. On disk it lands URL-encoded as
`Standard User%09Sales.profile-meta.xml`.

#### Never add a range to a profile that has none

A profile with **zero** `loginIpRanges` is already in the target state.
Adding one *restricts* it — the opposite of the intent. The only valid
operation on this setting is removal.

### 2b. Security token required on API logins

**Symptom:** `INVALID_LOGIN: Invalid username, password, security token;
or user locked out.` The password is correct and the Lightning UI login
works fine, but every API/SOAP login fails.

**Cause:** Salesforce requires the **security token appended to the
password** on SOAP/API logins — *unless* the org has Trusted IP Ranges
covering the caller's address. Straight from the docs: *"If your
organization does not have a range of trusted IP addresses configured,
you must append a security token to your password during the
authentication process."*

This is the one place Network Access genuinely fixes API logins, and it
is why the no-profile-IP-ranges standard does not leave the scaffold
without an IP lever.

**Two fixes, in order of preference:**

1. **Add the range under `Setup → Security → Network Access`.** Fixes
   every persona at once, needs no per-user secrets, and nothing has to
   be re-copied into `.mcp.json` when a token is reset. This is the
   intended setup for these projects.
2. **Append each user's security token to `SALESFORCE_PASSWORD`** —
   literally `passwordTOKEN`, no separator. Get or reset it at
   `Settings → My Personal Information → Reset My Security Token`; it is
   emailed to the user and **is invalidated whenever the password
   changes**, which makes it a second thing to keep in sync on every
   forced reset (see § 4). Use only where Network Access can't be
   changed.

**Tell it apart:** UI login works, API says `INVALID_LOGIN`. Do not read
this as a broken User record (§ 5) — check `LoginHistory`, which will
show the failed API attempts here, whereas § 5's case has **zero** rows
by any mechanism.

### 3. MFA / WebAuthn passkey wall (usually the admin)

**Symptom:** username/password is accepted, then `Verify Your Identity`
(`UnifiedPasskeyVerificationUi`) offers only "Log In With a Passkey" and
"Having Trouble? Contact your admin." When the blocked user *is* the
admin, there is nobody to escalate to.

**No agent can satisfy this** — passkeys need a physical device or
browser credential.

**Fix for API access:** OAuth 2.0 Client Credentials Flow. Create a
Connected App with Client Credentials Flow enabled and `Run As` set to
the admin user, then use:

```json
"env": {
  "SALESFORCE_CONNECTION_TYPE": "OAuth_2.0_Client_Credentials",
  "SALESFORCE_CLIENT_ID": "...",
  "SALESFORCE_CLIENT_SECRET": "...",
  "SALESFORCE_INSTANCE_URL": "https://..."
}
```

Server-to-server, no interactive login, so it sidesteps MFA permanently.
**Tradeoff:** it always runs as one fixed user, so it is an admin
connection — never a substitute for real persona-level permission testing.

**Fix for UI access:** a human with device access must register a TOTP
authenticator on that user once. Until then, that persona has no UI pass;
say so explicitly in reports rather than substituting silently.

### 4. Forced "Change Your Password" screen

Two different triggers that look the same:

- **Weak trigger** — first UI login from a machine or network the org has
  not seen before. **Click Cancel.** The login completes normally, landing
  on Home with the existing password intact. No `.mcp.json` change needed.
  *Always try Cancel first.*
- **Genuine reset** — a real mandatory reset (often the first-ever login,
  after a "Scheduled Improvements" interstitial). Cancel will not get
  past it; a new password is required. When this happens:
  1. Update `SALESFORCE_PASSWORD` in `.mcp.json` **immediately**, or every
     future API call on that connection breaks.
  2. Update the persona table in `qa-notes.md`.
  3. Restart the Claude Code session (see #6) — the running server still
     holds the old password in memory.
  4. **If this persona was relying on a security token (§ 2b), it is now
     dead.** Changing a password invalidates the security token. The
     connection will keep failing with `INVALID_LOGIN` even after the new
     password is in `.mcp.json` and the session is restarted, which reads
     exactly like the password edit didn't take. Either add the Network
     Access range and drop the token entirely (preferred), or reset and
     re-append the new token.

### 5. A user that can never log in, by any mechanism

**Symptom:** correct credentials rejected identically through SOAP login,
OAuth `grant_type=password`, and the Lightning UI, with **zero
`LoginHistory` rows across every attempt, ever.**

Ruled out exhaustively once, on a real user, before giving up: password
correctness, username byte-exactness, `IsFrozen`/`IsPasswordLocked`,
permission set assignment, Login IP Range coverage, org-wide Delegated
Authentication, Session Security Level Required at Login, and browser
session state. A different dummy user on the *same profile*, given the
same treatment, logged in fine — proving the profile was not the problem
and something was uniquely broken about that one User record.

**Fix: stop diagnosing. Create a brand-new User** with the same profile,
permission sets, name and role. It works immediately. Deactivate the
broken one and note it as permanently retired so nobody re-investigates.

### 6. Editing `.mcp.json` does not reload a running server

An already-connected MCP server keeps its original env vars — they are
read once at process start. `/mcp` reload is not enough. **Only a full
Claude Code session restart** reliably respawns it with new config.

**Symptom:** the identical error message before and after the edit, for
exactly the one server that was already live. Newly-*added* servers (never
previously connected) do pick up config correctly on first connect.

### 7. Not every declared persona is exposed as a tool in a session

A server listed in `.mcp.json` may simply not be available this session —
and one missing at session start has been seen to appear later after a
reconnect. Confirm with `ToolSearch` before assuming a persona's API
connection exists. If it is missing, say so in the report and fall back
per `qa-notes.md` — never invent API results for a connection you could
not reach.

**A `CONNECT_TIMEOUT` on a persona's MCP server is usually an IP block,
not a broken server or bad credentials.** The connection failure and the
login failure look like separate problems and are frequently the same
one. Do not conclude a persona is unconfigured or that access does not
exist — run `check-personas.mjs`, which separates them in one pass:
a persona whose server timed out but whose login PASSES has a transport
problem, while one that FAILS with `LOGIN_DURING_RESTRICTED_DOMAIN` is
simply IP-blocked and needs § 2.

---

## Visibility walls (the object is there; your tool cannot see it)

### 8. The API-version blind spot — "the object does not exist" when it does

**Symptom:** through the persona MCP connections, an object reports as
completely non-existent:

- `describe_object` → "The requested resource does not exist"
- REST → `sObject type 'Appraisal' is not supported`
- anonymous Apex → fails to compile, `Invalid type: Schema.Vehicle`
- `Schema.getGlobalDescribe()` → thousands of objects, zero matches

**Cause:** the MCP connections are pinned to an older API version that
does not expose Industries / Automotive Cloud objects. **The objects are
real and full of data.** The `sf` CLI at an explicit newer
`--api-version` sees every one of them.

**The corollary that wastes the most time — "ghost fields."** Custom
lookup fields *pointing at* a hidden object disappear from describe along
with their target. This presents as "a field the code writes to but which
does not exist in the schema," which looks exactly like a serious org
defect. It is not. Apex writes to them successfully because it compiles
at its own newer API version.

**Method:** use the `sf` CLI for all schema work, metadata retrieval, and
any query touching Industries objects. Use the persona MCP connections
for persona-scoped DML and permission testing — they remain the only way
to test *as a named persona*, which is their actual job.

### 9. Custom fields deployed with zero FLS for anyone

**Symptom:** `No such column 'AF_Brand__c' on entity 'Lead'` — **even via
the admin connection** — making it look like the entire custom data model
was never deployed. Retrieving metadata proves it was.

**Cause:** fields deployed via Metadata API get **no field-level security
for anyone by default**, and nothing had ever assigned it.

**Fix — check `PermissionSetGroup` FIRST.** Orgs routinely contain
per-persona permission set *groups* that were simply never assigned to
any user. Do not conclude "no permission set exists":

```bash
sf org list metadata --metadata-type PermissionSetGroup
```

Assign via `PermissionSetAssignment` using **`PermissionSetGroupId`**
(not `PermissionSetId`).

**Do not** shortcut this with blanket `*_FullAccess` permission sets.
They grant `editable: true` on every field they cover, including fields
deliberately designed read-only-except-flow — which then silently masks
real defects and produces false passes on exactly the access-control test
cases that matter. Assign the real per-persona groups.

### 10. Metadata objects are not queryable through MCP connections

`Profile`, `PermissionSet`, `TraceFlag`, `ApexLog` commonly return
`sObject type 'X' is not supported.` Do not retry field combinations —
use the `sf` CLI, or mark the check "not independently verifiable via
API" and move on.

---

## Quick triage

| Symptom | First thing to check |
|---|---|
| *Anything at all, at session start* | **Run `check-personas.mjs` before diagnosing by hand** |
| Every persona fails to log in | Org-wide SOAP API login toggle (#1) |
| UI login works but every API call on that persona fails | Missing `API Enabled` user permission (#1b) |
| Some personas fail; UI says "check your username and password" | Profile Login IP Ranges (#2) — delete them, don't widen them |
| UI login works but API says `INVALID_LOGIN` | Missing security token (#2b) — add the Network Access range |
| It worked last session and nothing changed | The IP changed (#2). It always changes — which is why the ranges get removed, not adjusted. |
| You patched the IP ranges and some personas still fail | You missed a profile — enumerate them with SOQL (#2) |
| `Profile:Standard User` "cannot be found" | Standard profiles use API names: `Standard`, `Admin` (#2) |
| An MCP server reports `CONNECT_TIMEOUT` | Usually an IP block, not a broken server (#7) |
| Password was just changed and it still fails | Restart the session (#6) |
| Only the admin fails, after accepting the password | Passkey/MFA wall → Client Credentials (#3) |
| One specific user fails everywhere, no LoginHistory rows | Retire it, create a new User (#5) |
| "Object does not exist" but data is definitely there | API-version blind spot → use `sf` CLI (#8) |
| "No such column" on a custom field, even as admin | FLS never granted → assign the PSG (#9) |
| A profile deploy "Succeeded" but nothing changed | Metadata API cannot remove `loginIpRanges` (#2) |
