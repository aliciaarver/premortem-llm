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
mitigations, spikes, and task skeletons for next steps. Skip this skill (proceed
normally instead) for: straight implementation requests, code review of existing
diffs (→ `/code-review`), design doc authoring, or QA on finished features. If the
user says "ok convinced, implement," exit premortem mode and switch to execution.

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
3. **Always include a mitigation** — a concrete action, not "be careful."
4. **Never approve without a concern** — even a solid, simple plan gets its one
   most-likely failure point named.
5. **Attack confident assumptions**, not easy strawmen — stress-test what the team
   treats as settled.

### Required format per concern

```
[SEVERITY] Concern #N: <short title>

What the plan assumes: <explicit assumption>
Why this might be wrong: <specific counter-evidence or failure path>
What happens if it is: <concrete impact — quantify when possible>
Mitigation: <specific action before or during implementation>
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

Blocking mitigations (must do before code): <bullets or "none">
Nice-to-have mitigations: <bullets or "none">
```

- **Yes with mitigations** — risks are addressable; blocking items must be done first.
- **No — rethink first** — a CRITICAL concern has no credible mitigation yet.
- **Needs spike** — unknowns too large; complete Step 3 spike before any implementation.

### Task splitting rule

If proceeding and the fix touches **3+ independent modules**, do not output one
monolithic task. Split into 2-4 ordered sub-tasks. Each sub-task after the first
must start its plan with:

```
1. Depends on: "<title of previous sub-task>"
```

### Optional task skeleton (only when Proceed = Yes with mitigations)

Check whether the repo has a task-tracking doc with structured fields (e.g. a
`TECH-LEAD.md`/`PM.md` describing a specialist/complexity/analysis/plan format for
task cards, as in the ai-dashboard convention). If it does, match that format —
example shape below. If not, output a plain plan instead: a short title, a few
sentences of analysis, and numbered steps — no forced fields.

```
### [Tech Debt] <short title>
- What's broken: <current pain in one line>
- Fix direction: <direction, not full implementation>
- Urgency: critical | high | medium | low
- Specialist: frontend | backend | fullstack
- Complexity: simple | medium | complex

**Analysis:**
2-5 sentences: which files/modules/endpoints, what the spike showed, what must not regress.

**Plan:**
1. <concrete step>
2. ...
```

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
> Mitigation: Key the cache by a hash of the token/permission set, not just the
> endpoint, so a permission change invalidates it immediately.

**Bad concern (reject this style):**

> [MEDIUM] Concern: Caching might cause issues over time.
