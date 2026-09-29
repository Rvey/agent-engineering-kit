#!/usr/bin/env bash
# Check files required for a local Agent Engineering Kit installation.
# Usage: scripts/setup-check.sh <target-dir> [--no-github]
set -euo pipefail

target="${1:-}"
github=1
if [[ "${2:-}" == --no-github ]]; then github=0; fi
if [[ -z "$target" || "$target" == --* || ! -d "$target" || $# -gt 2 || ( $# -eq 2 && "${2:-}" != --no-github ) ]]; then
  echo "usage: $0 <target-dir> [--no-github]" >&2
  exit 2
fi
target="$(cd "$target" && pwd -P)"
cd "$target"
failed=0

pass() { printf 'PASS  %s\n' "$1"; }
missing() { printf 'TODO  %s\n' "$1"; failed=1; }

if [[ -f AGENTS.md ]] && ! grep -Eq 'agent-engineering-kit:template|<Project Name>|<lint command>|<typecheck command>|<test command>|<format command>|<build command>' AGENTS.md; then
  pass "Project-specific AGENTS.md"
else
  missing "Generate project-specific AGENTS.md"
fi

if [[ -f .agents/skills/full-setup/SKILL.md && -f .agents/skills/agents-md/SKILL.md ]]; then
  pass "Setup and generation skills"
else
  missing "Install the kit skills"
fi

if [[ -f .agents/install-hooks.sh && -f .agents/setup-check.sh && -f .agents/hooks/pre-commit ]]; then
  pass "Local setup tools"
else
  missing "Install the local setup tools"
fi

if [[ -f .agents/verify.sh ]] && bash -n .agents/verify.sh 2>/dev/null && [[ -x .agents/verify.sh ]]; then
  pass "Executable verification script"
else
  missing "Generate an executable .agents/verify.sh"
fi

if (( github )); then
  if [[ -f .github/workflows/gates.yml ]] && grep -Eq 'bash \.agents/verify\.sh' .github/workflows/gates.yml && ! grep -q 'SETUP: replace this' .github/workflows/gates.yml; then
    pass "CI verification wired; toolchain marker cleared"
  else
    missing "Configure .github/workflows/gates.yml with the repository toolchain and dependency install"
  fi
  if [[ -f .github/workflows/policy.yml && -f .github/scripts/policy-check.sh ]]; then
    pass "PR policy files"
  else
    missing "Install the PR policy files"
  fi
  if [[ -f .github/CODEOWNERS ]] && grep -Eq '^/[^#]*@[A-Za-z0-9][A-Za-z0-9-]*' .github/CODEOWNERS && ! grep -Eq '@your-org/' .github/CODEOWNERS; then
    pass "CODEOWNERS configured"
  else
    missing "Configure .github/CODEOWNERS with real owners"
  fi
fi

if [[ "$(git rev-parse --show-toplevel 2>/dev/null || true)" == "$target" ]]; then
  hooks_path="$(git config --get core.hooksPath || true)"
  if [[ -n "$hooks_path" && -x "$hooks_path/pre-commit" ]] && grep -Eq '\.agents/verify\.sh --fast' "$hooks_path/pre-commit"; then
    pass "Fast gates are installed as a pre-commit hook"
  else
    missing "Install or integrate the fast pre-commit gate"
  fi
else
  missing "Run setup at the Git repository root"
fi

if (( failed )); then
  echo "Local setup: INCOMPLETE"
  exit 1
fi
echo "Local setup: READY. Check GitHub branch protection separately."
