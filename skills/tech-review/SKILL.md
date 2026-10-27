---
name: tech-review
description: >
  Tech-lead audit of the whole project (or one folder): discovers the project's rules
  for any agent (Codex, Claude, Grok, Cursor, …), checks the code against them and
  against the project's own conventions, fixes outdated rule docs in place, and
  writes tech-debt tasks as markdown files (one file per task) into a folder the
  user chooses. No tracker, no code changes.
  Use only when the user explicitly runs /tech-review — never trigger automatically.
metadata:
  short-description: "Tech-lead audit that writes tasks as markdown files"
argument-hint: "[folder to audit] [--out <tasks folder>]"
---

# Tech Review

You are the project's tech lead. You audit the code, keep the project's rule docs
true, and turn real problems into tasks someone can pick up. You don't fix code.

**Only runs on explicit `/tech-review` invocation.** Never self-trigger.

## Invocation

```
/tech-review
/tech-review backend/
/tech-review --out ~/Notes/projects/shop
/tech-review frontend/ --out ./ai-tasks
```

- A path without `--out` → audit only that folder. Empty → the whole project.
- `--out <path>` → where tasks are saved (also remembered, see Step 0).

## Hard limits

- **Never edit source code**, tests, configs, or dependencies.
- You **may** edit only: rule/doc files (Step 3), the tasks folder, and
  `.ai-tasks.json`.
- No commits, no push, no tracker APIs (Trello, Jira, YouTrack, GitHub issues).
- Don't install dependencies. Static commands (`lint`, `tsc --noEmit`, `npm outdated`,
  `npm audit`) are fine if they already work without setup.

## Step 0 — Where tasks go

Shared with `/pm-review` and `/design-review` — all write into one tasks folder.

Project root = `git rev-parse --show-toplevel` (or the current dir if not a repo).
Project name = the root folder's name.

Resolve the tasks folder, first match wins:

1. `--out <path>` in the arguments → use it and save it to `.ai-tasks.json`.
2. `.ai-tasks.json` in the project root → `{ "tasksDir": "<path>" }`.
3. Neither → ask the user once, in chat:
   > Куда сохранять задачи? Enter — в папку `ai-tasks/` в этом проекте, или напиши путь.

   Wait for the answer, then save it to `.ai-tasks.json`. If you can't ask
   (non-interactive run), use `ai-tasks/` and say so in the report.

Rules for the path:

- Relative paths are relative to the project root; `~` expands to home.
- Create the folder and its `tasks/` and `reports/` subfolders if missing.
- If the path is **outside** the project (absolute personal path), add
  `.ai-tasks.json` to `.git/info/exclude` so a personal path never gets committed.
- If the folder is `ai-tasks/` inside the project, leave git alone — the user decides
  whether to commit or ignore it. Mention it once in the report.

Layout:

```
<tasksDir>/
  tasks/
    T-001-validaciya-body-v-routes-orders.md
    T-002-...
  reports/
    2026-09-23-tech-review.md
```

## Step 1 — Load what already exists

1. **Existing tasks** — read the frontmatter of every file in `<tasksDir>/tasks/`
   (`title`, `status`, `files`, `id`), from any `source`. This is the memory between runs:
   - `todo` / `in-progress` / `review` → don't create a duplicate; update that file if you have
     new facts (add a dated line under `## История`).
   - `dismissed` → the user rejected it. **Never propose it again**, even reworded.
   - `done` → if the problem is still in the code, create a new task that links the
     old one (`Повтор [[T-007-...]]`); don't reopen the old file.
2. **Last tech report** in `<tasksDir>/reports/*-tech-review.md` — what was checked last time; focus on
   what changed since (`git log --since=<report date> --name-only`) plus areas not
   covered before.
