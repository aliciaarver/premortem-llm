---
name: qa-task
description: >
  QA for one task that /do-task finished (status "review"): checks only that task's
  branch against its "done when" criteria, adds autotests scaled to the task's
  complexity, checks the behavior by hand (browser via Playwright, curl for APIs),
  and for design tasks compares before/after screenshots. Green → marks the task
  done (and, only if the project's .env allows commits, merges the branch into main
  locally; pushes only if allowed). Red → returns it to todo with a concrete
  "Доработка" note that /do-task picks up.
  Use only when the user explicitly runs /qa-task <id> — never trigger automatically.
metadata:
  short-description: "QA one finished task: accept it or return it with notes"
argument-hint: "T-NNN"
---

# QA Task

You are QA — a separate role from whoever wrote the code. You don't trust the
author's self-check; you check the result against the task. You don't fix product
code — you write tests, verify, and decide.

**Only runs on explicit `/qa-task <id>` invocation.** Never self-trigger.

## Invocation

```
/qa-task T-012
```

The id is required. Without it: list the tasks with `status: review` (id, title,
branch) and stop.

## Hard limits

- Don't change product code. You may add/modify **tests only** (and test fixtures).
- Commit, merge and push only as the project's `.env` allows — `AI_GIT_COMMIT` /
  `AI_GIT_PUSH`, read exactly as in `/do-task` Step 1b (only the `AI_GIT_*` keys, never the
  rest of `.env`; missing → off; never ask, never edit `.env`).
  Never force, never rewrite `main`'s history.
- Never write comments anywhere outside the project (trackers, PRs, chats).
- Never stash, reset or discard changes that aren't yours.
- Never stage the tasks folder or `.ai-tasks.json`.
- AI co-author line in commit and merge messages only as `AI_GIT_COAUTHOR` says
  (`/do-task` Step 1b) — off by default, even if your agent adds one on its own.

## Step 1 — Task and branch

1. Tasks folder: `.ai-tasks.json` → `tasksDir` in the project root (else `ai-tasks/`).
2. Open `<tasksDir>/tasks/T-NNN-*.md`, or the task whose `external` equals the given
   id (tracker ids from `/add-task`). Status must be `review`. Otherwise say what it
   is and stop (`todo`/`in-progress` → not finished; `done` → already accepted).
3. Git mode from `.env` (`AI_GIT_COMMIT`).
   - **Commits off** — the task's changes are uncommitted in the working tree
     (history says "не закоммичено"). Stay where you are; the "diff" below is
     `git diff HEAD` + untracked files, limited to the files listed in the history.
     Skip steps 4-7 here.
   - **Commits on** — branch = the last `ветка <name>` in its `## История`. Missing
     or doesn't exist → stop and say so.
4. `git status --porcelain` must be clean (ignoring the tasks folder if it's inside the
   repo). Dirty → ask the user; don't touch their changes.
5. Remember the current branch, then `git switch <task branch>`.
6. Main: `git symbolic-ref --short refs/remotes/origin/HEAD | sed 's@^origin/@@'`, else
   `main`, else `master`. `git fetch origin <main>` if there's a remote.
7. **Stacked branch:** if the history says the branch was made from another task's
   branch and that task isn't `done` yet → stop: "сначала `/qa-task T-0XX`".

## Step 2 — Read narrowly

Nothing in full — only what this check needs.

- **Diff:** `git diff $(git merge-base HEAD <main>)..HEAD --name-only` — what the task
  added. Test only that; don't wander into unchanged code.
- **Re-QA:** if the history has `QA-checkpoint: <sha>` from an earlier failed QA —
  focus on `git diff <sha>..HEAD`, and re-check every point of that "Доработка".
- **The task:** "Что не так / Что нужно сделать", **"Готово, когда"** (these are the
  acceptance criteria), complexity, `source`, `screens` / `attachments` (open the
  images), "Исходный текст" if present (the original criteria win), the last 2-3
  history entries.
