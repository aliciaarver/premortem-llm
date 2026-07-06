---
name: task-qa
description: >
  Run the test/lint gate on a card's branch, then either merge and move the
  card to done, or move it to rework with the failure recorded locally —
  replacing ai-dashboard's QA button and merge/rework flow without a separate
  app or Trello comments.
  Use when the user runs /task-qa with a card ID.
metadata:
  short-description: "Test-gate a branch, then merge-to-done or move-to-rework"
argument-hint: "<trello-card-id>"
---

# Task QA

Runs the repo's test/lint suite against the card's branch and acts on the
result: green merges and moves the card to done; red moves the card to rework
and records why — locally, not as a Trello comment.

## Invocation

```
/task-qa AbC123
```

Trello short ID only, same as `/task-analyze` and `/task-work`.

## Requirements

`TRELLO_KEY` and `TRELLO_TOKEN` in a `.env` file loaded by the project — never
accept these pasted into chat. Also needs the done and rework list IDs
(`TRELLO_DONE_LIST_ID`, `TRELLO_REWORK_LIST_ID` in `.env`, or ask once per
project).

## Step 1 — Locate the branch

Fetch the card read-only (name/desc/idList). Find its branch: check
`.task-notes/{id}.md` for a recorded branch name from `/task-work`, or match
`git branch --list` against the card's ID/slug. If nothing matches, ask the
user which branch this card corresponds to — don't guess.

Confirm the card is actually on the testing list before proceeding; if it's
elsewhere, tell the user and ask whether to continue anyway.

## Step 2 — Run the gate

Detect and run the repo's own test/lint commands (check `package.json` scripts,
`TECH-LEAD.md`'s testing section, or `CLAUDE.md`) — don't assume `npm test`
universally. Run on the card's branch, not main.

## Step 3 — Act on the result

**Green (all pass):**
1. Ask before merging and pushing — same confirmation bar as any other
   merge/push, no exception for QA passing.
2. On confirmation: fast-forward merge (or the repo's documented merge style)
   into the main branch, push. Never add a `Co-Authored-By: Claude` (or any AI)
   trailer to any commit this skill touches, in any repo.
3. Move the card to done:
   ```
   PUT https://api.trello.com/1/cards/{id}?key={TRELLO_KEY}&token={TRELLO_TOKEN}&idList={done_list_id}
   ```

**Red (any failure):**
1. Don't merge. Move the card to rework:
   ```
   PUT https://api.trello.com/1/cards/{id}?key={TRELLO_KEY}&token={TRELLO_TOKEN}&idList={rework_list_id}
   ```
   List move only — no comment posted to the card.
2. Append a "QA result" section to `.task-notes/{id}.md` (create the file if
   `/task-analyze` never ran for this card) with the specific failing
   test/lint output — not a vague "tests failed."
3. Tell the user directly in chat what broke and where; don't rely on the
   Trello card to carry that information.

## What this skill doesn't do

- Doesn't fix the failing code — that's back to `/task-work` or manual work.
- Doesn't create or comment on Trello cards — list moves only, same as
  `/task-work`.
- Never merges or pushes without explicit confirmation, regardless of how
  clean the test run looked.
