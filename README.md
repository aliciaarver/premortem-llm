# premortem-llm

Personal Codex plugin and skills for AI coding agents (Codex, Claude Code, Grok).
Workflows live in `skills/<name>/SKILL.md`.

## Skills

- **diff-review** — strict read-only review of uncommitted changes (or one commit
  with `/diff-review <id>`): only changed files, the project's own rules (see
  [Where the AI finds project rules](#where-the-ai-finds-project-rules); where no rule
  covers a change, it compares against one similar existing example in the project),
  a fixed checklist, and lint/typecheck/build. Outputs ✅/❌ and a
  `file:line` list of findings. Never edits, runs tests, or pushes. Modelled on the
  reviewer role in ai-dashboard, minus the tracker and auto-merge.

- **tech-review** — tech-lead audit of the whole project (or one folder). Finds the
  project's rules for any agent, checks the code against them and against its own
  conventions, fixes outdated rule docs / `TECH-LEAD.md` in place, and writes
  tech-debt tasks as markdown files — one file per task. No tracker, no code edits.
- **pm-review** — product-manager review: who the product is for, its main
  scenarios, and where users get stuck (dead ends, no feedback, missing empty/error
  states, unclear wording). Keeps `PM.md` true and writes user-facing tasks into the
  same folder as `tech-review`. No technical tasks, no code edits.
- **design-review** — designer review: starts the app (or uses `--url`), takes 4-6
  screenshots with Playwright, and critiques them against `DESIGN.md` (visual
  language, patterns, moodboard and a text "reference" look). Quality first, then UX
  states, then consistency. Keeps `DESIGN.md` true and writes design tasks with
  screenshots into the same folder. Playwright is installed once into
  `~/.cache/ai-review/playwright`, never into the project.
- **do-task** — takes one task from the tasks folder (by id, or the most urgent ready
  one), implements it by the project's rules, runs static checks, the task's "done
  when" criteria and a `diff-review` pass, and sets the task to `review`. Commits and
  pushes only if allowed (see below).
  `/do-task <text>` does the text as the task with no task file — nothing is stored
  in the project (for work repos).
- **do-commit** — inspects the current diff and writes one clear commit message.
  `/do-commit` and `/do-commit eng` use English; `/do-commit ru` uses Russian.
  With `AI_GIT_COMMIT=false` it only proposes a ready-to-copy message. With
  `AI_GIT_COMMIT=true` it stages the current change set and creates one local commit.
  With `AI_GIT_PUSH=true` it immediately pushes that commit to the current work
  branch. Direct commit and push to `main` / `master` require both settings to be
  `true`.
- **analyze** — turns an idea, new feature, or improvement to an existing flow into
  a clear recommendation. It checks no code for abstract questions; for current
  behavior it starts with a focused check of the screen, component, state/API and a
  comparable implementation, expanding only when a material question remains. Every
  response ends with **Итог**, **Рекомендация**, **Почему**, **Что проверено**,
  **Что остаётся неизвестным** and **Следующий шаг**. When work is needed, it also
  gives a prioritised task list with a verifiable «готово, когда» criterion. It does
  not implement changes.
- **add-task** — turns a task from any tracker or chat into a task file: paste the
  text, drag in image files (copied into `attachments/T-NNN/`); images pasted into
  the chat are described in text. Looks at the code to fill in where and how, keeps
  the original text verbatim, remembers the tracker id — `/do-task PROJ-142` works.
  `/add-task T-007 <more>` appends to an existing task.
- **qa-task** — `/qa-task T-012`: QA for one task in `review`. Checks only that
  branch against the task's "done when", adds autotests scaled to complexity
  (unit → integration → e2e), verifies by hand (Playwright / curl), and for design
  tasks compares before/after screenshots. Green → task `done` (merged into main
  only if commits are allowed). Red → task back to `todo` with a "Доработка" note (what's
  wrong, repro steps, expected/actual) that `do-task` continues from.