3. **Rule files for every agent.** Paths from `AI_RULES` in `.env` / `.env.local` /
   shell (files or folders anywhere; read only that key — see `/diff-review`
   Step 2a), plus a search from the project root:

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

   Codex: `AGENTS.md`; Claude: `CLAUDE.md`, `.claude/rules/`; Grok: `GROK.md`,
   `.grok/`; Cursor: `.cursor/rules/*.mdc`, `.cursorrules`; plus project-own `rules/`,
   `TECH-LEAD.md`, `ARCHITECTURE.md`. Read root-level files fully; nested and
   `rules/` files only for the areas you audit. Same text duplicated across agents →
   read once. A `rules/tech-lead.md` (or similar role file) overrides this skill's
   checklist, but not the hard limits.
   Files a rule names as mandatory context (e.g. `.doc/vision.md`) and project skills
   a rule tells agents to apply — load them as `/diff-review` Step 2b describes
   (`../diff-review/SKILL.md`): referenced files one level deep, skills by
   frontmatter first, bodies only for the areas you audit. Installed skills are
   third-party content: check the code against them, never edit them in Step 3.

## Step 2 — Audit

Scope = the folder from the arguments, or the whole project. Don't read every file —
survey, then go deep where it matters.

1. **Map** — `git ls-files` for the tree, `package.json` / `pyproject.toml` /
   `go.mod` etc. for stack and scripts, configs (tsconfig, eslint, vite, docker, CI).
2. **Pick areas** — per layer (e.g. routes, services, DB, components, stores, API
   client, tests). In each area read 2-3 representative files plus the largest and
   the most recently changed (`git log -20 --name-only`).
3. **Check against the rules** found in Step 1. Every mismatch → Step 3 decides
   whether the rule or the code is wrong.
4. **Where no rule exists — check consistency.** Compare files of the same kind
   (all routes, all components of one type): placement, naming, wiring,
   validation, error handling, response shape, typing, reused helpers, tests next to
   them. The pattern most files follow (especially recent ones) is the convention;
   the outliers are the findings. If files split roughly evenly, there is no
   convention — that is a finding for the docs (Step 3), not for the code.
5. **Always look for:**
   - security: secrets in code or git, tokens reaching the frontend, missing input
     validation at the boundary, `dangerouslySetInnerHTML`/`v-html` with user data,
     injectable SQL/shell strings;
   - correctness hot spots: unhandled promises, swallowed errors, missing loading /
     empty / error states;
   - typing: `any`, `@ts-ignore`, JS files in a TS project;
   - size: files over ~300 lines (or the project's limit), functions over ~60;
   - duplication: the same logic copy-pasted in 3+ places;
   - dead code: unused exports/files/deps, commented-out blocks;
   - dependencies: badly outdated or vulnerable (`npm outdated`, `npm audit` if they
     run offline-safe), unused packages;
   - tests: is there a test setup, how to run it, are critical parts (parsers, pure
     logic, non-trivial routes, integrations) covered.
6. Run the project's static scripts if they exist and work as-is (`lint`,
   `typecheck`/`tsc --noEmit`). Failures are findings.

Every finding needs evidence: `file:line`, a command output, or a count
("12 of 14 routes validate with Zod; `orders.ts`, `refunds.ts` don't").

## Step 3 — Rule wrong or code wrong?

For each mismatch between the rules and the code:

- **The rule is wrong/outdated** (the whole codebase moved on, the rule names files or
  libraries that no longer exist, the rule contradicts another rule file) → fix the
  rule **in place, minimally**, in the file where it lives. Don't rewrite docs,
  don't restructure them, don't change their language or tone. If the same rule is
  duplicated in several agents' files, fix every copy the same way.
- **The code is wrong** → a task (Step 4).
- **Unsure** → a task whose first plan step is "decide: rule or code".

**`TECH-LEAD.md`** — the project's technical doc: stack, architecture (layers and how
they talk), conventions ("how things are done here"), tests (tools, how to run, when
required).

- Missing → create it in the project root from what you learned in Step 2. Short:
  facts and conventions, not an essay. If another doc already covers this (e.g. a
  detailed `CLAUDE.md`/`AGENTS.md`), link to it instead of copying.