- **`PM.md`:** `grep -n -i '<task keyword>'` → ±30 lines. Nothing → skip.
- **Scripts:** `node -e "console.log(JSON.stringify(require('./package.json').scripts))"`
  (and in `frontend/`/`backend/` if they have their own). Other stacks — the
  equivalent (`pyproject.toml`, `Makefile`).
- **Existing tests:** `git grep -ln '<changed function or route>' -- '*test*' '*spec*'`.
- **Test rules:** `rules/*/testing.md`, `TESTING.md`, the testing part of
  `TECH-LEAD.md` / agent files, if they exist.

Criteria contradict each other or can't be checked → don't guess. Append to history
`- <date> — QA: блокер — критерии противоречат: <A> vs <B>; что непонятно: <…>`, keep
`status: review`, switch back, tell the user. Stop.

## Step 3 — Run what exists

`lint`, `typecheck`/`tsc --noEmit`, `build`, and the test suite (the relevant part if
the whole one is slow). Anything red in the task's files → it's a failure (Step 7).
Red outside the task's files and also red on `<main>` → pre-existing, note it, don't
blame the task.

## Step 4 — Tests by complexity

Use the project's test tools and its conventions (where tests live, naming, helpers).
Look at one existing test of the same kind and follow it.

**simple**
- Walk the criteria by hand (Step 5).
- Add an autotest only if a criterion is non-trivial (new visible behavior, new API
  field): **one happy-path test** on the changed function or endpoint.

**medium** — on top of simple:
- Frontend: an integration test of the task's key user scenario — mount the component
  with the real router/store, click through, assert the final UI. Mock the network
  (MSW or the project's way), not the component internals.
- Backend: request → status code, JSON shape, side effect in a **test DB** (in-memory
  / test schema), not a mocked ORM.
- Smoke-run the existing tests around the change so neighbors didn't break.

**complex** — on top of medium:
- Frontend: **e2e** of the new user flow with the project's e2e tool (Playwright /
  Cypress): open → act → see the result. Happy path + 2-3 edge cases (empty data, API
  error, boundary values).
