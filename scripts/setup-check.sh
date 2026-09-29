#!/usr/bin/env bash
# Check local readiness of an adopted repository, or of this kit checkout with --kit.
# Usage: scripts/setup-check.sh <target-dir> [--no-github] [--fix] [--strict] [--kit]
#   --fix    scaffold safe missing pieces (verify.sh starter, hooks install)
#   --strict also require a clean tree and a configured remote
#   --kit    check this kit checkout instead of an adopted repo
# Exit 0 when READY, 1 when INCOMPLETE, 2 on usage error.
set -euo pipefail

target=""
github=1
fix=0
strict=0
kit=0
for arg in "$@"; do
  case "$arg" in
    --no-github) github=0 ;;
    --fix) fix=1 ;;
    --strict) strict=1 ;;
    --kit) kit=1 ;;
    --help|-h) sed -n '2,7p' "$0" | sed 's/^# //'; exit 0 ;;
    *) if [[ "$arg" == --* ]]; then echo "error: unknown option: $arg" >&2; exit 2; elif [[ -z "$target" ]]; then target="$arg"; else echo "error: unexpected argument: $arg" >&2; exit 2; fi ;;
  esac
done
if (( kit )); then
  cd "$(dirname "$0")/.."
  target="$(pwd -P)"
  failed=0
  pass() { echo "PASS  $1"; }
  missing() { echo "TODO  $1"; failed=1; }
  if grep -Eq 'agent-engineering-kit:template' templates/AGENTS.template.md; then pass "Template marker kept in templates/"; else missing "Restore template marker in templates/AGENTS.template.md"; fi
  if ! grep -Eq '<Project Name>|<lint command>|<typecheck command>|<test command>|<format command>|<build command>' AGENTS.md; then pass "Root AGENTS.md is project-specific"; else missing "Regenerate root AGENTS.md from repo evidence"; fi
  if [ -f scripts/lint.sh ] && [ -f tests/setup-smoke.sh ] && [ -d templates/verify ]; then pass "Lint, smoke test, verify starters present"; else missing "Restore scripts/lint.sh, tests/setup-smoke.sh, templates/verify/"; fi
  if (( failed )); then echo "Kit self-check: INCOMPLETE"; exit 1; fi
  echo "Kit self-check: READY"
  exit 0
fi

if [ -z "$target" ] || [ ! -d "$target" ]; then echo "usage: $0 <target-dir> [--no-github] [--fix] [--strict] [--kit]" >&2; exit 2; fi
target="$(cd "$target" && pwd -P)"
cd "$target"
failed=0

pass() { echo "PASS  $1"; }
missing() { echo "TODO  $1 -- fix: $2"; failed=1; }
if [ -f AGENTS.md ] && ! grep -Eq 'agent-engineering-kit:template|<Project Name>|<lint command>|<typecheck command>|<test command>|<format command>|<build command>' AGENTS.md; then
  pass "Project-specific AGENTS.md"
else
  missing "Generate project-specific AGENTS.md" "follow .agents/skills/agents-md/SKILL.md"
fi

if [ -f .agents/skills/full-setup/SKILL.md ] && [ -f .agents/skills/agents-md/SKILL.md ]; then
  pass "Setup and generation skills"
else
  missing "Install the kit skills" "rerun scripts/bootstrap.sh <dir>"
fi

if [ -f .agents/install-hooks.sh ] && [ -f .agents/setup-check.sh ] && [ -f .agents/hooks/pre-commit ] && [ -f .agents/verify-templates/shell.sh ]; then
  pass "Local setup tools"
else
  missing "Install the local setup tools" "rerun scripts/bootstrap.sh <dir>"
fi

if [ -f .agents/verify.sh ] && bash -n .agents/verify.sh 2>/dev/null && [ -x .agents/verify.sh ] && ! grep -q 'SETUP:' .agents/verify.sh; then
  pass "Executable verification script"
elif (( fix )) && [ ! -f .agents/verify.sh ]; then
  mkdir -p .agents
  starter=".agents/verify-templates/shell.sh"
  [ -f "$starter" ] || starter="$(dirname "$0")/../templates/verify/shell.sh"
  cp "$starter" .agents/verify.sh
  chmod +x .agents/verify.sh
  echo "FIXED .agents/verify.sh from shell starter -- edit it for your toolchain"
  failed=1
else
  missing "Generate an executable .agents/verify.sh" "copy .agents/verify-templates/<stack>.sh or run with --fix"
fi
if (( github )); then
  if [ -f .github/workflows/gates.yml ] && grep -Eq 'bash .agents/verify.sh' .github/workflows/gates.yml && ! grep -q 'SETUP: replace this' .github/workflows/gates.yml; then
    pass "CI verification wired; toolchain marker cleared"
  else
    missing "Configure .github/workflows/gates.yml" "add toolchain install, remove SETUP marker"
  fi
  if [ -f .github/workflows/policy.yml ] && [ -f .github/scripts/policy-check.sh ]; then
    pass "PR policy files"
  else
    missing "Install the PR policy files" "rerun scripts/bootstrap.sh <dir>"
  fi
  if [ -f .github/CODEOWNERS ] && grep -Eq '^/[^#]*@[A-Za-z0-9][A-Za-z0-9-]*' .github/CODEOWNERS && ! grep -Eq '@your-org/' .github/CODEOWNERS; then
    pass "CODEOWNERS configured"
  else
    missing "Configure .github/CODEOWNERS with real owners" "copy CODEOWNERS.example and edit handles"
  fi
fi

if [ "$(git rev-parse --show-toplevel 2>/dev/null || true)" = "$target" ]; then
  hooks_path="$(git config --get core.hooksPath || true)"
  if [ -n "$hooks_path" ] && [ -x "$hooks_path/pre-commit" ]; then
    pass "Fast gates installed as pre-commit hook"
  elif (( fix )); then
    if bash .agents/install-hooks.sh . 2>/dev/null; then echo "FIXED pre-commit hook installed"; else missing "Install or integrate the fast pre-commit gate" "run .agents/install-hooks.sh or merge manually"; fi
  else
    missing "Install or integrate the fast pre-commit gate" "run .agents/install-hooks.sh or rerun with --fix"
  fi
else
  missing "Run setup at the Git repository root" "cd to repo root first"
fi

if (( strict )); then
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then missing "Working tree clean (strict)" "commit or stash changes"; fi
  if ! git remote get-url origin >/dev/null 2>&1; then missing "Git remote configured (strict)" "git remote add origin <url>"; fi
fi

if (( failed )); then
  echo "Local setup: INCOMPLETE"
  exit 1
fi
echo "Local setup: READY. Check GitHub branch protection separately."
