---
name: task-analyze
description: >
  Pull a Trello card, analyze what it actually requires (specialist, complexity,
  concrete plan), and save that analysis to a local file next to the code — the
  same record-keeping ai-dashboard does, minus the AI writing anything back to
  Trello itself. Use when the user runs /task-analyze with a card ID.
metadata:
  short-description: "Analyze a Trello card and save the plan as a local file"
argument-hint: "<trello-card-id>"
---

# Task Analyze

Reads a Trello card (read-only — no writes to Trello ever), produces a
specialist/complexity/analysis/plan writeup, and saves it as a local file in the
repo. This skill never posts comments or edits anything on the board itself —
if you want the analysis on the card, copy it there yourself.

## Invocation

```
/task-analyze AbC123
```

Takes the Trello short ID only (the part after `/c/` in the card's URL) — the
model can look up everything else about the card from that.

## Requirements

Needs `TRELLO_KEY` and `TRELLO_TOKEN` in a `.env` file loaded by the project —
never accept these values pasted into chat. If either is missing from `.env`,
stop and tell the user to add it there.

## Step 1 — Fetch the card (read-only)

```
GET https://api.trello.com/1/cards/{id}?key={TRELLO_KEY}&token={TRELLO_TOKEN}&fields=name,desc,shortUrl,idList
GET https://api.trello.com/1/cards/{id}/actions?filter=commentCard&key={TRELLO_KEY}&token={TRELLO_TOKEN}
```

`{id}` can be the short ID straight from the URL — Trello's API accepts it
directly, no need to resolve to the long ID first. Only ever call `GET` endpoints
in this skill — no `POST`/`PUT` to Trello under any circumstance.

Read the card name, description, and existing comments (later comments may
contain prior analysis, QA feedback, or scope changes — don't analyze against a
stale description if comments already narrowed the ask).

## Step 2 — Load repo context

Same context-loading order as `/premortem`, when working inside a git repo:

1. `TECH-LEAD.md` → stack, architecture, conventions
2. `DESIGN.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `README.md`
3. Read only the files actually relevant to the card's ask — not the whole repo

If none of these exist, work from the card text and a quick read of the
obviously-relevant code.

## Step 3 — Analyze

Determine:

- **Specialist:** `frontend` | `backend` | `fullstack` — whichever owns the bulk
  of the change. A UX/visual change with no new backend field is `frontend`, even
  if it touches an API client.
- **Complexity:** `simple` (one file/module) | `medium` (one subsystem) |
  `complex` (cross-cutting, multiple modules/services)
- **Analysis:** 2-5 sentences — which files/modules/endpoints are involved, what
  the current behavior is, what must not regress. Name real paths, not
  placeholders.
- **Plan:** numbered, concrete steps. Each step names a file or a command, not
  "update the relevant code."

If the card is too vague to plan concretely (no acceptance criteria, contradicts
itself, or depends on an external unknown), don't fabricate a plan — write down
the specific open question in the file instead of guessing, and say so to the
user directly (not as a Trello comment).

## Step 4 — Save the analysis locally

Write to `.task-notes/{id}.md` in the repo root, creating the directory if needed:

```
# {card name} ({id})

Trello: {shortUrl}

**Specialist:** frontend
**Complexity:** medium

**Analysis:**
<2-5 sentences>

**Plan:**
1. <step>
2. <step>
```

Tell the user the file path once written. Never write anything back to Trello —
if the user wants this on the card itself, that's their call to paste it in.

## What this skill doesn't do

- Never posts comments, edits the description, or writes to Trello in any way —
  strictly read-only against the Trello API.
- Doesn't move the card between lists — that's `/task-work` and `/task-qa`.
- Doesn't create new cards — that's `/task-propose`.
- Doesn't write or edit code — analysis only.
