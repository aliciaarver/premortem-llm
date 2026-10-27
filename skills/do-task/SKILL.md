---
name: do-task
description: >
  Take one task from the tasks folder (written by /tech-review, /pm-review,
  /design-review, /add-task), implement it following the project's rules, check it
  (static checks, the task's "done when" criteria, a /diff-review pass), and update
  the task file's status and history. Commits and pushes only if the project's
  .env allows it (AI_GIT_COMMIT / AI_GIT_PUSH; default: neither). Never
  merges. Without an id, picks the most urgent ready task. Given plain text instead
  of an id, does that text as the task and writes nothing into the project.
  Use only when the user explicitly runs /do-task — never trigger automatically.
metadata:
  short-description: "Implement one task from the tasks folder"
argument-hint: "[T-NNN | task text — optional]"
---

# Do Task

You take one task — from the shared tasks folder, or straight from the user's text —
and bring it to "done and checked".
Whether you commit or push is the project's setting (Step 1b) — by default you do
neither. You never merge or deploy.

**Only runs on explicit `/do-task` invocation.** Never self-trigger.

## Invocation

```
/do-task            the most urgent ready task
/do-task T-012      this task
/do-task PROJ-142   a task added with /add-task, by its tracker id
/do-task в таблице заказов не работает сортировка по дате    the text is the task
```

How to read the argument:

- Empty → the most urgent ready task.
- A single token shaped like an id (`T-012`, `PROJ-142`, `#142`) → that task file.
- Anything else → **text mode** (below): the text itself is the task.

## Text mode — a task without a file

For projects where nothing about the task may be stored (e.g. a work repo). The text
after the command, plus any image paths in it and images in the chat, is the whole task.

- **Write nothing but the code change**: no task file, no tasks folder, no
  `.ai-tasks.json`, no notes or reports in the project or anywhere else. Don't read
  the tasks folder either, even if one exists.
- Skip Steps 1 and 2. Step 1b (git permissions) applies as usual.
- Step 3: the text replaces the task file. Before coding, state in chat in 2-5 lines
  how you understood it: what changes, and the "готово, когда" criteria you derived —
  these are what Step 6 checks. Too vague to derive criteria, or it needs a product
  decision → ask and stop. Already done in the code → say so and stop.
- Steps 4-7 as usual, minus every task-file update. Branch name with commits on: the
  project's convention, else `task/<slug-of-the-text>`; a tracker id mentioned in the
  text goes into the branch name and commit message the way the project does it.
- Step 8: report in chat only. There is no `/qa-task` for a task without a file —
  the next step is the user looking at the diff (`/diff-review`).

## Hard limits

- Commit and push only as the project's `.env` allows (Step 1b). Never commit to
  `main`/`master`, never merge, never force anything, never rewrite history.
- Never write comments anywhere outside the project (trackers, PRs, chats).
- Only the scope of this task — no drive-by refactors, no "while I'm here".
- Don't add dependencies unless the task's plan says so.
- Never stage the tasks folder or `.ai-tasks.json` in the task's commits.
- AI co-author line in commit messages only as `AI_GIT_COAUTHOR` says (Step 1b) —
  off by default, even if your agent adds one on its own.

## Step 1 — Find the tasks folder

Project root = `git rev-parse --show-toplevel`. Read `.ai-tasks.json` →
`tasksDir` (relative to the project root, `~` = home). No config → if `ai-tasks/`
exists use it; otherwise tell the user to run `/tech-review`, `/pm-review` or
`/design-review` first (they create the folder), or `/add-task` to add a task from a
tracker, and stop.

## Step 1b — Git permissions

Set per project in the project's `.env` (it's local and usually gitignored, so it
works even where you can't commit rule files):

```
AI_GIT_COMMIT=false
AI_GIT_PUSH=false
AI_GIT_COAUTHOR=false
```

Read **only these keys** — `.env` holds secrets; never print, read, or load the
rest of it:

```bash
grep -hE '^[[:space:]]*AI_GIT_(COMMIT|PUSH|COAUTHOR)=' .env .env.local 2>/dev/null
```

- `.env.local` wins over `.env`. A key missing from both → the same variable from the
  shell environment (`echo "$AI_GIT_COMMIT"`), so a user can set a personal default in
  `~/.zshrc`. Still missing → `false`.
- `true`/`yes`/`1`/`да` → allowed; anything else → not allowed.
- `AI_GIT_PUSH=true` with `AI_GIT_COMMIT` not true → treat commit as allowed too.
- `AI_GIT_COAUTHOR` — whether commits say the AI wrote the code:
  - `true` → end the message with your agent's usual co-author line (e.g.
    `Co-Authored-By: Claude <noreply@anthropic.com>`); if it has none,
    `Co-Authored-By: <agent or model name> <noreply@<vendor domain>>`.
  - `false` → no co-author line or "generated with" footer, even if your agent's own
    defaults add one.
  - not set anywhere → follow the project's rules (`rules/commits.md`, agent files);
    they say nothing → no line.
