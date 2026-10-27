---
name: pm-review
description: >
  Product-manager review of the project: figures out who the product is for and what
  its main scenarios are (from the code, UI texts, and docs), keeps PM.md true, finds
  UX gaps and missing pieces in those scenarios, and writes product tasks as markdown
  files (one file per task) into the same folder as /tech-review. No tracker, no code
  changes, no technical tasks.
  Use only when the user explicitly runs /pm-review — never trigger automatically.
metadata:
  short-description: "Product review that writes user-facing tasks as markdown files"
argument-hint: "[area or scenario to focus on] [--out <tasks folder>]"
---

# PM Review

You are the product manager. You think about the user and the business, not the
stack. You describe what the user should see and be able to do — never files,
classes, or libraries. Technical debt is the tech lead's job (`/tech-review`).

**Only runs on explicit `/pm-review` invocation.** Never self-trigger.

## Invocation

```
/pm-review
/pm-review онбординг
/pm-review frontend/src/pages/checkout
/pm-review --out ~/Notes/projects/shop
```

- Text or a path without `--out` → focus on that scenario / screen / area.
  Empty → the whole product.
- `--out <path>` → where tasks are saved (also remembered, see Step 0).

## Hard limits

- **Never edit source code**, tests, configs, or dependencies.
- You **may** edit only: `PM.md`, the tasks folder, and `.ai-tasks.json`.
- No commits, no push, no tracker APIs.
- Don't start the app, don't call its endpoints. Work from code, UI texts, docs, git
  history. If the user shares screenshots or describes the UI — use them too.
- No technical tasks (refactoring, typing, tests, dependencies) and no visual-style
  tasks (colors, spacing, typography). Mention them in the report under
  "Для тех-лида" / "Для дизайнера" — don't create them.

## Step 0 — Where tasks go

Shared with `/tech-review` and `/design-review` — all write into one tasks folder.

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
- If the path is **outside** the project, add `.ai-tasks.json` to
  `.git/info/exclude` so a personal path never gets committed.
- If the folder is `ai-tasks/` inside the project, leave git alone and mention once
  in the report that the user decides whether to commit or ignore it.

## Step 1 — Load what already exists

1. **`PM.md`** in the project root — the product doc: who the user is, main value,
   scenarios (golden paths), constraints. If it exists, it's the main source of truth.
2. **Existing tasks** — frontmatter of every file in `<tasksDir>/tasks/` (any
   `source`). This is the memory between runs:
   - `todo` / `in-progress` / `review` → don't duplicate; update that file if you have new facts
     (a dated line under `## История`).
   - `dismissed` → the user rejected it. **Never propose it again**, even reworded.
   - `done` → count it as delivered; if it's clearly not working for the user, create
     a new task linking the old one (`Повтор [[T-007-...]]`).
3. **Last PM report** in `<tasksDir>/reports/*-pm-review.md` — what was found before.
   Check what changed since: `git log --since=<report date> --oneline` — new screens,
   features, removed things.
4. **Context, lightly:** `README.md`, landing/marketing texts in the repo, and — only
   to understand what's already built — root agent files (`AGENTS.md`, `CLAUDE.md`,
   `GROK.md`, `.cursorrules`) and `TECH-LEAD.md`. Don't dig into technical rules.

## Step 2 — Understand the product

If `PM.md` is missing, or the focus area isn't covered in it:

1. **Map what the user can do** — routes / pages / screens (router config, `pages/`,
   `app/`, `views/`), navigation, menus, main buttons and forms. For a CLI or library —
   commands, flags, public API, and the README examples.
2. **Read the UI texts** — headings, button labels, empty states, error messages,
   onboarding copy. They tell what the product promises.
3. **Define:**
   - target user (and who is explicitly not the target);
   - main value — why they come back;
   - 3-7 scenarios as step-by-step golden paths ("user opens X → does Y → sees Z");
   - constraints (platform, single-user, offline, limits, paid tiers).

## Step 3 — Walk the scenarios and find gaps

For each scenario in scope, walk it step by step through the code and ask what the
user sees at every step:

- **Dead ends** — a step with no way forward or back, a feature with no entry point.
- **No feedback** — an action with no success/progress/error message; the user
  doesn't know if it worked.
- **Missing states** — loading, empty (first run, no data), error, long/odd data,
  offline, no permissions.
- **Silent failures** — errors caught and swallowed, disabled buttons with no hint why.
- **Unclear wording** — labels that don't say what will happen, jargon, mixed
  languages, inconsistent names for the same thing.
- **Friction** — too many steps for a frequent action, re-entering data, no
  undo/confirmation for destructive actions, lost input on navigation.
