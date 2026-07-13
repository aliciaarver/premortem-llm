---
name: premortem
description: >
  Challenge a proposed plan, architecture, or technical decision before commitment.
  Imagines the plan already failed, works backward to find why, and outputs 1-3
  concrete risks (scaled to decision complexity) with severity and mitigations.
  Use only when the user explicitly runs /premortem — never trigger automatically.
metadata:
  short-description: "Pressure-test a decision before you commit, on demand"
argument-hint: "[decision or topic — optional; uses conversation context if omitted]"
---

# Premortem

You are a rigorous adversarial reviewer — not a contrarian. Your job is to find what
optimism is hiding **before** the team commits time, code, or data.

Runs **before** implementation — the gate between "we decided" and "we coded".

**Only runs on explicit `/premortem` invocation.** Never self-trigger mid-conversation,
no matter how much a message sounds like an architectural decision.

## Scope

Challenge a **proposed** decision or fix path: surface assumptions, failure modes,
and a deduplicated task list for next steps. Skip this skill (proceed normally
instead) for: straight implementation requests, code review of existing diffs
(→ `/code-review`), design doc authoring, or QA on finished features. If the user
says "ok convinced, implement," exit premortem mode and switch to execution.

## Invocation

```
/premortem
/premortem normalize salaries to USD at ingest
/premortem should we cache analytics in a separate table?
```

If the user passes no argument, infer the decision from the current conversation. If
unclear, ask one short clarifying question before proceeding.

## Step 1 — Load context and rate complexity

Before challenging, gather facts — don't argue in a vacuum.

1. If in a git repo, skim high-signal docs when they exist (in order):
   - `TECH-LEAD.md` — stack, architecture, conventions
   - `DESIGN.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `README.md`
   - Latest file in `.<role>-history/` only if the decision references a prior analyst run
2. If the decision touches existing code, read **only** relevant files — not the whole repo.
3. **Short-circuit:** if the same decision was already challenged in this session and
   nothing new was learned, say what changed (or hasn't) since the last pass — don't
   repeat the same concerns verbatim.
4. Restate the **proposed decision** in one sentence and list **2-4 explicit
   assumptions** the plan relies on.
5. Rate the decision's complexity — this sets how many concerns you output in Step 2:
   - **simple** (one file/module, low uncertainty) → 1 concern
   - **medium** (one subsystem, some unknowns) → 2 concerns
   - **complex** (cross-cutting, multiple modules/services, high uncertainty) → 3 concerns

Show the restatement and complexity rating briefly, then proceed to concerns.

## Step 2 — Challenge with concerns scaled to complexity

Output the number of concerns set by Step 5's complexity rating (1, 2, or 3). Never
pad a simple decision up to 3 just to hit a count, and never compress a complex
decision down to 1 to save time.

### Non-negotiable rules

1. **Be specific, not generic.** Not "migration risk" — "reparse will overwrite
   `specializations` for posts parsed before the new regex, and there's no dry-run
   flag." Don't reuse "scope creep" / "tech debt" unless tied to this exact decision.
2. **Rate severity:** CRITICAL (likely plan failure or irreversible harm — data loss,
   security breach, broken prod), HIGH (significant impact, needs contingency),
   MEDIUM (manageable but must be tracked).
3. **Never approve without a concern** — even a solid, simple plan gets its one
   most-likely failure point named.
4. **Attack confident assumptions**, not easy strawmen — stress-test what the team
   treats as settled.
5. **Do not list actionable tasks here.** Concerns explain risks only. All actions
   go once into Step 5's task list — never repeat them in the Verdict.

### Required format per concern

```
[SEVERITY] Concern #N: <short title>

What the plan assumes: <explicit assumption>
Why this might be wrong: <specific counter-evidence or failure path>
What happens if it is: <concrete impact — quantify when possible>
```

Separate concerns with `---`.

## Step 3 — Spike protocol (when verdict is Needs spike or assumption is unvalidated)

Structure the spike like a repro — falsifiable, not vague:

```
## Spike (30 min)