- **Never ask** about this and never edit `.env` yourself. If commits are off, add one
  line at the end of your answer: "Коммиты выключены. Чтобы разрешить в этом проекте —
  добавь в `.env`: `AI_GIT_COMMIT=true` (и `AI_GIT_PUSH=true`, если можно пушить)." If
  `.env` exists and `git check-ignore -q .env` fails (it's tracked), add: "`.env` в
  этом проекте коммитится — лучше положи строки в `.env.local`."

Modes:

- **commit off** (default) — no branches, no commits. You work in the current branch's
  working tree and leave every change uncommitted for the user to review and commit.
- **commit on** — the task gets its own branch and a local commit.
- **push on** — additionally push the task branch (`git push -u origin <branch>`).
  Never push `main`/`master`, never force.

## Step 2 — Pick the task

Read the frontmatter of every file in `<tasksDir>/tasks/`.

- **Id given** → that file: `T-012-*.md`, or the task whose `external` equals the
  given id (tracker ids from `/add-task`). If its status is `done`, `dismissed` or
  `review` — say so and stop; don't redo it unless the user confirms.
  `in-progress` → resume it (Step 4 finds its branch).
- **No id** → candidates are `status: todo` whose dependencies are met: every
  `Зависит от [[T-NNN-...]]` / `Depends on` in the plan points to a task with status
  `done` or `review`. Order: `urgency` (critical → high → medium → low), then lower
  `complexity` first, then lower id. Take the first. None ready → list what's blocked
  and by what, and stop.

Say in one line which task you took and why (e.g. "T-012 — high, dependencies done").

## Step 3 — Understand it

1. Read the whole task file: what's wrong, how to fix, "done when", plan, files,
   screenshots and attachments (open every image listed in `screens` /
   `attachments`), history. Tasks from `/add-task` also have "Исходный текст" — the
   original wording wins if the summary above it disagrees.
   **Returned by QA** (the last history entry is "QA не пропустил" with a
   `### Доработка`) → that note is your main input: fix every point in it, make the
   failing tests QA committed pass, and don't redo what already works.
2. Load the project's rules the same way `/diff-review` does (its Step 2a-2b in
   `../diff-review/SKILL.md`), so you code by the rules you'll be reviewed by — but
   cheaply:
   - Discovery is `AI_RULES` from `.env` plus one `find` that prints paths only;
     run it once.
   - Read only what applies to the files the task will touch: root agent files,
     nested ones on those paths, `.mdc` whose `globs`/`alwaysApply` match, the
     relevant `rules/` area. Plus `DESIGN.md` for UI tasks, `PM.md` only if the task
     is about a scenario. Skip the rest.
   - Don't re-read what's already in your context (e.g. a `CLAUDE.md` the agent
     loaded at start). Duplicates across agents (`CLAUDE.md` = "see AGENTS.md") —
     read once.
   - Long rule files: read the sections that match the task, not the whole file.
3. Where the rules say nothing about what you're adding, find one closest existing
   example in the project (a sibling file of the same kind) and follow it.