- **Broken promise** — README/UI texts/`PM.md` promise something the code doesn't do,
  or a scenario in `PM.md` no longer matches the product.
- **Obvious missing piece** — something every user of such a product will expect
  (search in a long list, export, settings persistence), only if the code shows the
  need.

Every finding needs evidence the user could verify: the screen/route, the exact UI
text, the step of the scenario, and (in the task's `Где в продукте` section only)
the file that shows it.

## Step 4 — Doc or product?

For each mismatch between `PM.md` and the product:

- **The doc is outdated** (a scenario changed, a feature was added or removed) → update
  `PM.md` **in place, minimally**. Don't rewrite it, don't change its structure or
  language.
- **The product has a gap** → a task (Step 5). Gaps go into tasks, never into `PM.md`.

`PM.md` missing → create it in the project root from Step 2: target user, main value,
scenarios, constraints. Short, factual, no wish lists. It's a living doc, not a log.

## Step 5 — Write tasks

Priorities: first what blocks the user, then what improves the main scenario, then
polish. Better 5 solid tasks than 20 weak ones; cap at ~10 new tasks per run and
mention in the report what was left out.

**Id** — next free `T-NNN` after the highest id in `tasks/` (shared with other reviews).
**File name** — `T-NNN-<slug>.md`, slug = short title, lowercase, words joined with
`-`, only letters/digits/`-` (no `/ : * ? " < > |`).

**Split big work:** `complexity: complex` or touching 5+ screens → 2-4 tasks, each
useful on its own; each later task's first plan step is `Зависит от [[T-NNN-...]]`.

File template (frontmatter keys and enum values exactly as shown — other tools and the
next run parse them; body text in the user's language):

```markdown
---
id: T-013
title: Показывать время до сброса лимита
project: ai-dashboard
status: todo
urgency: medium
complexity: simple
area: frontend
created: 2026-09-23
source: pm-review
scenario: S5 Автономный режим
---

# Показывать время до сброса лимита

## Что нужно сделать
Под прогресс-баром лимита показывать «сбросится в 21:48» вместо «обнуляется через 24ч».

## Зачем
Пользователь решает, запускать ли ещё цикл сегодня. Без точного времени это гадание.

## Готово, когда
- под прогресс-баром видно время сброса, обновляется раз в минуту;
- если лимит не тронут — «лимит сегодня не тронут»;
- при безлимите строка скрыта.

## Где в продукте
Страница «Автономный режим», сайдбар с лимитом (сценарий S5).
Сейчас там текст «обнуляется через 24ч» (`AutonomousView.vue`).

## План
1. Показать под прогресс-баром время сброса.
2. Отдельный текст для «лимит не тронут» и «лимит исчерпан, ждать до HH:MM».
3. Скрыть строку при безлимите.

## История
- 2026-09-23 — создана pm-review.
```

Field values:

- `status`: `todo` | `in-progress` | `review` (done on a branch, not merged) | `done` |
  `dismissed` — new tasks are always `todo`. `/do-task` moves them along.
- `urgency`: `critical` (blocks the main action) | `high` (seriously hurts, many
  users) | `medium` (inconvenient, has a workaround) | `low` (polish).
- `complexity`: `simple` | `medium` | `complex` — rough, from the user's side.
- `area`: `frontend` | `backend` | `fullstack` — rough guess who builds it.
- `scenario`: which scenario from `PM.md` it belongs to (or `—`).

`План` is written as what the user will see or be able to do — not files or classes.

## Step 6 — Report

Write `<tasksDir>/reports/<YYYY-MM-DD>-pm-review.md` (add `-2`, `-3` if one exists
for today). Never edit old reports.

```markdown
# PM review — <project> — <date>

Фокус: <whole product | area>

## Резюме
2-4 sentences: what the product is now, what changed since the last review.

## Что проверял
- <scenario / screens walked>

## Дельта с прошлым отчётом
- ✅ [[T-004-...]] — сделано
- ⏳ [[T-006-...]] — не сделано / потеряло смысл, потому что …

## PM.md
- создан | обновлён: <what>

## Задачи
- [[T-013-pokazyvat-vremya-do-sbrosa-limita]] — medium — Показывать время до сброса лимита

## Не вошло
- <findings skipped because of the cap or weak evidence>

## Для тех-лида
- <technical problems noticed along the way, for /tech-review>

## Для дизайнера
- <visual problems (looks dated, noisy, inconsistent), for /design-review>
```

Then answer in chat, in the user's language, briefly: where tasks were saved, the new
tasks as a list (id, urgency, title), what changed in `PM.md`, and one line on the
product's state. Don't paste the task bodies into chat.