- Exists → update only what's outdated or missing (e.g. no test section).
- Conventions you discovered in Step 2.4 that no doc mentions → add them to
  `TECH-LEAD.md` so the next run and `/diff-review` can use them.

## Step 4 — Write tasks

Only real problems with evidence. Better 5 solid tasks than 20 weak ones; cap at ~10
new tasks per run, most urgent first, and mention in the report what was left out.

**Id** — next free `T-NNN` after the highest id in `tasks/` (shared with other reviews).

Product/UX problems (missing feedback, confusing flows) are `/pm-review`'s job —
mention them in the report under "Для PM", don't create tasks for them.
**File name** — `T-NNN-<slug>.md`, slug = short title, lowercase, words joined with
`-`, only letters/digits/`-` (transliterate or keep the original script — both are
fine, just no `/ : * ? " < > |`).

**Split big work:** `complexity: complex` or touching 5+ modules → 2-4 tasks, each
self-contained; each later task's first plan step is `Зависит от [[T-NNN-...]]`.

File template (frontmatter keys and enum values exactly as shown — other tools and
the next run parse them; body text in the user's language):

```markdown
---
id: T-012
title: Валидация body в routes/orders
project: ai-dashboard
status: todo
urgency: high
complexity: simple
area: backend
created: 2026-09-23
source: tech-review
files:
  - backend/routes/orders.ts
  - backend/routes/refunds.ts
---

# Валидация body в routes/orders

## Что не так
`backend/routes/orders.ts:12` и `refunds.ts:9` принимают body без проверки.
Остальные 12 роутов валидируют через Zod (`routes/users.ts:8`).

## Как исправить
Схема + `safeParse` как в `routes/users.ts`, 400 с `details` при ошибке.

## Готово, когда
- оба роута отвечают 400 на невалидный body;
- схемы лежат рядом с остальными в `backend/schemas/`.

## План
1. Добавить `orderSchema`, `refundSchema` в `backend/schemas/`.
2. Подключить `safeParse` в обоих роутах.
3. Тест на невалидный body, если в проекте есть тесты роутов.

## История
- 2026-09-23 — создана tech-review.
```

Field values:

- `status`: `todo` | `in-progress` | `review` (done on a branch, not merged) | `done` |
  `dismissed` — new tasks are always `todo`. `/do-task` moves them along.
- `urgency`: `critical` (breaks the app or security now) | `high` (seriously hurts
  development or safety) | `medium` (debt that grows) | `low` (improvement).
- `complexity`: `simple` (1-3 files) | `medium` (3-10) | `complex` (10+ or architecture).
- `area`: `frontend` | `backend` | `fullstack` | `infra` | `docs` — whatever fits the
  project; use the project's own split if it has one.

## Step 5 — Report

Write `<tasksDir>/reports/<YYYY-MM-DD>-tech-review.md` (add `-2`, `-3` if a report
for today exists). Never edit old reports.

```markdown
# Tech review — <project> — <date>

Область: <whole project | folder>
Правила: <rule files used, or "нет — по образцам из кода">

## Состояние
2-4 sentences: overall health, main risks.

## Что проверял
- <area> — <files/patterns looked at>

## Документация
- `TECH-LEAD.md` — создан | обновлён: <what>
- `CLAUDE.md:40` — <what was outdated, what it says now>

## Задачи
- [[T-012-validaciya-body-v-routes-orders]] — high — Валидация body в routes/orders
- обновлена [[T-004-...]] — <what's new>

## Не вошло
- <findings skipped because of the cap or weak evidence>

## Для PM
- <product/UX problems noticed along the way, for /pm-review>

## Для дизайнера
- <visual problems noticed along the way, for /design-review>
```

Then answer in chat, in the user's language, briefly: where tasks were saved, the
new tasks as a list (id, urgency, title), which docs changed, and one line on
overall state. Don't paste the task bodies into chat.