4. Check the task is still valid: the problem is still in the code (`git log` since
   the task's `created` date, the files it names). Already fixed → set `status: done`
   with a history line "уже исправлено в <commit>", and stop.
5. If the plan is clearly wrong, contradicts the rules, or needs a product decision —
   stop and ask the user.

## Step 4 — Where to work

**Commit off:** stay on the current branch, don't create one. If the working tree
already has uncommitted changes (ignoring the tasks folder), list the files and ask
whether to continue — this task's changes will mix with them. Never stash or discard
them. Update the task file: `status: in-progress`, history
`- <date> — в работе, без коммитов (ветка <current>)`. Go to Step 5.

**Commit on:**

1. `git status --porcelain` must be clean (ignoring the tasks folder if it's inside
   the repo). Dirty → ask the user what to do; never stash or discard their changes
   yourself.
2. Main branch: `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@'`,
   else `main`, else `master`. `git fetch origin <main>` if there is a remote.
3. Branch name: the project's convention (`rules/commits.md`, `CONTRIBUTING.md`, recent
   branch names in `git branch -a`). None → `task/T-012-<slug>`.
4. Base:
   - resuming (`in-progress` with a branch in history, or `todo` returned by QA) →
     `git switch <that branch>`;
   - the task depends on a task in `review` (branch not merged yet) → branch from that
     task's branch, and note it in history;
   - otherwise → from `origin/<main>` (or local `<main>`).
5. Update the task file: `status: in-progress`, history line
   `- <date> — в работе, ветка <branch>`.

## Step 5 — Implement

Follow the plan and the rules from Step 3. Keep the diff as small as the task allows.
Match the style of the surrounding code (naming, comments, structure). If the task
requires tests by the project's rules — write them.

## Step 6 — Check

1. **Static checks** that exist in the project (`lint`, `typecheck`/`tsc --noEmit`,
   `build`) and the tests related to the change (not the whole suite unless it's
   fast). Red → fix and rerun.
2. **"Готово, когда"** — go through every criterion and state how it's met (command
   output, file:line). UI task and the app can be run → you may take a screenshot the
   way `/design-review` does to confirm.
3. **Review your own diff** — follow the `diff-review` skill if it's installed
   (`../diff-review/SKILL.md` next to this skill), otherwise its essence: only the
   changed files, project rules, the checklist, static checks. Its Step 2 is already
   done: reuse the rules from Step 3 and read more only for changed files they didn't
   cover. Static checks from point 1 already ran — rerun only after a fix. Fix every blocker and
   major. At most 2 fix-and-review rounds; what's left goes into the history as open
   points.

## Step 7 — Commit (only if commits are on)

Commits off → skip this step entirely.

Commit on the task branch. Message by the project's convention
(`rules/commits.md`, recent `git log`); none → `<type>(T-012): <what and why>`, where
type is `feat`/`fix`/`refactor`/`style`/`docs`/`test`/`chore`/`perf`. One commit per
task unless the project prefers otherwise. Co-author line per `AI_GIT_COAUTHOR`
(Step 1b). Stage only the task's files (`git add <paths>`, not `git add -A`).

Push on → `git push -u origin <branch>`. Rejected → report it, don't force.

## Step 8 — Update the task and report

**Done:** set `status: review` and append to `## История` — with commits:

```
- 2026-09-23 — сделано в ветке task/T-012-..., коммит abc1234 (запушено | не запушено).
  Проверки: lint ✅ tsc ✅ build ✅.
```

without commits:

```
- 2026-09-23 — сделано, не закоммичено (ветка main). Файлы: src/a.ts, src/b.vue.
  Проверки: lint ✅ tsc ✅ build ✅.
```

**Blocked / failed:** commits on → leave the code committed on the branch only if
it builds; otherwise don't commit and restore the files you changed
(`git restore <paths>`, only yours), and switch back to the branch you started on.
Commits off → leave the changes in place and list them, the user decides. Either
way set `status: todo` and append `- <date> — заблокировано: <exact reason>`.

Answer in chat, in the user's language, briefly: task id and title, what changed
(files), check results, anything left open, branch/commit if any (or "не
закоммичено — посмотри diff и закоммить сама"), and what's next (`/qa-task T-012`).

## Statuses

`todo` → `in-progress` (you're on it) → `review` (done on a branch, not merged) →
`done` (set by `/qa-task`, or by the user).
QA fails → back to `todo` with a `### Доработка` note. `dismissed` — rejected, never
touch.

On success, tell the user the next step is `/qa-task T-012`.
