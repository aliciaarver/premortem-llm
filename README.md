# premortem-llm

Personal skills for AI coding agents (Claude Code, Grok, Cursor, ...). Each
lives in `skills/<name>/SKILL.md`.

## Skills

- **premortem** — pressure-test a decision before committing to it (`/premortem`).
- **task-analyze** — read a Trello card, save an analysis locally, never post to Trello.
- **task-propose** — scan the repo for tasks, create only the ones you approve.
- **task-work** — branch, implement, move the card to testing.
- **task-qa** — run tests, merge + mark done on green, or move to rework on red.

`task-*` together replace ai-dashboard's role/QA flow for one Trello board —
no separate app, no comments posted by the AI, every new card needs your
explicit approval.

## Install

```
./install.sh
```

Symlinks every skill into `~/.claude/skills` and `~/.grok/skills`. Cursor
doesn't have an equivalent skills folder — copy a `SKILL.md`'s body into
`.cursor/commands/<name>.md` if you want it there.

## Trello setup

```
TRELLO_KEY=
TRELLO_TOKEN=
TRELLO_BOARD_ID=
TRELLO_BACKLOG_LIST_ID=
TRELLO_TESTING_LIST_ID=
TRELLO_DONE_LIST_ID=
TRELLO_REWORK_LIST_ID=
```

In a `.env` file per project — never pasted into chat.

## Commits

No `Co-Authored-By: Claude` (or any AI) trailer.
