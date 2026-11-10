#!/usr/bin/env bash
# kit-agent-guard.sh -- Claude Code PreToolUse hook for helper agents.
# Fails closed: a helper starts only on a known model (its definition in
# .claude/agents/, an explicit model, or the session model for forks). Fable is refused; Opus above medium
# effort goes to the user for a yes. Anything unreadable is refused.
set -euo pipefail

decide() {
  jq -n --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

if ! command -v jq > /dev/null 2>&1; then
  # Without jq there is no safe way to decide; deny in plain JSON.
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"kit-agent-guard needs jq to check helper models. Install jq, then retry."}}'
  exit 0
fi

payload="$(cat)"
field() {
  jq -er --arg k "$1" '.tool_input[$k] // "" | tostring | ascii_downcase' <<< "$payload" 2> /dev/null
}
if ! agent="$(field subagent_type)" || ! model="$(field model)" || ! effort="$(field effort)"; then
  decide deny "kit-agent-guard could not read the helper request."
fi

# frontmatter_value <file> <key> -- lower-cased value of a frontmatter key.
frontmatter_value() {
  awk -v k="$2" 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit}
    inside && index($0, k ":") == 1 {v=substr($0, length(k) + 2); gsub(/^[ \t"]+|[ \t"]+$/, "", v); print tolower(v); exit}' "$1"
}

# The agent's own definition decides its model and default effort: project
# agents first, then the user's. No definition and no model means unknown.
pinned=""
for dir in "${CLAUDE_PROJECT_DIR:-$PWD}/.claude/agents" "${HOME:-}/.claude/agents"; do
  for def in "$dir"/*.md; do
    [[ -f "$def" && "$(frontmatter_value "$def" name)" == "$agent" ]] || continue
    pinned="$(frontmatter_value "$def" model)"
    [[ -n "$pinned" && "$pinned" != inherit ]] || pinned="session"
    [[ -n "$effort" ]] || effort="$(frontmatter_value "$def" effort)"
    break 2
  done
done
# Forks and the built-in Explore run on the main session's model.
if [[ -z "$pinned" ]]; then
  case "$agent" in fork|explore) pinned="session" ;; esac
fi
effective="${model:-$pinned}"

family=""
if [[ "$effective" =~ ^(claude-)?(haiku|sonnet|opus)(-[0-9a-z.-]+)?$ ]]; then
  family="${BASH_REMATCH[2]}"
fi
case "$effective" in
  *fable*)
    decide deny "House rule: never use Fable. Use opus at medium, or a pinned helper (scout, worker, reviewer)." ;;
  "")
    decide deny "Start helpers with a pinned agent (scout, worker, reviewer, Explore) or pass model: haiku, sonnet or opus." ;;
  session)
    # The session model is unknown here and may be Opus.
    case "$effort" in
      high|xhigh|max)
        decide ask "House rule: Opus runs at medium. This helper inherits the session model and asks for $effort effort; approve only if that is intended." ;;
    esac
    exit 0 ;;
esac
[[ -n "$family" ]] || decide deny "Unknown helper model '$effective'. Use haiku, sonnet or opus."
if [[ "$family" == opus ]]; then
  case "$effort" in
    high|xhigh|max)
      decide ask "House rule: Opus runs at medium. This helper asks for $effort effort; approve only if you want Opus above medium." ;;
  esac
fi
exit 0
