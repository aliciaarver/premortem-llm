---
name: do-commit
description: >
  Propose a commit message for the current changes, or create the commit when
  AI_GIT_COMMIT is enabled. Use only when the user explicitly runs /do-commit.
metadata:
  short-description: "Commit current changes or propose a message"
---

# Do Commit

Turn the current repository changes into one clear commit message. English is the
default; `ru` requests Russian and `eng` requests English.

**Only runs on an explicit `/do-commit` invocation.** Never commits implicitly.

## Invocation

```
/do-commit       English commit message
/do-commit eng   English commit message
/do-commit ru    Russian commit message
```

Any other argument is invalid: explain the accepted choices and stop.

## Permissions

Read only `AI_GIT_COMMIT` from `.env` and `.env.local`:

```bash
grep -hE '^[[:space:]]*AI_GIT_COMMIT=' .env .env.local 2>/dev/null
```

`.env.local` wins. If it is absent from both files, use the shell variable of the
same name; if it is still absent, commits are disabled. `true`, `yes`, `1`, and
`да` enable commits; every other value disables them. Never print or load other
environment values, and never edit these files.

## Workflow

1. Refuse to commit on `main` or `master`; propose the message instead and say why.
2. Inspect `git status --short`, the staged diff, and the unstaged diff. If there
   are no changes, say so and stop. If staged changes exist, they are the exact
   commit scope; do not add other files. Otherwise, treat all files shown by status
   as the proposed scope and state that file list before changing Git.
3. Read the applicable commit-message convention from project rules or recent
   commits. If none exists, use a concise Conventional Commit style
   (`fix: ...`, `feat: ...`, `refactor: ...`, etc.). Derive the message from the
   actual diff, never merely from filenames.
4. With commits disabled, output only one ready-to-copy message in the requested
   language. Do not stage, commit, push, create a branch, or alter files.
5. With commits enabled, stage only the listed unstaged files when needed, then
   create one commit using the generated message. Never use `git add -A`, never
   push, amend, force, reset, or rewrite history. Report the commit hash and the
   exact staged files.

If the diff combines clearly unrelated changes, or the intended scope cannot be
reliably distinguished, ask the user which files belong in this commit instead of
staging or committing anything.
