#!/usr/bin/env bash
# verify.sh -- starter gate for a Node/TypeScript repository.
#
# This is a STARTER: replace the SETUP lines with the real commands from
# package.json. Keep --fast limited to lint + types so the pre-commit hook
# stays under a couple of seconds.
set -euo pipefail
cd "$(dirname "$0")/.."
fast=0
[ "${1:-}" = "--fast" ] && fast=1

echo "== install (locked) =="
# SETUP: use the lockfile you actually have.
if [ -f package-lock.json ]; then npm ci --no-audit --no-fund
elif [ -f pnpm-lock.yaml ]; then pnpm install --frozen-lockfile
elif [ -f yarn.lock ]; then yarn install --immutable
else echo "no Node lockfile found -- run your install command, then rerun" >&2; exit 1
fi

echo "== lint =="
# SETUP: replace with your script name, e.g. npm run lint
npm run lint

echo "== types =="
# SETUP: replace with your script name, e.g. npm run typecheck
npm run typecheck

if (( ! fast )); then
  echo "== tests =="
  # SETUP: replace with your test script, e.g. npm test
  npm test

  echo "== build =="
  # SETUP: replace with your build script when the repo ships a bundle
  npm run build
fi

echo "verify: OK"
