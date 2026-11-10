#!/usr/bin/env bash
# kit-route-reminder.sh -- Claude Code UserPromptSubmit hook.
# Adds a one-line routing reminder to every prompt so the agent routes the
# task with the boost-prompt skill. Prints nothing when the skill is absent.
set -euo pipefail

# Drain the hook payload; only the reminder matters here.
cat > /dev/null

root="${CLAUDE_PROJECT_DIR:-$PWD}"
[[ -f "$root/.agents/skills/boost-prompt/SKILL.md" ]] || exit 0

cat <<'EOF'
Routing: before the first tool call of a task that edits files or runs more than one command, state "Route: model · effort · agents · sessions" from .agents/skills/boost-prompt/SKILL.md (Route mode) and wait for the user's yes. House rules: never Fable; Opus at medium, ask before high; recommend sessions and pinned helpers (scout, worker, reviewer) whenever the task has pieces.
EOF