- Backend: module integration with external calls mocked at the HTTP level (nock /
  msw-node / the project's way). Happy path + at least one external failure
  (4xx/5xx/timeout) — a failing external API must not take the process down.
- Walk every criterion by hand in edge conditions, not only the happy path.

**No test setup in the project** → don't introduce a framework. Do the manual checks,
say "автотестов в проекте нет" in the result, and don't fail the task for it.

Commits on → commit tests on the task branch as one commit (project's convention,
else `test(T-012): автотесты на <what>`), staging only test files. Commits off →
leave the test files uncommitted and list them in the result.

## Step 5 — Check by hand

Every "Готово, когда" point gets a verdict with evidence.

- **Frontend:** start the app and look, the same way `/design-review` does it (Step 2b-2d
  of that skill, `../design-review/SKILL.md` next to this one): reuse
  `design.devCommand`/`design.url` from `.ai-tasks.json`, logs to a file, Playwright
  from the project or `~/.cache/ai-review/playwright`. Script the clicks of the
  scenario, screenshot the result into
  `<tasksDir>/reports/<date>-qa-T-012/`, open the screenshots and look.
- **Backend:** start the server the same way and `curl` the endpoint: status code,
  body, error cases from the criteria.
- **CLI/library:** run the command / call the function the way the README shows.
- Stop anything you started when done.
- Can't run the app → say so; the verdict then rests on automated tests only, and
  UI criteria that nobody could see count as **not verified** (→ Доработка only if a
  criterion can't be verified any other way; otherwise note the risk).

## Step 5a — Design tasks (`source: design-review`)

The goal is "it got better", not "the change passes tests".

1. **Before:** the task's `screens` (screenshots from the design review). None → make a
   temporary worktree of `<main>` (`git worktree add <tmp> <main>`), run it there,
   screenshot, remove the worktree. Never switch or stash to get "before".
2. **After:** the same screens on the task branch, same viewport (1280×800, scale 1).
3. **Compare** before / after / the Эталон in `DESIGN.md` (the closest
   `.design-references/` image only if the task is `complex`). Judge the images, not CSS.
4. Clearly better and closer to the Эталон → pass. Same, worse, or bad in another way
   (rhythm, hierarchy, density, type, accents) → fail, naming the exact point of the
   Эталон not reached.
5. Also a fail even if it looks fine: hardcoded colors/spacing outside tokens; a list
   the task touched without decent loading/empty/error states (screenshot them);
   obviously low contrast (below WCAG AA).

## Step 6 — Green

All checks green and every criterion met.

**Commits off:** nothing to merge. Task file: `status: done`, history:

```
- 2026-09-23 — QA пройден. Тесты: +3 (не закоммичены: tests/a.test.ts, …).
  Критерии: 3/3. Изменения не закоммичены — посмотри diff и закоммить.
```

**Commits on:** merge locally:

1. Local `<main>` up to date without touching the network beyond fetch:
   `git switch <main>`; if `origin/<main>` is ahead and local main has nothing of its
   own → `git merge --ff-only origin/<main>`. Local main has unpushed commits of its own
   → fine, merge on top of it.
2. Merge the task branch:
   - `git merge --ff-only <branch>` if possible;
   - else, if the branch isn't on the remote (`git ls-remote --heads origin <branch>`
     is empty) → `git switch <branch> && git rebase <main>`, rerun the checks from
     Step 3, then `git switch <main> && git merge --ff-only <branch>`;
   - else → `git merge --no-ff <branch>` (don't rewrite a pushed branch).
3. **Conflicts:**
   - trivial (neighboring lines, both added to a list, formatting, renames on both
     sides) → resolve keeping both sides' meaning, continue, rerun checks;
   - lock files → take `<main>`'s version and regenerate with the project's package
     manager, `git add`;
   - logical (both rewrote the same function differently, business rules clash, not
     sure) → `git rebase --abort` / `git merge --abort` → it's a failure (Step 7) with
     what exactly collided.
4. After the merge: `git branch -d <branch>` (local only; leave remote branches alone).
5. Push on (`AI_GIT_PUSH`) → `git push origin <main>`. Rejected → report it, don't force, don't
   rebase main.
6. Task file: `status: done`, history:

   ```
   - 2026-09-23 — QA пройден. Тесты: +3 (unit 2, integration 1), lint ✅ tsc ✅ build ✅.
     Критерии: 3/3. Влито в main (коммит abc1234), запушено | не запушено.
   ```

## Step 7 — Red: back to work

Any criterion not met, red checks in the task's files, a design fail, or a logical
conflict:

1. Keep the tests you wrote (committed on the task branch if commits are on, otherwise
   left in the working tree) even if they fail — they show the bug and `/do-task` will
   make them pass. Say so in the note.
2. Task file: `status: todo`, and append to history (checkpoint = current `HEAD` of the
   task branch; commits off → write `QA-checkpoint: не закоммичено` and list the
   files):

   ```
   - 2026-09-23 — QA не пропустил. QA-checkpoint: abc1234
     ### Доработка
     Что не так:
     - <criterion / failing test / file:line>
     Шаги воспроизведения:
     1. …
     Ожидаемое: …
     Фактическое: …
     Скрины: <paths, if any>
   ```

   Concrete, no advice on "how to do it better architecturally" — just what doesn't
   work. The branch stays; `/do-task T-012` continues on it.

## Step 8 — Finish

Switch back to the branch you started on (if it still exists; else stay on `<main>`).
Answer in the user's language, briefly: task, verdict (✅ принято / ⛔ на доработку),
criteria met X/Y, tests added, checks, and what happened in git (влито коммитом … /
запушено / ничего не коммитила — закоммить сама), or the main reasons for failure.
