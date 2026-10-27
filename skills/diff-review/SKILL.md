---
name: diff-review
description: >
  Review uncommitted changes (or one given commit) like a strict project
  reviewer: only changed files, narrow per-file diffs, the project's own rules
  (discovered across Codex, Claude, Grok, Cursor and other agents' rule files), a
  fixed checklist, and static checks (lint, typecheck, build). Outputs a green/red verdict and a file:line list of findings.
  Read-only — never edits code, never runs tests, never pushes.
  Use only when the user explicitly runs /diff-review — never trigger automatically.
metadata:
  short-description: "Strict read-only review of uncommitted changes or one commit"
argument-hint: "[commit id | task description — optional]"
---

# Diff Review

You are a code reviewer. Your job is to say **"годно" or "доработать"** about the
current changes, with concrete file:line findings — not to fix them.

**Only runs on explicit `/diff-review` invocation.** Never self-trigger.

## Invocation

```
/diff-review
/diff-review a1b2c3d
/diff-review добавить экспорт отчёта в CSV
```

The argument is optional:

- Resolves to a commit (`git rev-parse --verify --quiet '<arg>^{commit}'` succeeds) →
  **commit mode**: review only that commit's changes. Take the task from its message.
- Otherwise, non-empty → **uncommitted mode**, and the text is the task description
  (what the change was supposed to do).
- Empty → **uncommitted mode**; take the task from the conversation or the branch name.

## Hard limits

- **Do not edit files**, do not commit, do not push, do not rebase, do not `git switch`.
- **Do not write or run tests** — that is QA's job. Static checks only.
- **Do not open the app** or call its endpoints.
- **Do not review files outside the diff.** Neighbouring files only for a few lines
  of context around a changed line, plus the one reference example per kind of
  change from Step 2c.
- Do not judge product decisions or propose alternative architectures beyond what
  the project rules require.

## Step 1 — Diff scope

1. File list:
   - **uncommitted mode**: `git diff HEAD --name-only` (staged + unstaged) and
     `git ls-files --others --exclude-standard` (new untracked files). Review the union.
     Committed work is out of scope, even on a feature branch.
   - **commit mode** (`$C` = full hash): `git show --name-only --format= $C`. For a
     merge commit use `git diff $C^1 $C --name-only` (what the merge brought in).
     Uncommitted changes are out of scope.
2. If the diff is empty — say so and stop (uncommitted mode: "нет незакоммиченных
   изменений; для коммита — `/diff-review <id>`").
3. Skip generated noise when reading (lockfiles, `dist/`, snapshots), but still flag
   it under "Файловый шум" if it shouldn't be there.

## Step 2 — Load project rules (only what the diff touches)

You don't know in advance where this project keeps its rules or which agent they
were written for. Discover first, then read.

### 2a. Discover rule files for every agent

**Explicit paths first.** The user may point at rules that live anywhere, via
`AI_RULES` — comma-separated files and/or folders, relative to the project root:

```bash
grep -hE '^[[:space:]]*AI_RULES=' .env .env.local 2>/dev/null
```

Read **only this key** — `.env` holds secrets; never print or load the rest. `.env.local`
wins over `.env`; missing in both → `$AI_RULES` from the shell; still missing → none.
Never edit `.env`. A listed path that doesn't exist → say so in the report.
`AI_RULES` set → its paths are rule sources, **added** to what the search below finds
(root agent files load anyway). Folders from it: see "Rule folders" in 2b.

**Then search** for the usual places:

Run once from the repo root:

```bash
find . \( -name node_modules -o -name .git -o -name dist -o -name build \
  -o -name .next -o -name vendor -o -name .venv \
  -o -path '*/.agents/skills' -o -path '*/.claude/skills' -o -path '*/.cursor/skills' \
  -o -path '*/.codex/skills' -o -path '*/.grok/skills' \) -prune -o -type f \( \
  -name AGENTS.md -o -name AGENTS.override.md \
  -o -name CLAUDE.md -o -name CLAUDE.local.md \
  -o -name GROK.md -o -name GEMINI.md \
  -o -name .cursorrules -o -name .windsurfrules -o -name .clinerules \
  -o -name copilot-instructions.md -o -name '*.instructions.md' \
  -o -path '*/.cursor/rules/*' -o -path '*/.claude/rules/*' \
  -o -path '*/.grok/*.md' -o -path '*/.codex/*.md' -o -path '*/.windsurf/rules/*' \
  -o -path './rules/*' -o -path './docs/rules/*' \
  -o -name CONTRIBUTING.md -o -name TECH-LEAD.md -o -name ARCHITECTURE.md \
\) ! -name .DS_Store -print
```

Where each agent keeps rules (all count equally — the project may use any mix):

| Agent | Files |
| --- | --- |
| Codex | `AGENTS.md`, `AGENTS.override.md` (root and nested), `.codex/*.md` |
| Claude | `CLAUDE.md`, `CLAUDE.local.md` (root and nested), `.claude/rules/*.md` |
| Grok | `GROK.md`, `.grok/*.md` (e.g. `.grok/GROK.md`) |
| Cursor | `.cursor/rules/**/*.mdc` / `*.md`, legacy `.cursorrules` |
| Others | `GEMINI.md`, `.windsurfrules`, `.windsurf/rules/`, `.clinerules`, `.github/copilot-instructions.md`, `.github/instructions/*.instructions.md` |
| Project-own | `rules/**`, `docs/rules/**`, `CONTRIBUTING.md`, `TECH-LEAD.md`, `ARCHITECTURE.md` |

Skill folders (`.agents/skills`, `.claude/skills`, …) are pruned on purpose: an
`AGENTS.md` inside an installed skill is that skill's content, not a project rule.

Print the discovered list in the report (`Правила:` line). If nothing is found,
say "файлов правил нет" and go to Step 2c for every change. Also add one line to the
report: "Правила лежат в другом месте? Добавь в `.env.local`:
`AI_RULES=<папка или файл>`".

### 2b. Pick what applies to this diff

Read only once per session, and only files relevant to the changed paths:

- **Root-level** agent files (`AGENTS.md`, `CLAUDE.md`, `GROK.md`, `.cursorrules`, …) —
  always read; they hold project-wide invariants.
- **Nested** agent files (`frontend/AGENTS.md`, `backend/CLAUDE.md`, …) — read only if
  a changed file lives in that directory or below it. Deeper file wins on conflict.
- **Cursor `.mdc`** — read the frontmatter first: `alwaysApply: true` → apply;
  `globs:` → apply only if a changed file matches; only `description:` → apply if
  the description fits the diff. Same for `applyTo:` in `*.instructions.md`.
- **Rule folders** (from `AI_RULES`, a reference in a rule file, or `rules/`) of any
  name: small (≈300 lines total, `cat <dir>/**/*.md* | wc -l`) → read all. Larger →
  list the files, read each one's frontmatter or first heading, then read fully only
  those that fit this diff.
- **`rules/`-style folders** — pick by area: frontend diff → frontend rules (and the
  stack subfolder, e.g. `vue/` or `react/`); backend diff → backend rules; fullstack →
  both. Plus general files like `self-check.md`, `commits.md`, `typescript.md`.
- **Reviewer-specific rules** (`rules/reviewer.md`, `.cursor/rules/*review*`, a
  "Review" section in any agent file) — override this checklist where they conflict,
  except the hard limits above: still no edits, no push, no card moves.
- The same content is often duplicated across agents (e.g. `AGENTS.md` and
  `CLAUDE.md` with the same text, or `CLAUDE.md` just saying "see AGENTS.md") —
  follow the reference, read the duplicate once. If two agents' files genuinely
  contradict each other, note it as a minor finding, don't pick a side silently.

- **Files a rule points to** — if a rule file names other files as mandatory
  context ("follow `.doc/vision.md`", "see `docs/architecture.md`", "rules are in
  `standards/`"), read those too — this is how rules in a folder of any name get found —
  only the parts relevant to the diff. One level deep: don't follow links inside
  them. If the rule says which wins on conflict, respect it.
- **Project skills** — if a rule says to apply skills from a folder (e.g. "apply
  skills from `.agents/skills` when relevant"), list `<dir>/*/SKILL.md` and read only
  their frontmatter (`name`, `description`). Read the body of a skill only when its
  description fits this diff (FSD skill → files moved between layers; UI-kit skill →
  new components), and only the relevant sections. Never read a skill's bundled
  references wholesale (a skill's own `AGENTS.md` can be thousands of lines) — open
  one only to check a specific point. No rule mentions skills → ignore the folder.

Skip tool-specific instructions that don't concern code (how to run the agent,
tracker tokens, terminal setup). Take only what applies to this diff. Don't quote
rules back.

### 2c. No rule for it → learn from one existing example

Rules win when they exist. When there are no rule files, or the rules say nothing
about this kind of change (e.g. the diff adds an API endpoint and no rule describes
how endpoints are written), take the convention from how the project already does
the same thing — from **one** place, not the whole repo.

1. Name the kind of change: new endpoint, new component, new DB query/migration,
   new store/hook, new test, new config entry, etc.
2. Find **one** closest existing example of the same kind, which is not part of the
   diff. Prefer, in order:
   - a sibling in the same folder (`routes/users.ts` for a new `routes/orders.ts`);
   - the same kind of thing in the nearest parent module;
   - the most recently changed example (`git log -1 --format=%H -- <path>`), since
     old code may follow outdated conventions.
   Use a narrow search (`ls` of the folder, `git grep -l '<pattern>' -- <dir>`),
   not a repo-wide scan.
3. Read only the relevant part of that one example and note what it does:
   file placement and naming, how it's registered/wired (router, index, DI),
   validation, error handling and response shape, logging, typing, the helpers
   and shared utilities it reuses, whether it has a test next to it.
4. Compare the diff against that example. Deviations become findings, pointing to
   both places: "`routes/orders.ts:12` — no Zod validation of the body; next to
   it `routes/users.ts:8` validates with `userSchema.safeParse`. Do the same."
   A diff that re-implements a helper the example already uses is a finding too.
5. If the examples you find disagree with each other, there is no convention —
   don't invent one and don't raise a finding for it.
6. If there is no similar code at all (the first endpoint in the project) — say
   so; review that part only against the general checklist.

In the report, list which example was used for each kind of change:
`Образец: routes/users.ts (для нового эндпоинта)`.

## Step 3 — Read the diff narrowly

For each file:

- uncommitted mode: `git diff HEAD -- <file>`; an untracked file is new — read it whole.
- commit mode: `git show $C -- <file>` (merge: `git diff $C^1 $C -- <file>`).

Don't read whole files otherwise — for context use `sed -n 'N,Mp' <file>` (commit
mode: `git show $C:<file> | sed -n 'N,Mp'`, since the working tree may have moved on).

## Step 4 — Checklist

Go through every item; each finding must point to a file and line.

- **Соответствие задаче** — the change does what the task says, no more. No stray scope,
  no unrelated refactors.
- **Архитектура** — project layering and invariants from the rules (e.g. FSD layers,
  alias imports, no cycles on the frontend; secrets stay on the backend, routes and
  facades where the rules say).
- **Корректность** — obvious bugs visible in the diff: wrong condition, missing
  `await`, unhandled promise, null/empty cases, off-by-one, broken error path.
- **Типизация** — new code is typed; no bare `any`, `@ts-ignore`, or `as unknown as`
  without a reason in a comment.
- **Стили** (UI) — existing classes/tokens, no hardcoded colors/sizes when variables exist.
- **Безопасность** — no tokens/secrets in code or logs, `.env`/credentials not
  committed, no `console.log` with user data, input validated at the boundary.
- **Чистота** — no commented-out code, dead code, orphan imports, debug leftovers,
  or comments that just restate the code.
- **Размер файлов** — changed files over ~300 lines (or the project's limit) flagged
  if the diff made them grow.
- **Тесты** — if the rules or the task require tests for this kind of change, check
  they exist in the diff (happy path + key edge cases). Do not run them.
- **Коммиты** (commit mode only) — the message follows `rules/commits.md` (or the
  repo's visible convention).
- **Файловый шум** — no build output, caches, `.DS_Store`, stray lockfile changes,
  or merge-conflict markers.

## Step 5 — Static checks

Find scripts: `node -e "console.log(JSON.stringify(require('./package.json').scripts))"`
(and in `frontend/` / `backend/` if they have their own `package.json`). Run what
exists among `lint`, `typecheck`, `tsc`/`tsc --noEmit`, `build`. For other stacks use
the obvious equivalent (`ruff`/`mypy`, `cargo check`, `go vet`) only if configured.

- Don't install dependencies or change config to make a check run. If a check can't
  run (no `node_modules`, sandbox blocks it) — report it as "не прогнал: <why>", not
  as a failure.
- Commit mode: checks run on the current working tree, not on that commit. If `HEAD`
  is not `$C` or there are uncommitted changes, say so next to the results, and count
  only errors on lines that commit changed. Don't check out `$C` to rerun.
- Errors only in files outside the diff are pre-existing, not this diff's fault —
  mention them separately and don't count them against the verdict. Don't
  `git stash` or check out the base to verify.

## Step 6 — Report

Answer in the user's language. Format:

```
## Ревью: незакоммиченные изменения | коммит <short hash> «<subject>»

Смотрел: <N файлов>
Правила: <which rule files were applied, or "нет">
Образец: <reference example per kind of change from Step 2c, if used>
Статика: lint ✅ | tsc ❌ (3 ошибки) | build — не прогнал: нет node_modules

## Вердикт: ✅ Годно | ❌ Доработать

## Замечания

1. [blocker] `path/to/file.ts:42` — что не так.
   Нужно: что сделать.
2. [major] ...
3. [minor] ...
```

Severity:

- **blocker** — static check failed on changed code, bug, security issue, broken
  architecture invariant, or task not done. Any blocker → ❌.
- **major** — rule violation that must be fixed before merge (typing, dead code,
  file noise, missing required tests). Any major → ❌.
- **minor** — style nits that don't block. Minors alone → ✅.

Rules for findings:

- Concrete, no vague wording: not "improve error handling" — "`api/user.ts:57`
  `fetchUser` swallows the 404 and returns `{}`; the UI then renders an empty profile.
  Throw or return `null`."
- One finding per unique problem; if the same issue repeats, list it once with all
  locations.
- No praise section, no summary of what the code does.
- Zero findings → say "Замечаний нет" and give ✅.

Finish with nothing else. Don't offer to fix unless the user asks.
