# {{[STORY-ID]}} {{Story Name}} — QA report

**Tested:** {{DATE}}
**Org:** `{{INSTANCE_URL}}`
**Personas used:** {{list, and note any admin substitutions}}
**Harnesses:** API (persona MCP connections) · Lightning UI (Playwright) · `sf` CLI (schema/metadata)
**Test cases:** {{n}} in `test-cases/{{file}}`

---

## Section 1 — Summary of what was done

{{What was tested, as a business statement of the story. Which personas
drove it. Which harness proved what. How many test cases ran, how many
were added during execution. The headline verdict in one or two
sentences — what works, what does not.}}

| | |
|---|---|
| Test cases executed | {{n}} ({{n}} written + {{n}} added) |
| Passed / Failed / Partial / Not verified | {{n}} / {{n}} / {{n}} / {{n}} |
| Bugs raised | {{n}} — see `tickets/{{STORY}}/README.md` |
| BA gaps raised | {{n}} |

---

## Section 2 — Test cases executed

| TC | What it tests | Result | Finding |
|---|---|---|---|
| TC-001 | {{the behaviour under test, in one line}} | PASS | {{evidence: record id / screenshot}} |
| TC-002 | {{…}} | FAIL | {{BUG-STORY-01}} — {{one line + literal error}} |
| TC-003 | {{…}} | PARTIAL | {{what passed, what didn't}} |
| TC-004 | {{…}} | Not verified | {{why}} |
| TC-0xx *(added)* | {{gap in the written suite this covers}} | {{…}} | {{…}} |

Verdicts: `PASS` / `FAIL` / `PARTIAL` / `Not verified`.
Every row carries concrete evidence — record id, exact error text,
screenshot filename. "Works as expected" is not a finding.

### Not independently verified

Named, with the reason, so the user knows exactly what still needs a
human:

- **TC-0xx** — {{Lightning dashboard component / real mailbox delivery /
  profile access not queryable / persona has no UI login}}

---

## Section 3 — BA / requirement gaps

Things **not specified**. The build cannot be called wrong because the
documents never said what right was. These need a **business decision,
not a developer** — never mix them in with the bugs.

### GAP-{{STORY}}-01 — {{what is undefined}}

**The situation:** …

**What the documents say:** BRD p. {{n}}, {{§}} — *"{{quote}}"*;
Solution Design p. {{n}}, {{§}} — *"{{quote}}"*. {{Where they fall
silent, or contradict each other.}}

**Decision needed from:** {{BA / business owner}} — {{the specific
question}}

---

## Section 4 — Walkthrough by functional requirement and acceptance criterion

Organised by requirement, not by test case. Everything below can be
replayed by hand in the org.

### FR{{n}} — {{requirement text, quoted from the BRD}}

**What I did**

1. Logged in as {{persona}} → {{App}} → {{tab}} → {{list view}}.
2. {{Click path: menu → action → option}}.
3. {{API call made, where the check was API-side:
   `salesforce_dml_records` on `{{Object}}` with {{fields}}.}}

**Records used / created**

| Record | Id | Purpose |
|---|---|---|
| {{Name}} | `{{Id}}` | {{what it demonstrates}} |

**What happened:** {{observed behaviour}}

**Verdict:** {{PASS — meets FR{{n}} | FAIL}}

> ⚠️ **Bug hit here:** at step {{n}} you will see:
> ```
> {{literal error text}}
> ```
> This is **BUG-{{STORY}}-{{NN}}**.

### AC{{n}} — {{acceptance criterion text, quoted}}

{{Same shape: steps, records, what happened, verdict, bug flagged at the
step where it appears.}}

---

## Section 5 — Hands-on: run the story yourself

### What this story is, and how it was built

{{Plain explanation of the business process the story describes, then
how the org actually implements it — which objects, which automation,
which gates. Enough that the user understands the implementation, not
just the verdict.}}

### Records created for you

All named `DEMO {{STORY-ID}} NN - <purpose>` — search that prefix and
all of them come back. Each is clean (no child records) and owned by the
persona who would really own it.

| # | Record | Id | Owner (persona) | Scenario it is for |
|---|---|---|---|---|
| 01 | DEMO {{STORY}} 01 - happy path | `{{Id}}` | {{persona}} | {{FR/AC}} |
| 02 | DEMO {{STORY}} 02 - {{negative case}} | `{{Id}}` | {{persona}} | {{FR/AC}} |
| 03 | DEMO {{STORY}} 03 - {{defect repro}} | `{{Id}}` | {{persona}} | {{BUG-…}} |

### How to log in

- **App:** {{App name}}
- **Persona:** {{username}} / {{password}}
- **Login friction to expect:** {{forced password change → click Cancel /
  2FA / none}}

### What to do, step by step

**{{FR/AC}} — use record {{DEMO … 01}}**
1. {{Click path}}
2. {{Action}}
- **You should see:** {{expected — with the actual figures/field values}}
- **You will actually see:** {{what the defect does, verbatim}} → **BUG-{{STORY}}-{{NN}}**

{{Repeat per FR/AC.}}

### Scorecard — fill in as you go

| # | What you are checking | Record | Expected | Matches? |
|---|---|---|---|---|
| 1 | {{FR1}} | DEMO {{STORY}} 01 | {{expected}} | ☐ |
| 2 | {{FR2}} | DEMO {{STORY}} 02 | {{expected}} | ☐ |

---

## Records left in the org as evidence

Not cleaned up, deliberately, so findings can be re-checked:

- `{{Id}}` — {{what it demonstrates}}

## Org configuration changed during testing

Anything altered in the org itself, so it can be reviewed or reverted:

- {{change}} — {{why, and who authorized it}}
