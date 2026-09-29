#!/usr/bin/env bash
# new-skill.sh — scaffold a correctly shaped skill under .agents/skills/.
#
# Usage:
#   scripts/new-skill.sh <skill-name>
#
# Creates .agents/skills/<skill-name>/SKILL.md with valid frontmatter and a
# workflow skeleton. Refuses to overwrite an existing skill. Reminds you to
# wire the skill into AGENTS.md.
set -euo pipefail

NAME="${1:-}"

if [[ -z "$NAME" ]]; then
  echo "error: usage: $0 <skill-name>" >&2
  exit 1
fi

if [[ ! "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
  echo "error: skill name must be kebab-case (a-z, 0-9, dashes): '$NAME'" >&2
  exit 1
fi

DEST=".agents/skills/$NAME"

if [[ -e "$DEST" ]]; then
  echo "error: $DEST already exists — edit it instead, or choose another name." >&2
  exit 1
fi

mkdir -p "$DEST"

TITLE="$(printf '%s' "$NAME" | awk -F- '{for (i=1; i<=NF; i++) $i=toupper(substr($i,1,1)) substr($i,2); print}' OFS=' ')"

cat > "$DEST/SKILL.md" <<EOF
---
name: $NAME
description: "One or two sentences on what this does. Use when <trigger 1>, <trigger 2>, or <trigger 3>."
---

# $TITLE

One paragraph on the philosophy: why this workflow exists and what it prevents.

## When to use

- <concrete trigger>
- <concrete trigger>

## When NOT to use

- <case that belongs to another skill>

## Workflow

1. **<Step name>.** <What to do, with a deliverable.>
2. **<Step name>.** <What to do, with a deliverable.>
3. **<Step name>.** <What to do, with a deliverable.>

## Verification

- <command that proves the work is done>
- <what to report in the handoff>
EOF

echo "Created $DEST/SKILL.md"
echo
echo "Next steps:"
echo "  1. Fill in the workflow and verification gates."
echo "  2. Add a row to the task → skill routing table in AGENTS.md:"
echo "       | <task description> | .agents/skills/$NAME/SKILL.md |"
echo "  3. Smoke-test it with a real task that should trigger the skill."
