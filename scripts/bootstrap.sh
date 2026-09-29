#!/usr/bin/env bash
# bootstrap.sh — install the Agent Engineering Kit into a repository.
#
# Usage:
#   scripts/bootstrap.sh <target-dir> [--force] [--with-cursor] [--skills-only] [--no-github] [--dry-run]
#
# What it does:
#   - copies templates/AGENTS.template.md into <target-dir>/AGENTS.md (skipped
#     if present unless --force). The template is a shape, not content: the
#     next step is generating the project file with the agents-md skill.
#   - copies .agents/skills/ into <target-dir>/.agents/skills/
#   - copies local setup tools and verify.sh starters under <target-dir>/.agents/
#   - copies the loop-enforcement files into <target-dir>/.github/
#     (PR template, no-AI policy workflow + check script, CODEOWNERS example)
#   - copies .cursor/rules/ templates when --with-cursor is given
#   - with --skills-only, copies only the skills (no AGENTS.md)
#   - with --no-github, skips the .github/ files (non-GitHub hosts)
#   - with --dry-run, prints every copy/skip decision and writes nothing
#
# Nothing is deleted. --force overwrites matching kit paths, not extra files in skill directories.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
FORCE=0
WITH_CURSOR=0
SKILLS_ONLY=0
WITH_GITHUB=1
DRY=0

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
  exit 0
fi

for arg in "${@:2}"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --with-cursor) WITH_CURSOR=1 ;;
    --skills-only) SKILLS_ONLY=1 ;;
    --no-github) WITH_GITHUB=0 ;;
    --dry-run) DRY=1 ;;
    --help|-h)
      awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
      exit 0
      ;;
    *) echo "error: unknown option: $arg" >&2; exit 1 ;;
  esac
done

if [[ -z "$TARGET" || "$TARGET" == --* ]]; then
  echo "error: usage: $0 <target-dir> [--force] [--with-cursor] [--skills-only] [--no-github] [--dry-run]" >&2
  exit 1
fi

if [[ ! -d "$TARGET" ]]; then
  echo "error: target directory does not exist: $TARGET" >&2
  exit 1
fi

TARGET="$(cd "$TARGET" && pwd -P)"
echo "Installing Agent Engineering Kit"
echo "  from: $KIT_DIR"
echo "  into: $TARGET"
echo

copy_file() {
  local src="$1" dest="$2"
  local parent
  parent="$(dirname "$dest")"
  while [[ "$parent" != "$TARGET" ]]; do
    if [[ -L "$parent" ]]; then
      echo "error: refusing symlink parent: $parent" >&2
      exit 1
    fi
    parent="$(dirname "$parent")"
  done
  if [[ -L "$dest" ]]; then
    echo "error: refusing symlink destination: $dest" >&2
    exit 1
  fi
  if [[ -d "$dest" ]]; then
    echo "error: expected a file destination: $dest" >&2
    exit 1
  fi
  if [[ -e "$dest" && "$FORCE" -ne 1 ]]; then
    echo "  skip   $(basename "$dest") (exists — use --force to overwrite)"
  elif [[ "$DRY" -eq 1 ]]; then
    echo "  plan   ${dest#"$TARGET"/}"
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
    copy_file "$KIT_DIR/templates/AGENTS.template.md" "$TARGET/AGENTS.md"
  fi
fi

# Copy missing files on rerun; --force updates kit files without removing local additions.
[[ "$DRY" -eq 1 ]] || mkdir -p "$TARGET/.agents/skills"
for skill_dir in "$KIT_DIR"/.agents/skills/*/; do
  name="$(basename "$skill_dir")"
  if [[ -L "$TARGET/.agents/skills/$name" ]]; then
    echo "error: refusing symlink skill directory: $name" >&2
    exit 1
  fi
  while IFS= read -r -d '' source_file; do
    relative_file="${source_file#"$KIT_DIR"/}"
    copy_file "$source_file" "$TARGET/$relative_file"
  done < <(find "$skill_dir" -type f -print0)
done

if [[ "$SKILLS_ONLY" -ne 1 ]]; then
  [[ "$DRY" -eq 1 ]] || mkdir -p "$TARGET/.agents/skills"
  copy_file "$KIT_DIR/.agents/skills/README.md" "$TARGET/.agents/skills/README.md"
  copy_file "$KIT_DIR/scripts/install-hooks.sh" "$TARGET/.agents/install-hooks.sh"
  copy_file "$KIT_DIR/scripts/setup-check.sh" "$TARGET/.agents/setup-check.sh"
  copy_file "$KIT_DIR/templates/hooks/pre-commit" "$TARGET/.agents/hooks/pre-commit"
  for starter in "$KIT_DIR"/templates/verify/*.sh; do
    copy_file "$starter" "$TARGET/.agents/verify-templates/$(basename "$starter")"
  done
fi

if [[ "$WITH_CURSOR" -eq 1 ]]; then
  for rule in "$KIT_DIR"/.cursor/rules/*.mdc; do
    copy_file "$rule" "$TARGET/.cursor/rules/$(basename "$rule")"
  done
fi

if [[ "$WITH_GITHUB" -eq 1 && "$SKILLS_ONLY" -ne 1 ]]; then
  copy_file "$KIT_DIR/templates/github/pull_request_template.md" "$TARGET/.github/pull_request_template.md"
  copy_file "$KIT_DIR/templates/github/workflows/policy.yml" "$TARGET/.github/workflows/policy.yml"
  copy_file "$KIT_DIR/templates/github/workflows/gates.yml" "$TARGET/.github/workflows/gates.yml"
  copy_file "$KIT_DIR/templates/github/scripts/policy-check.sh" "$TARGET/.github/scripts/policy-check.sh"
  copy_file "$KIT_DIR/templates/github/CODEOWNERS.example" "$TARGET/.github/CODEOWNERS.example"
fi

cat <<'NEXT'

Next steps
  1. In the target repo, ask your agent:
         Complete this repository's Agent Engineering Kit setup. Follow
         .agents/skills/full-setup/SKILL.md. Derive unknowns from the repo;
         ask me only for facts or permissions you cannot determine.
  2. Check local readiness with bash .agents/setup-check.sh .
  3. No .agents/verify.sh yet? Copy one starter and edit the SETUP lines:
         .agents/verify-templates/shell.sh | node.sh | python.sh
     Then bash .agents/setup-check.sh . --fix installs the fast commit hook.
  4. Start future sessions with: "Read AGENTS.md and follow it."

Docs: docs/01-agent-workflow.md (the loop), docs/03-verification-gates.md
(gates), docs/04-performance-guards.md (the hard rules), docs/05-adding-a-skill.md,
docs/07-loop-enforcement.md (making juniors unable to skip the loop).
NEXT
