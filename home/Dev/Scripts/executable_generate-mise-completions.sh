#!/bin/bash

# This script generates zsh completion files for all tools installed by mise.
# Completions are saved to $XDG_DATA_HOME/zsh/completions (default: ~/.local/share/zsh/completions).
#
# Usage:
#   generate-mise-completions.sh
#
# Example:
#   generate-mise-completions.sh

set -euo pipefail

MISEROOT="${XDG_DATA_HOME:-$HOME/.local/share}/mise/installs"
COMP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/completions"

mkdir -p "$COMP_DIR"

# Common commands CLIs use to emit zsh completions
declare -a ATTEMPTS=(
  "completion zsh"
  "completions zsh"
  "--completion zsh"
  "completion --zsh"
  "generate-completion zsh"
)

if [[ ! -d "$MISEROOT" ]]; then
  echo "Mise installs root not found: $MISEROOT" >&2
  exit 1
fi

# Each top-level directory name under MISEROOT is a tool name
for tool in "$MISEROOT"/*; do
  [[ -d "$tool" ]] || continue
  tool_name="$(basename "$tool")"

  out="$COMP_DIR/_$tool_name"
  success=0

  for cmd in "${ATTEMPTS[@]}"; do
    tmp="$(mktemp)"
    if mise exec "$tool_name" -- $tool_name $cmd >"$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
      mv "$tmp" "$out"
      echo "✓ $tool_name ($cmd)"
      success=1
      break
    fi
    rm -f "$tmp"
  done

  if [[ $success -eq 0 ]]; then
    echo "✗ $tool_name (no known completion generator)" >&2
  fi
done

echo "Done. Ensure in your .zshrc (before compinit):"
echo 'fpath=("$XDG_DATA_HOME/zsh/completions" $fpath)'
