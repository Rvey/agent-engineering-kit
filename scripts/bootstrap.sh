#!/usr/bin/env bash
# bootstrap.sh — install the Agent Engineering Kit into a repository.
#
# Usage:
#   scripts/bootstrap.sh <target-dir> [--force] [--with-cursor] [--skills-only] [--no-github]
#
# What it does:
#   - copies the AGENTS.md template into <target-dir> (skipped if present
#     unless --force). The template is a shape, not content: the next step is
#     to generate the project-specific file with the agents-md skill.
#   - copies .agents/skills/ into <target-dir>/.agents/skills/
#   - copies the loop-enforcement files into <target-dir>/.github/
#     (PR template, no-AI policy workflow + check script, CODEOWNERS example)
#   - copies .cursor/rules/ templates when --with-cursor is given
#   - with --skills-only, copies only the skills (no AGENTS.md)
#   - with --no-github, skips the .github/ files (non-GitHub hosts)
#
# Nothing is deleted. Existing files are never overwritten unless --force.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
FORCE=0
WITH_CURSOR=0
SKILLS_ONLY=0
WITH_GITHUB=1

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --with-cursor) WITH_CURSOR=1 ;;
    --skills-only) SKILLS_ONLY=1 ;;
    --no-github) WITH_GITHUB=0 ;;
    --help|-h)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
  esac
done

if [[ -z "$TARGET" || "$TARGET" == --* ]]; then
  echo "error: usage: $0 <target-dir> [--force] [--with-cursor] [--skills-only] [--no-github]" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "error: target directory does not exist: $TARGET" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd)"
echo "Installing Agent Engineering Kit"
echo "  from: $KIT_DIR"
echo "  into: $TARGET"
echo

copy_file() {
  local src="$1" dest="$2"
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    echo "  skip   $(basename "$dest") (exists — use --force to overwrite)"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  copy   ${dest#"$TARGET"/}"
  fi
}

if [[ "$SKILLS_ONLY" -ne 1 ]]; then
  if [[ -e "$TARGET/AGENTS.md" && "$FORCE" -ne 1 ]]; then
    echo "  skip   AGENTS.md (exists — merge missing facts, or use --force)"
    echo "         To merge or refresh it from real repo evidence, run the"
    echo "         generation prompt printed at the end of this script."
  else
    copy_file "$KIT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  fi
fi

# Skills: always merged (never deletes), each dir copied individually so a
# partially-installed target gets topped up.
mkdir -p "$TARGET/.agents/skills"
for skill_dir in "$KIT_DIR"/.agents/skills/*/; do
  name="$(basename "$skill_dir")"
  if [[ -e "$TARGET/.agents/skills/$name" && "$FORCE" -ne 1 ]]; then
    echo "  skip   .agents/skills/$name (exists — use --force to overwrite)"
  else
    rm -rf "$TARGET/.agents/skills/$name"
    cp -R "$skill_dir" "$TARGET/.agents/skills/$name"
    echo "  copy   .agents/skills/$name"
  fi
done

if [[ "$SKILLS_ONLY" -ne 1 ]]; then
  mkdir -p "$TARGET/.agents/skills"
  copy_file "$KIT_DIR/.agents/skills/README.md" "$TARGET/.agents/skills/README.md"
fi

if [[ "$WITH_CURSOR" -eq 1 ]]; then
  for rule in "$KIT_DIR"/.cursor/rules/*.mdc; do
    copy_file "$rule" "$TARGET/.cursor/rules/$(basename "$rule")"
  done
fi

if [[ "$WITH_GITHUB" -eq 1 && "$SKILLS_ONLY" -ne 1 ]]; then
  copy_file "$KIT_DIR/templates/github/pull_request_template.md" "$TARGET/.github/pull_request_template.md"
  copy_file "$KIT_DIR/templates/github/workflows/policy.yml" "$TARGET/.github/workflows/policy.yml"
  copy_file "$KIT_DIR/templates/github/scripts/policy-check.sh" "$TARGET/.github/scripts/policy-check.sh"
  copy_file "$KIT_DIR/templates/github/CODEOWNERS.example" "$TARGET/.github/CODEOWNERS.example"
fi

cat <<'NEXT'

Next steps
  1. Generate this repo's AGENTS.md. Open your agent in the target repo and
     paste (fill in what you know; leave out what you don't):

         Generate this repo's AGENTS.md. Follow
         .agents/skills/agents-md/SKILL.md.

         Brief: we built <what it is>. Stack: <stack>. Layout: <where
         things live>. Commands: lint=<cmd>, typecheck=<cmd>, test=<cmd>.
         Things agents keep getting wrong: <incidents, if any>.

     No brief? Paste instead:
         Generate this repo's AGENTS.md. No brief — derive everything from
         the repo. Follow .agents/skills/agents-md/SKILL.md.

     The generator replaces the template, traces every gate command to real
     config, and asks instead of guessing. It will not ship placeholders.
     Full instructions: README.md → Generate AGENTS.md.
  2. Install the pre-commit hook (runs the fast gates before each commit):
         scripts/install-hooks.sh <this-project>     # run from the kit
  3. Wire the gate commands into CI and require the "policy / loop evidence"
     check in branch protection. Rename .github/CODEOWNERS.example to
     .github/CODEOWNERS and set real owners. Why it works this way:
     docs/07-loop-enforcement.md.
  4. Start agent sessions with: "Read AGENTS.md and follow it."
  5. When a workflow burns you twice, add a skill (scripts/new-skill.sh) and a
     routing row in AGENTS.md.

Docs: docs/01-agent-workflow.md (the loop), docs/03-verification-gates.md
(gates), docs/04-performance-guards.md (the hard rules), docs/05-adding-a-skill.md,
docs/07-loop-enforcement.md (making juniors unable to skip the loop).
NEXT
