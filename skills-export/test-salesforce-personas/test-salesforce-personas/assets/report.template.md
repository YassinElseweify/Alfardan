# <STORY-ID> — <story title> — test report

**Date:** <YYYY-MM-DD> · **Org:** <sandbox> · **Personas:** <list>
**Tickets:** `tickets/<STORY-ID>/README.md` · **Screenshots:** `screenshots/<STORY-ID>/`

---

## Section 1 — Summary of what was done

- **Tested:** <FRs / ACs / test cases>, as <personas>, API + UI.
- **Ran:** <n> test cases (<n> added during execution): <n> pass · <n> fail · <n> partial · <n> not verified.
- **Substitutions:** <steps done as admin / via the persona's API because … — or "none">.
- **Verdict:** <one or two sentences>.

## Section 2 — Test cases executed

| TC | What it tests | Result | Evidence / finding |
|---|---|---|---|
| <STORY>-TC-001 | … | **PASS** | … |
| <STORY>-TC-002 | … | **FAIL** | "<literal message>" on <record> (`id`) — **BUG-<STORY>-01** |
| <STORY>-TC-0nn *(added)* | … | … | … |

**Not independently verified:**
- <item> — <why>.

## Section 3 — BA gaps to raise

1. **<What is undefined>.** <Where the documents are silent / disagree, with quotes>. **Decision needed:** <what, from whom>.

## Section 4 — Walkthrough by requirement

### FR1 — <requirement, short>
- **Did:** <persona> → <click path> on <record> (`id`).
- **Saw:** <result>. **FR1: PASS / FAIL.**
- At step <n> you will see "<literal error>" — **BUG-<STORY>-01**.

### AC1 — …

## Section 5 — Hands-on

**How it works:** <plain explanation of the story and its implementation>.

**Logins:** <persona> (`username`) in the <app> app. Passwords: qa-notes. *Change Your Password* → Cancel.

| Record (search "DEMO <STORY>") | Scenario | Persona |
|---|---|---|
| DEMO <STORY> H01 - <purpose> | … | … |

**Run it:**
1. **H01 — <scenario>.** <click path>. *Expect:* <result, figures>. *You will see:* <actual, if a bug>.

| # | Step | Expected | You saw | Ticket |
|---|---|---|---|---|
| 1 | | | | |

---

## Records left in the org
| Record | State |
|---|---|

## Org configuration changed during testing
- <change> — reverted <when>. (or "None")