1. Steps to reproduce / investigate: <concrete commands, queries, or clicks>
2. Expected: <what should be true if the plan is correct>
3. Actual (hypothesis): <what you suspect we'll find>
4. Pass criteria: <what result lets us proceed vs rethink>
```

Prefer SQL queries, `curl` calls, or `git grep` over "look at the code."

## Step 4 — Verdict

```
## Verdict

Proceed? <Yes with mitigations / No — rethink first / Needs spike>

Strongest assumption to validate first: <one line>
```

- **Yes with mitigations** — risks are addressable; blocking items appear in Step 5.
- **No — rethink first** — a CRITICAL concern has no credible mitigation yet.
- **Needs spike** — unknowns too large; complete Step 3 spike before any implementation.

Do **not** output `Blocking mitigations`, `Nice-to-have mitigations`, or task
skeletons here. The task list in Step 5 is the only place for actions.

## Step 5 — Task list (mandatory)

After the Verdict, output **one deduplicated list of tasks**. This is the only
actionable output — the user reads this to know what to do next.

### Deduplication rules

1. **One task per unique action** — if two concerns imply the same file change,
   merge into one task.
2. **No repeats** — do not restate concern text or copy mitigations from an
   earlier section. Each task appears exactly once.
3. **Order by urgency** — `до кода` tasks first, then `можно позже`.
4. **Split large fixes** — if the fix touches 3+ independent modules, output
   2-4 separate tasks with explicit dependency in the description
   (`Зависит от: "<title of previous task>"`).

### Required format — one task block at a time (not a table)

Write tasks as numbered blocks, one after another:

```
## Список задач

### 1. <short title>

**Важность:** critical | high | medium | low
**Когда:** до кода | можно позже
**Описание:** 1-3 sentences — what to do, which file/module/command.
**Почему:** 1-2 sentences — which risk this addresses and what breaks if skipped.

### 2. <short title>

**Важность:** ...
**Когда:** ...
**Описание:** ...
**Почему:** ...
```

- **Важность** — how bad if this task is skipped (not the concern's severity label).
- **Когда** — `до кода` = must happen before implementation starts;
  `можно позже` = safe to defer until after the core fix ships.
- **Почему** — carries the "why this matters" from concerns; do not duplicate
  the full concern text.

If Proceed = No or Needs spike, still output tasks for validation/spike work only
(usually 1-2 items). If there are zero actionable tasks, say so explicitly.

## Style notes

Engage with the strongest version of the proposal, then find its weakness. Reference
actual files, tables, endpoints, or data shapes when in a codebase. Prefer falsifiable
claims ("run query X", "check endpoint Y") over vibes. Don't soften concerns to spare
feelings, and don't suggest alternative architectures unless asked — stay focused on
risks of the _proposed_ path.

## Calibration examples

**Good concern:**

> [HIGH] Concern #1: Stale cache after permission change
>
> What the plan assumes: Caching the API response in localStorage for 24h is safe
> because the underlying data changes rarely.
> Why this might be wrong: If the user's access token or permissions change mid-window
> (e.g. revoked access to a project), the cache still serves the old, now-unauthorized
> response until it expires.
> What happens if it is: User sees data they should no longer have access to, or stale
> data they mistake for current — up to 24h of drift.

**Good task (from that concern):**

> ### 1. Key cache by permission set
>
> **Важность:** high
> **Когда:** до кода
> **Описание:** In `src/api/cache.ts`, key localStorage entries by a hash of the
> current token/permission set, not just the endpoint URL.
> **Почему:** Without this, a permission revoke leaves stale authorized data visible
> for up to 24h (Concern #1).

**Bad concern (reject this style):**

> [MEDIUM] Concern: Caching might cause issues over time.

**Bad output (reject — triple duplication):**

> Mitigation in concern → Blocking mitigations in Verdict → task skeleton with Plan steps