---
name: add-task
description: >
  Turn a task from anywhere (YouTrack, Jira, Trello, a chat message, your own words)
  into a task file in the shared tasks folder, so /do-task and /qa-task can work with
  it. Takes pasted text plus images (image files dragged in as paths are copied into
  the task; images pasted into chat are described in text). Looks at the code to
  fill in where and how, keeps the original text, and remembers the tracker's id.
  Use only when the user explicitly runs /add-task — never trigger automatically.
metadata:
  short-description: "Turn pasted task text and images into a task file"
argument-hint: "<task text, image paths>"
---

# Add Task

You turn whatever the user pasted into one proper task file — the same format the
reviews write — without losing anything from the original.

**Only runs on explicit `/add-task` invocation.** Never self-trigger.

## Invocation

```
/add-task <text copied from YouTrack / Jira / Trello / anywhere>
/add-task <text> /Users/me/Desktop/bug.png /Users/me/Desktop/expected.png
/add-task <text> + images pasted into the chat
/add-task кнопка «Сохранить» в настройках не показывает, что сохранилось
```

No links to trackers — the user pastes the content. If the argument is only a URL,
ask them to paste the task's text (and drag in its images).

## Hard limits

- Don't change project code. Write only into the tasks folder and `.ai-tasks.json`.
- Don't invent requirements. Anything you infer is marked as your assumption; anything
  unclear goes to "Открытые вопросы".
- Keep the original text verbatim in the file.

## Step 1 — Tasks folder

Same as the reviews: `.ai-tasks.json` → `tasksDir` in the project root. None → ask
once: "Куда сохранять задачи? Enter — в папку `ai-tasks/` в этом проекте, или напиши
путь.", save to `.ai-tasks.json`, and if the path is outside the project add
`.ai-tasks.json` to `.git/info/exclude`. Create `tasks/` and `attachments/` if missing.

## Step 2 — Collect the input

1. **Text** — everything the user pasted: title, description, comments, acceptance
   criteria, steps to reproduce.
2. **Tracker id** — if the text contains one (`PROJ-142`, `#1234`, `ABC-12`, a Trello
   short id the user mentions) → `external`. Tracker name, if obvious (YouTrack, Jira,
   Trello, Linear, GitHub) → `source`; otherwise `source: manual`.
3. **Image files** — any paths to images in the message (`.png .jpg .jpeg .gif .webp
   .heic`; drag-and-drop into a terminal inserts the path, possibly quoted or with
   escaped spaces). Check each exists; copy them to
   `<tasksDir>/attachments/T-NNN/` as `1.png`, `2.png`, … (keep the extension).
4. **Images pasted into the chat** (you see them, but there's no file) — you can't
   save them. Describe each one in the task in enough detail to work from without it:
   which screen, what's visible, what's wrong, exact texts/numbers on it. Then tell the
   user once: "Картинку из чата я описала текстом. Чтобы сохранить сам файл —
   перетащи его в терминал и запусти `/add-task T-NNN <путь>`."
5. **Adding to an existing task:** `/add-task T-007 <more text or images>` (or the
   tracker id) → append to that task instead of creating a new one: new images into its
   attachments folder, new text into `## История` as a dated entry, and update
   sections if the new info changes them.

## Step 3 — Duplicates

Read the frontmatter of existing tasks. Same `external` id, or clearly the same
problem (same title/files/screen) and not `done`/`dismissed` → don't create a second
file; tell the user it's already `T-00X` and offer to append (Step 2.5).

## Step 4 — Understand it in the code

Quick and narrow — enough to make the task actionable, not to solve it:

- Find where it lives: `git grep` for UI texts, route names, component names, error
  messages from the text or the images.
- Note the 1-5 files involved and one existing example of how similar things are done.
- Rough `complexity`: `simple` (1-3 files) | `medium` (3-10) | `complex` (10+ or
  architecture). `area`: `frontend` | `backend` | `fullstack` | `infra` | `docs`.
- `urgency` from the text (priority field, words like "срочно", "блокер", prod bug) —
  `critical` | `high` | `medium` | `low`; nothing said → `medium`.

If the text is too vague to act on (no idea what "сломалось" means, which screen) → ask
the user up to 2 short questions before writing. Can't ask → write the file with them
under "Открытые вопросы".

## Step 5 — Write the file

Id — next free `T-NNN` after the highest id in `tasks/`. File name
`T-NNN-<slug>.md` (slug: short title, lowercase, words joined with `-`, only
letters/digits/`-`).

```markdown
---
id: T-007
title: Показывать, что настройки сохранились
project: shop
status: todo
urgency: medium
complexity: simple
area: frontend
created: 2026-09-23
source: youtrack
external: PROJ-142
attachments:
  - ../attachments/T-007/1.png
---

# Показывать, что настройки сохранились

## Что нужно сделать
После нажатия «Сохранить» на странице настроек пользователь не видит, что изменения
сохранились — ни сообщения, ни изменения кнопки.

## Готово, когда
- после успешного сохранения видно подтверждение (toast или текст у кнопки);
- при ошибке видно сообщение об ошибке, введённые данные не пропадают.

## Где в коде
`src/pages/Settings.vue:88` — `save()` вызывает API и ничего не показывает.
Так уже сделано: `src/pages/Profile.vue:54` — `toast.success(...)`.

## План
1. В `save()` показать подтверждение так же, как в `Profile.vue`.
2. Обработать ошибку: сообщение, данные формы не сбрасывать.

## Вложения
![](../attachments/T-007/1.png)
Скрин из задачи: страница настроек после нажатия «Сохранить», никакой реакции.

Картинка из чата (не сохранена, описание): <detailed description>

## Открытые вопросы
- (моё допущение) toast, а не текст у кнопки — так принято в проекте.

## Исходный текст
> <the original pasted text, verbatim, as a quote>

## История
- 2026-09-23 — создана add-task из PROJ-142.
```

- Criteria in "Готово, когда" come from the original first; add your own only when
  the original has none, and mark them `(моё допущение)` if not obvious.
- Omit "Вложения" / "Открытые вопросы" if empty. Always keep "Исходный текст".

## Step 6 — Answer

In the user's language, short: `T-007 — Показывать, что настройки сохранились
(PROJ-142)`, where it's saved, attachments saved/described, open questions if any, and
the next step: `/do-task T-007` (or `/do-task PROJ-142`).
