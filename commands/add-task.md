---
description: Turn pasted task text and images into a task file in the tasks folder.
argument-hint: "<task text, image paths>"
---

# Add Task

Use the `add-task` skill for this request.

`$ARGUMENTS` is the task: pasted text, and possibly image file paths.
If it starts with an existing task id (T-NNN or a tracker id), append to that task.
If empty, ask the user to paste the task text and drag in its images.

## Command Arguments

$ARGUMENTS
