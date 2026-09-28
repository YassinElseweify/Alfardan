# Retest — <KEY> bugs in "<status>" (<YYYY-MM-DD>)

**Scope:** the <n> <KEY> bugs in status *<status>* on <date>.
**How:** Lightning UI as <persona> on fresh records. Admin used only for <setup / access checks / reading generated files>.
**Retest records:** <customer / deal names and ids>.
**Screenshots:** `screenshots/RETEST-<YYYY-MM-DD>/`

## Verdicts

| Ticket | Verdict | Evidence |
|---|---|---|
| <KEY-1> <short title> | **Fixed** | <what was done and seen>. `<screenshot>` |
| <KEY-2> <short title> | **Partially fixed → To Do** | <what works now>; <what still fails, literal message>. |
| <KEY-3> <short title> | **Not fixed → To Do** | … |
| <KEY-4> <short title> | **Fixed, with a regression** | <…>; regression tracked in <KEY-n>. |

**Totals:** <n> fixed · <n> moved back to To Do (<keys>).
Each ticket moved back has a comment and went <path of transitions>.

## Moved to Done

<n> clean fixes went <path>: <keys>.
Fixed tickets left open, and why:
- <KEY>: <open BA question / edge case / backfill>.

## New findings during the retest

- <regression or new bug> — drafted as <BUG id> / commented on <KEY>.
