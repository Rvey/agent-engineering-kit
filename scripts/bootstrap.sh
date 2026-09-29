#!/usr/bin/env bash
# bootstrap.sh — install the Agent Engineering Kit into a repository.
#
# Usage:
#   scripts/bootstrap.sh <target-dir> [--force] [--with-cursor] [--skills-only]
#
# What it does:
#   - copies AGENTS.md into <target-dir> (skipped if present unless --force)
#   - copies .agents/skills/ into <target-dir>/.agents/skills/
#   - copies .cursor/rules/ templates when --with-cursor is given
#   - with --skills-only, copies only the skills (no AGENTS.md)
#
# Nothing is deleted. Existing files are never overwritten unless --force.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-}"
FORCE=0
WITH_CURSOR=0
SKILLS_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --with-cursor) WITH_CURSOR=1 ;;
    --skills-only) SKILLS_ONLY=1 ;;
    --help|-h)
      sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
  esac
done

if [[ -z "$TARGET" || "$TARGET" == --* ]]; then
  echo "error: usage: $0 <target-dir> [--force] [--with-cursor] [--skills-only]" >&2
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
    echo "  skip   AGENTS.md (exists — merge the template manually, or use --force)"
    echo "         The kit's AGENTS.md is a template: adapt it to this repo."
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

cat <<'NEXT'

Next steps
  1. Adapt AGENTS.md: replace every <placeholder> and example command with
     this repo's real gates and paths.
  2. Wire the same gate commands into CI.
  3. Start agent sessions with: "Read AGENTS.md and follow it."
  4. When a workflow burns you twice, add a skill (scripts/new-skill.sh) and a
     routing row in AGENTS.md.

Docs: docs/01-agent-workflow.md (the loop), docs/03-verification-gates.md
(gates), docs/04-performance-guards.md (the hard rules), docs/05-adding-a-skill.md.
NEXT
