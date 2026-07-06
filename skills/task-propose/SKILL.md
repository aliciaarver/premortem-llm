---
name: task-propose
description: >
  Scan the current repo for worthwhile tasks (tech debt, bugs, gaps vs. docs),
  draft each as a specialist/complexity/analysis/plan writeup, get the user's
  Create/Reject call on each one, and create approved cards on the target Trello
  list — replacing ai-dashboard's PM/Tech-Lead/Designer "proposed tasks" feature.
  Use when the user runs /task-propose.
metadata:
  short-description: "Propose new Trello cards from a repo scan, user approves each"
argument-hint: "[optional focus, e.g. 'frontend only' or 'performance']"
---

# Task Propose

Scans the repo, drafts candidate tasks, and — only for the ones the user
explicitly approves — creates them as Trello cards. This is the safeguard
against board clutter that ai-dashboard also enforces: the developer confirms
each card, not the analyst role.

## Invocation

```
/task-propose
/task-propose frontend only
/task-propose performance and dead code
```

Optional argument narrows the scan focus. No argument = full scan.

## Requirements

`TRELLO_KEY` and `TRELLO_TOKEN` in a `.env` file loaded by the project, same as
`/task-analyze` — never accept these pasted into chat. Also needs the board ID
(for the duplicate check in Step 1) and the target list ID to create cards on —
read `TRELLO_BOARD_ID`/`TRELLO_BACKLOG_LIST_ID` from `.env` if set, otherwise
ask the user once per project rather than guessing.

## Step 1 — Load context and prior dismissals

1. Read `TECH-LEAD.md`, `DESIGN.md`, `CLAUDE.md`, `PM.md` if present — Step 2
   uses these per lens.
2. Read `.task-propose-dismissed.json` in the repo root if it exists — a flat
   list of previously-rejected task titles/hashes. Don't re-propose these unless
   something material changed (say so if you're re-raising a dismissed one).
3. Skim `git log --oneline -30` for recent direction — don't propose something
   already in flight.
4. Fetch existing open cards on the board (read-only):
   ```
   GET https://api.trello.com/1/boards/{board_id}/cards/open?key={TRELLO_KEY}&token={TRELLO_TOKEN}&fields=name,idList
   ```
   Keep this list of titles to check candidates against in Step 2 — don't
   propose a card that's already sitting on the board under a different but
   clearly-equivalent title.

## Step 2 — Find candidates

Scan through three lenses — skip a lens if its source doc doesn't exist:

- **PM lens** (`PM.md`): scenarios or invariants described but not actually true
  in the product today; a documented "what counts as a product bug" that's
  currently happening.
- **Tech Lead lens** (`TECH-LEAD.md`, code): a documented invariant that isn't
  enforced, unaddressed `TODO`/`FIXME`, files over the repo's own stated size
  limit (check the actual number in the repo's own rules — don't assume
  200/300 lines), repeated patterns that should be extracted, real bugs found
  while reading (not hypothetical), test coverage gaps on recently-changed
  high-risk code.
- **Designer lens** (`DESIGN.md`): entries under a "known issues" / "divergence"
  section — visual inconsistency, UX friction, accessibility gaps — anything
  the doc itself already flags as unresolved.

Tag each candidate with which lens found it. Drop anything that duplicates an
existing open card from Step 1's fetch (same ask, different wording still
counts as a duplicate — compare meaning, not exact text). Don't invent busywork.
If a lens's doc is absent, or the honest scan turns up nothing, say so — an
empty list is a valid and useful result, not a failure to produce output.

## Step 3 — Draft each candidate

Same shape as `/task-analyze`'s output, plus urgency:

```
### [Tech Debt | Bug | Feature] <short title>
- What's wrong: <one line, concrete>
- Fix direction: <one line, direction not full implementation>
- Specialist: frontend | backend | fullstack
- Complexity: simple | medium | complex
- Urgency: low | medium | high

**Analysis:**
<2-5 sentences: real files/modules, why this matters, what must not regress>

**Plan:**
1. <concrete step>
2. ...
```

## Step 4 — Get a Create/Reject call on each

Present the full list, then ask the user which to create and which to reject —
one decision per candidate, not a single "approve all." Use whatever
multi-select mechanism is natural in the current context; the requirement is
that each candidate gets an explicit answer, not a blanket yes.

## Step 5 — Create approved cards, record rejections

For each **approved** candidate:

```
POST https://api.trello.com/1/cards?key={TRELLO_KEY}&token={TRELLO_TOKEN}
  &idList={target_list_id}&name={title}&desc={analysis_and_plan_as_markdown}
```

For each **rejected** candidate, append its title (or a short hash of it) to
`.task-propose-dismissed.json` so it isn't re-proposed next run without cause.

Report back the created cards' `shortUrl`s.

## What this skill doesn't do

- Doesn't analyze a specific already-existing card — that's `/task-analyze`.
- Doesn't move cards through the board or touch code — analysis and card
  creation only.
- Never creates a card without an explicit per-candidate approval.
