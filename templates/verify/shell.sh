#!/usr/bin/env bash
# verify.sh -- starter gate for a shell/tooling repository.
#
# This is a STARTER: replace the placeholders below. Pick one starter for your
# stack, delete the lines that do not apply, and keep the fast/full split:
#   --fast  runs in the pre-commit hook; must finish in a couple of seconds
#   (none)  runs in CI; may be slower and more thorough
set -euo pipefail
cd "$(dirname "$0")/.."
fast=0
[ "${1:-}" = "--fast" ] && fast=1

echo "== syntax =="
while IFS= read -r f; do bash -n "$f"; done < <(find . -name '*.sh' -not -path './.git/*' 2>/dev/null)

if command -v shellcheck >/dev/null 2>&1; then
  echo "== shellcheck =="
  find . -name '*.sh' -not -path './.git/*' -print0 | xargs -0 shellcheck -S warning
fi

if (( ! fast )); then
  echo "== tests =="
  # SETUP: replace with your test command, e.g. bash tests/run.sh
  echo "no test command configured yet"
fi

echo "verify: OK"
