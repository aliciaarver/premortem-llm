---
description: Screenshot-based design critique that writes design tasks as markdown files.
argument-hint: "[screen or scenario] [--url <running app url>] [--out <tasks folder>]"
---

# Design Review

Use the `design-review` skill for this request.

If `$ARGUMENTS` contains `--url <url>`, the app is already running there.
If `$ARGUMENTS` contains `--out <path>`, save tasks there and remember it.
If `$ARGUMENTS` contains other text, focus on that screen or scenario.
If empty, review the main scenarios.

## Command Arguments

$ARGUMENTS
