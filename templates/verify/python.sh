#!/usr/bin/env bash
# verify.sh -- starter gate for a Python repository.
#
# This is a STARTER: replace the SETUP lines with the real commands from
# pyproject.toml. Keep --fast limited to lint + types so the pre-commit hook
# stays under a couple of seconds.
set -euo pipefail
cd "$(dirname "$0")/.."
fast=0
[ "${1:-}" = "--fast" ] && fast=1

echo "== install (locked) =="
# SETUP: use the tool your repo standardizes on (uv, poetry, pip-tools, ...).
if [ -f uv.lock ]; then uv sync --frozen
elif [ -f poetry.lock ]; then poetry install --sync
else echo "no Python lockfile found -- install dependencies, then rerun" >&2; exit 1
fi

run() { if command -v uv >/dev/null 2>&1 && [ -f uv.lock ]; then uv run "$@"; else "$@"; fi; }

echo "== lint =="
run ruff check .

echo "== format check =="
run ruff format --check .

echo "== types =="
# SETUP: drop this line if the repo is intentionally untyped.
run mypy .

if (( ! fast )); then
  echo "== tests =="
  run pytest
fi

echo "verify: OK"
