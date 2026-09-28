# <STORY-ID> — <story title> — bug tickets

**Found during:** QA testing of <STORY-ID>, <YYYY-MM-DD>
**Org:** `<url>` · **Report:** `reports/<STORY-ID>-report.md` · **Screenshots:** `screenshots/<STORY-ID>/`
**Status:** Draft — not yet in Jira. Review by id; nothing is filed until approved.

> **Reproducible in the Lightning UI.**
> - <Persona>: `<username>` (<app> app)
>
> Login is <one/two>-step. Dismiss *Change Your Password* with **Cancel**.

When approved, each is raised in **<KEY>** as a Bug, assigned to **<name>**, parent **<EPIC>**,
labels <labels>, linked *relates to* <story ticket>.

## Summary

<What the defect set means for the business, in two or three short paragraphs.>

| ID | Title | Priority | Affects |
|---|---|---|---|
| BUG-<STORY>-01 | <plain-language failure> | High | <Persona> (persona-specific; admin unaffected) |
| BUG-<STORY>-02 | … | Medium | General — reproduced as System Administrator |

### Already tracked — new evidence, no new ticket

| Jira | What we saw | New evidence to add as a comment |
|---|---|---|

---

## BUG-<STORY>-01 — <plain-language failure> (High)

**Module:** <area — sub-area>
**Applies to:** <who; how many times reproduced; admin result>

### Description

<Plain language: what is broken, what it means for the user/business.>

### Steps to Reproduce

1. Log in as <persona> → <app> → <record name> (`id`).
2. <menu> → <action> → <field> **<value>** → **<button>**.

### Expected Result

<What the requirement says.>

### Actual Result

> <literal on-screen message>

- <read-back values, record ids, number of reproductions>

### Root Cause

**Confirmed from <flow XML / validation rule / Apex / debug log `07L…` / UserRecordAccess>.**
- <mechanism>

### Proposed Solution

1. <fix>

### Reference

- **BRD** §<x.y>, p.<nn>, FR<n> — *"<exact quote>"*

**Screenshots:** `<nn-what>.png`
