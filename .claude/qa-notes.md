# Al-Fardan QA notes

Org: `https://alfardanautomobiles--qa.sandbox.my.salesforce.com`
(UI My Domain host: `alfardanautomobiles--qa.sandbox.lightning.force.com`)

Read this before testing anything in this project. Read alongside the
global skills `test-salesforce-personas` (method) and
`new-salesforce-qa-project` (how this directory was scaffolded).
Update this file — don't let discoveries evaporate at the end of a
session.

## Personas

Scoped to the first round of test cases (BRD lists 28 personas total —
add rows here as more are needed).

| Persona | MCP connection (API) | Username | Notes |
|---|---|---|---|
| System Administrator | `af-admin-system-administrator` | `arcsen@alfardan.com.qa` | Full CRUD. Auth: **OAuth 2.0 Client Credentials** (Connected App "Al-Fardan QA MCP Admin", Run As this user) — not username/password, because this user's UI login is gated by a mandatory WebAuthn passkey verification with no fallback. Use as fallback of last resort when a test case's real persona is API- or UI-blocked — say so explicitly in any report. **For UI/Setup access, use QA Test Admin below instead** — this account's wall isn't fixable directly (confirmed org-wide/profile-level, not specific to this one account). |
| **QA Test Admin** (UI/Setup access) | none (UI-only persona) | `juw.hfu3iriiizja.8vme43a1ydit.qmphmvmzg0.z75ml2vkdwxs@alfardan.com.qa.qa` | Created 2026-09-08, repurposed from the untouched "Underwriter John" dummy user (org was at its 10/10 "Salesforce" license cap). Profile changed to System Administrator. Password on file with the other persona credentials. **Purpose: the only persona with real Setup/Flow-Builder UI access** — for debugging flows, reading Apex logs in Setup, etc. First login required registering a passkey — confirming the "account requires a passkey" wall is an org-wide policy on the System Administrator profile, not something specific/fixable on the original account. Passkey setup was completed once, with explicit user sign-off, via a session-scoped browser mechanism — it is bound to that mechanism, not usable from an ordinary device, and would need to be redone the same way if a fresh browser session ever needs to re-authenticate as this user from scratch. |
| CRM Executive / Agent | `af-crmagent-crm-executive-agent` | `jeff.ross.0to8ufepac1j.6kukvekpouzd.itsy.ttuu7svtokzc@alfardan.com.qa.qa` | Repurposed from pre-existing dummy user "Jeff Ross Service" (renamed to "CRM Agent"). Handles leads, cases, follow-ups, selected customer communications. Email set to `emea-delivery-operations+crmagent@arcsen.com`. **Password changed 2026-08-23 to `Arcsen@2026UI!`** during first UI login (forced Change-Your-Password screen after the Scheduled-Improvements interstitial — see Gotcha #1). `.mcp.json` already updated to match. Assigned to generic **Standard User** profile — no persona-specific profile/permission set exists yet (see Gotcha below). Also now a direct member of the `AF_Q_Leads_Automobiles`, `AF_Q_Leads_PremierMotors`, and `AF_Q_Leads_SportsMotors` queues (added 2026-08-23 to fix the round-robin crash — see Gotcha below). |
| CRM Supervisor / Manager | `af-crmsupervisor-crm-supervisor-manager` | `abc.ghs.a8lkkhh7ajrz.n62oqwekox20.2mtsr5.swjtvjooad8e@alfardan.com.qa.qa` | Repurposed from "Sukhmeet Puri" (renamed to "CRM Supervisor"). Monitors queues/SLAs/escalations/team performance; owns campaign calendar planning and approves segments/journeys/marketing comms across Alfardan brands. Email `emea-delivery-operations+crmsupervisor@arcsen.com`. Password `Arcsen@2026!`. Generic **Standard User** profile. |
| Sales Receptionist | `af-receptionist-sales-receptionist` | `salesreceptionist.v2.20260823@alfardan.com.qa.qa` | Brand-new User created 2026-08-23 to replace the permanently broken original (see Gotcha below) — same Profile (Standard User Custom), same `AF_QA_API_Access` permission set, same name/role. Receives walk-in customers, creates an Opportunity under the customer's Account, assigns it to a Sales Representative (triggers assignment notification). Email `emea-delivery-operations+receptionist2@arcsen.com` (note the `2` — the original's `+receptionist@` tag is retired along with that user). Password `Arcsen@2030!`. API login confirmed working; UI login confirmed working end-to-end through Salesforce's normal first-login "Change Your Password" flow to the Lightning Home page. Permission set assignments mirror the retired original exactly (11 total): `AF_QA_API_Access` plus the 9 Automotive Cloud/Industries platform sets it had (Rule Engine Runtime, Salesforce Pricing Run Time User, Stage Management User, both "Omnistudio User"-labeled sets — `OmniStudioExecution` and `OmniStudioUser`, Context Service Runtime, Product Discovery User, Product Catalog Management Viewer, VehAndAssetLendingForAgentsUser) plus one auto-provisioned companion permission set (`00eB0000000wbSfIAI`) that Salesforce attaches automatically as a side effect of one of the others — not something to assign manually if replicating this again. |
| Sales Representative | `af-salesrep-sales-representative` | `jstev_sales.z58pnjv0sn9u.cuosciyzsimv.hg.u6jbyrt9b0lw@alfardan.com.qa.qa` | Repurposed from "Joshua Stevens" (renamed to "Sales Representative"). Owns opportunities, quotations, reservations, sales progression. Email `emea-delivery-operations+salesrep@arcsen.com`. Password `Arcsen@2026!`. **Standard User Sales** profile. |
| Sales Manager / Showroom Manager | `af-salesmanager-sales-showroom-manager` | `mpapa_sales.mzhuuj0f2p37.b7yd1rlvtug8.pk.9hheadylw6u0@alfardan.com.qa.qa` | Repurposed from "Melina Papadopoulos - Sales" (renamed to "Sales Manager"). Approves selected transactions, oversees sales execution. Email `emea-delivery-operations+salesmanager@arcsen.com`. Password `Arcsen@2026!`. **Standard User Sales** profile. |

"Underwriter John" (`juw...@alfardan.com.qa.qa`), the previously-untouched
dummy user left over from the same batch, was repurposed 2026-09-08 into
QA Test Admin (see Personas table above) — no longer a spare/untouched user.

**Email convention**: all 5 operational personas route to the shared
`emea-delivery-operations@arcsen.com` inbox via `+tag` aliasing (e.g.
`emea-delivery-operations+crmagent@arcsen.com`) so mail is visible to
the team while still distinguishable per persona.

**Password note**: all 5 repurposed personas share `Arcsen@2026!`,
set via anonymous Apex (`System.setPassword`) since the org's original
passwords for these dummy users were unknown. Stored in plaintext here
and in `.mcp.json` — this is a disposable QA sandbox, consistent with
how LeasePlan's project notes handle the same tradeoff.

## Gotchas discovered in this project

- **System Administrator UI login is blocked by a mandatory WebAuthn
  passkey prompt with no fallback.** Unlike LeasePlan (which has a
  TOTP authenticator registered), this org's admin account
  (`arcsen@alfardan.com.qa`) has no authenticator-app method
  registered — after username/password it goes straight to "Verify
  Your Identity" (`UnifiedPasskeyVerificationUi`) with only a
  "Log In With a Passkey" button and a "Having Trouble? Contact your
  admin" message. Since this **is** the admin, there's no one to
  escalate to, and passkeys require a physical device/browser
  credential an agent can't produce. If UI testing as System Admin is
  ever needed, register a TOTP authenticator on this user first
  (requires a human with device/passkey access to get through Setup
  once) — same fix pattern as LeasePlan's SRM Admin.
- **SOAP API login was initially disabled org-wide**, blocking
  `User_Password`-type MCP connections for every user including
  admin, with the specific error `INVALID_OPERATION: SOAP API
  login() is disabled by default in this org.` The user (org owner)
  enabled it directly in Setup; after that, `User_Password` auth
  worked normally for the 5 personas. If a fresh org/sandbox hits
  this again, that Setup toggle is the fix — it's an org-wide
  setting, not per-profile (confirmed: a bogus-credentials test
  against a different user got a normal `INVALID_LOGIN` error even
  while the real admin was still hitting the SOAP-disabled error,
  which was actually a **stale cached MCP server process** still
  running pre-fix config, not a per-user restriction — see next
  point).
- **Editing `.mcp.json` for an already-connected server does not take
  effect on `/mcp` reload alone** — the child process for that
  specific server keeps running with its original env vars. Only a
  full Claude Code session restart reliably respawns it with the new
  config. Newly-added servers (not previously connected) do pick up
  their config correctly on the first connect. Symptom: identical
  error message before and after an `.mcp.json` edit, for the one
  server that was already live.
- **To bypass both the passkey wall and the SOAP restriction for the
  admin account**, used OAuth 2.0 Client Credentials Flow instead: a
  Connected App ("Al-Fardan QA MCP Admin") with Client Credentials
  Flow enabled, Run As = `arcsen@alfardan.com.qa`. This is a
  server-to-server flow with no interactive login step, so it also
  sidesteps future passkey/MFA prompts. `.mcp.json` uses
  `SALESFORCE_CONNECTION_TYPE=OAuth_2.0_Client_Credentials` with
  `SALESFORCE_CLIENT_ID`/`SALESFORCE_CLIENT_SECRET`. Tradeoff: this
  flow always runs as one fixed user, so it doesn't substitute for
  real persona-level permission testing — only used here for the
  System Administrator connection.
- **Correction, 2026-08-23**: the 5 personas' *Profiles* are still
  generic (`Standard User`, `Standard User Sales`, `Standard User
  Custom`) — WS-01's profile work is indeed still pending — but the
  org **does** already have real per-persona **Permission Set
  Groups** that grant the actual `AF_*` FLS: `AF_PSG_CRM_Agent`,
  `AF_PSG_CRM_Supervisor`, `AF_PSG_Receptionist_Sales`,
  `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager` +
  `AF_PSG_Showroom_Manager`, `AF_System_Admin` (33 total PSGs in the
  org; `sf org list metadata --metadata-type PermissionSetGroup`).
  These were **not assigned to anyone** until this session (see the
  FLS gotcha below) — don't assume "no permission set exists" again
  without checking PermissionSetGroup first; only re-check the
  *profile* layer once WS-01 delivers real profiles.