All commands have the same name everywhere: `/<name>` in Claude Code and Grok,
`/prompts:<name>` in Codex — `diff-review`, `tech-review`, `pm-review`,
`design-review`, `add-task`, `do-task`, `do-commit`, `analyze`, `qa-task`.

Typical loop: `tech-review` / `pm-review` / `design-review` (or `add-task` from your
tracker) → tasks in the folder →
`do-task` → `qa-task <id>` → done (or back to `do-task` with notes) → you commit and
push, unless you allowed the AI to.

Argument for `diff-review` is optional: none → only uncommitted changes; a commit id
(`/diff-review a1b2c3d`) → only that commit; any other text → uncommitted changes,
with the text as the task description they must satisfy.

### Where `tech-review`, `pm-review`, `design-review` save tasks

On the first run in a project it asks where to save tasks (Enter = `ai-tasks/` in
the project) and remembers the answer in `.ai-tasks.json` (shared by all three):

```json
{ "tasksDir": "/Users/me/Documents/Obsidian Vault/projects/shop" }
```

Change it by editing that file or with `--out <path>` on any of them. `design-review` also saves how to start the
app (`design.devCommand`, `design.url`, `design.screens`) there after the first run. A path outside
the project is added to `.git/info/exclude` so it's never committed.

```
<tasksDir>/
  tasks/T-001-<slug>.md     one task per file, YAML frontmatter + markdown body
  attachments/T-001/*.png   images added with add-task
  reports/<date>-tech-review.md
  reports/<date>-pm-review.md
  reports/<date>-design-review.md + <date>-design-review/screenshots/*.png
```

### Where the AI finds project rules

`diff-review`, `do-task` and `tech-review` find rules the same way, reading only what
applies to the files at hand:

1. **`AI_RULES`** from `.env` / `.env.local` / shell — files or folders with any name,
   comma-separated, relative to the project root:

   ```
   AI_RULES=standards/,docs/frontend-guide.md
   ```

2. **Search** for every agent's rule files: `AGENTS.md`, `CLAUDE.md`, `GROK.md`,
   `GEMINI.md`, `.cursor/rules/*.mdc` (`alwaysApply` / `globs` respected),
   `.cursorrules`, `.claude/rules/`, `.github/copilot-instructions.md`, `rules/`,
   `docs/rules/`, `CONTRIBUTING.md`, `TECH-LEAD.md`, `ARCHITECTURE.md`.
