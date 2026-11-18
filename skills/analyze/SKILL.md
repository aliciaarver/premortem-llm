---
name: analyze
description: >
  Assess an idea, proposed feature, or existing-product improvement and end with
  a clear recommendation and next step. Use only when the user explicitly runs
  /analyze.
metadata:
  short-description: "Reach a clear decision with focused research"
---

# Analyze

Turn an idea or question into a decision the user can act on, rather than an
open-ended discussion. Be brief by default: no detailed implementation plan unless
the user asks for one.

**Only runs on an explicit `/analyze` invocation.** It does not implement, edit
files, create tasks, or make external changes.

## Scope the research

Choose the smallest level that can support a reliable recommendation:

- **Idea only** — do not inspect code when the question is abstract and does not
  depend on the current product.
- **Focused product check** — inspect code when the question concerns an existing
  screen, flow, component, API, or behavior. Start with exact names from the request:
  visible text, route, component name, API endpoint, or domain term. Read the entry
  point plus only the directly relevant state, API, and one comparable implementation;
  normally no more than 2–5 files.
- **Deeper check** — expand only when the first check cannot answer a material
  question. Before expanding, state what remains unknown, which paths will answer it,
  and why that changes the recommendation.

Do not run the app, tests, broad repository scans, or web searches unless the user
explicitly asks, or the answer cannot otherwise be made reliably. Never infer that a
feature exists without checking when the question is about the current product.

## Answer format

Start with the conclusion. Keep the normal response within roughly 350 words.

```text
Итог: делать / не делать / делать при условии …
Рекомендация: конкретный выбранный вариант.
Почему: 2–4 причины, отмечая подтверждённые факты и допущения.
Что проверено: файлы, экран, API — или «код не проверялся: не нужен для решения».
Что остаётся неизвестным: только пункты, способные изменить решение.
Следующий шаг: одно конкретное действие.
```

Give at most three alternatives and explain the trade-off only when it affects the
recommendation. If the question is too ambiguous to choose a direction, ask one
short question; otherwise state the assumption and proceed.
