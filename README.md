# premortem-llm

Personal Codex plugin and skill for AI coding agents. The workflow lives in
`skills/premortem/SKILL.md`.

## Skill

- **premortem** — pressure-test a decision before committing to it. Outputs risks,
  a verdict, and one deduplicated task list (importance, timing, description, why).

## Install

Run from a normal terminal (not inside the Codex sandbox — it cannot write to
`~/.codex` without escalation):

```bash
./install.sh
```

Options:

```bash
./install.sh --force       # replace blocking regular files with symlinks
./install.sh --no-plugin   # symlink skills/prompts only; skip codex plugin
./install.sh --help
```

The installer does four things:

1. Symlinks the skill into `.agents/skills` (Codex repo scope when you work
   inside this repo).
2. Symlinks the skill into `${CODEX_HOME:-~/.codex}/skills`, `~/.claude/skills`,
   and `~/.grok/skills`.
3. Symlinks `commands/premortem.md` into `${CODEX_HOME:-~/.codex}/prompts`.
   Available as `/prompts:premortem`.
4. Registers this repo as a local Codex plugin marketplace and installs
   `premortem-llm@premortem-local` (requires `codex` in PATH or `~/.local/bin`).

Use inside Codex:

```text
/prompts:premortem cache analytics in a separate table
```

After install, restart Codex or start a new thread.

### Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `cp: ~/.codex/skills/premortem: Not a directory` | Skills already installed as symlinks | Nothing to do; run `ls -la ~/.codex/skills` |
| `Skipped ... (exists and is not a symlink)` | Old regular file blocks the symlink | `./install.sh --force` |
| `codex CLI not found` | `codex` not in PATH when script runs | Run from terminal where `which codex` works, or `./install.sh --no-plugin` |
| Skill command missing in Codex after install | Session started before install, or invoked without `prompts:` prefix | Restart Codex or open a new thread, then use `/prompts:premortem` |
| Skills missing in Codex after install | Session started before install | Restart Codex or open a new thread |
| Skill name looks like `premortem-llm:premortem` | Plugin namespace | Normal for plugin skills; user skills in `~/.codex/skills` appear without prefix |

Verify:

```bash
ls -la ~/.codex/skills/premortem ~/.codex/prompts/premortem.md .agents/skills/premortem
codex plugin list | rg premortem
```

## Plugin files

- `.codex-plugin/plugin.json` — plugin manifest.
- `.agents/plugins/marketplace.json` — repo-local marketplace that exposes this plugin.
- `install.sh` — skill symlinks, Codex slash prompt symlinks, and Codex plugin registration/install.

## Archived task skills

Trello `task-*` skills were moved to
`ai-dashboard/_moved-from-premortem-llm/` — not wired into ai-dashboard, kept
for storage only.

## Commits

No `Co-Authored-By: Claude` or other AI trailer.