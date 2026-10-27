#!/usr/bin/env bash
# Installs these workflows as local skills, Codex slash prompts, and,
# when Codex is available, as a Codex plugin.
set -euo pipefail
cd "$(dirname "$0")"

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install premortem-llm skills for Codex, Claude, and Grok.

Options:
  --force       Replace existing regular files/dirs with symlinks (skills and prompts)
  --no-plugin   Skip Codex plugin registration; do not require codex CLI
  -h, --help    Show this help

Run from a normal terminal (not inside Codex sandbox) so ~/.codex can be written.
EOF
}

force=false
require_plugin=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=true
      shift
      ;;
    --no-plugin)
      require_plugin=false
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

codex_home="${CODEX_HOME:-$HOME/.codex}"
repo_agents_skills="$PWD/.agents/skills"
targets=("$codex_home/skills" "$HOME/.claude/skills" "$HOME/.grok/skills")

skill_names=()
for d in skills/*/; do
  skill_names+=("$(basename "$d")")
done
skill_count=${#skill_names[@]}
prompt_count=0
for _ in commands/*.md; do
  prompt_count=$((prompt_count + 1))
done

validate_command_prompt() {
  local file="$1"
  local first_line

  if [ ! -s "$file" ]; then
    echo "Invalid command prompt: $file is empty" >&2
    return 1
  fi

  first_line="$(sed -n '1p' "$file")"
  if [ "$first_line" = "stale" ]; then
    echo "Invalid command prompt: $file still contains placeholder text" >&2
    return 1
  fi

  return 0
}

for f in commands/*.md; do
  validate_command_prompt "$f"
done

skills_linked=0
skills_skipped=0
repo_skills_linked=0
repo_skills_skipped=0
prompts_linked=0
prompts_skipped=0
plugin_status="not attempted"
verify_ok=true
exit_code=0

link_path() {
  local src="$1"
  local link="$2"
  local kind="$3"

  if [ -e "$link" ] || [ -L "$link" ]; then
    if [ -L "$link" ]; then
      ln -sfn "$src" "$link"
      return 0
    fi
    if [ "$force" = true ]; then
      rm -rf "$link"
    else
      echo "Skipped $link ($kind exists and is not a symlink; use --force to replace)"
      return 1
    fi
  fi

  ln -sfn "$src" "$link"
  return 0
}

mkdir -p "$repo_agents_skills"
for name in "${skill_names[@]}"; do
  link="$repo_agents_skills/$name"
  if link_path "$PWD/skills/$name" "$link" "repo skill"; then
    repo_skills_linked=$((repo_skills_linked + 1))
  else
    repo_skills_skipped=$((repo_skills_skipped + 1))
  fi
done

for target in "${targets[@]}"; do
  mkdir -p "$target"
  for name in "${skill_names[@]}"; do
    link="$target/$name"
    if link_path "$PWD/skills/$name" "$link" "skill"; then
      skills_linked=$((skills_linked + 1))
    else
      skills_skipped=$((skills_skipped + 1))
    fi
  done
done

prompts_dir="$codex_home/prompts"
mkdir -p "$prompts_dir"
for f in commands/*.md; do
  name="$(basename "$f")"
  link="$prompts_dir/$name"
  if link_path "$PWD/$f" "$link" "prompt"; then
    prompts_linked=$((prompts_linked + 1))
    echo "Linked Codex custom prompt: $link"
  else
    prompts_skipped=$((prompts_skipped + 1))
  fi
done

bin_dir="$HOME/.local/bin"
for name in "${skill_names[@]}"; do
  command_path="$bin_dir/$name"
  if [ -f "$command_path" ] && grep -q "Use the $name skill for this request." "$command_path"; then
    rm "$command_path"
    echo "Removed old shell command wrapper: $command_path"
  fi
done

codex_bin=""
if command -v codex >/dev/null 2>&1; then
  codex_bin="codex"
elif [ -x "$HOME/.local/bin/codex" ]; then
  codex_bin="$HOME/.local/bin/codex"
fi

if [ "$require_plugin" = false ]; then
  plugin_status="skipped (--no-plugin)"
elif [ -n "$codex_bin" ]; then
  marketplace_root="$PWD"
  marketplace_name="premortem-local"
  plugin_selector="premortem-llm@$marketplace_name"

  if "$codex_bin" plugin marketplace list 2>/dev/null | awk -v root="$marketplace_root" '$0 ~ root { found = 1 } END { exit !found }'; then
    echo "Codex marketplace already registered: $marketplace_root"
  else
    "$codex_bin" plugin marketplace add "$marketplace_root"
  fi

  "$codex_bin" plugin add "$plugin_selector"
  plugin_status="installed ($plugin_selector)"
else
  plugin_status="failed (codex CLI not found in PATH or ~/.local/bin)"
  exit_code=1
fi

for name in "${skill_names[@]}"; do
  if [ ! -L "$codex_home/skills/$name" ]; then
    echo "Verify failed: missing $codex_home/skills/$name"
    verify_ok=false
  fi
done

for f in commands/*.md; do
  name="$(basename "$f")"
  if [ ! -L "$prompts_dir/$name" ]; then
    echo "Verify failed: missing $prompts_dir/$name"
    verify_ok=false
  fi
done

for name in "${skill_names[@]}"; do
  if [ ! -L "$repo_agents_skills/$name" ]; then
    echo "Verify failed: missing $repo_agents_skills/$name"
    verify_ok=false
  fi
done

expected_user_skills=$((skill_count * ${#targets[@]}))

echo
echo "Install summary"
echo "==============="
echo "Repo skills:     $repo_skills_linked / $skill_count (.agents/skills for Codex repo scope)"
echo "Repo skipped:    $repo_skills_skipped"
echo "User skills:     $skills_linked / $expected_user_skills (Codex, Claude, Grok)"
echo "User skipped:    $skills_skipped"
echo "Prompts linked:  $prompts_linked / $prompt_count"
echo "Prompts skipped: $prompts_skipped"
echo "Codex plugin:    $plugin_status"
echo "Verify:          $([ "$verify_ok" = true ] && echo "ok" || echo "failed")"
echo

if [ "$skills_skipped" -gt 0 ] || [ "$prompts_skipped" -gt 0 ] || [ "$repo_skills_skipped" -gt 0 ]; then
  echo "Some paths were skipped. Rerun with --force to replace existing files."
  exit_code=1
fi

if [ "$verify_ok" = false ]; then
  exit_code=1
fi

if [ "$plugin_status" = "failed (codex CLI not found in PATH or ~/.local/bin)" ]; then
  echo "Add codex to PATH (often ~/.local/bin) or rerun with --no-plugin."
elif [ "$plugin_status" != "skipped (--no-plugin)" ]; then
  echo "Restart Codex or start a new thread to pick up skill command wrappers."
  echo "Skill command wrappers are invoked as /prompts:<name>, for example /prompts:tech-review."
  echo "Plugin skills appear as premortem-llm:<name>; user skills appear as <name>."
fi

exit "$exit_code"
