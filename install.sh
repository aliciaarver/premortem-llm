#!/usr/bin/env bash
# Symlinks skills/* into any AI agent skill folders found on this machine.
set -euo pipefail
cd "$(dirname "$0")"

targets=(~/.claude/skills ~/.grok/skills)

for target in "${targets[@]}"; do
  mkdir -p "$target"
  for d in skills/*/; do
    name="$(basename "$d")"
    ln -sf "$PWD/$d" "$target/$name"
  done
  echo "Linked into $target"
done
