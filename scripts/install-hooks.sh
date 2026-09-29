#!/usr/bin/env bash
# install-hooks.sh — install the kit's pre-commit hook into a repository.
#
# Usage:
#   scripts/install-hooks.sh [target-dir]     (default: current directory)
#
# What it does:
#   - copies templates/hooks/pre-commit to <target>/.githooks/pre-commit
#   - points the repo at it via `git config core.hooksPath .githooks`
#
# The hook runs `bash .agents/verify.sh --fast` and refuses to commit when the
# fast gates fail. Remove with: git config --unset core.hooksPath
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-.}"

if [[ ! -d "$TARGET" ]]; then
  echo "error: no such directory: $TARGET" >&2
  exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

if ! git -C "$TARGET" rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not a git repository: $TARGET" >&2
  exit 1
fi

mkdir -p "$TARGET/.githooks"
cp "$KIT_DIR/templates/hooks/pre-commit" "$TARGET/.githooks/pre-commit"
chmod +x "$TARGET/.githooks/pre-commit"
git -C "$TARGET" config core.hooksPath .githooks

echo "Installed pre-commit hook: $TARGET/.githooks/pre-commit"
echo "  core.hooksPath is now .githooks"
echo
echo "It runs: bash .agents/verify.sh --fast"
echo "Keep the fast gates quick (lint + typecheck, not the full test suite)."
echo "Remove with: git -C \"$TARGET\" config --unset core.hooksPath"