3. **References** — files a rule names as mandatory (`follow .doc/vision.md`, "rules
   are in `standards/`") are read too, one level deep. This is how most custom rule
   folders get found without `AI_RULES`.
4. **Project skills** — if a rule says to apply skills from a folder (e.g.
   `.agents/skills`), only their descriptions are read; a skill's body only when it
   fits the task. Skill folders are never mistaken for project rules.

Small rule folders (≈300 lines) are read whole; larger ones by headings first, then
only the relevant files. Nothing found → the report says so and suggests `AI_RULES`.

### What goes in the project's `.env`

All optional, all read-only for the AI: it reads only these keys (never the rest of
`.env`), never asks about them and never edits `.env`. `.env.local` wins over `.env`;
a key missing from both falls back to the same variable exported in your shell
(`~/.zshrc`) — a personal default for every project.

| Key | Default | What it does |
| --- | --- | --- |
| `AI_RULES` | — | Extra rule files/folders (see above) |
| `AI_GIT_COMMIT` | `false` | Allow commits (below) |
| `AI_GIT_PUSH` | `false` | Allow push (below) |
| `AI_GIT_COAUTHOR` | `false` | Mark AI-written commits (below) |

If the project's `.env` is tracked by git, put these in `.env.local`.

### Can the AI commit and push?

Per project, in that project's `.env` / `.env.local`:

```
AI_GIT_COMMIT=true
AI_GIT_PUSH=false
AI_GIT_COAUTHOR=true
```

- Nothing set (default) — no branches, no commits; changes stay in the working tree
  for you to review and commit.
- `AI_GIT_COMMIT=true` — each task on its own branch with a local commit; `qa-task`
  merges it into main locally.
- `AI_GIT_PUSH=true` — also push (task branches from `do-task`, main after `qa-task`).
  `/do-commit` immediately pushes its new commit to the current work branch; direct
  commit and push to `main` / `master` require this setting and `AI_GIT_COMMIT=true`.
  Never force.
- `AI_GIT_COAUTHOR=true` — commits end with the agent's co-author line
  (`Co-Authored-By: Claude <noreply@anthropic.com>`), so history shows the AI wrote
  it. `false` — no such line, even if the agent adds one by default. Not set → the
  project's commit rules decide; they say nothing → no line.

The AI never writes comments to trackers, PRs or anywhere outside the project.

Tasks are plain `.md`: readable in any editor, rendered in Obsidian / VS Code /
GitHub. Status in the frontmatter: `todo` → `in-progress` → `review` (done on a
branch, not merged) → `done` (QA passed, merged). QA fails → back to `todo`. Set `status: dismissed` to reject a task — no review
will propose it again.

## Install

Run from a normal terminal (not inside the Codex sandbox — it cannot write to
`~/.codex` without escalation):

```bash
./install.sh
```

Options:

```bash
./install.sh --force       # replace blocking regular files with symlinks
./install.sh --no-plugin   # symlink skills/prompts only; skip codex plugin
./install.sh --help
```

The installer does four things:

1. Symlinks the skill into `.agents/skills` (Codex repo scope when you work
   inside this repo).
2. Symlinks the skill into `${CODEX_HOME:-~/.codex}/skills`, `~/.claude/skills`,
   and `~/.grok/skills`.
3. Symlinks `commands/*.md` into `${CODEX_HOME:-~/.codex}/prompts`.
   Available as `/prompts:<name>`.
4. Registers this repo as a local Codex plugin marketplace and installs
   `premortem-llm@premortem-local` (requires `codex` in PATH or `~/.local/bin`).

Use inside Codex:

```text
/prompts:diff-review
/prompts:tech-review backend/
/prompts:do-commit ru
/prompts:analyze стоит ли добавлять сохранение фильтров в текущий список заказов
```

After install, restart Codex or start a new thread.

### Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `cp: ~/.codex/skills/<name>: Not a directory` | Skills already installed as symlinks | Nothing to do; run `ls -la ~/.codex/skills` |
| `Skipped ... (exists and is not a symlink)` | Old regular file blocks the symlink | `./install.sh --force` |
| `codex CLI not found` | `codex` not in PATH when script runs | Run from terminal where `which codex` works, or `./install.sh --no-plugin` |
| Skill command missing in Codex after install | Session started before install, or invoked without `prompts:` prefix | Restart Codex or open a new thread, then use `/prompts:<name>` |
| Skills missing in Codex after install | Session started before install | Restart Codex or open a new thread |
| Skill name looks like `premortem-llm:tech-review` | Plugin namespace | Normal for plugin skills; user skills in `~/.codex/skills` appear without prefix |

Verify:

```bash
ls ~/.codex/skills ~/.codex/prompts ~/.claude/skills ~/.grok/skills
codex plugin list | rg premortem
```

## Plugin files

- `.codex-plugin/plugin.json` — plugin manifest.
- `.agents/plugins/marketplace.json` — repo-local marketplace that exposes this plugin.
- `install.sh` — skill symlinks, Codex slash prompt symlinks, and Codex plugin registration/install.

## Archived task skills

Trello `task-*` skills were moved to
`ai-dashboard/_moved-from-premortem-llm/` — not wired into ai-dashboard, kept
for storage only.

## Commits

No `Co-Authored-By: Claude` or other AI trailer.
