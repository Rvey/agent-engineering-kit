#!/usr/bin/env bash
# install-hooks.sh — install the kit's pre-commit hook into a repository.
#
# Usage:
#   scripts/install-hooks.sh [target-dir]     (default: current directory)
#
# What it does:
#   - installs into .githooks only if that path is free or already ours
#   - points the repo at it unless another hooksPath is configured
#
# The hook runs `bash .agents/verify.sh --fast` and refuses to commit when the
# fast gates fail. Remove with: git config --unset core.hooksPath
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [[ "$(basename "$SCRIPT_DIR")" == .agents ]]; then
  hook_source="$SCRIPT_DIR/hooks/pre-commit"
else
  hook_source="$SCRIPT_DIR/../templates/hooks/pre-commit"
fi
TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
  echo "error: no such directory: $TARGET" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd -P)"

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not a git repository: $TARGET" >&2
  exit 1
fi
if [[ "$(git -C "$TARGET" rev-parse --show-toplevel)" != "$TARGET" ]]; then
  echo "error: pass the git repository root, not a subdirectory" >&2
  exit 1
fi

hook_path="$TARGET/.githooks/pre-commit"
configured_path="$(git -C "$TARGET" config --get core.hooksPath || true)"
if [[ -n "$configured_path" && "$configured_path" != .githooks ]]; then
  echo "error: core.hooksPath is already '$configured_path'; integrate the fast gate into that hook" >&2
  exit 1
fi
default_hook="$(git -C "$TARGET" rev-parse --git-path hooks/pre-commit)"
[[ "$default_hook" == /* ]] || default_hook="$TARGET/$default_hook"
if [[ -z "$configured_path" && -f "$default_hook" ]]; then
  echo "error: a Git pre-commit hook already exists at '$default_hook'; integrate the fast gate there" >&2
  exit 1
fi
if [[ -L "$TARGET/.githooks" || -L "$hook_path" ]]; then
  echo "error: refusing symlink hook path" >&2
  exit 1
fi
if [[ -e "$hook_path" ]] && ! cmp -s "$hook_source" "$hook_path"; then
  echo "error: existing pre-commit hook differs; add 'bash .agents/verify.sh --fast' to it manually" >&2
  exit 1
fi

mkdir -p "$TARGET/.githooks"
if [[ ! -e "$hook_path" ]]; then
  cp "$hook_source" "$hook_path"
fi
chmod +x "$TARGET/.githooks/pre-commit"
git -C "$TARGET" config core.hooksPath .githooks

echo "Installed pre-commit hook: $TARGET/.githooks/pre-commit"
echo "  core.hooksPath is now .githooks"
echo
echo "It runs: bash .agents/verify.sh --fast"
echo "Keep the fast gates quick (lint + typecheck, not the full test suite)."
echo "Remove with: git -C \"$TARGET\" config --unset core.hooksPath"
