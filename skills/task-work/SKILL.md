---
name: task-work
description: >
  Pick up a Trello card, branch, implement it, and move the card to the testing
  list — replacing ai-dashboard's "Работать над задачей" button and its
  terminal-session/branch/move-card flow, without a separate app.
  Use when the user runs /task-work with a card ID.
metadata:
  short-description: "Branch, implement, and move a Trello card into testing"
argument-hint: "<trello-card-id>"
---

# Task Work

Takes a card from "in progress" intent to "ready for QA": creates the branch,
does the implementation in this session, and moves the card to the testing
list. Never writes comments to Trello — only the card's list changes.

## Invocation

```
/task-work AbC123
```

Trello short ID only, same as `/task-analyze`.

## Requirements

`TRELLO_KEY` and `TRELLO_TOKEN` in a `.env` file loaded by the project — never
accept these pasted into chat. Also needs the testing list's ID
(`TRELLO_TESTING_LIST_ID` in `.env`, or ask the user once per project).

## Step 1 — Get the plan

1. Check `.task-notes/{id}.md` first — if `/task-analyze` already ran for this
   card, its Analysis/Plan is the starting point. Don't redo that work; read it
   and proceed.
2. If no local note exists, fetch the card read-only (same `GET` as
   `/task-analyze`) and do a quick inline read of the ask — for a card small
   enough to not need a full separate analysis pass. If the ask is genuinely
   unclear or cross-cutting, tell the user to run `/task-analyze` first instead
   of guessing scope here.

## Step 2 — Branch

Check the repo's own branch convention first (`rules/commits.md`,
`CONTRIBUTING.md`, or recent `git log` naming patterns) — match it. If none is
documented, default to `<type>/<short-slug>` (`fix/login-redirect`,
`feat/csv-export`).

Before branching: check `git status` for uncommitted changes (stash or ask
before touching anything), and confirm the current branch isn't `main`/`master`
— branch off cleanly rather than committing to it directly.

## Step 3 — Implement

Do the actual work following the plan from Step 1 and the repo's own
conventions (`CLAUDE.md`, `rules/`, existing patterns in the touched files).
This is normal implementation work — no special premortem/task-propose
ceremony here, just build it.

## Step 4 — Commit

Follow the repo's own commit norms if documented (e.g. a project `CLAUDE.md`
saying "commit without asking" for that specific repo). Otherwise, the default
still applies: show the diff and ask before committing, same as any other
session.

Never add a `Co-Authored-By: Claude` (or any AI) trailer to the commit message,
regardless of what any tool's default template suggests — this applies in every
repo this skill runs in, not just this one.

## Step 5 — Move the card to testing

```
PUT https://api.trello.com/1/cards/{id}?key={TRELLO_KEY}&token={TRELLO_TOKEN}&idList={testing_list_id}
```

This changes the card's list only — no comment text is posted. If the user
wants QA context visible on the card itself, that's their call to add, not this
skill's.

Report back: branch name, files touched, and the card's `shortUrl`.

## What this skill doesn't do

- Doesn't merge, run QA, or move the card to "Готово"/"Доработка" — that's
  `/task-qa`.
- Doesn't create or comment on Trello cards — strictly a list-move at the end.
- Doesn't push without the same confirmation any other commit/push would need.