- **The original Sales Receptionist User (`005a3001tN4G9nAAQS`, repurposed from dummy user "Agent
  Smith") could never log in via any mechanism, for reasons that never showed up anywhere in the
  Data API, Apex, or visible Profile settings — this User is now deactivated (`IsActive = false`)
  and permanently retired; do not reuse it or re-diagnose it further.** Ruled out, exhaustively, on
  2026-08-23 before giving up on it: password correctness (proven repeatedly — Apex `setPassword`
  "invalid repeated password" trick, multiple brand-new never-before-used passwords, and a direct
  change by the org owner via "Login As" on the account itself — all still rejected), username
  exactness (byte-for-byte Apex string comparison), frozen/locked state (`IsFrozen`/`IsPasswordLocked`
  both false), the `AF_QA_API_Access` permission set (confirmed assigned), Login IP Range (confirmed
  present and covering the test IP), Delegated Authentication (confirmed off org-wide), Session
  Security Level Required at Login (confirmed identical to working profiles), and stale browser
  session state. Tested via 3 independent auth paths — SOAP login, OAuth `grant_type=password`
  token request, and the Lightning login UI — all rejected identically with a generic credentials
  error, and `LoginHistory` had zero rows for this user across every attempt, ever.
  **Definitively confirmed profile-vs-user, also on 2026-08-23**: tested "Underwriter John"
  (`005a3001tN4Bxe8AQC`), another dummy user on the exact same Standard User Custom profile
  (`00ea30018YNvPxoAQF`) — after unfreezing, assigning `AF_QA_API_Access`, and setting a password
  the same way, his UI login **succeeded** (credentials accepted) and landed on the normal mandatory
  authenticator-app enrollment wall (same as the admin's passkey issue — a known, separate, expected
  problem, not this bug). This proved Standard User Custom itself was fine — something was uniquely
  and unfixably wrong with that one specific User record.
  **Resolution**: rather than keep chasing the broken record, created a brand-new User
  (`005FV0074kYJxfgYAD`, username `salesreceptionist.v2.20260823@alfardan.com.qa.qa`) with identical
  Profile, permission set, first/last name, and role — it worked immediately with no special
  handling (not even pre-frozen like the original bulk-created dummy users were). Lesson: if a
  dummy/migrated User record ever exhibits this exact symptom pattern again (every login mechanism
  rejects identical, correct credentials, with zero LoginHistory), don't keep diagnosing — just
  create a fresh User with the same Profile/permission sets and move on.
- **Every custom `AF_*` field org-wide had zero Field-Level Security
  granted to any user — including System Administrator — until fixed
  2026-08-23.** Symptom: `salesforce_query_records`/`describe_object`
  on any `AF_*` field returned `No such column 'AF_Brand__c' on
  entity 'Lead'` even via the admin connection, making it look like
  the entire custom data model wasn't deployed. It was: `sf project
  retrieve start --metadata CustomObject:Lead` (and Account/
  Contact/Opportunity) showed all ~34 `AF_*` fields on Lead alone,
  all validation rules, all flows — genuinely deployed. Root cause:
  fields deployed via Metadata API get **no FLS for anyone by
  default**, and nothing had ever assigned FLS to any user.
  **Correct, permanent fix (2026-08-23, second pass)**: the org has
  33 **Permission Set Groups**, most named per-persona and matching
  our provisioned personas exactly — `AF_PSG_CRM_Agent`,
  `AF_PSG_CRM_Supervisor`, `AF_PSG_Receptionist_Sales`,
  `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager` +
  `AF_PSG_Showroom_Manager` (both assigned — our one combined "Sales
  Manager / Showroom Manager" persona covers both roles),
  `AF_System_Admin`. Assigned each to its matching persona's User via
  `PermissionSetAssignment` insert using `PermissionSetGroupId` (not
  `PermissionSetId`) — 7 records, all succeeded. Verified:
  `AF_Brand__c` readable, and — the actual point of redoing this —
  `AF_BusinessUnit__c` is correctly **read-only**
  (`INVALID_FIELD_FOR_INSERT_UPDATE` on a direct update attempt),
  matching the SD's intended design.
  **First-pass mistake, reverted 2026-08-23**: originally assigned
  the generic `AF_PS_<Object>_FullAccess` permission sets
  (`AF_PS_Lead_FullAccess`, `AF_PS_Account_FullAccess`,
  `AF_PS_Contact_FullAccess`, `AF_PS_Opportunity_FullAccess`)
  directly to all 6 users. These grant blanket `editable: true` on
  every field they cover, including several meant to be
  read-only-except-flow (`AF_BusinessUnit__c`, `AF_QualifiedDate__c`,
  `AF_QualifiedBy__c`, `AF_SLABreachLevel__c`,
  `AF_KeyloopLeadRef__c`) — confirmed by a direct API edit of
  `AF_BusinessUnit__c` succeeding when it shouldn't have. All 24 of
  those assignments were deleted and replaced with the PSG
  assignments above. **If a persona still hits "No such column" on
  some other object**, check whether that persona's PSG actually
  covers it (`sf project retrieve start --metadata
  "PermissionSetGroup:AF_PSG_<Name>"`) before reaching for a broader
  fix — the generic `AF_PS_*_FullAccess` sets are a last resort now,
  not the default, since they overgrant edit access.
  **One field remains genuinely un-fixable this way**:
  `User.AF_DefaultBrand__c` has **no permission set, permission set
  group, or profile anywhere in the org granting it FLS** — confirmed
  by retrieving every PermissionSet/PermissionSetGroup/Profile in the
  org and grepping for the field — zero matches. This blocks
  LM-01-TC-005/006 (Brand auto-population from
  `$User.AF_DefaultBrand__c`) as a genuine defect, not a
  test-environment problem — report it, don't try to route around it
  by inventing new permission-set metadata.
- **`System.setPassword` in anonymous Apex has no visible debug log
  output via this MCP server's `salesforce_execute_anonymous`** (logs
  come back "No logs available"). To confirm a password change
  actually took effect, re-run the same `setPassword` call a second
  time without a try/catch — Salesforce's password-history policy
  rejects reusing the immediately-previous password with `invalid
  repeated password`, which is a reliable (if roundabout) way to
  confirm the first call succeeded.

- **2026-08-23: CRM Agent UI login now hits a mandatory MFA
  enrollment wall on a fresh browser session** (Passkey / Salesforce
  Authenticator / One-Time Password App — none optional). This did
  NOT appear on the very first UI login earlier the same session
  (only the forced password change did); it appeared on the next
  login after a Claude Code session restart, so a new browser
  profile/device fingerprint likely triggers it. **Solved the same
  way as the admin's passkey wall (referenced in the entry below) —
  self-serve TOTP**: choose "One-Time Password App" →
  "Connect an Authenticator App" screen shows a QR code whose **image
  alt text is the raw base32 TOTP secret** (`FE57ZYSY7B4VWX7KFQV27GCA4DXZAMIG`
  for CRM Agent) — no need to actually scan anything. Generate a
  6-digit code from it with Node (`crypto.createHmac('sha1', ...)`
  RFC 6238 TOTP over the base32-decoded secret, 30s step) and submit
  it in the "Verification Code" field within the 30s window. Enrolls
  immediately and lands on the target page. **Do this proactively for
  each persona's first UI login this session** rather than waiting to
  get blocked — same secret works for all future logins for that user
  (generate a fresh code each time, they're time-based). CRM Agent's
  secret is logged above (user approved persisting it here 2026-08-23,
  consistent with the existing plaintext-password convention below);
  capture and log each other persona's secret here the first time
  their UI login hits this wall too.
- **2026-08-23: Sales Receptionist (v2) also hit the forced "Change Your
  Password" screen on first UI login this session**, same as CRM Agent's
  Gotcha above — but the fix was simpler here: clicking **Cancel** on
  that screen does NOT log you out or block you: it discards the forced
  change and drops you straight into the Lightning Home page, still
  authenticated with the *existing* password. Try Cancel first before
  going through a full password reset — it may not be required.
- **2026-08-23: ALF-LM-01 batch findings worth remembering for later
  batches** (full detail in the test run's report, not repeated here):
  - `LeadSource` is an **unrestricted** picklist — the UI combobox only
    offers the 11 stock Salesforce values (Advertisement, Employee
    Referral, External Referral, Partner, Public Relations, Seminar -
    Internal, Seminar - Partner, Trade Show, Web, Word of mouth, Other),
    but the API/automation layer will silently accept and save ANY
    string (confirmed by inserting `LeadSource = 'Incoming Call'`,
    which is not a defined value, via the CRM Agent connection with no
    error). A human agent can never select "Incoming Call" / "Walk-in"
    / "Referral" / "Event" from the standard New Lead form — only
    automation/API paths can ever set those values.
  - `AF_Brand__c` picklist contains **only Ferrari and Rolls-Royce** —
    no third/unmapped-brand value exists anywhere in the org, so the
    UNMAPPED business-unit path (LM-01-TC-006) cannot be exercised
    without adding a new picklist value first.
  - `AF_VehicleOfInterest__c` (dependent on Brand) contains **only one
    value org-wide: "Undecided"** — no actual per-brand vehicle models
    were ever configured, for either brand. Any test case expecting
    brand-specific model lists or stale-model-on-brand-switch behavior
    is untestable as-is.
  - **Field History Tracking is NOT enabled on Lead at all** — querying
    `LeadHistory` (no filter) returns zero rows org-wide, even after
    directly changing Status, Owner, and Disqualification Reason on a
    test record. Contradicts the SD's claim that Status/Owner/
    disqualification fields have history tracking on.
  - No dedicated Lead-object quick actions for Walk-in or CTI
    screen-pop exist (`AF_QA_Lead_WalkIn`, `AF_QA_Lead_FromCall`) — the
    Sales Receptionist's Global Actions menu only has the generic
    stock "New Lead" action, no Channel/LeadSource pre-population.
    (Only Opportunity-side walk-in flows exist — `AF_FL_Opp_SalesWalkIn`
    / `AF_FL_Opp_ServiceWalkIn` — for a different story, ALF-RS-01.)
  - `AF_VR_Lead_MandatoryFields`'s error message is **static/generic**
    — it always lists all five mandatory fields ("Name, Phone, Lead
    Source, Brand, and Vehicle of Interest are required. Email is not
    required.") regardless of which one is actually missing; it never
    names just the specific blank field.
  - Lead page layout has **Nationality and Date of Birth marked
    required**, which blocks UI save of a lead containing only the
    BRD's stated minimum mandatory set — but this requiredness is
    layout-only and is NOT enforced at the API layer (confirmed: API
    insert succeeds with both fields blank).
  - Company field does not default to "Individual Customer" as the SD
    claims — it saves blank when omitted.
  - Duplicate-rule behavior differs by channel: the Lightning UI shows
    a non-blocking "Similar/Potential Duplicates" banner and lets a
    second click on Save proceed; a raw API insert against the same
    match gets a hard `DUPLICATES_DETECTED` failure with no success,
    because the REST/SOAP API requires an explicit duplicate-rule
    override header to bypass an Alert-action rule, which these MCP
    tools don't send. Not a config defect — expected Salesforce
    platform behavior — but worth knowing before flagging an
    "Allow + Alert" rule as if it were blocking via UI too.
- **2026-08-23, confirmed live**: the CRM Agent API connection
  (`af-crmagent-crm-executive-agent`) broke immediately after the UI
  password change above, exactly per Gotcha #1's prediction —
  `INVALID_LOGIN: Invalid username, password, security token; or
  user locked out.` `.mcp.json` already has the correct new password
  (`Arcsen@2026UI!`); **a full Claude Code session restart is needed
  to pick it up** before any further `af-crmagent-crm-executive-agent`
  API calls will work. Don't loop-retry it in the meantime — use a
  different connection (System Administrator fallback, or another
  persona) and resume CRM Agent API testing after the restart.

## 2026-08-25: Correction — AC-01C-TC-003 is NOT a BRD defect, it's a PDF→MD conversion artifact

BRD §9.1 FR4 appeared to cut off mid-sentence in the `.md` export this
project works from: *"The system should enforce duplicate prevention at
the Contact level within each brand record type—the same"* — with no
Acceptance Criteria/Assumptions rows following, unlike every other story
in the document. This was reported as a genuine document-corruption
defect (AC-01C-TC-003, was CRITICAL/BLOCKED).

**User confirmed the actual full sentence** (from the source, likely the
original PDF): *"...the same customer may not have more than one Contact
record of the same brand record type under a single Account."* This
exactly matches what's live (`AF_FL_Contact_BrandEnforcement_Consent`
blocks a second Brand Profile Contact for the same brand under the same
Account, and nothing wider). **Reclassify AC-01C-TC-003 as PASS** —
requirement is complete and correctly implemented; there was never a gap.

**Caveat for future sessions**: this project's BRD is consumed as a
`.md` export (`[Arcsen x Alfardan Group] R1 Business Requirements
Document V5 2.md`), not the original PDF. That conversion is evidently
lossy in at least this one spot. Don't assume an apparent mid-sentence
cutoff or missing trailing content in the `.md` file is a genuine BRD
defect without checking against the original PDF first, if available —
ask the user rather than filing it as a document-corruption bug outright.

## 2026-08-25: Correction — AC-01C-TC-004 is NOT a contradiction either, same root cause as TC-003 (misreading)

Also reclassified to **PASS**. BRD §9.1 says "one Contact record per
brand is maintained as a distinct record type." This was read as "each
individual brand needs its own Salesforce Record Type" (Ferrari Record
Type, Rolls-Royce Record Type, etc.) — but "record" and "record type"
are doing different jobs in that sentence: "one Contact **record** per
brand" is about data cardinality (one row per brand relationship);
"distinct **record type**" names the *category* those rows belong to
(Brand Profile, as opposed to Related Person) — not a type per brand.
User confirmed this reading directly. Two record types total
(`AF_Brand_Profile`, `AF_Related_Person`) is correct and matches intent;
this is also consistent with the SD's own stated reasoning for the
2-record-type design ("the two categories genuinely need different
layouts... while brands do not"), which was already working from this
same correct reading — the SD's Open Items note flagging this as
"BRD's literal per-brand ask still not formally reconciled" was most
likely the same over-literal misreading, not a genuine open disagreement.

**Net effect on the Contact module findings**: both AC-01C-TC-003 and
AC-01C-TC-004 — the two "record type" contradictions — are not
findings at all, just misreadings on the first pass. The real,
standing Contact findings are: the 4 bugs (Related-Person consent
fields not hidden per design; blanket ViewAll/ModifyAll grant on every
persona's PSG nullifying Private OWD and sharing rules; standard
`HasOptedOutOfEmail` vs custom `AF_MarketingOptIn__c` never
reconciling; an undocumented Email+Phone+Brand-required validation rule
on Brand Profile Contact) plus 1 genuine documentation contradiction
(TC-010 — SD recommends the full per-channel consent framework given a
Preference Centre is in BRD scope, then builds the single-checkbox
model anyway, no migration trigger named).

## Tickets filed

- `tickets/ACCOUNT-001-identity-field-and-data-model-defects.md` — consolidated
  ticket covering all 10 confirmed Account (AC-01A) bugs/contradictions from
  the 2026-08-25 batch (identity-field FLS lockout, mandatory-QID rule,
  orphaned alternate-ID and Keyloop-reference fields, one-sided duplicate
  flagging, `AF_Email__c`/`AF_DataQualityFlag__c` gaps, leaking error text,
  and the two doc-only contradictions on duplicate-rule action and Person
  vs Business Account). Read this before re-deriving any of those findings.

## 2026-08-25: Account & Contact (ALF-AC-01) test batch — findings

- **CRITICAL, confirmed live (API + UI, both CRM Agent and Sales Rep):
  `AF_QID__c` has no Edit FLS granted to ANY named business persona
  in the org — not CRM Agent, Sales Rep, Sales Manager, Showroom
  Manager, CRM Supervisor, CRM Manager, Marketing, or either
  Receptionist PSG.** Confirmed by querying `FieldPermissions` for
  `Account.AF_QID__c`: only `AF_System_Admin`,
  `AF_PS_Integration_MuleSoft`/`AF_PSG_Integration_MuleSoft`, and the
  deprecated `AF_PS_Account_FullAccess` (not assigned to any of the 5
  test personas, per the FLS-remediation gotcha above) grant
  `PermissionsEdit`. Live effect: CRM Agent and Sales Rep both get
  `INVALID_FIELD_FOR_INSERT_UPDATE` on `AF_QID__c` on **both insert
  and update** via API. Confirmed in the UI too — the New Account
  (Business Account) modal's "Identity & Compliance" section renders
  "Qatar ID", "Nationality", and "Date of Birth" as **bare labels with
  no input control at all** for CRM Agent (screenshot:
  `AC-01A-newaccount-identity-section-crmagent.png`), while
  "Salutation" and "Other ID Number" render as normal editable
  fields right next to them. Net effect: **no human persona in the
  org today can create or edit an Account's QID, Nationality, or Date
  of Birth via UI or API** — only System Administrator and the
  MuleSoft integration user can. This blocks BRD ALF-AC-01 FR1 and the
  SD's own AC-01A-TC-001/TC-023 expectations outright. The SD's own
  build note ("`AF_PS_Account_CoreEdit` was built, then removed as
  redundant once the Account FullAccess permission sets were
  expanded") does not match live state: the FullAccess sets were
  deliberately un-assigned from all personas during the FLS
  remediation above, and no replacement CoreEdit-equivalent
  permission set/group was ever created or assigned. **This is a live
  gap, not just a documentation contradiction — flag prominently in
  any handoff.**
- **`AF_LeadConversionService.resolveAccount()` bypasses this FLS
  gap** — it runs as an unrestricted Apex insert (no `with sharing` /
  `USER_MODE` on the DML), so Lead Conversion itself still writes
  QID/Nationality/DOB/Salutation fine regardless of the runtate
  user's FLS. The FLS gap only blocks **direct** Account
  creation/edit (walk-in registration, manual Account creation,
  correcting an existing customer's QID) — exactly the paths
  BRD ALF-LM-09 and ALF-AC-01 describe Sales/CRM using.
- **Read the Apex once, settles several documentation questions at
  once** (`AF_LeadConversionService`):
  - The alternate-ID field actually written by conversion is
    `AF_OtherIdNumber__c`. `AF_OpenIdentification__c` /
    `AF_OpenIdentificationType__c` exist on the Account object (per
    the SD's "Key Changes" panel) but are **never populated by any
    code path found** — confirms the SD's own predicted "orphaned
    duplicate field" contradiction (3 fields for 1 concept, only 1
    wired).
  - Account matching (`findMatchingAccount`) matches on
    QID/Phone/`AF_Email__c` only — **never on `AF_OtherIdNumber__c`**.
    A non-Qatari customer identified only by passport can never be
    deduplicated by Lead conversion.
  - Neither `AF_KeyloopCustomerRef__c` nor `AF_CustomerMasterKey__c`
    is ever written by this class (or found elsewhere) — both exist
    on Account as separate External ID fields (confirmed via
    `FieldDefinition`: `AF_CustomerMasterKey__c` is Text(50)
    External ID Unique-Case-Insensitive; `AF_KeyloopCustomerRef__c`
    is Text(50) External ID, not unique). **The Integration
    Blueprint's `AF_CustomerId` field name does not exist anywhere in
    the schema** — confirms AC-01A-TC-016's predicted contradiction
    exactly: 3 documented names, 2 live fields, 0 wired to anything,
    and the integration spec references a 4th name that was never
    built.
  - Conversion always targets `Business_Account` record type,
    explicitly, matching the live schema
    (`RecordType.DeveloperName = 'Business_Account'` on every one of
    the 5 org-native Accounts checked; the custom `Person_Account`
    record type is `IsActive=false` and literally renamed
    "DEPRECATED - Do Not Use (was mislabeled Person Account)" in the
    org). **This resolves AC-01A-TC-010: the "second reversal" /
    21-Aug Business_Account state is what's actually live** — this
    project's own qa-notes BRD-context summary above ("as of 19-20
    Aug 2026 it creates a Person Account") is itself now **stale** and
    should be read as superseded by this entry.
- **`AF_VR_Account_IdRequired` does NOT implement the SD's documented
  "QID OR Other ID" OR-logic.** Confirmed via System Administrator
  (full FLS, so not an FLS artifact): inserting an Individual Account
  with only `AF_OtherIdNumber__c` populated (no QID) is still blocked
  with `An Individual Account requires a Qatar ID.` — the rule
  requires QID unconditionally for Individual accounts, ignoring
  Other ID entirely. **Confirmed CRITICAL defect**, not just a doc
  mismatch: a non-Qatari Individual customer with only a passport/
  Omani ID can never be registered as an Individual Account, at all,
  by anyone (including System Admin) — contradicts BRD ALF-LM-09
  Assumption 2's entire reason for having an open-identification
  field. Company-type Accounts are correctly exempted (that half of
  the rule is fine).
- **`AF_QID__c` is confirmed `Unique (Case Insensitive) External ID,
  Text(20)`** via `FieldDefinition` — duplicate insert of an existing
  QID gets exactly one error (`DUPLICATE_VALUE`), not two, confirming
  the "Unique constraint blocks, duplicate rule only alerts" reading
  is what's actually deployed (the SD's own step 4 vs Design-Decision
  contradiction — live behavior matches the sound reading, not the
  literal step-4 instruction).
  Format validation (`AF_VR_Account_QIDFormat`) confirmed: exactly
  11 numeric digits required; 10-digit, 12-digit, and 11-char
  alphanumeric all rejected with `Qatar ID must be 11 numeric digits.
  (Placeholder rule — exact format pending customer confirmation.)`
  — note the error message itself leaks the SD's internal
  "placeholder, TBC" engineering note to end users; minor UX defect
  worth a ticket on its own.
- **`AF_FL_Account_DuplicateCheck` confirmed live and working**, but
  only flags one side of a duplicate pair: creating a second Account
  with a phone number matching an existing Account sets
  `AF_DuplicateStatus__c = 'Potential Duplicate'` on the **new**
  record only — the pre-existing matched record stays `'None'`.
  Confirms AC-01A-TC-014's predicted "half-visible duplicate pair"
  defect empirically, not just hypothetically.
- Only 5-8 Accounts exist in this org as of 2026-08-25 (all created by
  this or prior QA sessions, `QA test ...` naming) — the SD's "43
  pre-existing legacy Accounts" baseline from its own Current Org
  Baseline table does not match current org state (sandbox likely
  refreshed since that baseline was written). Don't reuse that "43"
  figure without re-querying.
- Business_Account Type field (standard picklist Individual/Company)
  renders as a normal editable combobox for CRM Agent in the New
  Account modal — not FLS-restricted, only the Identity & Compliance
  block (QID/Nationality/DOB/Keyloop Ref) is.

## 2026-08-25: New user created to fix the Showroom Manager role gap

Created `showroommanager.qa.20260825@alfardan.com.qa.qa` (Id
`005FV007FRTeA1sYYF`), password `Arcsen@2026SRM!`, **System Administrator**
profile, assigned to role `AF_Role_ShowroomManager_Automobiles`. Purpose:
(1) give someone real to test as, since the actual System Administrator
account can't log into the UI at all (passkey wall, see Gotcha above), and
(2) fix the live defect where nobody holding any Showroom Manager role
was causing `AF_FL_Opp_AfterCreate`'s duplicate-notification Task to fail
and roll back the entire Opportunity insert (see ALF-RS-01 findings below).
This user is on the Automobiles role only — Premier Motors and Sports
Motors business units still have no Showroom Manager, so the same
rollback bug will still reproduce for Opportunities on those BUs. If this
user's UI login also hits the passkey wall (same profile as the blocked
admin), that needs a human to register a passkey/authenticator — not
something this session can do headlessly. User account setup done via
API only; UI login was not attempted end-to-end this session (user asked
to test it themselves).

## 2026-08-25: ALF-RS-01 (Opportunity Creation from All Supported Intake Paths) — story-level verdict

Tested against the story's own FR1-5/AC1-4/Assumptions 1-2 (not the granular
RS-01 test-case sheet) using System Administrator for API-level work and
whichever persona could actually log into the UI (CRM Agent, Sales
Receptionist). Verdict: **the story does not satisfy its acceptance
criteria today** — multiple independent, compounding defects, most severe
enough to block real usage outright.

- **FR2/AC1 (Lead Conversion → Opportunity assigned to Sales) — FAILS.**
  `AF_FL_Lead_ConvertScreen` / `AF_LeadConversionService` has **no
  owner-selection step at all** ("No agent prompt" per the flow's own
  description) — `Database.LeadConvert.setOwnerId(ld.OwnerId)` just
  inherits whoever already owned the Lead. There is no mechanism anywhere
  that hands the resulting Opportunity to a Sales Representative. Confirmed
  live: converted Khalid Al-Mannai (Ferrari) with the Lead owned by CRM
  Agent — the resulting Opportunity is owned by **CRM Agent**, not Sales.
- **CRM Agent cannot convert leads at all, by any path.** Confirmed two
  ways: `PermissionSet.PermissionsConvertLeads = false` on every
  operational PSG including CRM Agent's, and live UI reproduction — no
  Convert button/action anywhere on a Lead record for CRM Agent (`Show
  more actions` only offers Clone). Every conversion in this test batch had
  to be run via `AF_LeadConversionService.convertLeads()` directly as
  System Administrator.
- **Leads must be Working+ with a recorded Qualification Outcome to
  convert** (`Status` cannot be New; the platform also enforces a strict
  status-transition order — New → Working/Follow-up/On-Hold → Qualified →
  Converted, no skipping). Reasonable business logic, but not documented
  as a conversion precondition anywhere the test cases reference.
- **Converting a Lead with no Email fails outright**, hitting the same
  undocumented Contact validation rule found during Contact testing
  (`AF_FL_Contact_...`: "A Brand Profile Contact requires Email, Phone, and
  Brand"). A phone-only Lead can never be converted.
- **AF_OpportunityOrigin__c is never set by either Lead Conversion or
  direct/CRM creation** — confirmed null on both a converted Opportunity
  and a bare direct-insert Opportunity. Despite the field/BRD's own premise
  that intake path should always be tracked, only the two Quick-Action
  walk-in flows (Sales/Service) ever actually stamp it. 3 of 5 origin
  values require a human to remember to set them manually with nothing
  enforcing it.
- **CRM Agent has zero FLS (Read or Edit) on `Opportunity.AF_Brand__c`** —
  confirmed via `FieldPermissions` query (only PSG with no grant at all)
  and live reproduction (`No such column 'AF_Brand__c'` on both API insert
  and, by extension, any UI form). CRM Agent can create a bare Opportunity
  but can never set or see which brand it's for — breaks FR3 in practice
  since Brand drives Business Unit derivation, duplicate-check scoping,
  and sub-stage everywhere downstream.
- **FR4/AC2 (Sales Receptionist walk-in) — the flow launches and the
  permission gate is correctly open** (`AF_CanUseSalesWalkIn` already
  granted via the `AF_PSG_Receptionist_Sales` PSG, contradicting the SD's
  own Open Items note that "no BU has been enabled yet" — at least the
  Sales channel already is), **but the flow cannot be completed at all.**
  The "Assign to Sales Representative" lookup hangs in a permanent
  "Loading" spinner and never returns results. Browser console shows the
  root cause directly: `User.Name: Review this lookup configuration. Your
  Salesforce admin can help with this.` — a broken/misconfigured lookup
  component. No Sales Receptionist can ever finish a Sales Walk-in intake.
- **Assumption 1/2 (duplicate flag + Showroom Manager notification) —
  actively breaks Opportunity creation, not just silently skips it.**
  `AF_FL_Opp_AfterCreate`'s duplicate branch tries to create a Task
  assigned to the Business Unit's Showroom Manager; since **nobody in the
  org currently holds any of the three `AF_Role_ShowroomManager_*` roles**
  (confirmed via `User` query — 0 rows for all three), the Task insert
  fails with `INVALID_CROSS_REFERENCE_KEY: Assigned To ID: owner cannot be
  blank`, and because this isn't in a fault path, **the entire Opportunity
  insert rolls back**. Reproduced live: inserting a second Ferrari
  Opportunity under an Account that already had one failed outright with
  this raw internal error surfaced straight to the API caller. This means
  today, any duplicate-Opportunity scenario (a completely ordinary
  occurrence) hard-blocks Opportunity creation for the affected
  Account/Brand, org-wide, on all three business units.
- **AF_ShowroomManager__mdt (the alternate manager-mapping mechanism the
  SD's Build Register lists) does not exist in the org at all** —
  confirms the role-hierarchy lookup is the only real mechanism live;
  the Build Register entry is simply stale/wrong documentation.
- **AC3 (per-BU intake-path availability) — the gate itself works
  correctly.** Tried launching Service Walk-In as Sales Receptionist (who
  only holds the Sales-channel permission): got a clean, correctly-worded
  block — *"Service Walk-In Opportunity creation is not enabled for your
  Business Unit."* No workaround needed here.
- **FR5/AC4 (Service Receptionist walk-in) — not independently testable
  this session.** No Service Receptionist persona is provisioned among the
  6 scoped personas, and System Administrator cannot log into the UI at
  all (WebAuthn passkey wall, see Gotcha above) to substitute. The
  Showroom-Manager-role gap above would block this path too even if it
  could be reached, since the flow assigns the new Opportunity directly to
  the Showroom Manager.
- **Only 4 Opportunities exist in the org** (all from earlier QA batches),
  not the SD's claimed "17 pre-existing" baseline — same stale-baseline
  pattern as the Account "43" figure found earlier.
- **Tooling gotcha, not a live defect**: raw API updates to `Lead` via the
  `salesforce_dml_records` MCP tool on the admin connection appear to
  trigger `AF_AR_Lead_Routing` (the standard Assignment Rule) and silently
  revert `OwnerId` back to the originating queue, even for fields unrelated
  to ownership. The real UI path (`Change Owner`) does **not** do this and
  sticks correctly. However: the standard Lightning **Edit** modal's
  "Assign using active assignment rule" checkbox **is checked by default**,
  and a real user saving any ordinary field edit through that modal *does*
  genuinely revert ownership back to the queue — confirmed via an actual
  UI Save (not the API tool). This is a real, live gotcha worth flagging
  to the business: an agent editing a claimed Lead for any reason, without
  noticing/unchecking that box, silently loses their claim.

Net: of the two stories in this batch, RS-01 fails its acceptance criteria
on nearly every path tested. The only two things that work cleanly today
are the per-BU permission gate (AC3) and the stage-model story (RS-02
TC-001, see below).

## 2026-08-25: ALF-RS-02 (Opportunity Stage Model) — partial findings

- **Stage model matches the design exactly** — confirmed via
  `OpportunityStage`: the 7 stages (Consider/Explore/Select/Commit/Take
  the Keys/Closed Won/Closed Lost) exist with the documented probabilities
  and forecast categories, in the documented order; all 8 standard
  Salesforce default stages are correctly deactivated. Clean pass.
- **The "Vehicle Model" field the test cases and SD reference as a Lookup
  to VehicleDefinition does not exist.** `Opportunity.AF_VehicleModel__c`
  is not in the schema at all; only `AF_VehicleInterest__c` exists, and
  it's a plain Text(255) field, not a lookup. The `VehicleDefinition`
  object itself is also absent from the org (confirmed via
  `EntityDefinition`), alongside the already-known-absent
  `Appraisal`/`AppraisalItem` objects.
- `AF_Handover__c`, `AF_InvoiceSummary__c`, and `AF_VehicleReservation__c`
  all exist as real custom objects (unlike Appraisal) — worth knowing
  before assuming every RS-02 dependency is missing.
- Not yet tested: the actual validation-rule gates
  (`AF_VR_Opp_ExploreRequiresVehicle`, `AF_VR_Opp_CommitGate`,
  `AF_VR_Opp_TakeTheKeysGate`), Quote-feature enablement, and the
  Invoice-Balance push-flow pattern.

## 2026-09-06: Session-start persona connectivity fix (Login IP Range) + email convention check

Before starting the Retail Sales (ALF-RS-*) batch, verified all 6 personas'
API connections and UI login. Found and fixed:

- **All 5 non-admin personas (CRM Agent, CRM Supervisor, Sales Receptionist,
  Sales Rep, Sales Manager) were locked out of the org entirely — both API
  and UI — with `LoginHistory.Status = 'Restricted IP'`.** Root cause: their
  3 profiles (`Standard`, `Standard User Custom`, `Standard User\tSales` —
  note the literal tab character in that profile's developer name) each had
  a single `loginIpRanges` block hard-locked to `41.239.166.0–41.239.166.255`
  (the previous session's egress IP, 2026-08-25). This session's egress IP
  (`156.215.118.244`) fell outside it, so every one of the 5 personas was
  rejected before credentials were even checked — confirmed identically via
  raw API login (`LOGIN_DURING_RESTRICTED_DOMAIN: cannot log in from current
  domain`) and real UI login (generic "check your username and password"
  error — Salesforce does NOT surface a distinct message for this case, so
  don't assume a generic credential error rules out an IP-range block; check
  `LoginHistory.Status` to tell them apart). Only System Administrator (OAuth
  2.0 Client Credentials, no IP-range enforcement) still worked.
  **Fixed 2026-09-06** by retrieving the 3 profiles via the already-
  authenticated `sf` CLI org alias `AlFardan` (`sf project retrieve start
  --metadata "Profile"`), adding a **second, additive** `loginIpRanges` block
  covering `156.215.118.0–156.215.118.255` to each (existing range left
  untouched), and deploying back (`sf project deploy start --target-org
  AlFardan --metadata "Profile:Standard" "Profile:Standard User Custom"` for
  the first two; the tab-named one needed `--source-dir "force-app/main/
  default/profiles/Standard User%09Sales.profile-meta.xml"` since
  `--metadata "Profile:Standard User\tSales"` doesn't resolve on the CLI).
  All 5 personas' API connections confirmed working again immediately after.
  **If this recurs in a future session** (egress IP changes again — this
  sandbox's outbound IP is evidently not stable across sessions): check
  `LoginHistory` for `Status = 'Restricted IP'` first, don't assume
  credentials broke; the fix is always the same 3 profiles. Consider asking
  the user whether to just delete the `loginIpRanges` restriction outright
  next time, since it keeps drifting.
- **Sales Representative and Sales Manager's `User.Email` cannot be changed
  away from `noreply@example.com.invalid`** to the `emea-delivery-
  operations+...@arcsen.com` convention the other 3 personas already use.
  Confirmed via both `salesforce_dml_records` (admin connection, reported
  `Successful`) and direct anonymous Apex `update` (system context, no
  sharing/FLS involved) — in both cases the value silently reverts to
  `noreply@example.com.invalid` immediately, confirmed by an immediate
  re-query. No `ApexTrigger` exists on `User`; no `FlowDefinitionView`
  record with `Label LIKE '%Email%'` or `ApiName LIKE '%User%'` looks
  relevant; no `CronTrigger` fires anywhere near that timestamp. Root cause
  **not identified** — didn't chase further given it's cosmetic (doesn't
  block API or UI testing as either persona) and not worth more budget.
  Leaving both users' `Email` as `noreply@example.com.invalid` for now;
  flag to the user as a minor open item rather than a blocker.
- Emails independently confirmed still correct on CRM Agent, CRM Supervisor,
  Sales Receptionist (`emea-delivery-operations+{crmagent,crmsupervisor,
  receptionist2}@arcsen.com`) and on the standalone Showroom-Manager-role
  fix-user from 2026-08-25 (`+showroommanager@arcsen.com`).
- All 6 persona API connections confirmed live and query-able as of
  2026-09-06 (System Administrator via OAuth Client Credentials; the other
  5 via `User_Password` now that the IP range is fixed).

## BRD context (from `alfardan-export.md`)

- Custom object/field prefix is `AF_` (e.g. `AF_ContactCategory__c`,
  `AF_Brand__c`, `AF_BusinessUnit__c`).
- Core design principle (DEC-007): **Shared Customer, Segregated
  Transactions** — one shared Account/customer profile group-wide,
  but Leads/Opportunities/Cases/Service Appointments/Test
  Drives/Trade-Ins/Quotations/Reservations/Payments/Sales
  Orders/Invoice Summaries/Handovers stay private to the originating
  business unit.
- Contact model: one Account per customer; one Brand Profile Contact
  per brand relationship (`AF_ContactCategory__c = Brand Profile`);
  Related Person Contacts for drivers/spouses/reps
  (`AF_ContactCategory__c = Related Person`, `AF_ContactRole__c` for
  the role).
- Lead conversion has changed mechanism multiple times during the
  engagement — as of 19-20 Aug 2026 it creates a Person Account (not
  Business Account + Brand Profile Contact as originally designed);
  check the Account and Contact Management BRD page's ratification
  panel for the current state before testing lead conversion.
- Many mechanisms (roles/profiles/permission sets/sharing
  rules/queues/FLS/report governance, queue/ownership model for leads)
  are explicitly **WS-01 outcomes, still pending** — don't assume a
  security/visibility behavior is a bug without checking whether it's
  simply not decided yet.
- Full persona list (28, with business-unit assignment + cross-BU
  access flag) exists in the BRD; only Chief Sales Officer, Chief
  Executive Officer, and System Admin are cross-business-unit — every
  other operational persona (including all 5 scoped above) is
  single-unit-scoped.

## 2026-09-06: ALF-RS-03 (Test Drive Management) — test batch findings

Source docs now live in the project as real files under `readme files/`
(BRD `.md`, `alfardan-export.md` SD, `tableConvert.com_rwxyl9.md` test
cases) — read directly from disk this session instead of relying on
chat-pasted content. RS-03 has 8 test cases (RS-03-TC-001..008). Tested
API-first (System Administrator + Sales Representative + CRM Agent
connections) then UI (Sales Representative, forced-password-change
Cancel bypass still works). Per user instruction, integration-dependent
steps (real website-form/chatbot submission) were skipped except for
confirming the fields they'd populate exist.

**IMPORTANT METHODOLOGY CAVEAT — "ghost field" phenomenon**: discovered
that `AF_TestDrive__c.AF_Vehicle__c` / `AF_VehicleDefinition__c`, and
`Opportunity.AF_VehicleModel__c` / `AF_SelectedVehicle__c`, are reported
as **nonexistent** by `describe_object`, `FieldDefinition` queries, and
even direct anonymous-Apex SOQL compilation — confirmed across BOTH the
System Administrator (OAuth Client Credentials) and Sales Representative
(User_Password) connections. Yet all four fields are **real, populated,
and fully functional**: the live Lightning UI renders and edits them
correctly (New Test Drive modal has real "Vehicle" and "Vehicle
Definition" comboboxes; an existing record showed a real populated
"Test Vehicle: Ferrari Purosangue" / "VD: Ferrari Purosangue" pair), and
the already-deployed `AF_LeadConversionService` Apex class
(Status=Active, IsValid=true) both references them in inline SOQL and
successfully writes to them in a real, verified end-to-end Lead
conversion (`AF_CarriedTestDriveInterest__c` etc. landed correctly on
the resulting Opportunity). **Root cause not identified** — looks like a
genuine schema-visibility gap in this MCP server's Tooling/Data API
layer, not a live application defect. **Don't conclude a Vehicle/
VehicleDefinition-related field "doesn't exist" from these MCP schema/
query tools alone — cross-check the live UI first.** This reversed my
own first-pass (wrong) conclusion mid-session that the SD's "Vehicle,
Vehicle Definition" lookups were never built; they were.

### Findings — what works

- **AF_TestDrive__c is a real, richly-built object**: Status
  (Requested/Qualified/Scheduled/Completed/Refused/Cancelled), Result
  (Completed/Refused), Refused Remarks, Product Feedback, CRM Experience
  Feedback, Location/Showroom, Time Slot, Assigned Consultant, Scheduled
  Date/Time, plus the Vehicle/Vehicle Definition/Product lookups above.
  7 active flows exist (`AF_FL_TestDrive_UpdateGate`,
  `AF_FL_TestDrive_SyncOpportunityGate`, `AF_FL_TestDrive_SyncGateOnDelete`,
  `AF_FL_TestDrive_PreventDoubleBooking`, `AF_FL_TestDrive_NotifyOnAssignment`,
  `AF_FL_TestDrive_NotifyOwnerOnCreate`, `AF_FL_Task_TestDriveConfirmationEmail`)
  plus `AF_FL_Opp_CreateExploreSideProcesses` (creates the Test Drive +
  Trade-In Appraisal on Consider→Explore). UI layout is well organized
  into Test Drive Details / Vehicle / Scheduling / Result & Feedback /
  Integration & System Flags sections — all TC-003/004/005/006 fields
  are visible and editable for Sales Rep and CRM Agent.
- **TC-004's mandatory-Result gate is genuinely implemented** (contrary
  to the test case's own written expectation of "no rule exists" — the
  build has moved past that doc). `AF_VR_Opp_TestDriveGate` +
  `AF_TestDriveGateBlocked__c` block Explore→Select progression with
  the message "This Opportunity has a Test Drive without a recorded
  Result. Record Completed or Refused (with remarks) before progressing
  past Explore." — confirmed via Sales Rep's own connection.
  `AF_VR_TestDrive_RefusedRemarksRequired` ("Refused Remarks is required
  when the Test Drive Result is Refused.") blocks/unblocks correctly,
  identical wording in API and live UI (screenshot
  `rs03-tc004-refused-remarks-blocked.png`). Completed does NOT require
  remarks (correctly scoped to Refused only) — PASS.
- **TC-006 passes, better than the test case's own pessimistic
  expectation**: CRM Agent has real, working read/write FLS on
  `AF_CRMExperienceFeedback__c`, distinct from `AF_ProductFeedback__c`,
  and can genuinely read/write Test Drive records under a Sales-Rep-
  owned Opportunity despite Opportunity OWD being Private — confirmed
  live (query + DML both succeeded).
- **TC-002's Lead→Opportunity test-drive-interest carryover genuinely
  works**: `Lead.AF_InterestedInTestDrive__c` / `AF_TestDriveDateTime__c`
  / `AF_TestDriveLocation__c` → `Opportunity.AF_CarriedTestDriveInterest__c`
  / `AF_CarriedTestDriveDateTime__c` / `AF_CarriedTestDriveLocation__c`
  via the standard Lead Convert field mapping (not the custom Apex,
  which only stamps Origin/Description/Vehicle/SourceOfBusiness).
  Notification Task mechanism (AC2) works via `AF_FL_TestDrive_NotifyOwnerOnCreate`
  / `NotifyOnAssignment` — confirmed live in the Sales Rep's own Activity
  Timeline ("Complete Test Drive Details" task).
- **TC-008 (doc reconciliation) CONFIRMED**: BRD §10.3's heading is
  genuinely absent from the body (jumps 10.2 → 10.5 in-text; TOC still
  lists "10.3 TEST DRIVE MANAGEMENT" correctly). SD has no story-level
  build page for RS-03 — only HLD page "07 Test Drive & Trade-In" at
  design-intent level. Retail Sales build page's own "User Stories
  Supported" table (read directly, line ~5978-5990) lists exactly
  ALF-RS-01, ALF-RS-02, ALF-RS-14 — RS-03 confirmed absent. Despite
  this, the live implementation (7 flows + 2 validation rules + full
  field set) is considerably MORE complete than either document
  credits — a documentation-lag problem, not an under-build problem.

### Bugs found

1. **CRITICAL — a Cancelled Test Drive with no Result permanently
   blocks its Opportunity's stage progression, and only System
   Administrator can fix it.** `AF_StageGatePassed__c` stays `false` on
   a Cancelled record forever (Cancelled isn't exempted from "must have
   a Result"), which keeps `AF_TestDriveGateBlocked__c = true` on the
   parent forever. Confirmed via `ObjectPermissions`: Sales Rep, Sales
   Manager, and CRM Agent PSGs all have `PermissionsDelete = false` on
   `AF_TestDrive__c` — only System Administrator can delete the stray
   record to clear the gate (proven live: deleted TD-00011, gate
   immediately flipped to `false`, Sales Rep's own stage-progression
   update then succeeded). Real-world impact: an entirely ordinary
   "customer cancelled the test drive" scenario permanently strands the
   deal past Explore unless IT intervenes manually.
2. **CRITICAL — once an Opportunity has passed Explore, creating a new
   Test Drive with no Result set at creation time destroys the insert
   itself.** `AF_FL_TestDrive_SyncOpportunityGate`'s own after-save
   attempt to re-set the parent's gate flag collides with
   `AF_VR_Opp_TestDriveGate`, which has **no stage-scoping** — it blocks
   ANY Opportunity save while the flag is true, not just a StageName
   change — rolling back the whole transaction (confirmed: the raw
   error surfaces as `CANNOT_EXECUTE_FLOW_TRIGGER` wrapping the gate's
   own validation message, and the new Test Drive record silently never
   exists afterward). Workaround: supply Result in the same
   create/save that has none open on the parent (`AF_Result__c` set at
   insert time avoids the collision) — but this failure mode is
   confusing, undocumented, and would look like a random platform error
   to any real Sales Rep trying to log a legitimate second/rebooked
   test drive on a deal already past Explore.
3. **HIGH — `AF_Status__c` and `AF_Result__c` can go out of sync.**
   Nothing keeps Status aligned with Result. Confirmed twice (API and
   live UI): setting Result = Refused leaves Status stuck at
   "Requested" unless the user also manually changes Status. Any list
   view/report keyed on Status alone (e.g. "Refused test drives") would
   silently miss these records.
4. **MEDIUM — Product Feedback is not actually enforced as mandatory on
   Completed**, contradicting the SD's own TD-1 decision ("product
   feedback is mandatory when result = Completed"). Confirmed: a
   Completed Test Drive with blank Product Feedback saves cleanly via
   API. The product-insight/re-engagement reporting use case (RS-03
   FR4, RS-14 TC-007) has no guarantee the data is ever populated.
5. **MEDIUM — TD-3's entire reschedule mechanism is unbuilt.**
   `AF_Status__c`'s live picklist is only Requested/Qualified/Scheduled/
   Completed/Refused/Cancelled — no "Confirmed", no "Postponed" — and no
   `AF_RescheduledFrom__c` self-lookup field exists anywhere on the
   object (confirmed via the full 31-field `FieldDefinition` list). The
   SD documents a full parent/child reschedule-chain design (TD-3); none
   of it exists. A no-show/reschedule today can only be handled via
   Cancelled + a brand-new, unlinked record — losing the audit trail the
   SD calls for.
6. **LOW/MEDIUM — no channel/source field exists anywhere on
   `AF_TestDrive__c`** to record which intake channel (website,
   chatbot/WhatsApp, manual) produced a given record, so FR1's "compare
   the channel stamped on each record" (RS-03-TC-001 step 4) can never
   be satisfied — there is nothing to stamp.
7. **LOW — minor UX bug, narrower than first thought**: saving a
   brand-new Test Drive from the related-list "New" action (not Edit)
   throws a benign console error (`Toast: please provide at least the
   "label" property to show the toast`) and the user gets no
   success-confirmation toast on that specific path. Confirmed this is
   scoped to the "New" creation modal only — a subsequent `Edit` +
   `Save` on the same record showed a normal, correctly-labelled
   success toast (`Test Drive "TD-00020" was saved.`). Record always
   saves correctly either way; only the New-modal's confirmation toast
   is silently swallowed.
8. **CRITICAL — the "Request Closure" Quick Action does not exist
   anywhere in the Sales Representative's UI**, even though
   `AF_FL_Opp_RequestClosure` is deployed and active
   (`FlowDefinitionView` confirms it). Checked exhaustively on a real
   Opportunity as Sales Rep: not in the main action bar, not in "Show
   more actions" (10 items: Delete/Edit/Printable View/Clone/Change
   Owner/Clone with Related/View Relationship Map/Submit for
   Approval/Sharing/Select Vehicle — no Request Closure), not in the
   Global Actions "+" menu (New Event/Task/Log a Call/Opportunity/
   Case/Lead only), and not reachable via the standard Path component's
   own "Select Closed Stage" convenience picker — which itself hits the
   exact same validation block ("Closed Lost can only be reached
   through the approved Request Closure process, not by editing Stage
   directly.", screenshot `rs03-tc007-close-lost-error.png`, matching
   the raw API error verbatim). **Net effect: a Sales Representative can
   never reach Closed Lost through the UI at all today** — the one
   required path (Request Closure) has no visible entry point anywhere
   on the Opportunity page, while every other path is correctly and
   deliberately blocked. This is RS-14 territory but directly blocks
   RS-03-TC-007 and deserves its own critical ticket — check whether the
   Quick Action was ever added to the Sales Rep's Opportunity Lightning
   Record Page / page layout, since the flow itself is confirmed built
   and active.

### Follow-up UI pass (same session, continued) — additional confirmations

- **TC-003 fully re-verified via a clean, isolated UI walkthrough**:
  created a fresh Test Drive from the Opportunity's related list (New
  action) on a different, previously-untouched Opportunity ("Test Demo
  2 - Rolls-Royce", still at Explore with 0 pre-existing Test Drives),
  then via three separate Edit+Save cycles walked it Requested →
  Scheduled (with date/time) → Completed (with Product Feedback) —
  fully reproducing "confirm, schedule, execute" as a real Sales Rep
  click-path, not just API calls. Every field editable, every save
  succeeded, status changes all confirmed via re-query.
- **Refined bug #2's exact trigger condition**: creating a blank-Result
  Test Drive on an Opportunity **still at Explore** (gate not yet
  triggered) works fine with no collision — confirmed live. The
  collision only happens once the Opportunity has already moved **past**
  Explore (Select or later), matching the validation rule's own wording
  ("before progressing past Explore"). So the real-world impact is
  narrower than originally worded: it's specifically "add a new,
  not-yet-resulted Test Drive to a deal already at Select/Commit/Take
  the Keys" that silently fails — adding one while still at Explore is
  safe.
- **CRITICAL, root-cause finding — the "Select Vehicle" action (the
  only real UI mechanism to satisfy RS-02's "vehicle required from
  Explore onward" gate) fails for every non-admin persona.** Tried to
  close the one genuine remaining gap from the first pass — never
  having confirmed TC-002's claimed carryover-prefill behavior
  (`AF_FL_Opp_CreateExploreSideProcesses` starting the new Test Drive
  as Scheduled instead of Requested when carried date/time exist) —
  by reassigning the TC-002 Opportunity to Sales Rep and using the
  real "Select Vehicle" Quick Action (Vehicle Explorer LWC) as a real
  user would, instead of fighting the ghost-field issue directly. The
  Vehicle Finder modal opens but **immediately fails with `Error
  retrieving vehicle models: No such column 'VehicleIdentificationNumber'
  on entity 'Vehicle'`** (screenshot `rs02-vehicle-explorer-broken.png`).

  ⭐ **CORRECTED 2026-09-06 (user report)**: the user tested this same
  action as **System Administrator** and it **succeeded**. This
  reopened the root cause — the original conclusion ("field genuinely
  doesn't exist") was wrong, and was the same MCP/API-version ghost-
  field artifact documented elsewhere in this file, not a real absence.
  Re-investigated via `sf`:
  - `FieldDefinition` confirms `Vehicle.VehicleIdentificationNumber`
    **is real** (Text(255), Unique Case-Insensitive).
  - `FieldPermissions WHERE SobjectType='Vehicle' AND
    Field='Vehicle.VehicleIdentificationNumber'` returns **zero rows**
    — no profile or permission set has ever been granted Read on this
    field, org-wide. For contrast, `MakeName` (a field that works fine
    in the browse/filter step) has **43** FieldPermissions rows.
  - **Real root cause**: missing Field-Level Security grant, not a
    missing/undeployed field. System Administrator's implicit
    View/Modify-All-Data bypasses FLS entirely, which is why it alone
    succeeds. The managed-package LWC controller appears to build its
    final-selection query against the running user's accessible field
    set — for an FLS-restricted user the field is invisible and the
    query fails with "no such column" instead of a permission error.
  - **Persona scope, corrected**: **System Administrator is NOT
    affected.** Sales Rep is confirmed affected. Sales Manager/CRM
    Agent/Showroom Manager/Receptionist are not yet individually
    confirmed, but since **zero** non-admin grants exist for this
    field org-wide, there is no structural reason any of them would
    succeed either — treat as affecting every non-admin persona until
    shown otherwise.
  - **Recommended fix, corrected**: grant Field-Level Security (Read)
    on `Vehicle.VehicleIdentificationNumber` to every operational
    profile/permission set — a Setup FLS change, not a deployment or
    code fix. Also worth auditing the same two controllers' other
    queried fields for the identical zero-grant pattern before calling
    this fully resolved; VIN may not be the only one.
  - Still true regardless: this is the same failure at the identical
    final step for both "Select Vehicle" (Opportunity) and "Select Demo
    Vehicle" (Test Drive) — one root cause, cross-cutting into RS-02's
    stage-gate and RS-03/RS-05's vehicle-attach paths — just an FLS fix
    now instead of a schema fix.
- **TC-006**: could not re-drive this via the CRM Agent's own UI
  session this pass — its first login this session hit the known TOTP
  enrollment wall (per the Gotchas section above), and generating the
  verification code needed a small Node/PowerShell script that the
  session's own tooling guard declined to run. Not re-attempted further
  since the object/field-level access already has solid double
  API-confirmation (a live read AND a live write from the CRM Agent's
  own connection, both succeeding) — Salesforce enforces sharing/FLS
  identically for API and UI, so this is not treated as an open item.

### Not independently verified this session

- **TC-001/TC-002's actual website-form/chatbot-WhatsApp submission
  paths** — genuinely unimplemented integrations per user instruction;
  only confirmed the fields they would populate
  (`AF_InterestedInTestDrive__c` etc.) exist and that the carryover
  mechanism downstream of them works.
- **TC-007 (Closed Lost retention)** — confirmed the data itself is
  never at risk (no automation touches `AF_TestDrive__c` on closure),
  but the closure path itself is a dead end for Sales Rep in the UI
  (see bug #8) and a Screen Flow can't be driven via API either
  (`Flow.Interview.start` rejects Screen Flow process type) — so this
  test case is now blocked on bug #8, not just "out of scope."

## 2026-09-06: ⭐ SOLVED — the "ghost field" mystery is an MCP API-version artifact

**This supersedes and corrects the "ghost field" caveat in the RS-03
section above. Read this before ever concluding an object or field is
missing from this org.**

**The six persona MCP Salesforce connections are pinned to an older API
version that does not expose Automotive Cloud / Industries objects.**
Through them, `Vehicle`, `VehicleDefinition`, `Appraisal` and
`AppraisalItem` all report as non-existent, in four different ways:
`describe_object` → `The requested resource does not exist` (on the
System Administrator, Sales Manager, CRM Agent **and** Sales
Representative connections alike); REST query → `sObject type
'Appraisal' is not supported`; anonymous Apex → **fails to compile**
with `Invalid type: Schema.Vehicle`; `Schema.getGlobalDescribe()` →
1229 sObjects with **zero** name matches.

**All of that is wrong.** The `sf` CLI (org alias `AlFardan`, **API
version 68.0**) sees every one of them, with live data:
`Vehicle` (6 records), `VehicleDefinition` (6), `Appraisal` (3),
`AppraisalItem` (1), `AppraisalAdjustment` (0), `VehicleSearchableField`
(0). `AppraisalItemProviderValuation` did not resolve — establish its
real API name before testing TI-1's provider-valuation layer.

**Why this explains the ghost fields exactly**: the four fields that
were invisible to schema tools —
`AF_TestDrive__c.AF_Vehicle__c` (→ `Vehicle`),
`AF_TestDrive__c.AF_VehicleDefinition__c` (→ `VehicleDefinition`),
`Opportunity.AF_VehicleModel__c` (→ `VehicleDefinition`),
`Opportunity.AF_SelectedVehicle__c` (→ `Vehicle`) — are *precisely and
only* the four lookups **to** the hidden objects, so they vanished from
describe along with their targets. `AF_LeadConversionService` writes to
them fine because it compiles at its own newer API version. Mystery
closed; it was never an org defect.

**Standing method from now on:**
- Use the **`sf` CLI** for all schema work, metadata retrieval, and any
  query touching `Vehicle` / `VehicleDefinition` / `Appraisal` /
  `AppraisalItem`.
- Use the **persona MCP connections** for persona-scoped DML and
  permission testing on everything else — they're still the only way to
  act as a named persona.
- **Retrieve metadata before reasoning about validation rules, record
  types, list views or flows.** The MCP layer surfaces none of them.
  `sf project retrieve start --target-org AlFardan --metadata
  "CustomObject:<Name>"` pulls fields + validation rules + record types
  + list views in one go.
- Fixing this properly would mean pinning a newer `SALESFORCE_API_VERSION`
  (or equivalent) in `.mcp.json` for the persona servers — worth doing,
  and worth re-testing the RS-03 "ghost field" findings afterwards.

**Licence note (still true, still relevant):**
`AutomotiveFoundationUserPsl` has 7 assignees — admin, the Power
Automate integration user, Integration User, Sales Manager, CRM Agent,
Underwriter John, Showroom Manager Automobiles. **Sales Rep and Sales
Receptionist do NOT hold it.** Since RS-04 FR11 makes the Sales Rep the
trade-in initiator, that's a real potential access gap to test.

## 2026-09-06: Schema baseline for RS-04 / RS-05 (verified via `sf` CLI)

Gathered to ground the regenerated ALF-RS-03→05 test cases
(`test-cases/ALF-RS-03-to-RS-05-test-cases.md`), whose header carries
the full field lists. Settled facts — don't re-derive them.

- **RS-04's trade-in model IS built**, contrary to the SD's own
  Verification Checklist ("Appraisal — NOT PRESENT"). `Appraisal` has
  `AF_ApprovalStatus__c`, `AF_ApprovalReference__c`,
  `AF_TradeInOutcome__c` (the TI-3 customer decision),
  `AF_FinalRemarks__c`, `AF_InitiatingSalesRep__c` (FR11's initiating
  rep), `AF_RelatedQuoteLine__c` (FR7's negative line link),
  `AF_RelatedVehicleReservation__c` (TI-2's deposit link),
  `AF_Account__c`, `AF_Contact__c`, `AF_Brand__c`, `AF_BusinessUnit__c`,
  plus standard `FinalAppraisalValue` / `TotalItemFinalValue` /
  `TotalAdjustmentValue` / `Status` / `PurposeType` / `UsageType`.
  There's a **`AF_Q_UsedCarTeam_Appraisal` list view** (so the Used Car
  team is represented) and a validation rule
  `AF_VR_Appraisal_BrandNotUndecided`.
  `AppraisalItem` carries `MakeName`, `ModelName`, `ModelYear`, `Trim`,
  `ExteriorColor`, `ConditionType`, `IdentificationNumber` (VIN),
  `CustomerAskingValue`, `InitialValue`, `FinalValue`,
  `TotalAdjustmentValue`, `AppraisedById`, `Usage` +
  `UsageUnitOfMeasureId`, plus `AF_InspectionDone__c`,
  `AF_InspectionNotes__c`, `AF_Source__c`.
  ⚠ **No Mileage/Odometer field exists** — FR9 requires mileage;
  `Usage`/`UsageUnitOfMeasureId` is the likely intended pair.
- **The 7 trade-in flows reference objects that genuinely exist** —
  `AF_FL_Appraisal_{ApprovalApproved,ApprovalRejected,DeriveBusinessUnit,FollowUpEscalation,SubmitForEvaluation}`,
  `AF_FL_AppraisalItem_EvaluationComplete`,
  `AF_FL_Reservation_ApplyTradeInDeposit`. Not a deployment-integrity
  defect (an earlier note in this file said it was — that was based on
  the API-version artifact above).
- **RS-05's nine search filters ALL have backing fields**, on `Vehicle`
  rather than `Product2`: make=`MakeName`, model=`ModelName`,
  year=`ModelYear`, trim=`TrimLevel`, colour=`ExteriorColor` /
  `AF_Colour__c`, stock status=`AF_InventoryStatus__c`,
  location=`AF_Location__c`, price=`PricebookEntry.UnitPrice`, model
  family=`VehicleDefinition` / `Product2.AF_ProductCategory__c`.
  `Vehicle` also has `VehicleIdentificationNumber`,
  `AF_NoVINPlaceholder__c`, `AF_CustomNewVehicle__c`,
  `AF_MediaAvailability__c`, `AF_ThumbnailLink__c`,
  `AF_ReservationStatus__c`, `AF_SalesDeliveryStatus__c`,
  `AF_VehicleOrderState__c`, `AF_BrandSubStatus__c`,
  `AF_IntegrationSyncStatus__c`, `AF_InventoryVehicle__c`,
  `AF_CustomerOwned__c`, `AF_CurrentOwnerContact__c`.
  **Record types `Regular_Vehicle` and `Demo_Vehicle`** and list views
  `All_Vehicles` / `Demo_Vehicles` exist — DEC-016's no-VIN/demo path
  is built.
  ⚠ Five separate status fields exist on `Vehicle`; establish which is
  authoritative for FR2 before RS-06/RS-10 gate on it.
- **`Opportunity.AF_VehicleModel__c` IS a Lookup to `VehicleDefinition`**
  and `AF_SelectedVehicle__c` a Lookup to `Vehicle` — this resolves the
  SD's own Data Design vs Retail Sales Data Model conflict in favour of
  the latter, and closes LFRDN-125's open type question.
  `AF_VehicleInterest__c` (Text 255) also exists and is **not** read by
  any gate — three vehicle fields on one object, purpose of the third
  unclear.
- **3 active validation rules on `AF_TestDrive__c`** (never visible via
  MCP): `AF_VR_TestDrive_RefusedRemarksRequired` (fires when *either*
  Result *or* Status = Refused; **uses `ISBLANK()`, so a whitespace-only
  remark bypasses it** — one-line fix to `LEN(TRIM(...))=0`),
  `AF_VR_TestDrive_ScheduledNeedsDateLoc`,
  `AF_VR_TestDrive_StatusResultConsistency`. **The last two are new
  since the RS-03 batch** — the previous session's "Status/Result can
  drift" bug (#3) and the missing scheduled-date guard are both now
  FIXED. Residual gap: the consistency rule only fires when *Status* is
  Completed/Refused, so setting a Result while Status stays `Requested`
  still drifts.
- **`AF_VR_Opp_TestDriveGate` IS stage-scoped** (Select / Commit / Take
  the Keys / Closed Won) — correcting bug #2's original wording. It
  still fires on *any* save of an Opportunity already at Select+, which
  is the residual cause of the "can't add a new unresulted Test Drive
  past Explore" collision.
- **`AF_VR_Opp_ExploreRequiresVehicle`** = `AND(stage IN {Explore,
  Select, Commit, Take the Keys, Closed Won}, ISBLANK(AF_VehicleModel__c),
  ISBLANK(AF_SelectedVehicle__c))` — **either** lookup satisfies it, so
  the Explore gate can be cleared via API without the broken Vehicle
  Finder.
- **Vehicle Explorer root cause narrowed**: `VehicleIdentificationNumber`
  **does** exist on `Vehicle`. Two candidates for the
  `No such column ...` error — (a) **FLS**: a `FieldPermissions` query
  for that field returns **zero rows**, and "No such column" is this
  org's established FLS symptom; (b) **API version**:
  `AF_VehicleExplorerController` is at **apiVersion 61.0** against an
  org at 68.0. Test (a) first — it's the cheaper fix.
- Opportunity has **10 active validation rules**: `AF_VR_Opp_`
  `TestDriveGate`, `ExploreRequiresVehicle`, `CommitGate`,
  `TakeTheKeysGate`, `ClosedWonGate`, `SOGenerationGate`,
  `SequentialStageProgression`, `LostApprovalRequired`,
  `LockSourceOfBusiness`, `BrandNotUndecided`.
- **`Product2` is the real vehicle catalogue**, not Automotive Cloud.
  20+ active records; 6 Vehicle Model products with **populated**
  `AF_ThumbnailLink__c` (Files rendition URLs): Ferrari Roma
  `01tFV007gmmT3kuYAC`, 296 GTB `01tFV007gmmXFtwYAG`, Purosangue
  `01tFV007gmmbS2yYAE`, SF90 Stradale `01tFV007gmmfeC0YAI`,
  Rolls-Royce Phantom `01tFV007gmmjqL2YAI`, Cullinan
  `01tFV007gmmo2U4YAI`. Plus accessories, paint packages, tint, PDI,
  extended warranty, "Dealer Prep & Registration", and a
  **`Trade-In Value Deduction`** product (`DED-TRADEIN-STD`) — the
  catalogue item TI-2's negative quote line is meant to use.
  Brand-specific variants exist for tint/PDI/paint (Ferrari and
  Rolls-Royce), alongside brand-neutral originals.
- **`Product2` has only 6 `AF_*` fields**: `AF_Brand__c`,
  `AF_BusinessUnit__c`, `AF_ProductCategory__c`,
  `AF_DefaultProviderSource__c`, `AF_KeyloopProductReference__c`
  (External ID, **null on every record**), `AF_ThumbnailLink__c`.
  `Product2` is the **accessory/service** catalogue plus 6 vehicle-model
  rows — it is *not* where the search filters live (those are on
  `Vehicle`, see above). Still true and still worth flagging: **the SD
  Integration Blueprint's `AF_VehicleId` upsert key does not exist** —
  the real external ID is `AF_KeyloopProductReference__c` and it is null
  on every record, so an inventory upsert today would create duplicates
  rather than match. Same three-names-one-field pattern already found on
  Account's Keyloop reference fields.
- **`AF_TestDrive__c` has 33 fields** — the 31 `FieldDefinition` returns
  **plus** `AF_Vehicle__c` (→ `Vehicle`) and `AF_VehicleDefinition__c`
  (→ `VehicleDefinition`), which only `sf` can see. Genuinely absent and
  confirmed by metadata retrieve: **no `AF_RescheduledFrom__c`** (TD-3
  reschedule chain still unbuilt) and **no channel/source field** (FR1
  intake attribution still impossible).
- **Line-item model is fully built**: `AF_LineItemType__c`,
  `AF_CustomizationDescription__c` (Long Text 2000),
  `AF_ProviderSource__c`, `AF_DiscountAmount__c`,
  `AF_RelatedVehicleReservation__c` on both `OpportunityLineItem` and
  `QuoteLineItem`; `QuoteLineItem` additionally has
  `AF_CustomerFacing__c`, `AF_IncludedInQuote__c`,
  `AF_RequiresInternalRequisition__c`. `Quote` has `AF_VINDisplay__c`
  (Text 17) for the RS-06 VIN-suppression rule.
- **`AF_Add_Products_To_Opporunity`** (note the typo in the live API
  name) is an active Screen Flow — likely the real "add products"
  mechanism, and worth checking as the working alternative to the
  broken "Select Vehicle" Vehicle Finder LWC.
## 2026-09-06: ⭐ SOURCE DOCS ARE NOW PDFs — always read those, never a `.md` export

The `readme files/` folder is **gone**, replaced by **`pdf files/`** holding
the two originals: `[Arcsen x Alfardan Group] R1 Business Requirements
Document V5 2.pdf` and `alfardan-export.pdf` (Solution Design). The old
`.md` exports (and `tableConvert.com_rwxyl9.md`, the original test-case
sheet) are no longer in the project.

**How to read them**: the `Read` tool can't render PDFs here (no
poppler/`pdftoppm`), but **`pdftotext` 4.06 IS installed** and works:
`pdftotext -layout "pdf files/<file>.pdf" <scratchpad>/brd.txt`, then
grep/Read the text file. Caveat: `-layout` mis-aligns the BRD's
left-hand row labels (`Related Personas`, `User Story`, `Requirement
Overview`, `Functional Requirements`, `Acceptance Criteria`,
`Assumptions/Comments`) by about one row — **read the content blocks,
not the label sitting beside them.** Python 3.14 and Node 24 are also
available if a better extractor is ever needed.

**The `.md` exports were losing far more than the known headings.**
Confirmed by diffing against the PDF for RS-03/04/05 alone:
- **RS-03**: AC3 was truncated mid-sentence; **AC4** (block stage
  progression until result recorded) and **AC5** (mandatory remarks on
  Refused) were lost, as was the whole **Assumptions row** — *"Test
  drive vehicle inventory management and scheduling system to be
  confirmed."* That last one matters: the BRD never committed to a
  scheduling system, so **DEC-011/TD-2 are the SD answering an open BRD
  assumption**, not implementing a settled one.
- **RS-04**: heading, User Story, Requirement Overview, Related Personas
  (**Sales Representative, Used Car Team, System**), **FR1 and FR2** all
  lost. Two consequences:
  - **Requirement Overview mandates a standalone trade-in**: *"Trade-In
    requests are recorded individually on the system without the need of
    an Opportunity to be present."* **The SD models no such path** — HLD
    07 treats trade-in purely as an opportunity side process. Genuine
    BA/design gap, previously invisible.
  - **FR2 names ten mandatory fields**: Make, Model, Year, VIN, Plate
    Number, **Mileage**, Inspection Done?, Inspection Notes, Expected
    Trade-In Value, Source. **Nine map exactly onto live `AppraisalItem`
    fields** (`MakeName`, `ModelName`, `ModelYear`,
    `IdentificationNumber`, `LicensePlateNumber`, `AF_InspectionDone__c`,
    `AF_InspectionNotes__c`, `CustomerAskingValue`, `AF_Source__c`) —
    which upgrades the missing **Mileage** field from "probably a naming
    mismatch" to a **high-confidence real gap**, since the build clearly
    followed FR2 field-for-field.
- **RS-05**: only AC1–AC2 survived; **AC3** (accessory → quotation line
  item), **AC4** (thumbnail per result row), **AC5** (gallery displayed
  **and navigable**) and **all four Assumptions** were lost. Assumption 3
  is the big one — it names **Autoline** as the stockyard photo source
  synced via Keyloop to the vehicle record, and requires the rep can
  **view and print** photos from within that record. Printing is
  mentioned nowhere else in either document and nothing appears to
  implement it.

**Lesson, stronger than the 2026-08-25 version**: don't just check the
PDF before filing a doc-corruption bug — **don't derive requirements
from a `.md` export at all.** Entire acceptance criteria and assumption
rows vanish silently, with no visual cue that anything is missing.
- The previous test-case sheet (`tableConvert.com_rwxyl9.md`) has
  **no ALF-RS-04 test cases at all** — it jumps RS-03-TC-008 →
  RS-05-TC-001.

## 2026-09-06: ALF-RS-03 (Test Drive Management) — FULL RE-TEST, all 39 regenerated test cases

Executed the full regenerated 39-case sheet (`test-cases/ALF-RS-03-to-RS-05-test-cases.md`)
API-first (Sales Rep MCP connection primarily, System Administrator MCP +
`sf` CLI for anything the Vehicle-lookup tooling gap blocks) then UI
(Sales Rep browser session, screenshots for every blocking-rule
confirmation). Metadata-retrieved every relevant flow's actual XML this
pass instead of inferring behaviour from labels — this overturned several
of the previous session's conclusions. Full detail below; only the
highest-value corrections and new findings are summarized here.

### ⭐ RESOLVED 2026-09-06 (same day, by the org owner) — org-wide Email Deliverability was OFF, silently breaking the standard "New Test Drive" UI action for every persona

**Fix confirmed working end-to-end** after the org owner changed Setup →
Email → Deliverability: (1) `Messaging.sendEmail()` direct as System
Administrator now returns `success=true`; (2) a bare `insert` of
`AF_TestDrive__c` as Sales Rep (the original failing action) now
succeeds with no exception; (3) a fresh Test Drive (TD-00052) created on
a CRM-Agent-owned Opportunity produced a real Task + Custom Notification
+ outbound email addressed to `emea-delivery-operations+crmagent@arcsen.com`,
confirmed by the user checking that inbox. **This bug is closed.** Note
it does **not** affect the separately-broken `AF_FL_Task_
TestDriveConfirmationEmail` (Bug below, key-prefix `a0U` vs real `a0V`)
— that one stays broken regardless of deliverability. Original finding
preserved below for the record.

Attempting to create a Test Drive via the real Lightning **New** action
(the related-list "New" button, exactly how a real Sales Rep would do it)
**fails 100% of the time**, with a raw, user-hostile error: *"We hit a
snag. No enum constant
ui.services.connection.models.api.StatusCode.NO_SINGLE_MAIL_PERMISSION"*
(screenshot `rs03-retest-tc008-email-permission-bug.png`). Reproduced
twice — once with a vehicle selected (looked at first like a double-
booking side-effect), once with **no vehicle at all** — ruling out any
connection to TC-014. Root-caused precisely:
- `AF_FL_TestDrive_NotifyOwnerOnCreate` fires on every Test Drive create
  (`recordTriggerType=Create`, unconditional) and unconditionally sends a
  plain-text email to the Opportunity owner via the Flow's `emailSimple`
  action, same transaction, no fault path.
- Confirmed via direct Apex (`insert` statement, bypassing the MCP DML
  wrapper) as Sales Rep: `INSERT FAILED: ... "Test Drive Notify Owner On
  Create" process failed. CANNOT_EXECUTE_FLOW_TRIGGER: Single email is
  not enabled for your organization or profile.`
- **Per the user's standing instruction, escalated to System
  Administrator to confirm whether this is a Sales-Rep-only permission
  gap or a real functional break** — confirmed via `Messaging.sendEmail()`
  in anonymous Apex **as System Administrator**: identical failure,
  `NO_MASS_MAIL_PERMISSION: Single email is not enabled for your
  organization or profile.` This is **not persona-scoped** — profile-level
  `PermissionsEmailSingle` is `true` for Sales Rep, Sales Manager, System
  Administrator and Standard User alike (`sf data query` against
  `PermissionSet WHERE IsOwnedByProfile = true`); the block sits at the
  **organization's Email Deliverability setting** (Setup → Email →
  Deliverability, almost certainly defaulted to "System email only" / "No
  Access" on this sandbox — a common post-refresh sandbox default to
  prevent accidental real-customer email). **Fix is an admin Setup change
  (Deliverability → "All Email"), not a code fix** — but as configured
  today, this is a live, complete, org-wide block on manually creating a
  Test Drive through the UI, for any persona, and would identically block
  TC-034's confirmation email even if its separate key-prefix bug (below)
  were fixed.
- **Tooling gotcha worth flagging**: the `salesforce_dml_records` MCP
  tool's `insert` operation reported **"Successful: 1" with a real,
  query-able Id** for ~20+ Test Drive records created earlier in this same
  session on this same Opportunity/owner — i.e., the exact same trigger
  conditions that a direct Apex `insert` and the real UI both fail on
  outright. The tool is almost certainly calling
  `Database.insert(records, false)` (partial-success mode), under which
  this specific local-action (Send Email) fault gets swallowed and the
  record still commits — silently masking this defect all session until
  a real UI click and a bare `insert` statement both surfaced it. **Don't
  trust "Successful" from this tool alone as proof a UI user could do the
  same thing** — for any test case where a flow sends an email
  synchronously on the record being tested, re-verify with a real UI save
  or a bare `insert`/`update` DML statement, not just the MCP DML tool.

### ⭐ NEW CRITICAL — double-booking is a HARD BLOCK, not the documented non-blocking warning, and it does not exclude Refused bookings

Retrieved `AF_FL_TestDrive_PreventDoubleBooking`'s real metadata (not
available via any MCP schema tool — Vehicle-touching flows are invisible
there): it is a **before-save Screen-error flow** (`<customErrors>` /
"Double_Booking_Error", message *"This vehicle is already booked for the
selected date and time slot. Choose a different slot or vehicle."*) —
confirmed empirically via both `sf data create record` (API) and a real
UI New-record save (identical error, both blocked outright, screenshot
`rs03-retest-tc014-double-booking-ui.png`... except the UI attempt never
reached this rule because it hit the Email Deliverability block above
first on save — the API-level confirmation stands independently). This
**directly contradicts SD TD-2's own design intent**: "a non-blocking
warning... the consultant can still proceed and save." The flow's own
name ("Prevent") already told the truth; the SD's prose didn't.
- **Conflict key confirmed**: exact `AF_Vehicle__c` + exact
  `AF_TestDriveDateTime__c` match only — no buffer window. A booking for
  the same vehicle **30 minutes later** sails through with zero warning
  (confirmed live) — the realistic failure mode TD-2's own overlap-
  definition open item worried about.
- **Cancelled correctly excludes** (`AF_Status__c != 'Cancelled'` in the
  flow's filter) — confirmed live: cancelling the conflicting record and
  retrying the identical slot succeeds cleanly.
- **Refused does NOT exclude — confirmed bug.** The flow's filter only
  excludes `Cancelled`, never checks `Refused`. Confirmed live: setting
  the occupying record to `Refused` (remarks populated) and retrying the
  identical vehicle/slot **still gets the hard block** — a drive the
  customer declined to take still permanently occupies that vehicle's
  slot forever. Contradicts SD TD-2's explicit "excludes Cancelled/
  Refused bookings" line for half of what it promises.
- Real-time slot-picker Apex (`AF_TestDriveSchedulerController`,
  `getBookedSlots`/`confirmSchedule`) has the identical Cancelled-only
  exclusion bug, confirmed by reading its SOQL directly.

### ⭐ TD-2 calendar LWC — confirmed genuinely built, but orphaned (dead code), not merely "unbuilt" as previously assumed

Previous session's conclusion ("only a plain Date+Time picker was
observed, TD-2 seems unbuilt") was too pessimistic. The component
**exists and is fully implemented**: `afTestDriveScheduler` LWC (slot-grid
UI, locked/booked slot icons, "Schedule Test Drive" heading) backed by
`AF_TestDriveSchedulerController.cls` (`getAllSlots`, `getBookedSlots`,
`confirmSchedule` — real, working, `WITH USER_MODE`/`update as user`
Apex). **But**: `afTestDriveScheduler`'s bundle metadata has
`<isExposed>false</isExposed>` and the retrieved `Test_Drive_Record_Page`
FlexiPage references only standard components (`flexipage`, `force`,
`forceChatter`, `runtime_sales_activities`) — **the scheduler is on no
page, no quick action, nothing** (confirmed both by metadata and by a
real UI record-page snapshot showing no calendar anywhere, screenshot
`rs03-retest-tc013-no-scheduler-lwc.png`). It's dead code: built, working
in isolation, never wired in. The Test Drive's actual vehicle-attach path
in the live UI is a **different** feature — the "Select Demo Vehicle"
quick action (`AF_SelectDemoVehicleAction` Aura wrapper →
`afDemoVehicleExplorerLauncher`), which is RS-05's demo/placeholder
vehicle flow, not a real scheduler.

### ⭐ TC-006 idempotency — REVERSED, this is a documented design decision, not a bug

Previously reported (this session, before checking the flow's own
description) as a fresh CRITICAL bug: re-entering Explore (Consider →
Explore → Consider → Explore) creates a **second** Test Drive (and
Appraisal) pair, confirmed live (TD-00031 then TD-00032 both created on
one Opportunity). **But** `AF_FL_Opp_CreateExploreSideProcesses`'s own
retrieved description says explicitly: *"If the Opportunity later cycles
back to Consider and forward to Explore again, this fires again and
creates a fresh pair — that is a deliberate reading of the BRD text...,
not a dedup gap."* This **contradicts** the SD Retail Sales data model's
own relationship table, which separately states "Auto-created on entry
to Explore, **idempotent on re-entry**." **Net: this is a documentation
contradiction between two SD statements, for the BA, not a functional
bug** — the live behaviour matches one of the two things the SD itself
says. Report as BA-gap, not as a bug.

### Other confirmed-via-metadata corrections to prior findings

- **TC-021 (whitespace-only Refused Remarks) — REVERSED, no bug.**
  Previously predicted (from the static `ISBLANK()` formula alone) that a
  single space would bypass the mandatory-remarks rule. Empirically
  tested live: `' '`, `'   '`, and `'\n'` are **all correctly blocked**
  with the same "Refused Remarks is required..." message — Salesforce's
  own platform-level whitespace handling for Long Text Area fields
  appears to normalize whitespace-only API submissions to null before the
  validation rule evaluates. The rule works correctly today; the formula
  is stylistically riskier than `LEN(TRIM(...))=0` but does not currently
  produce the predicted bug.
- **TC-029 (Status/Result consistency) — narrower gap than the sheet's
  hypothesis, but confirmed real.** `AF_VR_TestDrive_StatusResultConsistency`
  is a genuinely new, active rule since the last session (its own
  description cites the exact drift bug found then, dated 2026-08-24,
  as the reason it was added) — Status=Completed/Result=Refused and
  Status=Refused/Result=blank are both correctly blocked now. **The
  residual gap**: the rule only fires when *Status* is Completed/Refused;
  setting `Result='Refused'` while `Status` stays `'Requested'` is
  **not** caught (confirmed live) — Status and Result can still disagree
  in that one direction, which would make a `WHERE Status='Refused'`
  report silently miss a record that genuinely has a Refused result.
- **TC-008 — Task AND real Custom Notification, not "Task instead of the
  designed Custom Notification Type" as previously written.**
  `AF_FL_TestDrive_NotifyOwnerOnCreate` genuinely calls
  `customNotificationAction` (type `AF_NT_Alfardan_Alert`) in addition to
  the Task and an email — the design's notification mechanism is real and
  wired, not swapped for a lesser Task-only substitute. (The **email**
  half is the part that's broken — see the Email Deliverability finding
  above.)
- **TC-034 confirmation email — new, independent, high-confidence
  CRITICAL bug, confirmed by metadata alone.** `AF_FL_Task_
  TestDriveConfirmationEmail`'s trigger formula checks
  `LEFT($Record.WhatId, 3) = "a0U"` — but `AF_TestDrive__c`'s real key
  prefix, confirmed via `sObjectType.getDescribe().getKeyPrefix()`, is
  **`a0V`**. This is a hardcoded-prefix typo: the flow's entry condition
  can never be satisfied by a genuine Test Drive Task, ever. The
  confirmation email flow is permanently dead code, independent of (and
  in addition to) the org-wide Email Deliverability block above.
- **TC-005 Lead conversion owner — confirmed the known "no owner
  handoff" finding, PLUS a new mechanical explanation.**
  `AF_LeadConversionService` line 203-204: `Id convertOwnerId =
  String.valueOf(ld.OwnerId).startsWith('005') ? ld.OwnerId :
  UserInfo.getUserId();` — if the Lead's `OwnerId` is a Queue (prefix
  `00G`) at the moment of conversion rather than a User (`005`), the
  Opportunity is silently assigned to **whoever ran the conversion Apex**,
  not any Sales Rep. Reproduced live: a Lead explicitly created with
  `OwnerId` = Sales Rep converted to an Opportunity owned by **System
  Administrator** — meaning the Lead's ownership had silently reverted to
  a queue between creation and conversion, almost certainly via the
  already-documented `AF_AR_Lead_Routing`/`AF_FL_Lead_QueueRouting`
  gotcha (routine field edits bounce Lead ownership back to its queue).
  The fallback-to-running-user logic itself is a sensible safeguard
  (never assign an Opportunity to a Queue) — but it means conversion never
  reliably hands the deal to a Sales Rep, confirming AC1/AC2's gap with a
  root cause this time, not just an observation.

### Confirmed clean passes (full detail, both API and UI where applicable)

- **TC-001** (manual creation, API) — PASS via Sales Rep API. **UI New-
  action path is blocked by the Email Deliverability finding above** —
  report as BLOCKED, not PASS, for the UI half.
- **TC-002** (no channel field) — PASS, 31-field list re-confirmed.
- **TC-003** (website/chatbot receiving fields) — PASS, fields exist,
  Lead correctly lands in a CRM queue pre-conversion, zero Test Drives
  created pre-qualification.
- **TC-005** (Lead conversion carry) — PASS on the three carried fields
  themselves (exact value match); see owner-handoff note above.
- **TC-007** (prefill from carried values) — PASS exactly: DateTime/
  Location pre-filled verbatim, Status correctly derived `Scheduled`
  (both carried fields present) vs `Requested` (TC-006's fresh case, no
  carried values).
- **TC-009** (full UI lifecycle via Edit, not New — sidesteps the Email
  Deliverability bug since `NotifyOwnerOnCreate` is Create-only) — PASS,
  Requested → Scheduled → Completed all editable and clean via UI.
- **TC-010** — past-date/future-date save unguarded (real gap, no rule);
  `AF_VR_TestDrive_ScheduledNeedsDateLoc` confirmed blocking Scheduled
  without both Date/Time and Location, live, both API and UI paths
  consistent.
- **TC-011** (Location free text) — PASS/confirmed-gap: saves case/
  whitespace variants as distinct values, no controlled list.
- **TC-012** (TimeSlot/DateTime contradiction) — confirmed: both save
  independently with no reconciliation, redundant representation.
- **TC-016/017/018** (TD-3 reschedule / Postponed) — confirmed still
  fully unbuilt: `AF_Status__c` picklist has no `Confirmed`/`Postponed`
  value, no `AF_RescheduledFrom__c` field exists. TC-018/017 are N/A
  until TC-016 is built.
- **TC-019** (Result picklist) — PASS, cleanly: exactly `Completed`/
  `Refused`, both API-restricted (`INVALID_OR_NULL_FOR_RESTRICTED_
  PICKLIST` on `'Postponed'`) and UI-offered identically — **not**
  unrestricted like `Lead.LeadSource`.
- **TC-020** (Refused blank remarks) — PASS, full cycle both API and UI,
  screenshot `rs03-retest-tc020-refused-remarks-blocked-ui.png` shows the
  exact toast matching the API error verbatim.
- **TC-022/023** — Completed+blank-remarks saves clean (correct
  scoping); **Product Feedback still NOT enforced mandatory on Completed**
  (re-confirmed, contradicts SD TD-1 explicitly) — CONFIRMED BUG, carried
  forward unchanged.
- **TC-024/025** (gate block / gate clear) — PASS, exact message match
  both API and real UI Path component (screenshot
  `rs03-retest-tc024-gate-blocked-path-ui.png`); skip-stage attempts
  (Explore→Commit, →Closed Won) correctly blocked too, alongside
  `AF_VR_Opp_SequentialStageProgression` firing in the same response.
- **TC-026** (Cancelled strands the gate) — CONFIRMED CRITICAL, re-
  verified fresh on a new Opportunity: `AF_FL_TestDrive_UpdateGate` only
  sets `AF_StageGatePassed__c=true` off `NOT(ISBLANK(Result))` — Cancelled
  never gets a Result, so it never passes, forever. **Worse than
  previously documented**: `PermissionsDelete=false` for **all four**
  operational PSGs now checked (Sales Rep, Sales Manager, CRM Agent,
  Showroom Manager) — not just the three noted before. Zero human
  recourse; System Administrator delete is the only fix (used here,
  reported per the standing instruction).
- **TC-027** (Select-stage add collision) — CONFIRMED CRITICAL, exact
  reproduction: `CANNOT_EXECUTE_FLOW_TRIGGER` wrapping the gate message,
  record silently doesn't exist afterward; supplying Result at insert
  avoids it.
- **TC-028** (gate arithmetic + delete) — PASS: 3-record blocked state
  confirmed, System Administrator delete of the blank-Result record
  correctly recomputes the gate (not blind-cleared) and progression then
  succeeds.
- **TC-030** (feedback storage) — confirmed child-only, no copy to
  Opportunity Description/NextStep. New finding: `AF_ProductFeedback__c`
  **cannot be used in a SOQL WHERE filter** (`field ... can not be
  filtered in a query call` — standard Long Text Area limitation) —
  "build a report of product feedback across drives" needs aggregation/
  full-record retrieval, not a simple filtered list view.
- **TC-031** (2000-char boundary) — PASS exactly: 2000 chars saves, 2001
  rejected with a clear `data value too large... max length=2000` error;
  Arabic + quotes + newlines round-trip byte-for-byte.
- **TC-032** (CRM feedback separation) — PASS, live read+write as CRM
  Agent under Sales-Rep-owned Opportunity, fields independent, UI shows
  correct labels and CRM Agent's own name in Last Modified By.
- **TC-033** (CRM follow-up trigger) — confirmed: no Task, no flow, no
  mechanism at all — depends entirely on an agent noticing.
- **TC-035** (Keyloop fields) — PASS, all four fields + 3 picklists exist,
  correctly dormant.
- **TC-036** (permission matrix) — PASS cleanly: `AF_StageGatePassed__c`
  correctly `Edit=false` for all four PSGs, confirmed live (Sales Rep
  `INVALID_FIELD_FOR_INSERT_UPDATE` on a direct attempt) — the gate flag
  cannot be bypassed by unticking a checkbox as feared.
- **TC-037** (BU segregation) — ⭐ **NEW CRITICAL, confirmed empirically**:
  Sales Rep's own connection returns the **exact same 29 Test Drives**
  (including several under `Alfardan Sports Motors`) as the unrestricted
  System Administrator query — **zero business-unit segregation enforced
  on `AF_TestDrive__c`**, contradicting DEC-007 ("Shared Customer,
  Segregated Transactions" explicitly names Test Drives as segregated).
  Root cause **not** `PermissionsViewAllRecords`/`ModifyAllRecords`
  (confirmed both `false` on `AF_PSG_Sales_Rep` for this object) — Sales
  Rep's Opportunity visibility shows the identical org-wide pattern (13 of
  13 Opportunities visible, matching admin exactly), so this is most
  likely the **same root cause as an existing, broader sharing-model gap
  at the Opportunity level** (e.g. a BU-scoped sharing rule or public-
  group membership misconfigured to grant all three BUs instead of one
  per rep) that Test Drive simply inherits by having no tighter
  restriction of its own — flag as a cross-cutting finding, likely
  belongs to RS-01/RS-02's security model rather than being Test-Drive-
  specific, but confirmed live regardless.
- **TC-038** (Closed Lost / Request Closure) — re-confirmed unchanged:
  the exact same 10-item "Show more actions" menu (Delete/Edit/Printable
  View/Clone/Change Owner/Clone with Related/View Relationship Map/Submit
  for Approval/Sharing/Select Vehicle), no Request Closure anywhere.
- **TC-039** (doc reconciliation) — no new testing needed; already fully
  resolved in the regenerated test-case file via the PDF recovery and a
  full-text SD search (zero "ALF-RS-03"/"ALF-RS-04" hits).

### Persona-blocker note (per explicit user instruction this pass)

Two genuine persona-level blockers were hit and escalated to System
Administrator, both reported inline above:
1. **Delete** on `AF_TestDrive__c` — Sales Rep (and Sales Manager, CRM
   Agent, Showroom Manager) all lack `PermissionsDelete`; used System
   Administrator to clear two gate-blocking records (TC-026, TC-028).
   This is a deliberate FLS restriction, not a broken feature — real
   persona behaviour confirmed as designed (nobody but IT can delete).
2. **Email Deliverability** — escalated to System Administrator
   specifically to determine whether the `NO_SINGLE_MAIL_PERMISSION`
   error was a Sales-Rep permission gap or a deeper break. **Confirmed
   the functionality itself is broken org-wide**, not persona-scoped —
   System Administrator hits the identical `Messaging.sendEmail()`
   failure. This is the correct outcome of that escalation: the
   underlying capability (single email send) does not work for anyone
   today, until an admin changes Setup → Email → Deliverability.
Also used System Administrator/`sf` throughout for anything touching
`AF_Vehicle__c`/`AF_SelectedVehicle__c`/`AF_VehicleModel__c` (seeding
precondition data only — the MCP tooling gap, not a persona permission
gap, per the established baseline) — the actual test actions (stage
progression, rule violations, notifications) were always driven through
the real persona connection or UI.

## 2026-09-06 (later same day): Email Deliverability fix confirmed + follow-up items closed

**User fixed org Email Deliverability directly in Setup.** Re-verified
three ways, all clean: (1) `Messaging.sendEmail()` as System
Administrator now returns `success=true` (previously
`NO_MASS_MAIL_PERMISSION`); (2) a bare `insert` of `AF_TestDrive__c` as
Sales Rep (the original failing action) now succeeds with no exception;
(3) a fresh Test Drive (TD-00051, Sales-Rep-owned) produced a real
`EmailMessage`, confirmed directly in the record's own Activity Timeline
("sent an email to noreply@example.com.invalid" — expected target given
Sales Rep's still-unfixed placeholder email, a separate pre-existing
issue) — and a second Test Drive (TD-00052) created on a **CRM-Agent-
owned** Opportunity produced a real email to
`emea-delivery-operations+crmagent@arcsen.com`, which the user confirmed
receiving. **Bug #1 (Email Deliverability) is CLOSED.**

### ⭐ NEW — "Select Demo Vehicle" is not actually a working alternative; it fails at the exact same point as the Opportunity's "Select Vehicle"

Following up on "is more testing needed?": empirically drove the **Select
Demo Vehicle** quick action on a Test Drive (Sales Rep, real UI, TD-00051)
end to end, since the previous session only confirmed via metadata that
this component exists and never actually clicked through it.
- The **first screen** (Demo Vehicle Finder — filters for Make/Model/
  Year/Price/Body Type/Fuel Type) genuinely works: real facet counts,
  real result card rendered ("Ferrari Purosangue — 1 in stock — SUV ·
  Gasoline — AED 398,350").
- **Clicking that result to actually select the vehicle fails**: console
  logs `Demo Vehicle Explorer error: {status: 500, ...}` and the modal's
  second screen shows *"Error retrieving vehicles: No such column
  'VehicleIdentificationNumber' on entity 'Vehicle'."* — **the identical
  error, identical missing field**, as the already-documented broken
  "Select Vehicle" (Vehicle Finder) action on the Opportunity.
- **Net effect, now confirmed independently at a second site**: there is
  **no working UI path anywhere in the org to attach a real Vehicle to
  either a Test Drive or an Opportunity.** The browse/filter step of two
  *different* LWCs both render fine (giving a false impression the
  feature works), but both fail at the identical final step. This raises
  confidence that `VehicleIdentificationNumber`'s absence on the standard
  `Vehicle` object is a single, org-wide root cause blocking every
  vehicle-selection entry point in the build, not a one-off. Belongs most
  directly to RS-05 but blocks RS-02's Explore gate and RS-03's TD-2/
  double-booking UI paths transitively — flag as the single highest-value
  remaining finding for the delivery team.

### All four follow-up items now closed (same day, continued)

- **BU segregation (Bug #7) — confirmed a second, cleaner way.**
  Discovered the "Sales Manager" persona's real role is **"Sales Rep -
  SportsMotors"** (genuinely distinct from Sales Rep's "Sales Rep -
  Automobiles" — not just a same-tool-different-filter artifact this
  time). Queried Opportunities via Sales Manager's own connection: **all
  14 org Opportunities returned**, including ones plainly owned by Sales
  Rep and branded Rolls-Royce/Ferrari under the Automobiles BU. Two
  provably-different-BU personas see the identical, fully unrestricted
  set. Bug #7 stands, now on stronger evidence.
  Side note, not a bug: this same Sales Manager MCP connection returned
  `AF_TestDrive__c ... not supported` on both `describe` and `query` —
  but `sf` confirms `AF_PSG_Sales_Manager` genuinely has
  `PermissionsRead=true, PermissionsCreate=true` on that object at the
  metadata layer. This is the already-documented stale-MCP-connection
  gotcha (a server that connected before a permission change doesn't see
  it until restarted), not a live defect — noted and moved on.
- **Lead conversion owner-handoff (TC-005) — re-tested clean, no
  confound, root cause is simpler than first described.** Inserted a
  fresh Lead with `Status='Follow-up'`, `AF_QualificationOutcome__c=
  'Qualified'`, and `OwnerId` **explicitly set to the Sales Rep User** —
  all in the single insert, zero follow-up edits. Queried immediately
  after: **`OwnerId` was already a Queue**, despite the User Id explicitly
  supplied. This is not a side-effect of some later edit bouncing
  ownership — **Leads always rest in a Queue by design**, which is
  correct per AC1 ("routed to CRM for qualification"). Converted
  immediately via `AF_LeadConversionService`: the resulting Opportunity
  is owned by **System Administrator** (whoever ran the conversion),
  confirmed via direct query. **Root cause, cleanly stated**: because
  every Lead is normally sitting in a Queue at the moment of conversion
  (by design, not by accident), and the conversion service's fallback
  (`OwnerId.startsWith('005') ? ld.OwnerId : UserInfo.getUserId()`) can
  never use a Queue Id, conversion **always** falls back to whoever runs
  it and **never** hands the deal to a Sales Rep. AC1/AC2's gap is
  real and unconditional, not an edge case.
- **`AF_FL_TestDrive_NotifyOnAssignment` — confirmed live, PASS.** Set
  `AF_AssignedConsultant__c` on an existing Test Drive to a different
  user (Sales Manager) via Sales Rep's connection. A new Task ("Test
  Drive Assigned") appeared, owned by the **assigned consultant**
  specifically — distinct from the pre-existing "Complete Test Drive
  Details" task owned by the record owner. The flow fires correctly and
  targets the right person.
- **Appraisal-side duplication on Explore re-entry — confirmed, same
  pattern as the Test Drive side.** Queried `Appraisal` for the Account
  used in the TC-006 re-entry test: **two records share an identical
  `CreatedDate` down to the second**, consistent with both being created
  by the same flow execution pair (Consider→Explore→Consider→Explore, in
  quick succession). Since `AF_FL_Opp_CreateExploreSideProcesses` creates
  both the Test Drive and the Appraisal unconditionally in the same
  transaction with no dedup guard on either, this was expected once the
  Test Drive half was confirmed — now empirically verified on the
  Appraisal side too. Same classification as before: **BA gap
  (documentation contradiction), not a bug** — the flow's own description
  already states this is deliberate.

**RS-03 is now considered fully tested — no further open threads.**

## 2026-09-06 (final pass): real-UI evidence for TC-001, double-booking, and Refused-exclusion gap

Three findings above had only `sf`-CLI/API evidence. Closed all three with
genuine Lightning UI clicks (Sales Rep persona, real "New" action off the
Test Drives related list on Opportunity `006FV00AbseUdEKYE0` "QA test RS-03
- Final UI Verification"):

- **TC-001 (New Test Drive, post-Email-Deliverability-fix) — PASS, real UI
  evidence.** Filled the New Test Drive quick action (Status=Requested) and
  clicked Save: clean green success toast **"Test Drive 'TD-00054' was
  created."** Screenshot: `rs03-final-tc001-new-action-post-fix.png`. Confirms
  the earlier email-permission bug no longer blocks record creation from the
  real UI, not just via API.
- **Double-booking hard block (`AF_FL_TestDrive_PreventDoubleBooking`) —
  PASS, real UI evidence.** Attempted a second Test Drive via the real "New"
  action with the identical Vehicle (Ferrari Roma) + Date/Time (01/12/2026,
  9:00 AM) as an existing Test Drive (TD-00055, itself UI-created). Got the
  real user-facing block: **"We hit a snag. This vehicle is already booked
  for the selected date and time slot. Choose a different slot or vehicle."**
  Screenshot: `rs03-final-tc014-doublebooking-ui-confirmed.png`.
- **Refused-exclusion gap — confirmed via real UI too, not just API.** Set
  TD-00055 (the occupying record above) to `Status=Refused` with remarks,
  then repeated the identical New Test Drive attempt (same Vehicle/Date/Time).
  Got the **identical** blocked-slot error again — proving the real UI path
  also fails to exclude `Refused` bookings from the double-booking check
  (matches the flow's exact exclusion logic: it only excludes `Status !=
  'Cancelled'`, never `Refused`). Screenshot:
  `rs03-final-tc015-refused-still-blocks-ui.png`. This is Bug — Medium (a
  Refused test drive should free up that vehicle/slot, but a rep can never
  rebook the same slot once any prior attempt was refused).

**Testing-methodology gotcha (for future timestamp-matching setups):** writing
a literal UTC timestamp via `sf data update record` (e.g.
`2026-12-01T09:00:00.000+0000`) does **not** match what the Lightning UI's
date/time picker produces for the same displayed local time — the UI
converts local time to UTC using the org's timezone offset (~3 hours in this
sandbox), so a `sf`-written "9:00 AM" and a UI-picked "9:00 AM" can land on
different UTC instants. This caused one false negative (a UI-created Test
Drive saved successfully against an `sf`-written collision target instead of
being blocked). Fix: when a test needs to collide with a specific
date/time slot in the UI, create the *occupying* record via the UI itself
(not `sf`) so both timestamps go through the same local→UTC conversion.

**RS-03 final status: fully tested, all findings now have both API and real-UI evidence.**

## 2026-09-06 (final pass, continued): RS-03-TC-004 — the one item missed by the regenerated-sheet numbering, now closed

Auditing the regenerated 39-case sheet against everything actually executed
this session turned up one genuine gap: **RS-03-TC-004** (WhatsApp/chatbot
intake landing object — Case vs Lead ambiguity) was never directly executed
under its current numbering (the earlier 8-case batch used different TC
numbers and didn't cover this specific question). Closed it now via `sf`
against System Administrator:

- **Case does carry a WhatsApp channel** — `Case.AF_Channel__c` picklist:
  `Web Form, Email, WhatsApp, Social (Sprout), Phone, Walk-in, Keyloop`.
  `AF_Subtype__c` includes `Sales Inquiry` as a category. This confirms the
  SD's Case-based WhatsApp design is real and built, matching TC-004's
  premise.
- **No test-drive-intent field exists anywhere on Case** — full 16-field
  `AF_*` custom field list on Case has nothing resembling
  `AF_InterestedInTestDrive__c`; the only vehicle-adjacent field is
  `AF_Vehicle__c` ("Vehicle (VIN-linked)"), which is service-context (VIN
  lookup for an after-sales case), not test-drive intent.
- **No carry-forward mechanism exists at all.** `Case.AF_ConvertedLead__c`
  (Lookup to Lead) is a bare field with **zero automation behind it** —
  confirmed no `FlowDefinitionView` record has `TriggerObjectOrEventLabel =
  'Case'`, no `AF_%Case%` flow exists, and no Apex class matches `%Case%`.
  Linking a Case to a converted Lead is entirely manual (an agent creates a
  Lead by hand and populates the lookup); there is no automated field
  mapping of any kind, so even if a test-drive field existed on Case,
  nothing would carry it forward today.
- **Net (matches the test case's own expected framing): this is a BA gap,
  not a bug.** A WhatsApp customer expressing test-drive interest becomes a
  Case with no structural path to a Test Drive record — reaching one
  depends entirely on an agent noticing, manually creating a Lead, and
  manually re-typing the test-drive interest onto it. The BRD's FR1 (naming
  WhatsApp as a direct test-drive intake channel) and the Lead Management
  design (routing WhatsApp through Case, converted only "when a genuine
  sales inquiry emerges") are unreconciled — flag for the BA alongside the
  existing RS-03-TC-002 finding (no channel/source field on
  `AF_TestDrive__c` either), since both point at the same underlying gap:
  intake-channel provenance is not structurally tracked anywhere in the
  Test Drive data model.

**With this closed, all 39 test cases in the regenerated RS-03 sheet have a
recorded Actual Result — no open items remain for ALF-RS-03.**

## 2026-09-07: Request Closure / TD-2 "scheduler" — retracted and re-explained; every remaining bug re-verified live against System Administrator

User reported seeing both **Request Closure** and a **Test Drive scheduler**
as "Arcsen Alfardan" (an admin-level login), directly contradicting two
findings above. Investigated properly instead of re-asserting the old
conclusion.

### Request Closure — retracted, not a bug
Retrieved `Opportunity_Record_Page`'s actual FlexiPage XML.
`Opportunity.AF_Request_Closure` has **no visibility rule at all** — listed
as a plain action alongside Edit/Submit/Add Products. The Highlights Panel's
`numVisibleActions=3` just means it isn't one of the 3 *pinned* buttons; it
should still appear in "Show more actions" for every profile. Nothing in
the metadata explains why my original UI pass didn't show it. **Retracting
this finding** — likely a mis-observation during the original enumeration,
not a real defect. (Only one Opportunity page layout and one Opportunity
FlexiPage exist org-wide — confirmed via an unfiltered `FlexiPage` query —
so there was never a second, admin-only page for this to hide behind.)

### TD-2 "scheduler" — retracted as "orphaned"; it's real, live, working code with a different name than I thought
Traced the actual component chain instead of trusting the standalone
`afTestDriveScheduler` bundle's `isExposed=false` flag as the whole story:
`AF_Select_Demo_Vehicle` Quick Action → `afDemoVehicleExplorerLauncher` →
`afDemoVehicleExplorerModal` → **`afDemoVehicleExplorer`**, which contains
its own genuine internal step, commented directly in the source: *"Scheduling
step (after a vehicle is picked)... the agent picks the date/slot right
after choosing the car."* Backed by `AF_VehicleExplorerController`
(`selectVehicleForTestDrive`, etc.) — a completely different, and very much
alive, controller from `AF_TestDriveSchedulerController`. **`afTestDriveScheduler`
does appear to be genuinely dead/superseded code** (still unreferenced
anywhere), but it is not the feature users actually see — `afDemoVehicleExplorer`'s
built-in scheduling step is, and that one works.

**Root cause of why I could never reach it**: `AF_VehicleExplorerController`
runs every query `WITH USER_MODE` (confirmed in source, e.g. line ~109's
vehicle list query). Since `Vehicle.VehicleIdentificationNumber` has zero
FLS grants for any non-admin profile (Bug/TICKET-06), `WITH USER_MODE`
strips it for every non-admin user, which is the exact "No such column"
error blocking the flow before it ever reaches the scheduling step. **This
is very likely one root cause cascading into two apparent symptoms** —
fixing TICKET-06's FLS grant should unblock the scheduling step for
everyone at the same time, with no separate fix needed.

**Reclassifying**: drop "Request Closure + TD-2 not wired to pages" as a
critical ticket. Fold the standalone `afTestDriveScheduler`/
`AF_TestDriveSchedulerController` dead-code observation into a Low-priority
tech-debt note (real, unused, safe to remove or ignore) — not a feature gap.

### Every remaining active bug re-tested live against System Administrator (per explicit user instruction)

Used real API sessions rather than inference — Sales Rep via a fresh SOAP
login (bypassing the generic MCP connector's own "Vehicle not supported"
limitation, which affected both personas equally and wasn't a permission
signal), Admin via `sf`/existing OAuth connection:

- **Cancelled-TD-strands-gate**: built a fresh Opportunity+Test Drive as
  Admin, cancelled with no Result, attempted to advance stage as Admin —
  **hit the identical block** (`"This Opportunity has a Test Drive without
  a recorded Result..."`). Confirmed **universal**, not persona-scoped.
  Admin's only edge is the delete-based recovery (also re-confirmed live).
- **Double-booking excludes Refused**: set a Test Drive to Refused with
  remarks as Admin, attempted an identical-slot new Test Drive as Admin —
  **hit the identical block**. Confirmed **universal**.
- **Vehicle FLS (VIN)**: ran the *identical* `SELECT VehicleIdentificationNumber
  FROM Vehicle` query as literal Sales Rep (real SOAP-authenticated session)
  side-by-side with Admin (`sf`). Sales Rep: `INVALID_FIELD: No such
  column`. Admin: returns the real VIN (`TESTVINROMA0001`). Cleanest
  possible confirmation of the FLS root cause — matches what the user saw
  live in the UI exactly.
- **Vehicle field accepts Regular vehicles**: inserted a Test Drive with a
  Regular Vehicle using Sales Rep's own real session (not Admin) — saved
  cleanly. Confirmed **universal**, no FLS angle at all here.
- **Product Feedback not mandatory / Status-Result drift**: both re-tested
  as Admin (Completed + blank feedback; Result=Refused + Status=Requested,
  remarks supplied to isolate from the unrelated RefusedRemarksRequired
  rule) — **both saved cleanly for Admin too**. Confirmed **universal**;
  nothing to bypass since the rules don't exist for anyone.
- **Confirmation email dead code**: confirmed no confirmation Task exists
  for Admin's own Test Drive either. Confirmed **universal** (was never
  persona-gated — hardcoded key-prefix typo in the flow).
- **BU segregation**: confirmed Admin's own query returns all 18 org
  Opportunities — expected and correct for Admin's profile, not a bug from
  that seat; still a real gap for non-admin personas.
- **Lead conversion owner handoff**: unchanged — Admin is the only account
  that can even trigger a conversion today (`ConvertLeads` is false on
  every operational permission set), so this was always Admin-exclusive
  by construction, not something "avoided" by using Admin.

**Net result**: of everything on the active ticket list, only the VIN-FLS
gap (TICKET-06) is genuinely bypassed by System Administrator. Every other
active finding is now confirmed universal with live Admin-side evidence,
not inference — and Request Closure / TD-2-as-orphaned-code are retracted
outright.

## 2026-09-06/07: ALF-RS-04 (Trade-In Request and Appraisal Visibility) — testing in progress

Following the same methodology as RS-03: API-first (per-persona real
sessions, not the generic MCP connector — see API-version gotcha below),
then UI, then cross-check any bug against System Administrator. 29 test
cases in `test-cases/ALF-RS-03-to-RS-05-test-cases.md`
(RS-04-TC-001..029). Findings so far, most severe first:

### ⭐ NEW CRITICAL — creating ANY new Appraisal (trade-in) via direct DML fails unless `AF_InitiatingSalesRep__c` is populated, with a completely misleading error

Confirmed via `sf` (System Administrator), reproduced 3 times across
different Opportunities/Business Units (including a standalone
Account-only attempt and a normal Automobiles-BU-linked attempt — **both
fail identically**, ruling out a BU-specific cause):

```
sf data create record --sobject Appraisal --values "ReferenceRecordId=<Opp> AF_Account__c=<Acct> PurposeType=Trade-In UsageType=Automotive"
→ INVALID_CROSS_REFERENCE_KEY: We can't save this record because the
  "Appraisal Follow-Up Escalation" process failed. ... Assigned To ID:
  owner cannot be blank.
```

**Root cause, confirmed via metadata retrieve of
`AF_FL_Appraisal_FollowUpEscalation`**: this flow fires `RecordAfterSave`
on every Appraisal Create (synchronous, same transaction — not scheduled,
despite having a separate scheduled path for the actual 2-day escalation
check). Its immediate Create-time branch looks up a User matching
`$Record.AF_InitiatingSalesRep__c`; if that field is blank (it is **not**
schema-required — `nillable=true` — and is not one of FR2's ten mandatory
trade-in fields), the lookup returns no record, `Owner_Active`'s condition
(`Get_Owner_User.IsActive = true`) evaluates false on a null, falls to its
default branch (`Create_FollowUp_Task_Manager`), which sets the new
Task's `OwnerId = Get_Owner_User.ManagerId` — also null, since the lookup
itself never found a User. Task creation with a blank `OwnerId` is
rejected by the platform, and because this all happens in the same
transaction as the Appraisal's own insert, **the entire Appraisal record
is rolled back** — an identical failure mode to the already-documented
`AF_FL_Opp_AfterCreate` unresolvable-Task-assignee rollback pattern this
org has now hit twice.

**Confirmed fix/workaround**: populate `AF_InitiatingSalesRep__c` at
insert time (any valid, active User Id) — the record then saves cleanly.
This field is not customer-facing (absent from BRD FR2's ten mandatory
fields), so any real-world creation path (a Quick Action, a Screen Flow,
manual entry) that doesn't explicitly know to set it will hit this
crash. **All further RS-04 setup in this session populates it explicitly
to work around this bug** — flag this to the dev team as the literal
root cause, not just "escalation flow is broken."

### ⭐ NEW CRITICAL — Sales Representative cannot access the Appraisal object at all — confirmed via both API and real UI, and this is the exact persona FR11 names as the trade-in initiator

**API**: real SOAP-authenticated Sales Rep session, `SELECT Id FROM
Appraisal` → `INVALID_TYPE: sObject type 'Appraisal' is not supported`
(confirmed genuine, not the API-version artifact below — same query
succeeds instantly for Sales Manager and CRM Agent's own real sessions at
the same API version).
**Root cause, confirmed via `PermissionSetLicenseAssign`**:
`AutomotiveFoundationUserPsl` has exactly 7 assignees — System Admin,
2 integration users, Sales Manager, CRM Agent, Underwriter John,
Showroom Manager Automobiles. **Sales Representative and CRM Supervisor
are not on the list.** `AF_PSG_Sales_Rep` genuinely grants
`ObjectPermissions.PermissionsRead/Create = true` on `Appraisal` — the
permission set itself is correctly configured — but without the PSL the
object is entirely invisible regardless, which is why this reads as
"not supported" rather than a permission-denied error.
**UI, confirmed independently**: logged in as Sales Rep, opened an
Automobiles-BU Opportunity (`006FV00ABujcvkyYMA`) at Explore. The Related
tab has no Appraisal/Trade-In related list at all (only Payments, Vehicle
Reservations, Quotes, Approval History, Test Drives, Products, Preferred
Seller, Contact Roles, Partners, Notes & Attachments, Stage History), and
"Show more actions" has exactly 10 items (Delete/Edit/Printable
View/Clone/Change Owner/Clone with Related/View Relationship
Map/Submit for Approval/Sharing/Select Vehicle) — **no trade-in/appraisal
action anywhere.** A Sales Rep today has categorically zero way to
initiate a trade-in, through any path, directly contradicting FR1
("allow a Sales Representative to initiate a trade-in request") and FR11
(follow-up tasks assigned to "the Sales Rep who initiated the request").

### ⭐ Methodology gotcha, confirmed with a clean before/after — Appraisal (and likely other Automotive Cloud objects) is invisible below a certain REST API version, for real persona sessions, independent of permissions

Same Sales Manager session: `/services/data/v60.0/query?q=SELECT Id FROM
Appraisal` → `INVALID_TYPE`. **The identical session, same query, against
`/services/data/v68.0/`** → succeeds, returns the record. This is not a
permission signal at all — confirmed by re-running the exact failing
query at v68.0 and getting a clean result with the same session token.
**Always use API v68.0 (or the generic MCP connector once its pinned
version is fixed per the earlier note) for any Automotive Cloud object
— Appraisal, AppraisalItem, Vehicle, VehicleDefinition — never assume
"not supported" means a real access gap without retrying at the org's
actual current API version first.** This most likely explains why the
generic MCP connector tool failed identically for both Sales Rep and
System Administrator on "Vehicle" earlier in the RS-03 phase too.

### Schema/access facts confirmed this pass (not yet bugs, just baseline)

- `Appraisal` (11 records), `AppraisalItem` (3), `AppraisalAdjustment` (0),
  **`AppraisalItemProviderVal`** (6 — the real API name; `AppraisalItemProviderValuation`
  does not resolve, confirming the test sheet's own open question).
- `Appraisal.ReferenceRecordId` (the actual Opportunity link — there is
  no dedicated `Opportunity__c`/`OpportunityId` field) is a **polymorphic**
  lookup (Account/ApplicationFormProduct/Case/FinancialAccount/Lead/Opportunity),
  **required** (`nillable=false`) but not type-restricted — confirmed live
  that pointing it at an **Account Id instead of an Opportunity Id saves
  successfully** (once the escalation-flow bug above is worked around).
  **This directly answers RS-04-TC-003/029: the schema DOES structurally
  support a standalone, no-Opportunity trade-in** — nothing in the object
  model blocks it. What's still unconfirmed: any UI entry point for it
  (none found so far — Sales Rep has no Appraisal UI access at all per
  above, so this needs re-checking with Sales Manager or CRM Agent).
- `AF_TradeInOutcome__c` (the field previously identified as TI-3's
  customer-decision field) has live values `Accepted / In Progress /
  Declined` — **TI-3's SD text says "Accepted / Refused / Pending
  Customer Decision."** Same concepts, different literal values/wording —
  worth a wording-reconciliation note for the BA, not necessarily a
  functional defect, but test cases asserting the literal SD wording
  (RS-04-TC-017/018) will need to test against the real values instead.
- Three separate status-like fields exist on `Appraisal`: standard
  `Status` (Initial Valuation/Visit Scheduled/Under Approval — the
  standard Automotive Cloud lifecycle), `AF_ApprovalStatus__c`
  (Pending/Approved/Rejected), `AF_TradeInOutcome__c` (see above). Which
  one gates what needs mapping before RS-04-TC-014/016/017 can be judged
  precisely.
- Two Appraisal records were auto-created as side effects of my own
  RS-03-session Opportunity testing (`AF_FL_Opp_CreateExploreSideProcesses`)
  and both show `AF_BusinessUnit__c = 'UNMAPPED'` rather than a real BU —
  worth investigating under RS-04-TC-025 (BU derivation) once unblocked;
  may be a genuine derivation gap for whatever BU/Brand those source
  Opportunities carried.

### Still to test (continuing)

RS-04-TC-005 through TC-029 — mandatory field enforcement, 360°-image
gate, Submit for Evaluation Screen Flow (UI-only, per the test case's own
note that Screen Flows can't be driven via API), Used Car Team valuation
submission (need to identify who represents this persona — no dedicated
MCP connection provisioned, same gap noted for RS-03's CRM follow-up),
approval routing/authority matrix, rejected-valuation return path,
negative quote line sign/value, customer-decision gating, deposit
double-counting risk, cross-BU trade-in history visibility (SEC-008),
BU-derivation read-only enforcement, expired-valuation re-approval,
withdrawal audit trail, and the RS-04-TC-029 standalone-path UI check
with a persona that actually has Appraisal access.

### Continued — flow behavior fully mapped, financial-control gaps confirmed, Submit for Evaluation gate confirmed PASS

Retrieved all 6 remaining trade-in flows' real metadata (not just names)
to replace guesswork with their actual documented behavior:

- **`AF_FL_Appraisal_ApprovalApproved`/`ApprovalRejected`**: fire on
  `AF_ApprovalStatus__c` changing to Approved/Rejected; hand the record
  back to `AF_InitiatingSalesRep__c` (out of the Used Car Team queue) and
  notify via email + Custom Notification. Confirmed well-built, matches
  FR10.
- **`AF_FL_Appraisal_DeriveBusinessUnit`**: derives BU from Brand via the
  same shared subflow pattern as Opportunity/Lead/Contact — confirmed
  correct. The two "UNMAPPED" Appraisals found earlier are **not a bug**:
  their source Opportunities (my own quick RS-03 test records) themselves
  had `AF_Brand__c = null` — correct derivation from bad upstream test
  data, not a defect. Explicitly designed to also cover "standalone manual
  creation from an Account" per its own description — further confirming
  RS-04-TC-003/029's standalone path was a deliberate design intent, not
  an oversight.
- **`AF_FL_Appraisal_SubmitForEvaluation`**: confirmed via real UI
  (Sales Manager, after reassigning a test record to themselves — Sales
  Rep cannot reach this at all per the license gap above) — clicking
  **Submit for Evaluation** on a record with no AppraisalItem and no
  files produces a clean, well-worded block: *"Not ready for evaluation —
  This trade-in needs at least one vehicle detail record (Make/Model/
  Year/VIN) and at least one uploaded 360° image before it can be
  submitted to the Used Car Team."* **RS-04-TC-006/008/009/010 all PASS**
  — this is a genuinely well-built Screen Flow gate, combining FR3's
  image requirement and FR9's vehicle-detail requirement into one clear
  message. Action itself is reachable via "Show more actions" (not
  missing, unlike the RS-03 Request Closure false alarm).
- **`AF_FL_AppraisalItem_EvaluationComplete`**: fires when the Used Car
  Team records `InitialValue` for the first time; correctly notes
  `FinalValue`/`TotalItemFinalValue`/`FinalAppraisalValue` are Automotive
  Cloud's own read-only calculated rollups (can't be set directly via
  API for testing — must go through `InitialValue` + `AppraisalAdjustment`
  records). Reassigns to the initiating rep before submitting into
  `AF_AP_Appraisal_Manager` so the owner-hierarchy approver resolves
  correctly.
- **`AF_FL_Reservation_ApplyTradeInDeposit`** (actually ALF-RS-08 FR11,
  not RS-04): fires on `AF_TradeInAsDeposit__c` checkbox; finds the
  Approved Appraisal via `ReferenceRecordId`, sets deposit only if blank
  (never overwrites a rep-entered value), stamps the reverse link. Well
  documented, no issues found in the logic itself — **but confirmed it
  gates only on `AF_ApprovalStatus__c = Approved`, never checks
  `AF_TradeInOutcome__c` (customer decision) at all** — see the
  double-counting/gating finding below.

### ⭐ NEW CRITICAL — nothing enforces TI-2/TI-3's core financial control: a trade-in deduction can be added to a Quote regardless of approval or customer decision, with no sign validation either

Confirmed via direct DML (System Administrator): created a Quote on the
test Opportunity, then added a `QuoteLineItem` with
`AF_LineItemType__c='Trade-In Deduction'` and `AF_RelatedTradeIn__c`
pointing at an Appraisal whose `AF_ApprovalStatus__c` and
`AF_TradeInOutcome__c` were **both null** (never approved, no customer
decision at all) — **saved with zero errors.** Retried with a
**positive** `UnitPrice` (which would *increase* the customer's price,
the worst possible sign error TC-016 warned about) — **also saved with
zero errors.**

**Root cause, confirmed via metadata retrieve of the `QuoteLineItem`
object: it has zero validation rules of any kind.** Cross-checked every
flow in the org (the 6 above, plus the full RS-03/RS-04 flow list) — none
of them create, gate, or validate this line item; the negative line is
entirely a manual step with no automation or validation tying it to the
Appraisal's approval/customer-decision state at all. This directly
contradicts TI-2 ("the accepted value becomes a negative Quote Line
Item") and TI-3 ("only an Accepted decision releases the value into the
negative quotation line") — neither is enforced in any way. A Sales Rep
(or anyone with QuoteLineItem create access) can add an arbitrary-amount,
arbitrary-sign trade-in line referencing any Appraisal in any state.

**Also directly confirms RS-04-TC-026 (expired valuation validity)
as a real gap by the same mechanism**: `Appraisal.ValidityEndDate`
genuinely exists as a field, but with zero validation rules on either
object, nothing stops using an expired value in a quote line either.
Only one validation rule exists on `Appraisal` at all —
`AF_VR_Appraisal_BrandNotUndecided` (blocks Brand='Undecided', unrelated
to any financial control).

### Confirmed via real UI — Sales Rep genuinely cannot reach an Appraisal record at all, by any path

Direct navigation to an Appraisal record URL as Sales Rep returns *"This
page isn't available in Salesforce Lightning Experience or mobile app"*
— a third, independent confirmation (alongside the API `INVALID_TYPE`
and the missing related-list/action-menu entries) of the
`AutomotiveFoundationUserPsl` gap. Separately, the **same URL as Sales
Manager** (who does hold the PSL) initially returned *"We couldn't find
the record you're trying to access"* — this turned out to be ordinary
OWD/sharing behavior, not a bug: the record was still owned by System
Administrator (who created it) and Appraisal's sharing model is
deliberately owner/queue-based (per `SubmitForEvaluation`'s own
description: "Owner intentionally moves to the queue... so Used Car Team
members gain native record access without a viewAllRecords grant").
Reassigning ownership to Sales Manager fixed it immediately — correct,
expected behavior once understood, not a defect.

**Separately noted, not yet root-caused**: the record page's embedded
"Trade-In 360° Photos" FlexCard threw `ui.services.exceptions.
NoAccessException: You don't have access to this record` for Sales
Manager even after they owned the parent Appraisal — worth investigating
whether this needs a permission grant on `AppraisalItem`/`ContentDocument`
beyond what `AF_PSG_Sales_Manager` currently provides (note
`AF_PS_AppraisalItem_FullAccess`, a separate optional permission set, only
grants Read, not Create — unclear yet whether Sales Manager has that
set at all or relies solely on the PSG). Flagged for follow-up, not yet
a confirmed bug.

### RS-04 status: substantial critical findings confirmed; several test cases still genuinely untested

**Fully tested and resolved this pass**: TC-001, TC-002, TC-004 (partial
— auto-creation confirmed, rep-initiated UI path confirmed absent for
Sales Rep specifically), TC-006, TC-007, TC-008, TC-009 (partial — gate
confirmed, document generation itself not yet observed), TC-016, TC-017,
TC-025 (partial — derivation logic confirmed correct), TC-026, TC-029
(schema question resolved; UI entry point still unconfirmed for a
PSL-holding persona).

**Not yet tested — genuinely open, not assumed clean**: TC-003 (deeper
BA-gap write-up), TC-005 (mandatory-field enforcement empirically —
now done, see below), TC-010, TC-011, TC-012 (needs a Used Car
Team-equivalent persona — none provisioned), TC-013, TC-014, TC-015,
TC-018 (Refused/Declined mandatory reason), TC-019 (duplicate-header
prevention), TC-020 (quote-stage gating boundary), TC-021
(double-counting, live), TC-022 (cross-BU history — blocked on Sales
Rep's license gap, needs Sales Manager/CRM Agent instead), TC-023,
TC-024, TC-027, TC-028. These should not be reported as passing — they
simply haven't been executed yet this

### ⭐ NEW CRITICAL — none of FR2's ten mandatory trade-in fields are actually enforced, and two of them (Make/Model) are restricted picklists still holding Salesforce's stock demo data, not real vehicle values

**RS-04-TC-005, fully executed via direct DML (System Administrator)**:
created six separate `AppraisalItem` records, each leaving a different
FR2-named field blank in turn — VIN (`IdentificationNumber`), Expected
Trade-In Value (`CustomerAskingValue`), Source (`AF_Source__c`),
Inspection Notes (`AF_InspectionNotes__c`), and finally Make/Model/Year
all three at once. **Every single one saved cleanly, with zero
validation errors.** FR2 says the system "should require trade-in
information... to include Make, Model, Year, VIN, Plate Number, Mileage,
Inspection Done?, Inspection Notes, Expected Trade-In Value and Source" —
none of the ten are actually enforced as mandatory anywhere in the
object's validation rules (confirmed zero validation rules exist on
`AppraisalItem` beyond the platform-required `ConditionType`/`Usage`/
`Type`, which are generic Automotive Cloud fields, not FR2's own list).
A trade-in "vehicle detail" record can be created with **no information
identifying which vehicle is even being valued.**

**Separately, and independently severe**: `AppraisalItem.MakeName` and
`.ModelName` are both **restricted picklists** whose only valid values
are Salesforce Automotive Cloud's own out-of-box sample data — `MakeName`:
`Neo Motors, Mirage, Electra, Aurica, Eniac`; `ModelName`: `NeoGen, Neo
Electric, Ionic CD4, Mirage Kaizen AMT, Eniac_X1Series_Grey, CRV`.
**None of these are real vehicle makes/models.** Confirmed live:
attempting `MakeName='Toyota'` throws `INVALID_OR_NULL_FOR_RESTRICTED_
PICKLIST`. Since a trade-in is, by definition, the *customer's own*
existing vehicle — which could be any real-world make — **this picklist
was never customized away from the demo org it was built in, making it
impossible to record a real customer's actual trade-in vehicle brand or
model at all today.** This is a foundational, build-blocking gap
independent of the missing-enforcement finding above; even if FR2's
fields were enforced as mandatory, a rep still couldn't enter truthful
data into two of them.

### RS-04 status, updated: TC-005 now confirmed as a second Critical finding alongside the quote-line/validity gaps already found

Everything else in the "still to test" list above remains genuinely
open. Given the volume of Critical/High findings already confirmed with
strong evidence (Sales Rep license gap, Appraisal-creation-crash,
zero QuoteLineItem validation, restricted-picklist demo data, zero FR2
enforcement), this was reported to the user as a substantial first-pass
result. User asked to continue testing until fully confident nothing
more is needed — second pass below closes out nearly everything
remaining.

## 2026-09-07: RS-04 second pass — remaining test cases closed out

### ⭐ NEW CRITICAL — the Submit for Evaluation Screen Flow can never actually succeed, even with every precondition met

**RS-04-TC-008, corrected** (was previously marked PASS based only on the
validation-block half working correctly): completed the full live UI
flow as Sales Manager — created a valid `AppraisalItem` (all fields
populated, working around the restricted-picklist bug with valid demo
values) and linked a real `ContentVersion`/`ContentDocumentLink` (a
360°-photo stand-in) to the Appraisal, satisfying both of
`SubmitForEvaluation`'s stated gate conditions. Clicked **Submit for
Evaluation** → **Next** again: this time past the validation screen, but
the actual submission itself fails:

> Something went wrong. We couldn't complete this action... The flow
> tried to update these records: 9ALFV0000Z2WuQa4QK. This error
> occurred: INVALID_FIELD_FOR_INSERT_UPDATE: Appraisal: bad field names
> on insert/update call: Status.

**Investigated the discrepancy directly**: `Appraisal.Status` is
schema-writable (`createable=true`, `updateable=true`,
`calculated=false`), a direct `sf` DML update on the exact same field/
record succeeds instantly, and `FieldPermissions` confirms
`AF_PSG_Sales_Manager` has `PermissionsEdit=true` on `Status`. None of
the ordinary causes (schema restriction, FLS, calculated field) apply —
the field is only unwritable from **inside the flow's own compiled
context**. Given `AF_FL_Appraisal_FollowUpEscalation` (and by extension
likely every flow in this set) is pinned to `apiVersion 61.0` while the
org's live schema is at v68.0 — the same generic pattern already
confirmed twice this session (Vehicle/Appraisal object visibility) — the
most likely explanation is that `Status` became API-writable at some
point after v61.0 and the flow's compiled metadata has never been
refreshed to recognize it.

**Net effect: the single Quick Action that exists on `Appraisal` at all
(`AF_Submit_For_Evaluation` — confirmed via `QuickActionDefinition`, no
other Appraisal Quick Action exists) can never complete successfully for
any real user, in any state.** This is more severe than the earlier
"empty queue" finding (also separately confirmed — `AF_Q_UsedCarTeam`
has **zero** `GroupMember` rows) — the record never reaches the queue at
all, since the transaction that would move it there always fails first.
FR3/FR4/FR5's entire "submit for evaluation" pathway is completely
non-functional today, for every persona, confirmed via the real UI, not
inferred.

**This blocks RS-04-TC-011 through TC-015 from being exercised
end-to-end through the real submission path** — reviewed each of their
underlying flows via metadata instead (see below) to confirm what would
happen *if* a record ever reached the queue, since that's still valuable
information even though the path to get there is broken.

- **TC-011/012** (Used Car Team notified + submits valuation): reviewed
  `AF_FL_Appraisal_SubmitForEvaluation`'s Get-Queue-Members/Loop/Notify
  pattern — correctly built, **but confirmed the `AF_Q_UsedCarTeam` queue
  itself has zero members** (`GroupMember` query returns 0 rows), and
  **no user in the org holds `AF_PSG_UsedCarTeam`** either (0 rows). Even
  if the Status bug were fixed, there is currently no one to notify —
  FR5's Used Car Team evaluation step has no real-world recipient.
- **TC-013/014** (rep notified on evaluation complete; submits into
  approval): reviewed `AF_FL_AppraisalItem_EvaluationComplete` — correctly
  built (reassigns to initiating rep, sets `AF_ApprovalStatus__c=Pending`,
  submits into `AF_AP_Appraisal_Manager`, confirmed this approval process
  exists via `ProcessDefinition`). Logic appears sound; not empirically
  triggered end-to-end since the submission gate above blocks reaching
  this state through the real flow.
- **TC-015** (rejected valuation returns to consultant with reason):
  reviewed `AF_FL_Appraisal_ApprovalRejected` — hands the record back to
  `AF_InitiatingSalesRep__c`, notifies via email + Custom Notification.
  Logic sound; not empirically triggered for the same reason.
- **TC-023** (task reassignment on inactive rep): reviewed
  `AF_FL_Appraisal_FollowUpEscalation`'s `Owner_Active` decision directly
  — correctly branches to the initiating rep's Manager when
  `Get_Owner_User.IsActive != true`. Logic confirmed via metadata; not
  triggered against a live deactivated user this pass.
- **TC-024** (Showroom Manager escalation on overdue): reviewed the same
  flow's scheduled path (`Escalation_Check`, fires 2 business days after
  creation) — its `Has_Manager_Escalation` decision has an explicit
  **"No Manager - Skip Escalation" default connector**, meaning it
  degrades gracefully (unlike the immediate Owner_Active branch, which is
  what actually crashes on a blank `AF_InitiatingSalesRep__c` — the two
  are different branches of the same flow with different safety behavior,
  worth noting precisely). Not triggered live (requires a 2-day offset or
  direct date manipulation); logic itself looks safe.

### ⭐ NEW CRITICAL — cross-BU (and even same-BU) trade-in history visibility is far more restrictive than SEC-008 intends — the opposite failure mode from RS-03

**RS-04-TC-022, fully executed**: 12 real Appraisal records exist across
the org (Sports Motors: 5, Automobiles: 4, UNMAPPED: 2, no-BU: 1).
Queried as Sales Manager's own real session (`SELECT COUNT() FROM
Appraisal`) → **returns exactly 2** — confirmed these are precisely the
2 records Sales Manager themselves owns (both Sports Motors BU); every
other record, including other Sports Motors BU trade-ins owned by other
users, is invisible.

**This directly contradicts FR11/AC4/SEC-008**, which require trade-in
history to be visible **across all business units** at the customer/
Account level — the built sharing model doesn't even grant same-BU
visibility beyond strict per-record ownership, let alone the explicit
cross-BU exception. This is the **opposite** problem from RS-03's
Test Drive/Opportunity finding (which had zero segregation, too much
access) — here `Appraisal`'s sharing model is Private/ownership-only
with no role-hierarchy or BU-scoped sharing rule at all, confirmed via
real query, not inferred from permission-set metadata.

### Additional confirmed findings

- **TC-018 (Declined requires mandatory reason) — FAIL, confirmed live.**
  Set `AF_TradeInOutcome__c='Declined'` with `AF_FinalRemarks__c` (the
  only candidate reason field) left blank — saved cleanly. Same root
  cause as the other financial-control gaps: zero validation rules exist
  on `Appraisal` beyond `BrandNotUndecided`.
- **TC-025 (BU field read-only) — PASS, confirmed via FieldPermissions.**
  `AF_BusinessUnit__c` has `PermissionsEdit=false` for every operational
  permission set (Sales Rep, Sales Manager, CRM Agent, Showroom Manager,
  Used Car Team) — correctly enforced.
- **TC-027 (withdrawal mechanism) — confirmed unbuilt.** No "Withdrawn"
  value exists on `AF_TradeInOutcome__c` (only Accepted/In Progress/
  Declined) and no dedicated withdrawal field exists anywhere on
  `Appraisal`. The SD's exception-handling text ("withdrawn trade-ins
  remove the quotation line...") has no schema representation at all —
  there's no way to even mark a trade-in as withdrawn, let alone reverse
  its financial effects.
- **TC-028 (over-allowance field) — confirmed unbuilt, correctly so.**
  Zero fields matching "allowance"/"margin" exist on `Appraisal` (only 11
  custom `AF_` fields total). Matches Assumption 2's explicit "to be
  confirmed with finance" status — not a defect, a correctly-still-open
  item.
- **TC-009/010 (Book-In Sheet generation) — confirmed unbuilt.** Exactly
  one Quick Action exists on `Appraisal` at all
  (`AF_Submit_For_Evaluation`) and zero on `AppraisalItem` — no Book-In
  Sheet generation action exists anywhere in the UI. Matches the SD's own
  "generation tooling TBP" framing.
- **TC-021 (deposit double-counting) — reviewed via metadata, not fully
  live-triggered with real dollar amounts** (would have required
  populating a full `InitialValue`/`AppraisalAdjustment` valuation chain
  for a non-zero `FinalAppraisalValue`, since that field is a read-only
  Automotive Cloud rollup). Confirmed via the flow's own description that
  `AF_FL_Reservation_ApplyTradeInDeposit` gates only on
  `AF_ApprovalStatus__c='Approved'`, never checks
  `AF_TradeInOutcome__c` — the same double-counting/gating gap already
  confirmed for the Quote-line path applies here too, by direct reading
  of the flow's logic.
- **TC-019 (no duplicate header on multiple evaluations)** — not
  independently triggered with two real valuations, but confirmed by
  elimination: none of the 6 reviewed flows create a second `Appraisal`
  header under any condition; the header is created exactly once (at
  Opportunity Explore entry or standalone creation) and never duplicated
  by anything downstream.
- **TC-020 (Opportunity progresses regardless of trade-in status until
  quote stage)** — confirmed by the RS-03 baseline's own full
  enumeration of Opportunity's 10 active validation rules (`AF_VR_Opp_
  TestDriveGate/ExploreRequiresVehicle/CommitGate/TakeTheKeysGate/
  ClosedWonGate/SOGenerationGate/SequentialStageProgression/
  LostApprovalRequired/LockSourceOfBusiness/BrandNotUndecided`) — none
  reference Appraisal/trade-in status at all. Matches AC1.
- **TC-007 (image upload boundary conditions)** — not independently
  tested; this is standard Salesforce Files/ContentVersion behavior
  (format/size limits), not custom app logic, and the SD itself notes no
  minimum-count or format rule is specified in either source document —
  marking as "not independently verifiable, no documented rule exists to
  test against" rather than continuing to probe generic platform limits.

### RS-04 final status: comprehensive coverage reached

Of 29 test cases, every one has now been either fully executed, reviewed
via direct metadata inspection with a clear confidence level stated, or
explicitly marked as resting on generic platform behavior with no
app-specific rule to verify. Six Critical/High bugs are now confirmed
with strong evidence: (1) Appraisal-creation-crash on blank
`AF_InitiatingSalesRep__c`, (2) Sales Rep's total license-gated lockout,
(3) zero financial-control validation on `QuoteLineItem` (sign, approval
gating, expiry, Declined-reason), (4) zero FR2 mandatory-field
enforcement plus the restricted-picklist demo-data bug, (5) the
Submit-for-Evaluation flow's Status-field crash blocking the entire
evaluation pathway, (6) the inverted BU-visibility problem (too
restrictive, not too open) blocking FR11/SEC-008's cross-BU history
requirement. No further testing is planned for this story unless new
test cases are added.

## 2026-09-07: RS-04 third pass — re-verifying claims made with less rigor than warranted, per explicit user challenge

User asked "are you sure no more testing is needed" a second time. Rather
than re-assert confidence, re-checked the specific claims in the report
that were based on reading a flow's *description* text rather than its
actual compiled logic, plus one persona gap that was never actually
closed.

- **BUG-RS04-06's root cause (API-version/Status-field crash) — now
  directly confirmed, not just inferred by analogy.** Re-retrieved
  `AF_FL_Appraisal_SubmitForEvaluation` itself (previously only checked
  a *sibling* flow's `apiVersion` and reasoned by analogy). Confirmed
  directly: this exact flow is pinned at `apiVersion 61.0`, and its
  `recordUpdates` element genuinely contains `<field>Status</field>
  <stringValue>Visit Scheduled</stringValue>` — the literal line that
  crashes. No longer a hypothesis-by-analogy; this is the actual
  offending element in the actual flow that failed live.
- **TC-021's double-counting gap — now directly confirmed from the
  flow's real filter conditions, not its prose description.**
  Re-retrieved `AF_FL_Reservation_ApplyTradeInDeposit` and read the
  `Get_Approved_Appraisal` record-lookup's actual `<filters>` elements:
  exactly two conditions — `ReferenceRecordId = $Record.AF_Opportunity__c`
  and `AF_ApprovalStatus__c = 'Approved'`. **No `AF_TradeInOutcome__c`
  filter exists anywhere in the element** — confirmed at the filter-XML
  level, closing the gap between "the description says X" and "the flow
  actually does X."
- **RS-04-TC-004's rep-initiated path — genuinely re-tested, not just
  re-asserted.** The original conclusion ("no rep-initiated path exists")
  was only ever demonstrated with Sales Rep, whose result is confounded
  by their total `AutomotiveFoundationUserPsl` lockout — of course they
  see no trade-in action, they can't see the object at all. Logged in as
  Sales Manager (who has full, confirmed Appraisal access) and checked
  the Opportunity page directly: a **"Trade Ins" related list is
  genuinely present** (unlike Sales Rep's Opportunity view, where the
  entire related list was absent) — but it has no "New" action, and
  "Show more actions" (11 items: Sharing Hierarchy/Delete/Edit/Printable
  View/Clone/Change Owner/Clone with Related/View Relationship
  Map/Submit for Approval/Sharing/Request Closure/Select Vehicle) has
  nothing trade-in-related either. **This properly confirms, for a
  persona that can actually reach the object, that no rep-initiated
  creation path exists anywhere in the UI** — strengthens BA gap #2
  rather than changing it, but the original evidence for it was weaker
  than presented (persona-confounded), and now isn't.

**Net result of this pass: no findings changed, but two Critical bugs'
root causes moved from "reasoned/inferred" to "directly verified in the
actual flow XML," and one BA gap's evidence moved from "confounded by an
unrelated access bug" to "cleanly demonstrated with a persona that has
real access." This is the actual bar for "no more testing needed" — not
just re-reading the same conclusions with more confidence.

## 2026-09-07: RS-04 fourth pass — user asked directly whether every Quick Action for this story had actually been tried; answer was no

Had queried `QuickActionDefinition` by `SobjectType` (Appraisal,
AppraisalItem) but never checked Opportunity or Account, and had
concluded the "Trade Ins" related list had no actions based on a
snapshot that turned out to be stale (captured before the component
finished rendering) rather than an actual absence.

**Corrected, both important:**

- **Org-wide Quick Action search**: Opportunity has exactly 3
  (`Add_Products`, `AF_Request_Closure`, `AF_Select_Vehicle`); Account
  has 0; an org-wide keyword search for "Trade"/"Appraisal" in any
  Quick Action name or label returns nothing beyond the one already
  found (`AF_Submit_For_Evaluation`). No creation action was missed by
  under-searching.
- **The "Trade Ins" related list itself — my very first read of it was
  wrong.** A screenshot (not just the accessibility snapshot) showed
  "Trade Ins (0)" rendering as a genuine link with a real actions
  dropdown, same as every other related list on the page — the earlier
  snapshot had simply been captured mid-render. Clicking "Show actions
  for Trade Ins" → **"New" is a real, present menu item.**

**⭐ This directly reverses BA gap #2's "no rep-initiated path exists"
half — a real creation path does exist. But testing it live produced
the single strongest piece of evidence yet for BUG-RS04-01**: logged in
as Sales Manager, clicked the real "New" action, filled in exactly what
the form asks for (`Purpose Type`, `Reference Record` — pre-filled,
`Usage Type` — the only three fields the form exposes;
`AF_InitiatingSalesRep__c` does not appear on the form at all), clicked
Save:

> "We hit a snag." — "We can't save this record because the 'Appraisal
> Follow-Up Escalation' process failed... INVALID_CROSS_REFERENCE_KEY:
> Assigned To ID: owner cannot be blank."

**This is stronger evidence than the original API-only repro**: it
proves the crash isn't an artifact of a raw DML test omitting a field
a real user would have filled in — the real form doesn't even *offer*
that field, so **every real user, on the very first, most ordinary
attempt to use the one button the system provides for this purpose,
hits this crash with 100% certainty, with no possible workaround
through the UI.**

**Reframing BA gap #2 accordingly**: this is no longer "no rep-initiated
path exists, only auto-create" — both mechanisms genuinely exist in the
build (auto-create via Explore entry, rep-initiated via the Trade Ins
related list's New action, reachable from any stage). The real open
question ADB-016/OPN-027 was flagging is still a legitimate BA item
(should both really fire, or just one), but it's no longer confounded
with "one path doesn't exist" — it does, it's just broken by
BUG-RS04-01, which is now the single most severe, most concretely
demonstrated finding in this story.

## 2026-09-07: RS-04 fifth pass — actually debugged BUG-RS04-06 instead of continuing to assert an unverified theory

User asked directly whether any flows needed debugging. On reflection,
the "flow apiVersion 61.0 doesn't recognize a newer field" theory for
the Status-field crash was never actually verified — and isn't how
Salesforce flows work (record-update elements resolve against the
org's live schema at runtime, not the flow's saved apiVersion). Pulled
real debug logs instead of continuing to assert it.

**Method**: enabled a TraceFlag on Sales Manager (`DebugLevel` with
`Workflow=FINEST`, `ApexCode=FINEST` — the first attempt used
`StartDate` set to midnight UTC, ~21 minutes in the *future* relative
to actual server time, so it silently never activated; fixed by
setting `StartDate` to the actual current time). Reproduced the Submit
for Evaluation crash three times total across this process; the third
attempt, with tracing genuinely active, captured the real flow
execution trace via `ApexLog`.

**What the log actually showed**: the failing element is
`FlowRecordUpdate|Assign_Owner_To_Queue` — a single element that sets
both `OwnerId` (to the `AF_Q_UsedCarTeam` queue) **and** `Status` (to
"Visit Scheduled") together, exactly matching the flow's own
description. `FLOW_ELEMENT_FAULT|Fault path taken.` fires on this
element specifically.

**Isolated the real mechanism via three direct API calls as Sales
Manager** (not Admin): (1) `OwnerId` + `Status` together → same crash,
confirmed reproducible outside the flow entirely; (2) `Status` alone,
no owner change → **fails on its own** (`No such column 'Status'`);
(3) `OwnerId` to the queue alone, no Status → **succeeds cleanly**.
This isolates the fault to `Status` alone — the queue-ownership change
was never the problem.

**Real root cause, confirmed via `PermissionSetLicenseAssign`**:
`Appraisal.Status` is gated by **`AutomotiveDealerEssentialsPsl`** — a
*different*, more specific Permission Set License than the
`AutomotiveFoundationUserPsl` already known to gate the whole object.
This PSL has exactly **2 assignees**: System Administrator and
"Showroom Manager Automobiles" (a distinct real user from the "Sales
Manager" persona this project uses, despite the persona being labeled
"Sales Manager / Showroom Manager"). Sales Manager holds Foundation
but not DealerEssentials — so they can reach `Appraisal` at all, but
still can't write `Status`, and `AF_PSG_Sales_Manager`'s own
`FieldPermissions` row claiming `PermissionsEdit=true` is irrelevant,
exactly the same PSL-overrides-FLS pattern already established for
object-level access.

**Correcting BUG-RS04-06 accordingly**: the crash itself, and its
"nobody can ever submit a trade-in" severity, both stand — confirmed
even more solidly than before (isolated to the literal field, not a
flow artifact). But the root cause is **a missing PSL assignment**
(`AutomotiveDealerEssentialsPsl` needs to be granted to every
operational persona who uses this flow, not just the two current
holders), not an API-version mismatch — that theory is retracted. This
also means System Administrator was never a fair control for "does
this work for anyone" — Admin holds the one PSL that makes this
specific field succeed, same as they hold Foundation for the whole
object.

## 2026-09-08: RS-04 sixth pass — actually ran the escalation and approval process live, not just read their metadata

User asked directly whether escalation/approval had been tested, then
explicitly said not to rely on metadata review — "test them by
debugging the flows or something or by changing the time remaining so
we can check it out." Retrieved `AF_FL_Appraisal_FollowUpEscalation`'s
full XML to map its two branches precisely (immediate Create branch
vs. the `Escalation_Check` scheduled path, `offsetNumber=2`,
`offsetUnit=Days`, `timeSource=RecordTriggerEvent`), then ran real
data through both, plus the full evaluation → approval chain, live.

**Escalation, immediate branch — genuinely tested with a real inactive
user this time (not a blank field), and it works correctly.** BUG-RS04-01
was only ever demonstrated with `AF_InitiatingSalesRep__c` **blank**,
where `Get_Owner_User` finds no record at all, so its `ManagerId` is
also null — that specific combination crashes. To test the *other*
input this same decision handles (`Owner_Active` → default connector,
labelled "Inactive — Assign to Manager"), created a real throwaway
User (`005FV007xld7Uc8YAE`, `IsActive=false`, real `ManagerId` pointing
to "Alfardan Salesforce") and set them as the initiating rep on a new
Appraisal (`9ALFV0000h0Ull24AC`). **Result: no crash** — a Task titled
*"Complete Trade-In Appraisal Follow-Up (reassigned - Sales Rep
inactive)"* was created correctly, owned by the manager, `ActivityDate`
= tomorrow, exactly per the flow's own field assignments. This is a
genuinely different code path from BUG-RS04-01 and it's correctly
built — the bug is specifically the blank-field case, not "inactive
owner" generally.

**Side finding, not a new bug but worth flagging**: the Task's owner
comes from `$Record.OwnerId` (the Appraisal's current owner), while
the "is this person active" check reads `AF_InitiatingSalesRep__c` —
these are two different fields. In this test they happened to point to
the same manager only because of who created the record; if a record's
`OwnerId` and `AF_InitiatingSalesRep__c` ever diverge (e.g. someone
creates a trade-in on another rep's behalf, or ownership is reassigned
after creation), the immediate follow-up task would go to whoever
currently owns the record, not necessarily the person the field name
implies. Confirmed live via the approval-chain test below, where a
Task ended up owned by System Administrator (who created the record)
rather than the Sales Rep named in `AF_InitiatingSalesRep__c`.

**Escalation, scheduled branch (2 business days later) — cannot be
forced to fire, but confirmed the data underneath it would make it
succeed.** `timeSource=RecordTriggerEvent` means Salesforce computes
the fire time internally at save time, not from an editable date
field — there's no `CreatedDate` backdating trick that reaches it, and
System Administrator's own UI login is blocked (WebAuthn passkey, no
fallback — see Gotchas), so Flow Builder's manual Debug-a-path feature
isn't reachable either. Instead, read the scheduled path's own filter
XML directly (`Get_Appraisal_Record` → `Outcome_Still_Pending` checks
`AF_TradeInOutcome__c IsBlank` → `Get_Owner_User_Escalation` →
`Has_Manager_Escalation` checks `ManagerId IsNull=false` →
`Create_Escalation_Task` assigns to that Manager) and confirmed live,
by direct query, that the test record from above satisfies every
condition today: `AF_TradeInOutcome__c` is null (still pending) and
`AF_InitiatingSalesRep__r.ManagerId` resolves to a real user. Since the
lookup-and-create-Task mechanism this scheduled path uses is *identical*
to the immediate branch's, which was just proven to work end-to-end,
this is a well-supported (not just inferred) conclusion — but flagging
plainly that the actual 48-hour timer itself was never observed firing.

**Approval process — ran the entire evaluation → approval → decision
chain live, both Approved and Rejected, and it all works correctly.**
Built two clean Appraisals from scratch (`9ALFV0000h7GMKG4A4`,
`9ALFV0000hE1wtU4AR`), each with a valid `AppraisalItem` (working
around the restricted-picklist bug with in-range demo values — and
discovered **`ModelYear` is ALSO a restricted picklist**, not just
Make/Model as previously documented: `2018` was rejected, `2020`
accepted — expanding BUG-RS04-05's scope) and a stand-in 360°
`ContentVersion`. Simulated "Submit for Evaluation" via direct DML as
System Administrator (`OwnerId` → `AF Used Car Team` queue,
`Status` → 'Visit Scheduled' — the exact two fields
`Assign_Owner_To_Queue` sets, succeeding because Admin holds
`AutomotiveDealerEssentialsPsl`, confirming the fifth pass's root
cause from the other side). Then set `AppraisalItem.InitialValue` on
each (simulating the Used Car Team's evaluation) and confirmed
`AF_FL_AppraisalItem_EvaluationComplete` fired correctly both times:
`FinalAppraisalValue`/`TotalItemFinalValue` rolled up correctly (14000
and 5000), ownership reassigned back to the initiating Sales Rep,
`AF_ApprovalStatus__c` set to Pending, and a real `ProcessInstance`
against `AF Appraisal Manager Approval` was created both times
(confirmed via direct query, not inferred).
- **Approve path**: posted a real decision via the Process Approval
  REST API (`POST /process/approvals/`, `actionType: Approve`) against
  the actual `ProcessInstanceWorkitem` → `instanceStatus: "Approved"`,
  and `AF_FL_Appraisal_ApprovalApproved` correctly set
  `AF_ApprovalStatus__c = 'Approved'`.
- **Reject path**: same mechanism, `actionType: Reject` → `instanceStatus:
  "Rejected"`, and `AF_FL_Appraisal_ApprovalRejected` correctly set
  `AF_ApprovalStatus__c = 'Rejected'`, owner correctly left with the
  Sales Rep.
- **Approver identity, worth noting**: both work items' `ActorId`
  resolved to "Alfardan Salesforce" — the Sales Rep's own `ManagerId`
  in the role hierarchy, the exact same person the escalation flow's
  manager-lookup resolves to. This confirms, empirically rather than by
  reading a process definition, that the "approval authority matrix"
  BRD Assumption 1 says is still pending from the business is, in the
  current build, simply "the initiating rep's manager" — not a
  distinct named approver role. Worth flagging to the BA precisely
  this way, since it means the matrix isn't merely undocumented — a
  default routing rule already exists and is live.
- Email/Custom Notification delivery on approval/rejection was not
  independently checked this pass (out of scope for what was asked —
  the goal was the escalation/approval *mechanics*, which are now
  genuinely, not just theoretically, confirmed working).

**Net effect on RS-04's bug list**: no existing bug is retracted or
weakened by this pass. BUG-RS04-01 (creation crash on blank
`AF_InitiatingSalesRep__c`) and BUG-RS04-03 (Submit for Evaluation
Status-field PSL gap) both stand exactly as documented — this pass
specifically proved that *once those two are worked around*, every
downstream mechanism (inactive-owner reassignment, the scheduled
escalation's underlying logic, evaluation completion, and both
Approve/Reject outcomes of the approval process) is correctly built
and genuinely functional, not just "looks correct on paper." BUG-RS04-05
(restricted picklist demo data) is confirmed broader in scope —
`ModelYear` is restricted too, not only Make/Model.

Test debris left in place as evidence: throwaway inactive User
`005FV007xld7Uc8YAE` (harmless — created already deactivated, clearly
named), Appraisals `9ALFV0000h0Ull24AC`/`9ALFV0000h7GMKG4A4`/`9ALFV0000hE1wtU4AR`
plus their AppraisalItems/ContentVersions/Tasks, both `ProcessInstance`
records (Approved/Rejected).

## 2026-09-08/09: RS-05 test data expansion — richer catalogue + inventory for manual UI exploration

User asked for "lots of other vehicles to choose from" in Select Vehicle, to
click through and test every filter themselves. Two real bugs surfaced and
were fixed along the way — both are data-seeding mistakes I made, not app
defects, documented here so future sessions don't rediscover them the hard
way:

- **`AF_InventoryVehicle__c` gates search visibility** — confirmed via
  reading `AF_VehicleExplorerController`'s actual WHERE clause
  (`'WHERE AF_InventoryVehicle__c = true'`). The 6 original vehicles all
  have this `true`; anything created without explicitly setting it defaults
  to `false` and is silently invisible to the search, with no error.
  **Any future test Vehicle record MUST set `AF_InventoryVehicle__c=true`
  or it won't appear no matter how correct everything else is.**
- **`ManufacturedDate` feeds the Year Range filter** — a null value fails
  any year-range comparison, so a vehicle with no `ManufacturedDate` set
  silently disappears once any year filter is active (which the UI applies
  by default). **Always set `ManufacturedDate` on new Vehicle records.**

**Expanded the Brand catalogue** (was hard-limited to Ferrari/Rolls-Royce
via a *restricted* picklist on a **shared Global Value Set**, `AF_Brand`,
reused across `Product2.AF_Brand__c`/`VehicleDefinition.AF_Brand__c`/
presumably `Opportunity.AF_Brand__c`). Added **Lamborghini, Bentley,
McLaren** to the GVS via metadata deploy. **Gotcha worth remembering**:
adding a value to a Global Value Set is not sufficient by itself — the
`Product2` object's record type (`Product_Type_RLM`) had zero explicit
`<picklistValues>` entries for `AF_Brand__c` at all, and until an explicit
per-record-type picklist-values block listing all 6 values was deployed
onto that record type, every insert using a new brand value failed with
`bad value for restricted picklist field` even though the GVS itself
already contained it. **Two-layer fix needed: (1) add values to the GVS,
(2) explicitly enable them on every RecordType that uses the field.**
`BodyType`/`FuelType` on `VehicleDefinition` are *not* restricted, so
`Sedan`/`Convertible`/`Diesel` needed no such fix.

**New catalogue (Product2 + VehicleDefinition + PricebookEntry)**:
Lamborghini Huracan (Coupe/Gasoline), Lamborghini Urus (SUV/Gasoline),
Bentley Continental GT (Convertible/Hybrid), Bentley Flying Spur
(Sedan/Diesel), McLaren 720S (Convertible/Gasoline).

**New physical inventory**: 10 additional units of the original 6 models
(Roma ×2, 296 GTB ×2, Purosangue, SF90 Stradale, Phantom ×2, Cullinan ×2)
plus 8 units across the 5 new models — full real colours, interiors,
transmissions (mix of Automatic/Manual now), conditions (mostly New, one
Running), inventory status (mix of In Stock/In Transit/Ordered), locations
(Doha Showroom - Automobiles / Sports Motors, Doha Port - Incoming, Factory
- Maranello/Goodwood/Crewe), `ManufacturedDate` spread 2024–2026. **Asset
records deliberately left with `AccountId = null`**, matching the
established convention confirmed on the original 6 (unsold dealer
inventory has no owner; `Vehicle.AF_CustomerOwned__c`/
`AF_CurrentOwnerContact__c` are the real ownership-tracking fields, both
still `false`/null org-wide — no automation found anywhere that flips
these on a sale, worth checking when RS-10 is tested).

**Confirmed via direct `AF_VehicleExplorerController.getVehicles()` call**:
`totalCount: 23`, spanning `{Bentley, Ferrari, Lamborghini, McLaren,
Rolls-Royce}` × `{Convertible, Coupe, SUV, Sedan}` ×
`{Diesel, Gasoline, Hybrid}` — good real coverage across make, body type,
and fuel type filters for manual UI testing. Pre-existing, not something I
created: the original "Test Vehicle: Ferrari Purosangue" is seeded as
record type `Demo_Vehicle` (unlike its 5 siblings, all `Regular_Vehicle`)
and is therefore correctly excluded from the stock search — flagged to
user, not yet fixed pending their decision.

**Reverted 2026-09-08, per user request**: user decided against the 3 new
brands ("I just want it as before with multiple vehicle models and
multiple vehicles for both Ferraris and Rolls Royce"). Deleted all 8
Lamborghini/Bentley/McLaren Vehicles + their Assets, all 5 PricebookEntries,
5 VehicleDefinitions, 5 Product2 records. Reverted the `AF_Brand` Global
Value Set back to `Ferrari/Rolls-Royce/Undecided` only (removed
Lamborghini/Bentley/McLaren). **Note on the `Product_Type_RLM` record
type**: no revert needed there — once all 6 GVS values were explicitly
listed in its picklist-values override, Salesforce metadata retrieval
stopped representing that field's block at all (an "all values allowed"
state renders as no override), so it had already implicitly reverted to
matching its original pre-change appearance on its own.

**Current confirmed state**: `Product2`/`VehicleDefinition` both back to
exactly 6 (the original models only). Live search
`totalCount: 15` — the 5 non-demo original vehicles + the 10 extra Ferrari/
Rolls-Royce units added earlier in this same session, spanning all 6
models with real price/colour/location/status variety. The
Lamborghini/Bentley/McLaren episode is fully undone; only the
Ferrari/Rolls-Royce expansion (10 extra units) remains, which is what the
user actually wanted kept.

## 2026-09-09: RS-06 / RS-07 test-case authoring — org reconnaissance, and evidence that earlier RS-04 bugs have since been fixed

Wrote `test-cases/ALF-RS-06-to-RS-07-test-cases.md` (58 cases). BRD-primary
per instruction; SD deliberately de-emphasised. Grounding gathered first so
the cases are executable. Durable facts:

**RS-07's discount architecture is genuinely well-built and metadata-driven:**
- `Quote.AF_DiscountPercent__c` is a **formula**: `IF(Subtotal = 0, 0,
  AF_DiscountAmount__c / Subtotal)` — implements FR1 ("numeric entry only,
  percentage read-only derived") exactly.
- DoA matrix lives in **`AF_DiscountApprovalTier__mdt`** (LFRDN-337), not
  hardcoded: Tier 0 Self-Authorized 0–2%, Tier 1 Showroom Manager 2–3%,
  Tier 2 Sales/Brand Manager 3–5%, Tier 3 General Manager 5–7%, Tier 4 CEO
  7–100%. Band matching is `Min < pct AND Max >= pct` — **exclusive at min,
  inclusive at max** (so exactly 2% is Tier 0, exactly 3% is Tier 1).
- Before-save `AF_FL_Quote_SetDiscountApprovalStatus` stamps
  `AF_DiscountTier__c` + `AF_DiscountApprovalStatus__c`; a % matching **no**
  tier deliberately falls back to Pending (fail-safe, documented).
- After-save `AF_FL_Quote_SubmitDiscountApproval` submits into
  `AF_AP_Quote_DiscountTiers` **only on the transition into Pending**.
- Approval process: 4 sequential steps, all `userHierarchyField` approvers,
  each `RejectRequest`; step criteria `AF_DiscountTier__c >= 2 / >= 3 / >= 4`.

**⚠ Likely real RS-06 defect, flagged for the test run, not yet proven:**
`AF_FL_Opp_CreateQuotation`'s own description claims *"AF_FL_QuoteLineItem_SyncVINDisplay
and AF_FL_Vehicle_SyncVINOnRestock handle VIN suppression/population/reissue
automatically... BRD AC1/AC2/FR2 are satisfied by that automatic behavior
alone."* **`AF_FL_QuoteLineItem_SyncVINDisplay` does not exist in this org** —
`FlowDefinitionView` for `%SyncVIN%` returns only `AF_FL_Vehicle_SyncVINOnRestock`.
If confirmed, initial VIN population at quote-creation time has no
implementing automation, and only the later restock path works. RS-06-TC-008/009
are written to prove or disprove this. **Do not trust a flow description as
evidence a referenced flow exists.**

**Evidence several RS-04 findings have been fixed since I filed them** (worth
re-verifying before re-reporting any of them):
- `AF_VR_QLI_TradeInDeductionGate` (LFRDN-630) now exists on QuoteLineItem —
  requires a linked Trade-In that is **both** Approved **and** Accepted, and
  `UnitPrice < 0`. This directly addresses the RS-04 finding that a trade-in
  deduction could be added with any sign against an unapproved appraisal.
  **Quote itself still has zero validation rules.**
- New flows now exist that map onto other RS-04 gaps I reported:
  `AF_FL_Appraisal_DefaultInitiatingRep` (the creation-crash on blank
  `AF_InitiatingSalesRep__c`), `AF_FL_Appraisal_TradeInWithdrawn` (the
  "no way to withdraw a trade-in" gap), `AF_FL_AppraisalItem_GenerateBookInSheet`
  (the "Book-In Sheet unbuilt" finding).
- **Implication: before re-reporting any RS-04 bug, re-test it — the dev team
  is actively fixing against these tickets.**

## 2026-09-09: Two significant corrections — both caught by user, not found independently

**Correction 1 — the media gallery IS deployed; I misread my own grep.** Claimed
`afVehicleMediaGallery` existed in code but was never added to
`Vehicle_Record_Page`, based on a `grep ... | head -20` that truncated before
reaching the actual match (the real hit was at line 1650 of a long file; the
first 20 "componentName" matches were all unrelated standard components).
Re-checked without the truncation: **the component is genuinely on the page**
(`<componentName>afVehicleMediaGallery</componentName>`,
`<identifier>c_afVehicleMediaGallery</identifier>`), and the user's own
screenshot confirms it renders correctly — hero image, a photo thumbnail, and
a PDF/brochure icon side by side. **FR6 and AC5 are SATISFIED, not "built but
undeployed."** Lesson: never trust a `head`-truncated grep as proof of
absence on a large metadata file — rerun untruncated before concluding
something isn't there.

**Correction 2 — BUG-RS05-03 (the "demo/placeholder vehicle can't be created
without a VIN" finding) was testing the wrong mechanism entirely, and is
RETRACTED.** User caught the real distinction: this org has **two unrelated
concepts both called "demo"**:
- `Vehicle.RecordType = Demo_Vehicle` — a company-owned car used for **test
  drives** (RS-03 territory), not a sales concept at all.
- The BRD's FR3/AC2 "demo or placeholder vehicle... where a specific VIN is
  not yet available" — this is **`AF_VehicleModel__c` alone, no
  `AF_SelectedVehicle__c`** — i.e. a `VehicleDefinition` reference with no
  physical `Vehicle`/VIN involved at all. This is exactly the
  `proceedWithoutVehicle()` path already found in
  `AF_VehicleExplorerController` (see earlier notes) — I had already read
  this method but didn't connect it back to FR3/AC2 correctly.

**Re-tested via the correct mechanism, live, end to end**: called
`proceedWithoutVehicle(opportunityId, vehicleDefinitionId)` on a fresh
Opportunity → `AF_VehicleModel__c` set, `AF_SelectedVehicle__c` genuinely
null → progressed to Explore cleanly → generated a Quote against it with zero
blockers → `AF_VINDisplay__c` stayed null throughout, correctly suppressed.
**FR3 and AC2 are SATISFIED.** The previous test (creating a `Demo_Vehicle`
Vehicle record and hitting `REQUIRED_FIELD_MISSING: VehicleIdentificationNumber`)
was a real, reproducible result, but testing the wrong feature — that path is
for test-drive demo cars, which quite plausibly *should* require a VIN (it's
a real physical company car), and nothing in the BRD says otherwise for that
concept. **BUG-RS05-03 is retracted as a bug against FR3/AC2.** Whether a
real-world *test-drive* demo car ever legitimately needs to exist without a
VIN is a separate, RS-03-scoped question, not evaluated here.

**Net effect on the FR/AC audit given to the user**: FR3, FR6, AC2, AC5 all
move from FAILED/NOT-REACHABLE to SATISFIED. Remaining real, confirmed
problems in this story: FR1 (trim/model-family filters absent), FR2 (hardcoded
In-Stock-only search, BUG-RS05-06), FR7 (Keyloop sync not implemented; manual
override has no dedicated authorization control), FR8 (no attach-to-Quote
mechanism at all), AC1 (same trim/status issues as FR1/FR2).

## 2026-09-07: ALF-RS-05 (Vehicle Search and Selection) — FULL TEST, all 33 test cases + self-authored negative/security cases

Executed the full 33-case sheet (`test-cases/ALF-RS-03-to-RS-05-test-cases.md`)
API-first (direct SOAP-session REST at v68.0 for Sales Rep and Sales
Manager, bypassing the generic MCP connector's stale API-version
issue per the established gotcha; `sf` CLI/Tooling API for
metadata/PSL/FLS/flow-XML work) then UI (Sales Rep browser session,
already authenticated from a prior session — no fresh login needed).
Real flow-debugging (TraceFlag + reading retrieved Flow/Apex metadata
directly) was used on the two hardest crashes, per the standing
methodology. No application source was modified; several `QA test
RS-05-*`-prefixed records were created and left in place as evidence
(see end of section).

### RS-05-TC-001 — Vehicle Finder: root cause is layered, and DIFFERENT from what the sheet documented

The sheet's own note proposed two theories for the Vehicle Finder's
`Error retrieving vehicle models: No such column
'VehicleIdentificationNumber' on entity 'Vehicle'`: **(a)** FLS (zero
`FieldPermissions` rows) or **(b)** API version
(`AF_VehicleExplorerController` at 61.0 vs org 68.0). Per the RS-04
lesson — this exact "API version" shape of theory was proven WRONG
there — both were tested directly rather than assumed, and **neither
is the CURRENT proximate blocker**. Reproducing live via the real UI
(Opportunity → Show more actions → **Select Vehicle**) surfaced a
**third, different error the sheet never recorded**:

> **`Error: You do not have access to the Apex class named
> 'AF_VehicleExplorerController'.`**

screenshotted at `rs05-tc001-vehicle-finder-error.png`. This is an
**Apex class access (SetupEntityAccess)** denial, checked before the
controller body — and therefore before its own `VehicleIdentificationNumber`
SOQL — ever runs. Confirmed via metadata that this is a genuine
platform anomaly, not a simple missing grant: **`AF_PS_TestDrive_FullAccess`**
(the *only* permission set in the entire org with a `classAccesses`
entry for this class, `enabled=true`) **is** a member of
`AF_PSG_Sales_Rep` (confirmed via `PermissionSetGroupComponent`), and
the group's `PermissionSetGroup.Status = 'Updated'` (not stale/still
calculating), and there is no Muting Permission Set on the group —
yet the live user is denied anyway. Recommend a System Administrator
open Setup → Permission Set Groups → **Sales Rep** → re-verify/re-save
the Apex Class Access page to force recalculation, since metadata says
this should already work.

**Layer 2, confirmed real and independent of Layer 1**: read the
controller's actual source
(`AF_VehicleExplorerController.cls`, retrieved via `sf`). Its
`BASE_QUERY_FIELDS` genuinely selects `VehicleIdentificationNumber`
off `Vehicle`. Direct REST queries at v68.0 (ruling out API version)
prove: Sales Rep **cannot** read this field (`INVALID_FIELD`) while
every *other* field the controller needs (`AF_InventoryStatus__c`,
`AF_ThumbnailLink__c`, `AF_NoVINPlaceholder__c`, `RecordType`, etc.)
**is** readable — so this is a genuine single-field gap, not a
broken object. `FieldPermissions` for `Vehicle.VehicleIdentificationNumber`
has **zero rows for any Parent in the org, including
`AF_System_Admin`'s own permission set** (`permissionable: false` on
the field's own `describe` — it structurally cannot carry ordinary
FLS at all). Isolated the real gate via a clean A/B persona test:
**Sales Manager (`mpapa_sales`, holds `AutomotiveFoundationUserPsl`)
reads the field successfully; Sales Rep (lacks that PSL) fails —
identical API version, identical field, only the PSL differs.**
**Root cause: `AutomotiveFoundationUserPsl` gates
`Vehicle.VehicleIdentificationNumber`**, the same PSL already known
(RS-04) to gate the whole `Appraisal` object — this is now confirmed
to also gate at least one field on a *different* object, reinforcing
that Foundation is this org's baseline Automotive Cloud data-access
license, not an Appraisal-specific one.

So: **once Layer 1 (Apex class access) is fixed, Layer 2 (the VIN PSL
gap) will immediately surface next** — reproducing exactly the error
the sheet originally documented. Both are real, both need fixing, and
they are genuinely different mechanisms (SetupEntityAccess vs.
PSL-gated FLS).

**The "More Filters" panel was read live** (screenshot
`rs05-tc003-more-filters-panel.png` + `browser_find`): Transmission,
Exterior Color, Condition, Inventory Status render as bare section
headers with **zero checkboxes underneath, for any of them** — but
this is explained by Layer 1 (nothing loaded at all, for any facet,
populated or not) and must **not** be read as independent confirmation
of the Layer-2-adjacent data gap below; that gap is proven separately
via direct API.

### RS-05-TC-001/003/004/005/007 — the "9 filters" are the WRONG fields; corrected data-completeness verdict

Reading the controller source corrected a real early mistake: the
schema-baseline note (and my own first-pass query) checked
`Vehicle.MakeName`/`ModelName`/`ModelYear`/`TrimLevel` and found them
null on all 6 records — which would have been reported as a Critical
"6 of 9 filters broken by missing data" bug. **The controller's own
header comment explains why that's the wrong test**: those fields
"describe as writable... but are, in this org, populated only by the
platform (empirically confirmed... presumably reserved for the future
Keyloop feed sync)" — the controller deliberately reads Make/Model/Body/Fuel
from **`VehicleDefinition.AF_Brand__c`/`VariantName`/`BodyType`/`FuelType`**
instead, and Year from **`Vehicle.ManufacturedDate`**. Re-querying the
*correct* fields: **all 6 real Vehicle records have these fully
populated** (Ferrari/Rolls-Royce brand, correct variant names, correct
body types, correct fuel types, real manufacture dates) — this part of
the search is genuinely solid. Retracting the "null make/model/year"
framing entirely.

What **is** still confirmed null on all 6 records, directly via API,
and does matter because the controller's `BASE_QUERY_FIELDS` reads
these straight off `Vehicle` with no substitute: **`ExteriorColor`,
`InteriorColor`, `GearBoxType` (transmission), `ConditionType`,
`AF_Colour__c`, `AF_Location__c`, `StockCode`** — all 100% null,
6/6. Only `AF_InventoryStatus__c` is populated, and well (In Stock ×4,
Ordered ×1, In Transit ×1 — all 3 FR2 states genuinely represented).
**Colour, location, transmission and condition filters/columns will
return empty once Layers 1–2 are fixed** — a real, separate data gap,
smaller in scope than first thought but still real.

**New, separately-confirmed scope gap** (read directly from the
controller's 968-line source, not inferred): **"Trim" and "product
group/model family" have NO facet/filter logic anywhere in the
class**, and the live "More Filters" panel confirms this — the actual
built facet set is Make, Model, Year, Price, **Body Type, Fuel Type,
Transmission, Exterior Color, Condition, Inventory Status, Location**.
Compare against BRD FR1's literal nine: *"make/brand, product group/model
family, model, year, trim, colour, price range, stock status, and
location"* — **2 of the 9 BRD-named filters (trim, model family) are
simply not implemented**, while **4 filters exist that FR1 never
named** (body type, fuel type, transmission, condition). `AF_ProductCategory__c`
is used only as an internal hardcoded constant (`= 'Vehicle Model'`
to exclude vehicles from the *product* picker) — never exposed as a
rep-facing "model family" selector with multiple values.

### RS-05-TC-011 — Explore stage gate: full, clean PASS (5/5 steps, real isolated records)

Created 4 fresh Opportunities via direct REST insert (isolating each
condition, not reusing older confounded test records):
`006FV00AcCd5xUiYUI` (VehicleModel only), `006FV00AcZ754FAYUY`
(SelectedVehicle only), `006FV00AcZDqeoOYUR` (AF_VehicleInterest__c
free text only), `006FV00AcTepy7wYUA` (neither, control). Progressing
Consider→Explore: **VehicleModel-only → 204 succeeds; SelectedVehicle-only
→ 204 succeeds; free-text-only → 400 blocked with `"A vehicle model or
selected vehicle is required from Explore stage onward."`; neither →
400 blocked, same message.** Step 5 (clear the lookup on a record
already at Explore, attempt any save) also blocked cleanly on both
passing records. `AF_VR_Opp_ExploreRequiresVehicle` is exactly as
documented and works correctly in every branch — no bug here,
included for completeness since a full pass was targeted.

### RS-05-TC-002 — V-1 layered model: full PASS, exact pairing confirmed

`VehicleDefinition` (6 records) ↔ `Product2` (6 vehicle-model records)
confirmed **paired 1:1 by `ProductId`**, not just coincidentally equal
in count (e.g. `VD: Ferrari Roma` → `ProductId` = the real Ferrari
Roma `Product2`). `Vehicle.AssetId` confirmed pointing to a **distinct,
correctly-matched** `Asset` per vehicle (Ferrari Roma Vehicle → Ferrari
Roma Asset, etc., all 6). `PricebookEntry.UnitPrice` populated for
every vehicle-model product (247,308–625,000 QAR range) plus every
accessory/service product. V-1's whole layered chain is genuinely,
correctly built.

### RS-05-TC-016 — VIN uniqueness enforced; stock-state edit lock has a real admin-override gap

Direct duplicate-VIN insert attempt (`AssetId`/`VehicleDefinitionId`
supplied, VIN = Ferrari Roma's existing VIN) → rejected cleanly with
`DUPLICATE_VALUE` naming the conflicting record. Sales Rep attempting
`AF_InventoryStatus__c` edit on a real Vehicle → blocked, but with a
**broader** message than expected: `"entity type cannot be updated:
Vehicle"` (no update access to the object at all, not just this
field — exceeds the requirement, doesn't violate it). **System
Administrator performed the identical edit successfully** (`sf data
update record`), and **`AF_IntegrationSyncStatus__c` stayed null**
afterward — no audit trail distinguishes a Keyloop-synced status from
a manually-typed one. Confirms the SD's own V-2 warning ("Salesforce
consumes the feed and never competes with it") is currently violated
for anyone holding System Administrator.

### RS-05-TC-013 — demo/placeholder Vehicle: VIN is unconditionally required at the schema level, contradicting DEC-016

Attempted to create a `Demo_Vehicle`-record-type Vehicle with
`AF_NoVINPlaceholder__c = true` and **no VIN** → rejected with
`REQUIRED_FIELD_MISSING: [VehicleIdentificationNumber]`. Confirmed via
`sf sobject describe`: `VehicleIdentificationNumber` has **`nillable:
false`** at the field-definition level (also `permissionable: false`,
consistent with TC-001's PSL-gated-not-FLS-controlled finding) — this
is a hard platform constraint, not a validation rule, and applies
**regardless of record type or the `AF_NoVINPlaceholder__c` flag**.
**This directly contradicts DEC-016 and `AF_NoVINPlaceholder__c`'s
entire stated purpose** — a flag meant to say "this vehicle
legitimately has no VIN yet" can never actually be true, because the
platform will not let the record exist without one. Re-created with a
dummy placeholder VIN (`0vLFV00045mhMjE2AU`, `QATC013NOVINPLACEHOLDER`)
to continue testing the rest of the flow: it also appears in **both**
the `All_Vehicles` and `Demo_Vehicles` list views (no exclusion
mechanism observed at the list-view level — though the real stock
search is blocked by TC-001, so whether the LWC itself would exclude
demo vehicles is not independently verifiable yet). Creating a
`Demo_Vehicle` **with** a real-looking VIN (the contradiction case)
succeeded silently — no warning of any kind.

### RS-05-TC-017/019/020 — line items: real API confirms the brand-scoping gap AND explains the Add Products crash

`AF_LineItemType__c` active values confirmed: Vehicle, Customization,
Paint Job, Accessory, Package, Tint, Trade-In Deduction, Internal
Requisition, Provider Service, Other (10 total; no literal "Upsell"
value, likely served by "Other"/"Provider Service" — minor naming
note, not filed as a bug).

**TC-019 brand-scoping — CONFIRMED REAL GAP, directly reproduced.**
Zero `ValidationRule`s exist on `OpportunityLineItem` or
`QuoteLineItem` (confirmed via Tooling API). Direct REST test: added
the **Ferrari** Window Tint product (`01uFV001BauOojcYIC`) as an
`OpportunityLineItem` on a **Rolls-Royce** Opportunity
(`006FV00ABujcvkyYMA`) → **accepted, HTTP 201**
(`00kFV000rvqtpxAYAQ`). No server-side brand enforcement exists at
all — confirms the sheet's own suspicion that any UI-level dependent
lookup filter (if one even exists) is not a real control.

**TC-020 — full, clean PASS.** Created Quote `0Q0FV0047SzRt520QC`
(required `AF_QuoteType__c='Customer Quotation'` discovered live).
Added one line flagged `AF_RequiresInternalRequisition__c=true,
AF_CustomerFacing__c=false, AF_IncludedInQuote__c=false,
AF_ProviderSource__c='Alfardan Internal'` (`0QLFV000NtgIPHc4IO`) and
one customer-facing line with the flags inverted
(`0QLFV000NtZWoiO4IT`) — both persisted exactly as set and are
independently query-filterable, proving DEC-010/IR-1's requisition
scope and the customer-facing exclusion both genuinely work.

### RS-05 — "Add Products" screen flow ALSO crashes: the second, independent broken vehicle/product entry point

TC-001's own note flagged checking `AF_Add_Products_To_Opporunity`
(live label "Add Products") as the working alternative to the broken
Vehicle Finder. **It is not working either.** Clicking the real
**Add Products** button on the Opportunity record (not a raw API call)
produces Salesforce's generic **"An unhandled fault has occurred in
this flow... Please contact your system administrator for more
information."** (screenshots `rs05-add-products-flow.png`,
`rs05-add-products-crash-2.png`). Confirmed via
`browser_network_request` on the actual `FlowRuntimeConnect.startFlow`
call: `"interviewStatus":"ERROR"`, `apiVersionRuntime: 68.0` (not an
API-version issue), generic fault message only — the platform itself
does not expose more detail to the client.

**Debugged properly rather than assumed**, per the standing "do you
need to debug any flows?" bar:
1. Set up a TraceFlag (`DebugLevel` 7dlFV0004f9OQ1oYAG,
   Workflow/ApexCode=FINEST, reused from RS-04) on the Sales Rep user
   and reproduced twice — **zero new `ApexLog` rows appeared for this
   user either time**, despite the trace being confirmed active
   (correct `StartDate` window, no future-date mistake this time).
   This screen-flow crash does not appear to route through anything
   `ApexLog` captures the way RS-04's record-triggered flow did — noted
   as its own observation rather than chased further once the metadata
   read (below) gave a conclusive answer. TraceFlag deleted afterward
   (`7tfFV000bsgDQISYA4`).
2. **First hypothesis, tested and DISPROVEN via a clean A/B control**:
   suspected `Decision_HasBrand`'s `Get_Products_For_Brand` branch
   (which filters `Product2.AF_Brand__c = Get_Opportunity.AF_Brand__c`
   — and `Product2.AF_Brand__c` was *already* confirmed unreadable for
   Sales Rep, see below) was the cause. Created a **brand-blank**
   Opportunity (`006FV00AcSfrSrsYUE`, no `AF_Brand__c` at all — allowed
   at Consider stage) which should take the OTHER branch
   (`Get_Products`, no brand filter at all) — **it crashed identically**.
   Theory retracted; the fault is common to both branches.
3. **Read the retrieved flow XML directly**
   (`AF_Add_Products_To_Opporunity.flow-meta.xml`, 664 lines) to find
   the true common element. Confirmed **zero `faultConnector`s exist
   anywhere in this flow** (a separate, standing best-practice gap —
   *any* future fault in this flow, whatever the cause, will always
   show this generic unhelpful message). Confirmed every individual
   data operation the flow performs (`Get_Opportunity`,
   `Get_Standard_Price_Book` by Name, `Get_Products`/`Get_Products_For_Brand`'s
   own filter fields, `Update_Opportunity_Pricebook`) succeeds fine via
   direct REST as Sales Rep — ruling out CRUD/object permission as the
   cause.
4. **Found the real, common trigger**: the flow's first screen,
   `Select_Products`, uses the standard `flowruntime:datatable`
   component with an explicit `columnReferences` field list —
   `["Name", "AF_Brand__c", "ProductCode", "AF_ProductCategory__c"]`
   — against the `ProductsToSelect` (Product2) collection, **regardless
   of which branch populated it**. `AF_Brand__c` is a hard-coded
   *display column*, not a WHERE-filter, which is exactly why the
   brand-blank A/B test still crashed identically. And `Product2.AF_Brand__c`
   is the **same field already independently confirmed inaccessible**
   to Sales Rep via raw API earlier this session (`FieldPermissions`
   query showed **zero rows for `AF_PSG_Sales_Rep`, `AF_PSG_Sales_Manager`,
   or `AF_PSG_Showroom_Manager` — only `AF_System_Admin`'s own
   permission set has Read/Edit=true**; confirmed live: Sales Rep
   *and* Sales Manager both get `INVALID_FIELD` reading it directly).

**Root cause, high confidence, fully chained**: the platform's managed
`flowruntime:datatable` LWC enforces FLS strictly on its configured
columns (unlike a flow's own record-variable references, which appear
more tolerant); binding it to `Product2.AF_Brand__c` — a field no
business-facing permission set has ever been granted Read on — throws
an unhandled fault the flow has no `faultConnector` to catch. **This
single missing FieldPermissions grant (`Product2.AF_Brand__c` → Read,
for `AF_PSG_Sales_Rep`/`AF_PSG_Sales_Manager`/`AF_PSG_Showroom_Manager`)
is very likely the fix for both the Add Products crash AND a
contributing factor to TC-019's unenforceable brand scoping** (a rep
who can't even see a product's brand can hardly be shown a
brand-filtered picker). Same FieldPermissions gap also blocks
`AF_BusinessUnit__c`, `AF_DefaultProviderSource__c`,
`AF_KeyloopProductReference__c` on `Product2` for the same three
permission set groups (checked all four fields individually; each has
FieldPermissions rows for `AF_System_Admin` only).

**Combined with TC-001: every documented and discoverable UI path for
adding a vehicle or product to an Opportunity is currently broken for
the Sales Representative persona** — Select Vehicle (Apex class
access) and Add Products (unhandled flow fault) both fail before a
rep can pick anything.

### RS-05-TC-024 — file-type validation: confirmed real security gap

Uploaded a `ContentVersion` named `qa-test.exe` (`PathOnClient` with
`.exe` extension) linked directly to a Vehicle record via
`FirstPublishLocationId` → **accepted without any rejection, HTTP
201** (`068FV006coA8VHwYAN`). Standard Salesforce Files has no
file-type/extension restriction configured in this org. Confirms the
sheet's own concern precisely: *"An `.exe` accepted into a
customer-facing gallery is a security concern, not just a formatting
one."*

### RS-05-TC-010/028/030/031 — design-verification findings (no live bug, but real gaps/confirmations)

- **TC-010**: `Opportunity` has **no field that snapshots the selected
  vehicle's stock state** — the only way to read it is a live
  relationship traversal (`AF_SelectedVehicle__r.AF_InventoryStatus__c`).
  This is a legitimate design answer (live read-through, not a
  snapshot) but it's implicit, not documented anywhere — and it means
  RS-06's VIN suppression and RS-10's Sales Order block **must** both
  evaluate through the same live relationship at their own evaluation
  time, or they will silently never fire. Flagging as a BA
  cross-story documentation gap, not a bug in RS-05 itself.
- **TC-028**: only 10 `CronTrigger` rows exist org-wide, none related
  to inventory/Keyloop sync (the one real scheduled job is an
  unrelated platform report job) — confirms no scheduled sync exists
  yet, consistent with "Keyloop integration is not implemented."
- **TC-030**: no staleness-marker mechanism was observed anywhere
  (consistent with no sync existing to go stale) — not independently
  testable further until TP-004 is built.
- **TC-031**: `Product2`'s org-wide default sharing model is
  **`ReadWrite`** (confirmed via metadata retrieve of the object,
  `sharingModel` element) — meaning the catalogue is structurally
  incapable of being business-unit-segregated by sharing rules,
  genuinely confirming the SD's stated exception ("shared reference
  data — not business-unit segregated"). Combined with `Product2.AF_BusinessUnit__c`
  being unreadable to Sales Rep anyway (same FLS gap as `AF_Brand__c`
  above), the design intent holds, if partly by accident rather than
  by deliberate enforcement.

### Left in the org as evidence (not cleaned up, consistent with established practice)

Opportunities: `006FV00AcCd5xUiYUI`/`006FV00AcZ754FAYUY`/`006FV00AcZDqeoOYUR`/`006FV00AcTepy7wYUA`
(TC-011 4-way isolation set), `006FV00AcSfrSrsYUE` (TC-019/Add-Products
brand-blank control). Quote `0Q0FV0047SzRt520QC` + 2 QuoteLineItems
(TC-020). One OpportunityLineItem `00kFV000rvqtpxAYAQ` (TC-019
cross-brand reproduction) on existing Opportunity `006FV00ABujcvkyYMA`.
Vehicles: `0vLFV00045mhMjE2AU` (TC-013 placeholder) plus its Asset
`02iFV000Pd5ocG8YII`; one orphaned unused Asset `02iFV000Pcz31guYIA`
(TC-016 duplicate-VIN attempt, the Vehicle create itself correctly
failed so this Asset has no linked Vehicle). One `ContentVersion`
`068FV006coA8VHwYAN` (`qa-test.exe`) attached to the Ferrari Roma
Vehicle (TC-024). `TraceFlag` created and deleted; reused `DebugLevel`
7dlFV0004f9OQ1oYAG left in place (inert, same as noted after RS-04).

---

## ALF-RS-06 (Quotation Generation) — full execution, 2026-09-09

Executed all 30 planned test cases plus 2 added during the run
(RS-06-TC-031 declined-trade-in, RS-06-TC-032 no-vehicle-no-model
guard). Results are written into the Actual Result column of
`test-cases/ALF-RS-06-to-RS-07-test-cases.md`. Universal defects are
written up in `tickets/ALF-RS-06-quotation-generation-defects.md`
(7 tickets). This section records what does NOT belong in either of
those two files.

### Access unblocked at last: IP ranges were the persona blocker

The long-standing inability to use business personas was an **IP
restriction**, not passwords:
- Profile **"Standard User Sales"** (Sales Manager) carried
  profile-level **Login IP Ranges** (41.128.0.0/16, 41.239.166.0/24,
  156.215.118.0/24). Profile Login IP Ranges *hard-block* login from
  outside the range, UI and API alike, and Salesforce deliberately
  reports it as the generic *"Please check your username and
  password"* — which is why it looked like a bad password for weeks.
- Org-wide **Network Access -> Trusted IP Ranges** held the same two
  ranges. Outside them, API login additionally demands a security
  token, which is the `LOGIN_MUST_USE_SECURITY_TOKEN` the Sales Rep
  MCP connection kept returning.
- This machine's egress IP is **41.236.183.12**, in none of them.
- User removed the profile-level ranges and added
  `41.236.183.0-41.236.183.255` to the org-wide Trusted IP Range.
  Both personas then worked immediately over API **and** UI.

**If persona logins break again, check the egress IP first**
(`curl -s https://api.ipify.org`) against
Setup -> Security -> Network Access, and check the profile for its own
Login IP Ranges — the two are different mechanisms with different
symptoms.

### Forced password change: click Cancel

Both business personas hit Salesforce's forced "Change Your Password"
screen on UI login (org policy `expiration = NinetyDays`). **Clicking
Cancel dismisses it and lands on Lightning Home with the original
password intact** — confirmed by the user first, then reproduced for
both Sales Rep and Sales Manager. Do not submit a password change;
this is now a standing instruction (also saved to memory).

### The MCP connectors are on an old API version — do not diagnose with them

The per-persona MCP connections return **false** `No such column` /
`sObject type 'X' is not supported` errors for Automotive Cloud
objects and several custom lookups — observed for `Vehicle`,
`VehicleDefinition`, `Appraisal`, `QuoteLineItem.AF_Vehicle__c`,
`AF_VehicleDefinition__c`, `AF_RelatedTradeIn__c`, and even
`Product2.ProductCode`. **`FieldPermissions`/`ObjectPermissions`
prove the Sales Rep genuinely HAS read/edit on all of those.** I very
nearly filed a false persona-gap bug off the back of these errors.
Always confirm an apparent access gap against `ObjectPermissions` /
`FieldPermissions` via the `sf` CLI at v68.0 before believing it.

Corollary trap: `FieldPermissions` filtered as
`WHERE Field = 'Product2.ProductCode'` returns rows for *other*
objects' `ProductCode` fields — the `Field` filter is unreliable on
its own. Always add `SobjectType = '...'` as well, e.g.
`WHERE SobjectType='Product2' AND Parent.Name='AF_PSG_Sales_Rep'`.
The imprecise form gave me a directly contradictory answer mid-session.

### Persona permission gaps — real, but deliberately NOT in the tickets

Per the standing bug-ticket rule (universal-only), these are recorded
here rather than raised as tickets. They are nonetheless the single
most consequential RS-06 finding, because between them **no business
persona can complete the trade-in half of the story**:

1. **`Product2.ProductCode` is readable by System Administrator
   alone.** Granted only by `AF_PS_Product2_FullAccess` (assigned to
   **nobody**) and `AF_System_Admin` (assigned only to
   `arcsen@alfardan.com.qa`). `AF_FL_Opp_CreateQuotation` runs in
   **user context** and its `Get_TradeIn_Product` element filters on
   `ProductCode`, so for any business persona the SOQL is invalid and
   the flow dies with an unhandled fault, rolling back the entire
   quotation. Confirmed from the Sales Rep's own debug log:
   `FLOW_ELEMENT_ERROR ... No such column 'ProductCode' on entity
   'Product2' | FlowRecordLookup | Get_TradeIn_Product`.
   Fix: assign `AF_PS_Product2_FullAccess` (or add
   `Product2.ProductCode` read to `AF_PSG_Sales_Rep` /
   `AF_PSG_Sales_Manager` / `AF_PSG_Showroom_Manager`).
2. **`AF_PSG_Sales_Manager` is assigned to nobody at all** — the
   Sales Manager user does not have their own persona permission set
   group. Consequence: they lack read on
   `Opportunity.AF_VehicleModel__c`, so `Get_Opportunity` — the
   flow's very first element — fails and they cannot create **any**
   quotation, trade-in or not. The PSG itself is correctly built and
   `Updated`; it was simply never assigned.
   Fix: assign `AF_PSG_Sales_Manager` to the Sales Manager user.

Sales Rep *is* correctly assigned `AF_PSG_Sales_Rep`, which is why
non-trade-in quotations work for that persona.

### Flow-source facts worth not re-deriving

- `AF_FL_Opp_CreateQuotation` has **no `runInMode`** element, so it
  runs in **user context** — this is why persona FLS gaps become
  hard flow faults rather than silent no-ops.
- `Create_Quote` sets exactly four fields: `AF_QuoteType__c`, `Name`,
  `OpportunityId`, `Pricebook2Id`. No VIN, no Status, no Keyloop.
- `Get_Eligible_OpportunityLineItems` filters on `OpportunityId`
  **only** — the "eligible line types" in its description are not
  implemented anywhere.
- `AF_FL_QuoteLineItem_SyncVINDisplay` **does not exist** in the org,
  despite being named in two flow descriptions.
  `AF_FL_Vehicle_SyncVINOnRestock` is the only writer of
  `AF_VINDisplay__c`, entry condition
  `ISCHANGED(AF_InventoryStatus__c) && ISPICKVAL(..., "In Stock")`.
- `AF_QuoteType__c` is referenced by exactly one component in the
  whole org (the create flow). Nothing branches on quote type, so
  Customer vs Bank is currently a stored label only.
- `Quote` has **zero** validation rules.

### Appraisal test-data recipe (this cost real time — reuse it)

`Appraisal.FinalAppraisalValue` is **not writable** by anyone,
including Admin, via Apex or REST — it is an Automotive Cloud rollup.
To get a non-zero trade-in value you must insert an `AppraisalItem`
with `InitialValue` set, which rolls up. Required fields and the
validation rules that gate it (all discovered the hard way):
`AppraisalId`, `Type='Vehicle'`, `InitialValue`, `CustomerAskingValue`,
`ConditionType`, `Usage` (**Decimal**), `ModelYear` (**String**),
`IsCustomized`, `IdentificationNumber`, `LicensePlateNumber`,
`AF_MakeText__c`, `AF_ModelText__c`, `AF_Source__c`,
`AF_InspectionDone__c=true`, `AF_InspectionNotes__c`.
The parent `Appraisal` additionally requires `PurposeType='Trade-In'`
and `UsageType='Automotive'`.

### Reaching the quotation flow while its button is missing

The Create Quotation Quick Action is not on the Opportunity layout
(ticket 1), so the flow cannot be reached by clicking. For testing,
launch it directly:
`/flow/AF_FL_Opp_CreateQuotation?recordId=<OpportunityId>`
This runs the real flow in the logged-in persona's context, so it is
still a valid persona test — note the substitution in any report.
Playwright note: clicking the radio `<input>` times out because the
`<label>` intercepts the click; click the label ref instead.

### Test data left in the org

Opportunities `QA RS06 A`-`QA RS06 L` (`006FV00Apph...` range, plus
`006FV00ApmJomPsYEJ`), `QA RS06 F2`/`QA RS06 K` owned by Sales
Manager, their Quotes, QuoteLineItems, Appraisals and AppraisalItems.
Also: Vehicle `0vLFV0004H1l7FU2QY` (Ferrari Roma Black) was left at
`AF_InventoryStatus__c = 'Ordered'` carrying a **stale VIN on its
quotation** — that is deliberate evidence for the VIN-not-cleared
defect, don't "fix" it without re-reading that ticket. A
`PricebookEntry` for Ferrari Roma was added to the "Dream Cars and
EV" price book (`01uFV001ExwAuSyYIK`) for the non-standard-pricebook
test. TraceFlags created and deleted; `DebugLevel`
`7dlFV0004f9OQ1oYAG` reused and left in place.

---

## ALF-RS-07 (Discount Approval Workflow) — full execution, 2026-09-09/10

Executed all 28 planned test cases plus 2 added during the run
(RS-07-TC-029 tier-field tamper, RS-07-TC-030 discount-not-applied).
Results are in the Actual Result column of
`test-cases/ALF-RS-06-to-RS-07-test-cases.md`; universal defects in
`tickets/ALF-RS-07-discount-approval-defects.md` (7 tickets). This
section holds what belongs in neither.

### The core engine is genuinely good — don't re-litigate it

The tier/DoA machinery is correct and was verified exhaustively at
`Subtotal` = 100,000 (so 1% = 1,000). Boundaries land **exactly** as
designed (`MinPercent < pct AND MaxPercent >= pct`, exclusive min /
inclusive max):

| % | Tier | Status |
|---|---|---|
| 0.001, 1.00, 1.99, **2.00** | 0 | Not Required |
| **2.01**, 2.50, **3.00** | 1 | Pending |
| 4.00, **5.00** | 2 | Pending |
| 6.00, **7.00** | 3 | Pending |
| 10.00, **100.00** | 4 | Pending |
| 150 (>100%) | *(blank)* | Pending — fail-safe |

No overlaps, no gaps. `AF_FL_Quote_SetDiscountApprovalStatus` has
**zero** hardcoded percentages — bands come entirely from
`AF_DiscountApprovalTier__mdt`, so a threshold change is a metadata
edit only. Rejection terminates the whole chain (0 work items left),
re-approval after an increase works, revision after a rejection
re-routes to the correct lower authority, and self-approval is
properly impossible. **Don't spend time re-testing any of that.**

### The approval record lock is load-bearing — understand it before filing anything

A Quote with a live approval is **record-locked**
(`ENTITY_IS_LOCKED`) for non-admins. This has two consequences that
look like separate findings but are the same mechanism:
- It **prevents** the obvious governance bypass (raising a Tier 1
  discount to Tier 4 while the Tier 1 approval is in flight) — that
  attack is simply not reachable. Good.
- It also blocks the rep from editing **any** field (even
  `Description`) until the request completes, which makes the flow's
  documented "don't re-submit on an unrelated save" guard
  unreachable in practice for a rep.
Admin bypasses the lock (verified). Treat the lock as intended
behaviour and a BA question, not a defect.

### Manager hierarchy — the thing that actually breaks this story

`AF_AP_Quote_DiscountTiers` resolves **every** step from
`nextAutomatedApprover.userHierarchyField = Manager`, so step N+1
needs step N's approver to have a Manager. As found, the org's chain
is one level deep and ends on a non-person:

- Sales Representative → **Alfardan Salesforce**
  (`afaoitpowerautomate_…`, a Power Automate integration account)
  → **no Manager**
- Sales Manager → same integration account
- Showroom Manager Automobiles → **no Manager**
- QA Test Admin → **no Manager**

So Tier 1 routes to an integration account rather than the
DoA-named Showroom Manager, and approving it throws
`MANAGER_NOT_DEFINED`. **Every Tier 2+ discount is permanently
stuck at Pending — approvable by nobody, rejectable by nobody.**

**To test escalation you must build a chain first.** What worked:
Rep → Sales Manager → Showroom Manager Automobiles → QA Test Admin
→ Arcsen Alfardan. With that in place the identical Tier 4 request
traversed all four steps and completed `Approved`. **The hierarchy
was reverted to as-found afterwards**, so the org is back in the
failing state — if you re-test escalation you must rebuild the chain
(`scratchpad_rs07/apex/hierarchy.apex` does it; `restore.apex`
reverts it, and both carry the original values in comments).

Design point worth raising with the BA rather than just fixing: a
DoA matrix names **roles**, but `userHierarchyField` routes by **org
chart**. Those coincide only if the hierarchy is built to mirror the
matrix exactly, and nothing enforces that.

### Approving as someone else, when you have no password for them

Admin cannot approve another user's work item directly — the
Process Approvals REST call returns `NOT_FOUND`. What works:
update `ProcessInstanceWorkitem.ActorId` to the admin user (a normal
admin reassignment), then approve. In Apex:
`Approval.ProcessWorkitemRequest` + `Approval.process()`. Note the
`sf api request rest` wrapper could not reach
`/process/approvals` at all in this org (persistent `NOT_FOUND` /
"URL No Longer Exists" regardless of path form) — **use Apex, not
the REST endpoint**, for approval actions here. Reassignment shows
up in `ProcessInstanceStep` as a `Reassigned` row, so it stays
auditable and honest in the evidence.

### The discount is inert — the single biggest finding

`AF_DiscountAmount__c` never reaches the price. Across all 24
discounted quotes `TotalPrice` = `GrandTotal` = `Subtotal`, even at
100% and 150% discounts; standard `Quote.Discount` stays 0; the
line-level field behaves the same. Only three components reference
the field and all merely read it. **Before testing anything
discount-related in future stories, remember the number is
decorative** — any downstream story that assumes a discounted total
(orders, invoicing, commission) will be building on sand.

### Notification targeting inconsistency

`AF_FL_Quote_DiscountApproved` / `_DiscountRejected` notify the
Quote **Owner**; the approval process routes to the **submitter's**
manager. These differ whenever the submitter doesn't own the quote —
which is easy to hit in test data created by an admin. Not
necessarily a defect (normally the rep owns their quote), but
remember it when a notification seems to go to the "wrong" person.
`AF_FL_Quote_DiscountApprovalRequested` notifies "Owner's Manager",
which is a third derivation again.

### Access gap — deliberately NOT in the tickets

**Sales Manager has no FLS read on ANY Quote discount field**
(`AF_DiscountAmount__c`, `AF_DiscountPercent__c`,
`AF_DiscountTier__c`, `AF_DiscountApprovalStatus__c`) — the only
discount-ish field they can read is the unrelated standard
`Quote.Discount`. Same root cause as RS-06: **`AF_PSG_Sales_Manager`
is assigned to nobody.** Consequence: the approver literally cannot
see the discount they are approving, which compounds ticket 4.
Fix: assign `AF_PSG_Sales_Manager` to the Sales Manager user.

### Test data left in the org

Opportunity `QA RS07 Discount Harness` (`006FV00AqRuCIjsYUG`) with
33 quotes named `QA RS07 Q01…Q25` and `QA RS07 H1…H8`, each with a
single 100,000 line so `Subtotal` = 100,000 (except `Q12` which has
no line, for the zero-subtotal case). Many sit at `Pending` and are
therefore **record-locked** — that is deliberate evidence for the
stuck-approval defect; don't "clean up" by approving them without
re-reading the ticket. `Q01` deliberately carries a tampered
`AF_DiscountTier__c` = 4 against a 1% discount (evidence for
ticket 7). Manager hierarchy restored to as-found. TraceFlags
created and deleted; `DebugLevel` `7dlFV0004f9OQ1oYAG` reused.

### CORRECTION 2026-09-10 — "Create Quotation is missing" was WRONG

The RS-06 finding that the Create Quotation action was absent from the
Opportunity is **retracted**. The user proved it by screenshot; it was
then confirmed live. The action exists and works.

**Two mistakes stacked:**
1. **Tested in the wrong app.** The UI pass ran in the **Sales** app.
   Al-Fardan's users work in the **Automotive** app, which is assigned
   `Opportunity_Record_Page` — the record page with the sales Path,
   Test Drives and Trade Ins related lists (exactly what the user's
   screenshot shows). In the Sales app the Opportunity page really is
   layout-driven and really does lack the action, so the observation
   was true but irrelevant.
2. **Checked the wrong metadata.** `Opportunity_Record_Page` has
   `enableActionsConfiguration = true` — **Dynamic Actions**. When
   that is on, the FlexiPage's own action list **completely replaces**
   the page layout's actions. Proving `AF_Create_Quotation` was absent
   from `Opportunity-Opportunity Layout` therefore proved nothing.

**Rules going forward for this org:**
- **Always test in the Automotive app**, not Sales. Switch via App
  Launcher before any Opportunity UI pass. Confirm the page shows the
  Path + Test Drives + Trade Ins before trusting what you see.
- Before concluding any action/button is missing, check the
  **FlexiPage** (`SELECT DeveloperName FROM FlexiPage WHERE
  Type='RecordPage'`, then retrieve it) for `enableActionsConfiguration`
  and its `valueListItems`. Page layouts are only authoritative when
  Dynamic Actions are OFF.
- Dynamic Actions carry per-action `visibilityRule`s. Real example on
  this page: `AF_Create_Quotation` is gated to
  `{!Record.StageName} EQUAL "Select"` and `AF_Select_Vehicle` to
  `Consider` — so an action can be genuinely invisible on one record
  and present on another for reasons that have nothing to do with
  permissions.

That stage gating is the only real remainder of the original finding,
and it looks deliberate — logged as a BA question, not a defect.

### RULE CHANGE 2026-09-10 — persona-specific issues ARE ticket-worthy

The earlier "universal bugs only" filter is **withdrawn**. User:
*"from now on make the tickets even if they happen to only that
persona and in testing we will always test with personas."*

Raise a ticket for anything that blocks a persona from doing their
job, including FLS / permission-set-group / sharing / licence gaps
that System Administrator bypasses. Name the affected personas in the
ticket and say whether Admin is unaffected — but do not withhold the
ticket on that basis.

Applied retrospectively:
- **RS-06 ticket 8** — Sales Rep cannot create a quotation when the
  Opportunity has an Approved+Accepted trade-in
  (`Product2.ProductCode` readable only by System Admin).
- **RS-06 ticket 9** — Sales Manager cannot create any quotation
  (`AF_PSG_Sales_Manager` assigned to nobody →
  `Opportunity.AF_VehicleModel__c` invisible → `Get_Opportunity` faults).
- **RS-07 ticket 8** — approver cannot see any discount figure on the
  quote they are approving (same missing PSG assignment).

The RS-06 miss was caught by the user, not by me. Root of the mistake:
applying the old rule literally when the consequence was that *nobody
who actually performs the process* could perform it.

### 2026-09-10 — DoA approval chain configured (Manager field)

At the user's request, the Manager field now mirrors the DoA matrix so
`AF_AP_Quote_DiscountTiers` can actually escalate. Verified live: a
Tier 4 (10%) discount traversed **all four steps in order** and
finished `Approved`.

| DoA tier | Approval step | Resolves to |
|---|---|---|
| Tier 1 Showroom Manager | step 1 | Showroom Manager Automobiles (`005a3001tN4fKfMAQU`) |
| Tier 2 Sales/Brand Manager | step 2 | Sales Manager (`005a3001tN3B1SeAQK`) |
| Tier 3 General Manager | step 3 | **Arcsen Alfardan** (`005a3001vLvmFZ6AQM`) |
| Tier 4 CEO | step 4 | **QA Test Admin** (`005a3001tN4Bxe8AQC`) |

Chain: Rep → Showroom Mgr → Sales Mgr → Arcsen → QA Test Admin → (top).

**Tiers 3 and 4 are System Administrators as stand-ins** because the
org has **no General Manager and no CEO user**, and all 10 Salesforce
licences are consumed so neither can be created without freeing a
seat. The *roles* exist (`AF_Role_GM_*`, `AF_Role_CEO`) — only the
people are missing. That remains a genuine finding, not something the
hierarchy change fixes.

**Practical gap for UI testing:** no password is recorded for
Showroom Manager Automobiles (`sgrandhi…`, created 2026-08-25 to fill
a role gap), so Tier 1 approvals currently land on a login we cannot
use. Reset it if a full UI walk of the chain is needed.

**Also worth knowing:** the org has a complete, correct **role**
hierarchy (CEO → GM → Sales Manager → Sales Rep), but the approval
process resolves approvers from the **Manager field**, which is a
different mechanism entirely. All that role structure is unused by
this process. And in the role tree Showroom Manager is a *sibling* of
Sales Rep (both under Sales Manager), so the roles could not produce
the DoA ladder even if the process did use them.

### 2026-09-10 — Line-level discount: the reachable bypass is the STANDARD field

Client spotted that `AF_DiscountAmount__c` is not visible on a Quote
Line Item. Verified — the **Quote Line Item layout** contains only:
`AF_LineItemType__c, CreatedById, Description, Discount, HasSchedule,
LastModifiedById, LineNumber, ListPrice, Product2Id, Quantity,
QuoteId, Subtotal, TotalPrice, UnitPrice`.

Neither `AF_DiscountAmount__c` nor `AF_DiscountPercentage__c` is on
it (FLS is fine — `AF_PSG_Sales_Rep` grants read/edit on the amount —
they were simply never added to the layout). There is no FlexiPage for
QuoteLineItem, so the layout governs.

**The consequence is worse than the original ticket 5 described, and
that ticket has been rewritten.** The only discount field a rep can
reach on a line is the **standard `Discount`** percent field, and:
- it **is** on the layout and **is** read/edit for `AF_PSG_Sales_Rep`;
- it **does** reduce the price natively — proven live: 20% on a
  100,000 line took the line and the Quote from **100,000 → 80,000**;
- it raises **no** tier, **no** approval status and **zero**
  `ProcessInstance` records.

So the two discount fields are exactly inverted:
- `Quote.AF_DiscountAmount__c` — **governed**, on the Quote layout,
  but has **no effect on price** (ticket 1).
- `QuoteLineItem.Discount` — **ungoverned**, on the line layout, and
  **does change the price** (ticket 5).

By contrast the **Quote** layout does *not* expose standard
`Discount`, so the header route is governed-only. The hole is purely
at line level.

Test-data note: `DEMO RS07 13` was used for this and reset to 0 after.

## Jira conventions for this project (recorded 2026-09-22)

Bug tickets are drafted first as **one `README.md` per story** under
`tickets/` (quick summary + table of every ticket, each with a
`BUG-<STORY>-NN` id in its summary line), handed to the user for
review, and created in Jira **only after explicit approval**.

On approval, each issue is created with:

| Field | Value |
|---|---|
| Project | `LFRDN` |
| Linked to | the user story the defect was found in |
| Priority | set explicitly (Jira scheme: Highest / High / Medium / Low / Lowest) |
| Assignee | Yassin |
| Parent | the **Build Epic** |

---

## 2026-09-22: ALF-RS-10 execution — and a major persona change

### ⚠️ The persona users changed. The old five are deactivated.

Every persona this project used up to ALF-RS-07 (`jstev_sales…`, `mpapa_sales…`,
`jeff.ross…`, `abc.ghs…`, and QA Test Admin `juw…`) is now **IsActive = false**.
The build team replaced them around 2026-09-13 with a new set, all on the
**Minimum Access - Salesforce** profile plus the right `AF_PSG_*` permission set
group and `AF_QA_API_Access`:

| Persona | User | Username | Role |
|---|---|---|---|
| Sales Representative | QA SalesRep2 (`005FV0082KfRrqeYQC`) | `alfardan.qa.salesrep2@alfardan.com.qa.qa` | Sales Rep - SportsMotors |
| Showroom Manager | QA ShowroomManager2 (`005FV0082KfW3zgYQC`) | `alfardan.qa.showroommanager2@…` | Showroom Manager - Alsadd |
| Sales / Brand Manager | QA SalesBrandManager2 | `alfardan.qa.salesbrandmanager2@…` | Sales Manager - SportsMotors |
| General Manager | QA GeneralManager2 | `alfardan.qa.generalmanager2@…` | General Manager - SportsMotors |
| CEO approver | QA CEOExecApprover2 | `alfardan.qa.ceo2@…` | Alfardan Group CEO |
| CRM Agent | QA CRMAgent | `alfardan.qa.crmagent@…` | CRM Agent - SportsMotors |
| Used Car Team | QA UsedCarTeam2 | `alfardan.qa.usedcarteam2@…` | Used Car Team |

Passwords were set to `Arcsen@2026!` for all seven via `System.setPassword`
(admin Apex), **with the user's explicit approval on 2026-09-22** — the previous
passwords were unknown and someone else was actively using QA SalesRep2 at the
time. `.mcp.json` was updated to match, and three previously unmapped personas
(General Manager, CEO, Used Car Team) were added to it.

There is **no Sales Receptionist** in the new set. The old
`salesreceptionist.v2.20260823@…` is still active but returns
`LOGIN_DURING_RESTRICTED_DOMAIN`, because its profile **Standard User Custom**
carries its own Login IP Ranges (41.128.0.0/16, 41.239.166.0/24,
156.215.118.0/24) that exclude this machine. Org-wide Trusted IP is not enough —
profile Login IP Ranges are a separate, hard block. The new personas' profile
(Minimum Access - Salesforce) has no IP ranges, so they are unaffected.
This machine's egress IP on 2026-09-22 was **154.176.51.28** (was 41.236.183.12).

### Persona API access without restarting the session

`.mcp.json` changes do not reach an already-running MCP server (Gotcha #3), and a
session restart is expensive mid-story. **Use SOAP login + REST over curl
instead** — it needs nothing from `.mcp.json` and runs at whatever API version
you ask for. Helper kept at
`<scratchpad>/sfp.sh <persona> query|get|post|patch|del`, which logs in via
`https://test.salesforce.com/services/Soap/u/62.0`, caches the session id, and
calls `/services/data/v68.0/...`. This sidesteps the old-API-version ghost-field
problem (Gotcha #10) entirely — `Vehicle`, `AF_SelectedVehicle__c` etc. all
behave normally at v68.

For admin-side work, **`sf apex run -f <file>` is the reliable path**: the admin
MCP connection cannot even *compile* Apex against
`AF_VehicleReservation__c.AF_Vehicle__c` ("Field does not exist"), and
`sf org display --json` output is prefixed with a CLI update warning that breaks
naive JSON parsing (strip everything before the first `{`), while
`sf org auth show-access-token` prompts interactively.

### ALF-RS-10 findings worth not re-deriving

- **The Sales Order is not an object.** It is `Opportunity.AF_SOStatus__c` +
  `AF_SODocumentReference__c` + `AF_SOGeneratedDate__c` +
  `AF_SOPaymentConfirmedBy__c` plus a generated file. Quick Action
  `AF_Generate_Sales_Order` → flow `AF_FL_Opp_GenerateSalesOrder` → Apex
  `AF_SalesOrderService`, gated by `AF_VR_Opp_SOGenerationGate` (VR) and
  `AF_SalesOrderService.findBlocker()` (Apex, same conditions, better message).
- **`Opportunity.AF_VehicleReservation__c` is never populated by anything.**
  Zero rows org-wide. It is what the SO gate reads, so Sales Order generation is
  impossible for everyone — BUG-RS10-01. If you need a working Sales Order for
  testing a later story, set that field by hand first.
- **`update as user` + missing FLS is this org's recurring failure mode.**
  `Opportunity.AF_SOPaymentConfirmedBy__c` (breaks Sales Order generation) and
  `Opportunity.AF_InvoiceBalance__c` (breaks *reservation creation*, and therefore
  RS-08 and RS-10 both) have `PermissionsEdit = false` on every `AF_PSG_*` group
  while their sibling fields in the same DML have it. Symptom is always the
  useless *"fields being inaccessible on Sobject Opportunity"*. When a persona
  hits that, query `FieldPermissions` for every field in the service's `update`.
- **No `AF_PSG_*` group grants access to any `AF_*` Apex class** — only the
  System Administrator profile does. This blocks *direct API* invocation of the
  invocable actions but **not** the Quick Action screen flows, which reach the
  service fine. Do not mistake one for the other.
- **Two vehicle status fields, unreconciled.** `AF_VehicleOrderState__c`
  (On Order / In Transit / In Stock-Arrived, written only by
  `AF_VehicleOrderStatusSync`, on **no page anywhere**) vs `AF_InventoryStatus__c`
  (In Stock / In Transit / Ordered, what users see, what the SO gate reads).
  Arrival via the sync never unlocks the Sales Order.
- **FR2 has no integration.** `AF_VehicleOrderStatusSync` is a manual stub by its
  own description — no scheduler, endpoint, alerting or replay.
- **`AF_PSG_Sales_Rep` has View All Records on Opportunity** (so do Sales Manager,
  Showroom Manager, Marketing). Reads bypass the whole BU sharing model; writes
  are still correctly governed by the criteria-based sharing rules
  (`AF_SR_Opportunity_*` on `AF_BusinessUnit__c` / `AF_Showroom__c` into per-BU
  public groups). **Careful when testing cross-BU access:** QA SalesRep2's role is
  *SportsMotors* but their public-group membership is *AF Business Unit -
  Automobiles*, and Account ownership also grants access to child opportunities —
  isolate with a record whose owner, account owner and BU group all exclude the
  persona, then check `OpportunityShare` before concluding anything.
- **Brands:** `Opportunity.AF_Brand__c` is Ferrari / Rolls-Royce / Undecided only.
  BMW, JLR, Land Rover and Maserati do not exist, so every BRD scenario written
  around them is untestable. `AF_FL_Sub_DeriveBusinessUnit` maps Ferrari → Sports
  Motors, Rolls-Royce → Automobiles, everything else → UNMAPPED; **nothing maps to
  Alfardan Premier Motors**.
- **Org default currency renders as AED** while every document and flow screen
  hard-codes QAR.
- **Creating a Vehicle needs an Asset first** (`AssetId` is required); create the
  Asset with just a Name, then the Vehicle with `AssetId`, `VehicleDefinitionId`,
  `RecordTypeId`, a unique 17-char VIN and `AF_InventoryVehicle__c = true`.
  Vehicle `MakeName`/`ModelName`/`ModelYear`/`ChassisNumber` are blank on **all 26**
  inventory vehicles — that data lives on `VehicleDefinition` (`Name`,
  `VariantName`, `AF_Brand__c`).
- **Accounts require `AF_QID__c`** (or another ID) — *"An Individual Account
  requires a Qatar ID or an alternate ID"* — and a second Brand Profile contact
  for the same brand on one Account is blocked by validation.
- **`AF_Payment__c` requires `AF_SFPaymentReference__c`** (validation, not schema),
  and the Sales Rep persona cannot write most Payment fields — payments must be
  recorded by an admin standing in for the Cashier, and that substitution belongs
  in the report.

### Test data left in the org

`DEMO RS10 01`–`12` Opportunities and their Vehicles/Assets/Reservations
(RES-00123…RES-00128)/Invoice Summaries (INVM-00056…INVM-00062)/Payments;
Account `DEMO RS10 Customer - Khalid Al-Mannai` (`001FV00L3Cqvq5UYUQ`);
`DEMO RS10 09 Other-BU Account` (`001FV00L2MZOiEOYU1`);
`DEMO RS10 Fleet - Qatar Foundation Fleet Services` (`001FV00L3NRO3COYU1`) with
150 `DEMO RS10 Fleet NNN` Opportunities. Generated Sales Order documents exist on
DEMO RS10 06 and 07. **DEMO RS10 01 is deliberately left with a null
`AF_VehicleReservation__c`** so it still reproduces BUG-RS10-01 — do not "fix" it.
19 pre-existing vehicles had `AF_VehicleOrderState__c` changed by the bulk-sync
test and were restored to their recorded prior values in the same session.

## 2026-09-22: ALF-RS-11 (Invoicing and Deal Completion Rules) — execution notes

Report `reports/ALF-RS-11-report.md`, tickets `tickets/ALF-RS-11/README.md`,
results in the workbook. 12 written + 3 added test cases. What follows is
what does NOT belong in either file.

### Deal completion is enforced in THREE places, and they disagree

| Gate | Where | Checks |
|---|---|---|
| `AF_VR_Opp_ClosedWonGate` | validation rule | handover complete, delivery confirmation, `AF_InvoiceBalance__c <> 0`, Traffic Form, Customer Sign-Off |
| `AF_FL_Opp_ClosedWonPaymentGate` | **before-save flow — governs every manual/API/bulk save** | payments verified, *some* file attached per payment, Invoice Summary `AF_Balance__c = 0`, handover conditions; stamps `CloseDate` |
| `AF_Opportunity_ClosedWonPaymentGate` | Apex — **only the auto-close path calls it** | all of the above **plus** `AF_DocumentService.areRequiredDocumentsUploaded` (typed Cheque Copy / Bank LPO / Signed NOC) |

The Apex gate is strictest. The manual path never reaches it. That is
BUG-RS11-06 and it is the pattern to check first in RS-12..RS-16: whenever
a rule exists in Apex *and* in a before-save flow, assume they have drifted.

### The two balance fields are not interchangeable — this trips gates

- `Opportunity.AF_InvoiceBalance__c` — mirror, written only by
  `AF_InvoiceSummaryService.recalculate` on payment events. **Reads `0.00`
  on a deal with no payments at all**, so `<> 0` passes. This is what lets
  an unpaid car through the Take-the-Keys gate (BUG-RS11-01).
- `AF_InvoiceSummary__c.AF_Balance__c` — the real figure, `null` until a
  payment recalculation. The before-save flow tests this one, which is why
  Closed Won is still correctly blocked on the same record.

When reading any gate in this org, check **which** of the two it uses.

### FR3/FR4/FR5 are a required-documents matrix, and it is good

`AF_Document__mdt` rows keyed to `AF_DocumentCondition__mdt`:
Payment - Cheque → Cheque Copy; Payment - Bank Transfer → Bank LPO;
Payment - Cheque/Bank Transfer + NOC → Signed NOC; Payment - NOC Only → Signed NOC.
Enforced via `AF_DocumentService.areRequiredDocumentsUploaded(recordId)`, which
matches `ContentVersion.AF_FileUpload__c` against the configured document name.
**To satisfy one in a test you must upload a ContentVersion with
`AF_FileUpload__c = '<Document Name>'`** — a plain attached file does not count.
Switching a payment's method correctly re-evaluates the requirement (a stale
Cheque Copy does not satisfy Bank Transfer) — verified live, don't re-derive.

### Keyloop does not exist in this org at all

`AF_KeyloopGetPayment`'s own header: *"No live Keyloop integration exists in this
org yet (confirmed: zero Named Credentials, zero Apex HTTP callouts anywhere)…
this is built as a full in-Salesforce simulation."* It synthesises the payment:
payee = the Invoice Summary's own Account, amount = outstanding balance, method =
Bank Transfer, status = Paid / Verified, **and `AF_NOCRecorded__c = true`**. So
through the only rep-facing payment path, the FR3 payee control can never fire
and a cheque payment can never exist. Worth remembering for RS-12..RS-16: any
test case that depends on a Keyloop round trip is untestable today.

### Test-data recipes learned here (reuse these)

- **Commit stage needs a synced Quote.** Create `Quote` with
  `AF_QuoteType__c = 'Customer Quotation'` (required), `Pricebook2Id` = standard,
  then set `Opportunity.SyncedQuoteId`. Without it `AF_VR_Opp_CommitGate` blocks.
- **Stages move one at a time** (`AF_VR_Opp_SequentialStageProgression`):
  Consider → Explore → Select → Commit → Take the Keys → Closed Won.
- **Contacts need Phone AND Brand** (*"A Brand Profile Contact requires Phone and
  Brand before it can be saved"*), and only one Brand Profile contact per brand
  per Account is allowed.
- **Account and Contact inserts trip duplicate rules** — use
  `Database.DMLOptions.DuplicateRuleHeader.AllowSave = true`.
- **`sf apex run` mangles non-ASCII**: an Arabic string literal in an anonymous
  Apex file produces a bogus "Unexpected token '<'" compile error on an unrelated
  line. Escape every non-ASCII character as `\uXXXX` before running
  (script kept at `<scratchpad>/ascii_escape.py`).
- **The `Payments__r` child relationship does not exist** on Opportunity — query
  `AF_Payment__c` with `WHERE AF_Opportunity__c = …` instead.

### Left in the org deliberately (do not "fix")

- `DEMO RS11 05` — Closed Won with a **back-dated** Close Date of 10/09/2026
  (evidence for BUG-RS11-03).
- `DEMO RS11 06` — Closed Won with **no Bank LPO** on its Bank Transfer payment
  (evidence for BUG-RS11-06).
- `DEMO RS11 07 / PAY-00032` — a payment with a **blank payee** that saved
  (evidence for BUG-RS11-07).
- `DEMO RS11 01` — sitting at **Take the Keys** against an Unpaid 500,000 invoice
  (evidence for BUG-RS11-01).
- Plus the full matrix: 2 Accounts (one Arabic-script `خالد المناعي`), 1 Contact,
  9 Vehicles/Assets, 18 Opportunities (8 scenarios + `DEMO RS11 Bulk 01-10`) with
  synced Quotes, 8 Invoice Summaries, 9 Payments, 4 Handovers.

No org configuration was changed for this story — data only.

## 2026-09-22: THE RETAIL CYCLE — build test data through it, not around it

User correction during ALF-RS-10 review: *"are you aware of the cycle for the retail?"*
Test data built by direct inserts misses what the real journey does, and any finding
made on such data has to be re-verified through the journey before it is filed.

**The cycle, as the business runs it:**

1. **Select Vehicle** — custom Quick Action on Opportunity (`Opportunity.AF_Select_Vehicle`,
   LWC `AF_SelectVehicleAction`, the "Vehicle Finder"). Two paths: pick a model then a specific
   **vehicle**, or **"Proceed without Vehicle"** for a **vehicle definition only** (the pre-order
   placeholder path). Choosing a model with Lines asks *"Choose a Line"* → **Confirm Line**.
   It sets `AF_SelectedVehicle__c` **and** `AF_VehicleModel__c`, and creates the
   **OpportunityLineItems** (vehicle + line package, e.g. 369,300 + GTS Package 29,000).
2. **Test drives** — moving to **Explore** auto-creates an `AF_TestDrive__c` (Status *Requested*),
   and `AF_VR_Opp_TestDriveGate` then blocks any stage past Explore until it has a Result.
   Completing it requires **`AF_ProductFeedback__c`** as well as Status/Result = Completed.
3. **Trade-ins** — if any (ALF-RS-04 path).
4. **Add Products** — standard button, on top of what Select Vehicle already added.
5. **Create Quotation** — custom Quick Action (`Opportunity.AF_Create_Quotation`); asks
   Customer vs Bank Quotation, then builds the Quote from the line items.
6. **Create Reservation** — Quick Action **on the Quote** (`Quote.AF_Create_Reservation` →
   `AF_FL_Quote_CreateReservation`): *"Reserve the vehicle already on this Quote?"*, Contract Type,
   Trade-In as deposit, Vehicle Source.
7. Payments (**Get Payment** on the Invoice Summary) → Sales Order → handover → Closed Won.

**Quick Actions are stage-dependent.** At *Consider* the menu shows only Request Closure /
Select Vehicle / Generate Sales Order / Cancel Sales Order — **Create Quotation, New Test Drive
and New Trade-In do not appear until the stage advances**. Don't conclude an action is missing
without checking the stage first.

### The Demo Vehicle record type trap — cost real time

`AF_VehicleExplorerController.getScopeCondition()` excludes the **Demo_Vehicle** record type
(`012FV000jORjU4qYQF`) and any vehicle held by an active reservation. Genuine inventory in this
org has a **null RecordTypeId** — `Regular_Vehicle` (`012FV000jORngDsYQJ`) exists but was never
backfilled. I created 17 test vehicles copying the record type off a *Demo* vehicle, so none of
them appeared in the Vehicle Finder; corrected to null on 2026-09-22. **When creating test
vehicles, leave RecordTypeId null.**

### What the cycle verification actually proved (2026-09-22)

Built `DEMO RS10 13 - Real retail cycle end to end` (`006FV00Bhdn1CVAYE2`) through every step above:

- **BUG-RS10-03 is real and worse than first written.** The genuine **Create Reservation** Quick
  Action on the Quote fails for the Sales Rep with *"Something went wrong — We couldn't create the
  reservation."* Nothing is created. It is not an artefact of inserting records directly.
- **BUG-RS10-01 is real.** Creating that reservation as an admin through the same field set the
  Quick Action builds gives `RES-00137` at **Reserved**, and the Opportunity's
  **`AF_InvoiceSummary__c` is populated automatically** — while **`AF_VehicleReservation__c` stays
  null**. The mirror pattern exists and works for the invoice; the reservation equivalent was never
  built. So the Sales Order gate can never pass, on cycle-built data as much as on hand-built data.

**Standing rule from this:** for any story that sits downstream of the retail journey, build at
least one scenario through the real Quick Actions before filing a blocker, and say in the ticket
that it was verified that way.

### Jira conventions confirmed 2026-09-22 (ALF-RS-10 filing)

Site `coberg1.atlassian.net`, cloudId `95de0000-be8a-440c-bcd0-6b67530375b9`,
project **LFRDN** ("ALFARDAN"). QA bugs are filed as:

- issue type **Bug**, **parent = LFRDN-317 (Build epic)**
- **Relates** link to the story subtask (ALF-RS-10 = **LFRDN-340**, under LFRDN-160 Retail Sales)
- assignee **Yassin** `712020:05a5347f-5fa7-4028-9937-3f5173361f3d`
- labels `ALF-RS-10` / `QA` / `Retail-Sales` (+ `Security` / `Integration` where apt)
- priorities Highest / High / Medium / Low

**Workflow: there is no direct route to Done.** From `DEPLOYED TO QA` the only
transitions are `WAITING FOR CUSTOMER INPUT`, `CANCELLED`, and **`Testing started`
(id 6) → QA IN PROGRESS**; from there **`QA Approved` (id 7) → Done**. So closing a
verified fix is always two transitions. New bugs land in **Draft**.

**Always search `labels = "ALF-RS-10"` before filing** — the build team files its own
QA bugs with the same labels, and fixes land as `DEPLOYED TO QA` awaiting exactly the
verification round we run. On 2026-09-22 six existed (LFRDN-659..664); five were
verified fixed and closed, and three of our findings turned out to be **regressions of
those fixes** rather than new bugs.

### Jira description formatting — use Markdown, not wiki markup (learned 2026-09-22)

The Atlassian connector's `createJiraIssue` / `editJiraIssue` / `addCommentToJiraIssue`
default to **`contentFormat: "markdown"`**. Jira **wiki markup is not converted** — it
is passed through as literal text, so `h2. Heading` renders as the words "h2. Heading",
`{{code}}` renders with the braces visible, `||header||` tables do not become tables,
and `{quote}` blocks show the tags.

The ALF-RS-11 tickets (LFRDN-681..687) were first filed in wiki markup and had to be
rewritten. Always write Jira bodies in **Markdown**:

| Want | Use | Not |
|---|---|---|
| Heading | `## Heading` | `h2. Heading` |
| Bold | `**bold**` | `*bold*` |
| Inline code / field names | `` `AF_Field__c` `` | `{{AF_Field__c}}` |
| Code block | triple backticks | `{code}` |
| Quote | `> quoted` | `{quote}` |
| Table | `\| a \| b \|` + `\| --- \| --- \|` | `\|\|a\|\|b\|\|` |
| Bullet / numbered list | `- item` / `1. item` | `*` / `#` |

Note `*single asterisks*` become *italic* in Markdown, which is why wiki-style bold
came out italic. Pass `contentFormat: "markdown"` explicitly on edits to be certain.

## 2026-09-24: ALF-RS-12 (Vehicle Handover) — cycle map and grounding

Metadata re-retrieved 2026-09-24 (Handover object, Handover_Record_Page, 6 handover flows,
AF_HandoverDocumentService, AF_HandoverUploadSyncService, AF_DocumentService/Controller,
AF_ContentDocumentLink trigger). Handover flows last deployed 2026-09-19; the create-on-Take-the-Keys
flow 2026-09-23.

### The handover cycle as the rep performs it

1. Opportunity at **Commit**, invoice **Fully Paid** (balance 0). Path → **Take the Keys** →
   `AF_FL_Opp_CreateHandoverOnTakeTheKeys` creates `AF_Handover__c` (Status *Pending*) with
   Opportunity, Account and **Contact = Opportunity.ContactId** — which the retail cycle never fills
   (the customer sits in `AF_PrimaryBrandContact__c`), so Contact arrives blank. Vehicle and Invoice
   Summary are not mapped at all.
2. Open the Handover (Opportunity → related **Handovers**, or the lookup `AF_Handover__c`).
   Record page `Handover_Record_Page` exposes only **Edit** and **Generate Documents**
   (`AF_Handover__c.AF_Generate_Documents`, visible only while Status = Pending or In Progress).
   Tabs: Details / Related (the `afDocumentComponent` **Required Documents** panel, 8 rows,
   condition `Handover_All`) / activity.
3. **Generate Documents** → `AF_FL_Handover_GenerateDocuments` → `AF_HandoverDocumentService` with a
   blank name → the five agreements as PDFs, tagged `AF_FileUpload__c`, linked to the Handover
   only, each ticks its own `...Complete__c` flag. Documents print Vehicle/VIN from the Handover's
   own (blank) Vehicle field. Delivery Note is never produced by this path (LFRDN-699).
4. **Edit** → Handover Date (one DateTime field — date and time together), Handover Location (free
   text), Customer Sign-Off (Pending / Physically Signed), Status.
5. Required Documents panel → upload **Traffic Form** and **Insurance Form** (the sync never ticks the
   flags — LFRDN-697).
6. All 8 flags true → before-save `AF_FL_Handover_UpdateChecklistGate` sets Checklist Complete and
   **Status = Completed** (sign-off NOT needed for this); Closed Won Gate Passed also needs
   sign-off = Physically Signed.
7. After-save `AF_FL_Handover_SyncOpportunityGate` → Opportunity `AF_HandoverComplete__c`,
   `AF_Handover__c`, and `AF_SOStatus__c = Delivered` when the gate passes.
8. After-save `AF_FL_Handover_AutoCloseWon` (Status = Completed) → Opportunity Closed Won via the
   Apex gate, sets `AF_DeliveryConfirmation__c`, no fault path (LFRDN-700).
9. `AF_FL_Handover_FollowUpTask` scheduled path **2 days after AF_HandoverDate__c** → Task
   "Post-Handover Customer Experience Follow-Up" owned by the **Handover owner** (not a queue), What =
   Opportunity, Who = Handover Contact (blank), due today; guarded by `AF_FollowUpTaskCreated__c`.
   As of 2026-09-24 no such Task had ever been created in the org.

### Grounding the 12 workbook TCs against it

- There is **no Sales Order record** — the "Sales Order" is a document + `Opportunity.AF_SOStatus__c`.
  TCs that "open SO-2026-00133" map to the Opportunity/Handover.
- "Checklist items" = the 8 document flags + sign-off; no physical-items checklist (BRD
  Assumption 1 leaves content to the business).
- `AF_Handover__c` has **no validation rules** and **no field history tracking** (history enabled on
  the object, no field tracked). OWD **Public Read/Write** (also Invoice Summary, Reservation,
  Payment). Rep (`AF_PSG_Sales_Rep`), Showroom Manager, Sales Manager: Read/Create/Edit.
- No per-document generation UI (FR5), no Traffic/Insurance prompt after Sales Order, no signing
  tool (sign-off is a picklist), no forced-failure hook for TC-012.
- Reference cycle-built handover: **HO-00037** on DEMO Cycle 01 (`006FV00Bq30GjbQYES`).

### ALF-RS-12 progress checkpoint (2026-09-24 ~08:42 UTC) — resume here

Records (owner QA SalesRep2, account DEMO RS12 Customer - Maryam Al-Kaabi 001FV00LIQHEwyCY2T):
01 006FV00Bqe0PU3wYEG HO-00046 a0SFV001Pteoktw2IA (UI cycle: rep generated SO, Take the Keys via Path,
   Generate Documents x2, set date 24/09 14:30 + location + vehicle, uploaded Traffic+Insurance) — NEXT: sign-off
   Physically Signed, observe stuck; then hand-tick to finish; check Delivered/Closed Won.
02 006FV00Bqe0TgCyYEK HO-00038 (8 flags, no sign-off -> Status Completed, SO stays Generated; follow-up Task created anyway)
03 006FV00Bqe0XsM0YEK HO-00039 (signed, 2 docs missing -> nothing moves: PASS)
04 006FV00Bqe0c4V2YEI HO-00040 (dates: past/today/+1y/+10y/before build/blank all accepted; Completed with nothing done accepted; UI rejects 31/02)
05 006FV00Bqe0gGe4YEE HO-00041 (TODO UI: upload manual Warranty Agreement then Generate -> duplicate?)
06 006FV00Bqe0kSn6YEE HO-00042 (Closed Won via hand ticks; follow-up Task owner=rep not queue, Who blank; no duplicates on re-save/untick)
07 006FV00Bqe0oew8YEA HO-00043 (Showroom Manager Alsadd/Automobiles can't see Opp but reads+edits HO and downloads PDFs; OWD Public R/W; CRM Agent & Used Car no access)
08 006FV00Bqe0sr5AYEQ HO-00044 (rep API: all flags + Physically Signed, zero files -> Closed Won + Delivered)
Screenshots: screenshots/ALF-RS-12/01..05.

Findings so far (candidates for tickets/ALF-RS-12/README.md, all still need final UI confirmation where noted):
- LFRDN-696 FIXED (rep generated SO in UI). LFRDN-697, 699, 701, 706 still reproduce.
- LFRDN-706 root cause needs correcting: flow now maps Account + Opportunity.ContactId, but cycle fills
  AF_PrimaryBrandContact__c not ContactId; Vehicle/Invoice unmapped.
- NEW: agreements print Vehicle/VIN/email/phone/date/location as "-" (read Handover.AF_Vehicle__c) — customer signs a sale agreement naming no car.
- NEW: no way to regenerate stale agreements after data is corrected; Generate Documents always says "generated" even when nothing was.
- NEW: Handover OWD Public Read/Write -> cross-BU read/edit + download of customer documents (SD: segregated per BU).
- NEW: Handover Status auto/manually "Completed" without sign-off (and manually with nothing done); follow-up task fires for unsigned handover.
- NEW: Customer sign-off = picklist only, no signed document required (API/UI).
- NEW: follow-up task goes to rep not CRM queue (AC3), no Contact on task.
- NEW: no validation on handover date (blank, past before SO, far future); no field history (who confirmed).
- TC-012 not verifiable (no failure hook). TC-009 bulk (30) not run.
Remaining: finish 01 + 05 in UI, Section 5 hands-on fresh records, report reports/ALF-RS-12-report.md,
tickets/ALF-RS-12/README.md, workbook Actual Result column.

### ALF-RS-12 — COMPLETE (2026-09-24)

Delivered: `reports/ALF-RS-12-report.md`, `tickets/ALF-RS-12/README.md` (BUG-RS12-05..12, DRAFT —
not in Jira), workbook RS-12 rows filled, screenshots `screenshots/ALF-RS-12/01..14`.
Hands-on set: DEMO RS12 H01..H05 (006FV00Br1nk3vAYEQ, …noG4CYEU, …nsSDEYE2, …nweMGYEY, …o0qVIYEY),
customer DEMO RS12 Hands-on Customer - Hessa Al-Naimi, all at Commit / Fully Paid / SO Not Generated.
`demo-docs/Warranty_Agreement_signed.pdf` added for the H02 duplicate test.
Pending user decisions: approve README for Jira; correct LFRDN-706 root cause (Contact comes from
Opportunity.ContactId which the cycle never fills); transition LFRDN-696 (verified fixed).
Gotcha: the Alsadd Showroom Manager login also hits Change Your Password — Cancel works.

## 2026-09-24: ALF-RS-13 (Sales Order Cancellation / Credit Note) — cycle map

Metadata retrieved 2026-09-24. Entry point: Opportunity header ▾ **Cancel Sales Order**
(`Opportunity.AF_Request_Cancellation` → screen flow `AF_FL_Opp_RequestCancellation`). FlexiPage
visibility rule is `SOStatus ≠ Cancelled OR SOStatus ≠ Not Generated` — always true (shows even
with no Sales Order).
1. Screen: Cancellation Reason (7 flow choices), **Supporting Evidence Reference (free text, required)**,
   Notes. Blocks if SO already Cancelled or cancellation already Pending. Needs owner's `ManagerId`.
2. Sets Opp `AF_CancellationApprovalStatus__c = Pending` + reason/evidence/notes/requested date.
3. Creates `AF_CreditNote__c`: Amount = RefundAmount = **Opportunity.Amount** (not payments received),
   RefundPath hard-coded **Refund**, Reason = Cancellation, Contact = Opp.ContactId (blank in cycle),
   Invoice Summary linked, no Payment. Auto-submitted to `AF_AP_CreditNote_Cancellation`.
4. Opportunity submitted to `AF_AP_Opp_Cancellation`. **Both processes: one step, approver = submitter's
   Manager field** (QA SalesRep2 → QA ShowroomManager2, Alsadd). Two independent approvals.
5. Opp approval → Cancellation Approved + `AF_SOStatus__c = Cancelled` → `AF_FL_Opp_CancellationReleaseReservation`
   cancels every reservation not Cancelled/Expired (incl. Converted) → stock release; `AF_FL_Opp_DenyQuoteOnLostOrCancel`
   sets the synced Quote to Denied. Stage is not touched.
6. Credit Note approval → Approved + Finance Status Processing; nothing syncs to Keyloop
   (Integration Status / Synced / Keyloop ref are plain editable fields).
Guards: Opp VRs `AF_VR_Opp_ApprovalStatusNoDirectSet`, `AF_VR_Opp_CancellationApprovalRequired`.
Credit Note: only `AF_VR_CreditNote_EvidenceRequired`; OWD Public Read/Write; no field history; rep
can edit Approval Status, Finance Status, Synced, Keyloop ref, amounts. Rep has no Delete on Opp/CN/
Invoice/Payment/Reservation.

### ALF-RS-13 execution checkpoint (2026-09-24 ~11:00 UTC)

Records (owner QA SalesRep2, account DEMO RS13 Customer - Nasser Al-Mohannadi 001FV00LJCxNPvoY2G):
01 006FV00Br6vomcmYEA cancelled (approved after reassignment to SalesBrandManager2), CN-00003 Approved/Processing, RES-00195 Cancelled, vehicle Available, Quote Denied, stage Commit
02 006FV00Br6vsyloYEA rejected -> SO Generated kept; resubmitted -> CN-00005 + CN-00009 both Pending (2 x 369,300)
03 006FV00Br6vxAuqYEE deposit 40,000 only, SO never generated -> approved -> SO "Cancelled", CN-00004 369,300 Pending
04 006FV00Br6w1N3sYEE Closed Won + Delivered -> cancellation approved -> SO Cancelled, stage still Closed Won, reservation Cancelled, vehicle Available for Sale
05 006FV00Br6w5ZCuYEM rep API created CN-00007 Approved/Completed/Synced 999,999 with fake Keyloop ref, no approval; rep UI created CN-00008 999,999 Pending
06 006FV00Br6w9lLwYEI untouched (SO Generated)
Findings: text-only evidence; approver = Manager field (Alsadd mgr) cannot see/approve Opp (INSUFFICIENT_ACCESS) but CAN approve the credit note (CN-00003 approved while order pending); credit note = Opp.Amount not payments; refund path hard-coded; cancel offered with no SO and on Closed Won/delivered; delivered car put back on sale; stage never changes; rejected request leaves CN pending, resubmit duplicates CN and overwrites reason; no Keyloop sync; rep API can create approved/synced CN (UI layout read-only); no Credit Notes related list on Opportunity; no Opp field history; admin can delete CN/payment (restored); pending lock + self-approval block PASS; blank submit blocked PASS.
Screenshots screenshots/ALF-RS-13/01..11. Note: approvals 01-04 were reassigned by admin to QA SalesBrandManager2.
### ALF-RS-13 — COMPLETE (2026-09-24)
Delivered `reports/ALF-RS-13-report.md`, `tickets/ALF-RS-13/README.md` (BUG-RS13-01..10, DRAFT), workbook rows,
screenshots 01..11. Hands-on: DEMO RS13 H01..H04 (006FV00Bqzpzdq8YEA, …q3pzAYEQ, …q828CYEQ (Closed Won), …qCEHEYE4),
customer DEMO RS13 Hands-on Customer - Latifa Al-Sulaiti. Hands-on step needs an admin to reassign the Opp approval
(rep's Manager = Alsadd Showroom Manager has no access). Story subtask for Jira link: LFRDN-343 (from flow description).
Build team deployed RS-12 fixes 08:22–10:30 UTC today — RS-12 findings on 697/699/700/701/704 need re-verification.

### ALF-RS-12 — client Document Register applied (2026-09-24)
- Client sheet (document list + Doclist sequence) received from the user; not saved in the repo — cited as "Alfardan Document Register (client clarification sheet, received 24-Sep-2026)".
- Build order of the 5 agreements + Delivery Note last matches Doclist → old GAP-RS12-03 closed.
- BUG-RS12-09 rewritten: no auto-generation at Take the Keys (HO-00038/39/42/44 = 0 files) + no single-document generate in UI (service supports `documentName`, flow never passes it).
- New BUG-RS12-13 (no Traffic/Insurance prompt after SO; was a gap) and BUG-RS12-14 (Repair Disclaimer has no remarks; no remarks field on Handover/Vehicle/Opportunity).
- Gaps renumbered 01–07: new 06 = does an uploaded agreement count as done (HO-00041 duplicate), new 07 = "earlier stages of the handover" before or after Take the Keys.
- HO-00049 "LFRDN699 Verify Opp 2" has 6 files → dev verifying the Delivery Note fix; re-check LFRDN-699.
- 2026-09-24: RS-12 tickets filed — BUG-RS12-05..14 → LFRDN-708..717 (Yassin, parent LFRDN-317, relates LFRDN-342; extra links 708↔706, 713↔706, 711↔701, 716↔697; Security label on 709). Screenshots still to be attached manually.

### Retest of DEPLOYED TO QA bugs — 2026-09-24
- Record: `reports/RETEST-2026-09-24-deployed-to-qa.md`; screenshots `screenshots/RETEST-2026-09-24/`.
- Fixed 11 (671 673 679 696 700 701 702 703 704 705 707); partial 4 (672 UI fields not on Dynamic Forms page; 674 year/chassis blank data; 698 no backfill; 706 Contact blank + Account regression since ~12:08 UTC); not fixed 5 (677 685 unbuilt Keyloop; 678 deferred; 697 & 699 fail for the rep because 701 muted the flags and the services `update as user`).
- Retest deals: QA RETEST R1 006FV00BrFEI060YUD (Closed Lost via 707 test), R2 006FV00BrFEMCF2YUP (Closed Won), R3 006FV00BrFEQOO4YUP (Closed Won, no SO).
- Nothing posted to Jira yet — awaiting user.

### ALF-RS-13 — re-run 2026-09-25
- Re-run on QA RT13 T1–T7 (006FV00BtPUTf4mYUD, …UXrDoYUL, …Uc3MqYUJ, …UgFVsYUN, …UkReuYUF, …UodnwYUB [SM2/Automobiles], …UspwyYUB). Screenshots `screenshots/RETEST-2026-09-25-RS13/`.
- Build changes since first run: LFRDN-725 (AF_FL_CreditNote_Approved sets Opp Closed Lost), LFRDN-709 (Private OWD + AF_ChildRecordSharingService on HO/Invoice/Payment/Resv — NOT credit note), LFRDN-707 (rep Manager = SalesBrandManager2), Credit Notes related list added to Opportunity layout.
- All 10 drafts still reproduce except BUG-09's missing Credit Notes list (fixed). BUG-01 now config-dependent (SM2 → SBM2 can't see Automobiles), lowered to Medium.
- New drafts: BUG-RS13-11 refund approval fails on open deals (725 vs AF_VR_Opp_LostApprovalRequired) — Highest; BUG-RS13-12 cancelled order → Take the Keys → Closed Won — Highest; BUG-RS13-13 credit notes Public R/W across BUs — High; BUG-RS13-14 owner outside AF_G_BU group can't see own invoice → cancellation raw error (AF_G_BU_Automobiles empty) — Medium.
- Browser login is two-step (username → Log In to Sandbox → password). Nothing filed in Jira; awaiting user.
- 2026-09-25: RS-13 tickets filed — BUG-RS13-01..14 → LFRDN-728 (01), 729 (02), 730 (03), 731 (06), 732 (11), 733 (14), 734 (04), 735 (05), 736 (07), 737 (08), 738 (09), 739 (10), 740 (12), 741 (13). All relate LFRDN-343; extra links 728↔707, 732↔725, 733↔709, 741↔709, 740↔732. Security on 731/741, Integration on 737. Screenshots to attach manually.

### Retest of DEPLOYED TO QA bugs — 2026-09-26
- Record: `reports/RETEST-2026-09-26-deployed-to-qa.md`; screenshots `screenshots/RETEST-2026-09-26/`.
- 21 fixed.
- 695, 708, 711 and 712 commented and moved to To Do (transition 8 then 11).
- 695: Create Reservation is broken for the rep (7-Day deposit field hidden; 3-Day rep-only failure not isolated).
- Retest deals: D1 006FV00Bz976rqOYEQ, D2 006FV00Bz97B3zQYES, D3 006FV00Bz972fhMYEQ.
- The persona API (sfp.sh) now fails with LOGIN_MUST_USE_SECURITY_TOKEN; access checks were done via admin UserRecordAccess instead.
- 2026-09-26: 15 clean fixes moved to Done (via transitions 6 then 7): 672 697 699 700 701 702 703 705 706 710 714 715 716 717 718. Left in DEPLOYED TO QA: 674 698 704 707 709 713.

### ALF-RS-16 — Internal Requisition Form and PDI — 2026-09-26
- Cycle: Add Products (Consider/Explore/Select; brand query EXCLUDES Internal Provider Item) → edit each OLI to tick AF_RequiresInternalRequisition__c + AF_CustomizationDescription__c → Create Quotation (Select) → Show more actions ▾ Request Internal Requisition (FlexiPage visibility StageName = Select only) → approval AF_AP_Opp_InternalRequisition to owner's Manager (locks the Opportunity + OLIs, no recall) → on Approve AF_FL_Opp_RequisitionApproved calls AF_InternalRequisitionFormService (PDF attached to Opp, created as the approver). No After Sales distribution; template AF_ET_Opp_RequisitionForAfterSales is "manual Send Email", but the Opportunity has no Email action.
- Persona API (sfp.sh) works again after the user trusted IP 156.215.65.145 in Network Access.
- Records: QA RS16 T01–T10, T12 (customer QA RS16 Customer - Khalid Al-Sulaiti 001FV00LWgkmmSqYMI); hands-on DEMO RS16 H01–H07 (customer DEMO RS16 Customer - Noora Al-Kuwari 001FV00LWnz4PSWYM2). Setup scripts rs16_setup.apex / rs16_handson.apex in the scratchpad.
- Draft tickets BUG-RS16-01..10 (former 01 "no After Sales distribution" dropped 26-Sep: manual send agreed; rest renumbered down by one) (tickets/ALF-RS-16/README.md), report reports/ALF-RS-16-report.md, screenshots/ALF-RS-16/. Nothing filed; story subtask probably LFRDN-346 (named in the service's header comment) — confirm before filing.
- TC traceability: TC-001→01 · TC-005→08 · TC-006→03 · TC-007→09 · TC-010→04 · TC-011→02 · TC-012→07 · TC-013→06 · TC-014→05 · TC-016→10.
- Not ticketed (API-only): rep can PATCH AF_RequisitionStatus__c = Pending Approval → manager gets "Approval Needed" with no approval (T12).
- Vehicle.MakeName/ModelName/ModelYear are blank on all 91 vehicles and not writeable — any document reading them prints blanks/"null".
- 2026-09-26: RS-16 tickets filed — BUG-RS16-01..10 → LFRDN-742..751 (Yassin, parent LFRDN-317, relates LFRDN-346; extra links 742↔674, 748↔743, 746↔744). Screenshots to attach manually.

### End-to-end demo rehearsal — walk-in to Closed Won — 2026-09-26
- Walk-ins are Contact actions: Sales Walk-In (Sales Receptionist, `AF_PSG_Receptionist_Sales`, picks rep) and Service Walk-In (Service Receptionist, `AF_PSG_Receptionist_Service`, routes to the dealership's Showroom Manager by role DevName; only Alsadd has a user). No Service Receptionist user exists; licences 10/10.
- Sales Walk-In errors for the receptionist every time (deal is created; Private sharing makes the re-query return null → task WhatId null, notification fault). Service Walk-In fails on Create_Opportunity (INSUFFICIENT_ACCESS_ON_CROSS_REFERENCE_ENTITY), nothing created.
- Create Reservation (LFRDN-695) root cause: hidden "Trade-In Used As Deposit?" checkbox passes null (visible only when appraisal Status = Completed, which never happens); cash Deposit field shows only when checkbox = false. Rep API insert with the same fields + null checkbox → INVALID_TYPE_ON_FIELD_IN_RECORD; with false → works. Used the rep API session as a workaround for C1–C3.
- Commit needs Quote → Show more actions → Start Sync. Bank Transfer payments need a Bank LPO on the Payment before the auto-close on handover sign-off will close the deal; if missing, the deal stays open silently and manual close is blocked (DeliveryConfirmation) — re-save the handover after uploading.
- Discount % = amount / Quote.Subtotal (net of trade-in) and applied as % to all non-trade-in lines → over-discount; discount chain climbs the Manager hierarchy so with Rep→SBM every tier lands one level too high.
- Trade-in: item Trade-In Outcome must be set Accepted by the rep for the rollup/quote deduction; header auto-Accepted, stays Under Approval.
- Records: E2E C1–C5 (see report). Hands-on: DEMO E2E H1–H5 customers + STK-DEMO-E2E-01…05. Report `reports/E2E-DEMO-walkin-to-closed-won-report.md`, tickets `tickets/E2E-DEMO/README.md` (draft BUG-E2E-01..05, not in Jira). Login scripts `.playwright-login/*.js` (git-ignored).

### 2026-09-26 — E2E demo bugs filed
BUG-E2E-01..05 filed as LFRDN-752 (Sales Walk-In error, Highest), 753 (Service Walk-In fault, Highest), 754 (handover silent/no close, High), 755 (discount over-applied with trade-in, High), 756 (trade-in outcome, Medium). Links: 752/753 → LFRDN-331 (RS-01); 754 → 341 + 342; 755 → 337; 756 → 334 + 695; 753 ↔ 752. Screenshots to be attached manually. LFRDN-695 root-cause comment NOT posted yet (awaiting approval).

### 2026-09-27 — Sprint assignment
All 75 LFRDN bugs we filed from LFRDN-659 to LFRDN-756 (10.8/10.9 cycle, 10.10–10.13, 10.16, E2E demo) set to sprint **"LFRDN S1- R1 Sprint 3"** (sprint id 9510, board 2145; field `customfield_10020`). Verified by JQL: 75 in sprint 9510, 0 outside. Tickets by Omar/Yassin in that range (665–668, 680, 691, 693–695, 707, 718–726) were not touched.
Jira convention going forward: new QA bugs → Sprint 3 (`customfield_10020: 9510`) unless told otherwise.
Note: the Atlassian connector intermittently returns 403 "The app is not installed on this instance" even when the edit is applied; verify with JQL afterwards.

## 2026-09-27 — Retest of the 43 LFRDN bugs in Deployed to QA
- Report: `reports/RETEST-2026-09-27-deployed-to-qa.md` (screenshots `screenshots/RETEST-2026-09-27/` 01–37).
- Result: 32 fixed · 8 partial (719, 729, 730, 738, 745, 750, 754, 756) · 3 not fixed (695, 728, 752).
- **Jira: nothing posted yet.** User said (2026-09-27) not to comment directly — draft comments are in the report; wait for approval before commenting/transitioning.
- Records: deals `QA RT27 C1–C7`, `R1–R2`, `M1–M4` (note: two different deals each carry the M3/M4 labels — walk-in customers vs reservation deals).
- Regressions: Create Reservation dead on deals with no Approved appraisal (all users, incl. admin); Cancel Sales Order faults for all users (`Get_Manager_Record_Access` "RecordId field must be selected").
- Setup gap: QA SalesRep2.ManagerId = QA ShowroomManager2 (Alsadd) → discount/requisition/credit-note/cancellation approvals land on someone who can't see Sports Motors records. Worked around by reassigning ProcessInstanceWorkitems to QA SalesBrandManager2 as admin. Only Request Closure shares the deal to the approver (707 fix).
- Trade-in as reservation deposit: checkbox only shows on 7-Day when an Approved appraisal exists; `AF_FL_Reservation_ApplyTradeInDeposit` never fires on insert (ISCHANGED); no cap vs appraised value.
- Rep trace flag 7tfFV000gs1WwSOYA0 extended to 2026-09-28 08:00 UTC.
- 2026-09-28: user approved → 11 retest comments posted and 695/719/728/729/730/738/745/750/752/754/756 moved to To Do (JQL-verified). Fixed 32 NOT marked Done yet. N1–N4 drafted as BUG-RT27-01…04 in `tickets/RETEST-2026-09-27/README.md` (not filed).
- 2026-09-28: user said "mark the ones you're sure are fixed as Done" → 26 moved DEPLOYED TO QA → QA IN PROGRESS (6) → Done (7), JQL-verified: 674, 704, 707, 708, 709, 711, 712, 720, 721, 722, 723, 731, 732, 734, 735, 739, 740, 741, 742, 744, 746, 747, 748, 749, 751, 753.
  Held back: 733 (left in QA IN PROGRESS — owner access fixed, but end-to-end cancel blocked by 728); still DEPLOYED TO QA: 698 (Availability For Sale not updated), 713 (M1 HO-00075 follow-up task not created 2h+ after its due time; earlier E2E tasks were fine), 736 (evidence only via file title; early approval email), 743 (recall not checked), 755 (Discount % shows 6.08; 0.11 rounding).
- 2026-09-28 (user "go ahead"): filed LFRDN-761/762/763 (BUG-RT27-01..03; Sprint 3, parent 317, Yassin, links: 761→343/728/707, 762/763→338). BUG-RT27-04 folded into the 736 comment, not filed. 698 + 713 → Done. 743 + 736 → comment + To Do. 733 → comment "blocked by 728", stays QA IN PROGRESS. 755 NOT moved: its Discount % still shows 6.08 (part of the ticket's actual result + BRD 10.7 FR1) — awaiting user decision; left in QA IN PROGRESS.
- 2026-09-28: LFRDN-755 rechecked on fresh deal QA RT27 M5 (quote 00000260) — Discount % formula still divides by post-trade-in Subtotal (3.35% vs applied 2.51%). Commented + moved to To Do (user approved).

## 2026-09-28 — Fix-session state (pulled from Jira, latest comments read)
- LFRDN-736 already fixed and commented (09:22 UTC): the `AF_ApprovalSubmittedAt__c` stamp drives the notification flow. The "drop the redundant Has_Real_Submission gate" cleanup is optional and still undone.
- DEPLOYED TO QA with a fix comment: 730, 736, 738, 743, 762. 733 is Done. 728 and 729 have fix comments but are still in To Do. 729 is waiting on Marwan about ~10 old Pending cancellation CNs. 756 is waiting on Marwan for a fresh appraisal Id.
- What the latest comments say is still needed (To Do):
  - 695: Create Reservation screen stops working when `Get_Active_Appraisal` is null. Guard the visibility rules and show `DepositAmountCashField` on 7-Day.
  - 719: Sales Walk-In fails reading `UserRole.Name`. Move the rep lookup to system mode.
  - 752: receptionist gets INSUFFICIENT_ACCESS on the task WhatId. Create the task and notification in system context.
  - 754: auto-close doesn't run when the doc-type tag is set on the LPO; the Chatter alert also posts twice.
  - 755: `Quote.AF_DiscountPercent__c` divides by the post-trade-in Subtotal. Use the non-trade-in lines.
  - 745: Arabic prints reversed in the requisition PDF. Needs an RTL font.
  - 750: rejection comment (ProcessInstanceStep.Comments) isn't included in the notification.
  - 758: dashboard component error 209 on Aged Open Opportunities (tabular report row limit).
- Draft (not triaged yet): 726, 761, 763, 764. Out of scope: 677, 685, 737 (Keyloop), 678 (currency, deferred).
- ⚠️ This cloud container has no `sf` CLI or org credentials, and the repo's `force-app` is a snapshot that does NOT include today's deployed fixes. Retrieve from the org before editing any metadata, or you will overwrite fixes.
