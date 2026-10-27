---
description: Implement one task (from the tasks folder, or from plain text) and check it. Commits only if the project allows.
argument-hint: "[T-NNN | task text]"
---

# Do Task

Use the `do-task` skill for this request.

If `$ARGUMENTS` contains a task id (T-NNN), take that task.
If it is any other text, that text is the task: do it without a task file and write
nothing into the project except the code change.
If empty, take the most urgent ready task.

## Command Arguments

$ARGUMENTS
