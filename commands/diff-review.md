---
description: Strict read-only review of uncommitted changes (or one commit) against project rules.
argument-hint: "[commit id | task description]"
---

# Diff Review

Use the `diff-review` skill for this request.

If `$ARGUMENTS` is a commit id, review only that commit.
Otherwise review only uncommitted changes; non-empty text is the task description
the change must satisfy.

## Command Arguments

$ARGUMENTS
