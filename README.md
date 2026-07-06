# premortem-llm

Personal Claude Code skills. Each lives in `skills/<name>/SKILL.md`.

## Skills

- **premortem** — pressure-test a proposed decision before you commit to it.
  Imagines the plan already failed, surfaces 1-3 concrete risks (scaled to
  decision complexity) with severity and mitigations, then gives a verdict.
  Explicit invocation only (`/premortem`), never self-triggered.

- **task-analyze** — reads a Trello card (read-only) and writes a
  specialist/complexity/analysis/plan writeup to a local file
  (`.task-notes/{id}.md`). Never posts to Trello.

- **task-propose** — scans the repo through a PM/Tech-Lead/Designer lens for
  worthwhile tasks, drafts each one, and creates only the ones the user
  explicitly approves as new Trello cards.

- **task-work** — takes a Trello card, branches, implements it, and moves the
  card to the testing list (list move only, no comment).

- **task-qa** — runs the repo's test/lint gate on a card's branch; merges and
  moves the card to done on green, or moves it to rework and records the
  failure locally on red.

Together, `task-*` replace ai-dashboard's PM/Tech-Lead/Designer/QA role
orchestration for a single Trello board — without a separate app, a visual
kanban UI, or an always-on autonomous loop. The AI never posts comments or
otherwise writes free text to Trello; card state changes (list moves, new
cards) are the only writes, and creating a card always requires per-item
approval.

## Installing the skills

The canonical source is this repo (`skills/<name>/SKILL.md`). Each agent looks
for skills in its own location — symlink rather than copy, so edits here stay
in sync everywhere:

**Claude Code**

```
mkdir -p ~/.claude/skills
for d in skills/*/; do ln -s "$PWD/$d" ~/.claude/skills/"$(basename "$d")"; done
```

Personal, available in any project. For a single project only, symlink into
that project's `.claude/skills/` instead of `~/.claude/skills/`.

**Grok**

Same idea, different root — Grok reads from `~/.grok/skills/<name>/SKILL.md`:

```
mkdir -p ~/.grok/skills
for d in skills/*/; do ln -s "$PWD/$d" ~/.grok/skills/"$(basename "$d")"; done
```

**Cursor**

Cursor doesn't use the same `SKILL.md` + frontmatter format or a `~/.cursor/skills`
directory — it works off project-level rule files (`.cursor/rules/*.mdc`) and,
in newer versions, `.cursor/commands/*.md` for slash-commands. There's no
single command that "installs" a skill; per project, either:

- copy a `SKILL.md`'s body into `.cursor/commands/<name>.md` (drop the
  `argument-hint`/`metadata` frontmatter, Cursor doesn't read it), or
- fold the rules into `.cursor/rules/<name>.mdc` if you want it always-on
  rather than invoked by name.

Check Cursor's current docs before relying on this — the commands/rules split
has changed across versions.

## Setup

Each Trello-touching skill needs a `.env` (or shell env) with:

```
TRELLO_KEY=
TRELLO_TOKEN=
TRELLO_BOARD_ID=            # task-propose (duplicate check)
TRELLO_BACKLOG_LIST_ID=     # task-propose
TRELLO_TESTING_LIST_ID=     # task-work
TRELLO_DONE_LIST_ID=        # task-qa
TRELLO_REWORK_LIST_ID=      # task-qa
```

These are never accepted pasted into chat — the skills only read them from
`.env`.

## Commits

No `Co-Authored-By: Claude` (or any AI) trailer, in this repo or in any repo
`task-work`/`task-qa` commit to.
