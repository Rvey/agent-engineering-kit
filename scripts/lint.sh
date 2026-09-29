#!/usr/bin/env bash
# lint.sh -- fast static checks for the kit repo. Exit 0 when clean.
# Usage: bash scripts/lint.sh
#   1. bash -n syntax on every shell file
#   2. shellcheck (required when installed; skipped with a warning otherwise)
#   3. skill frontmatter (name + description with Use when) and references/ integrity
#   4. relative markdown links resolve to files in the repo
set -euo pipefail
cd "$(dirname "$0")/.."
failed=0
fail() { echo "FAIL  $1"; failed=1; }
pass() { echo "PASS  $1"; }

syntax_ok=1
while IFS= read -r f; do
  if ! bash -n "$f"; then fail "syntax $f"; syntax_ok=0; fi
done < <(find scripts templates tests .agents -name '*.sh' -not -path '*/node_modules/*' 2>/dev/null)
if (( syntax_ok )); then pass "bash -n on all shell files"; fi

if command -v shellcheck >/dev/null 2>&1; then
  sc_ok=1
  while IFS= read -r f; do
    if ! shellcheck -S warning "$f"; then fail "shellcheck $f"; sc_ok=0; fi
  done < <(find scripts templates tests -name '*.sh' -not -path '*/node_modules/*' 2>/dev/null)
  if (( sc_ok )); then pass "shellcheck (severity warning)"; fi
else
  echo "SKIP  shellcheck not installed -- install it to enforce (brew/apt install shellcheck)"
fi
fm_ok=1
for skill in .agents/skills/*/; do
  name="$(basename "$skill")"
  [ -f "$skill/SKILL.md" ] || { fail "skill $name has no SKILL.md"; fm_ok=0; continue; }
  frontmatter="$(awk 'NR==1 && $0=="---" {inside=1; next} inside && $0=="---" {exit} inside {print}' "$skill/SKILL.md")"
  grep -Eq '^name: [a-z0-9]+(-[a-z0-9]+)*$' <<< "$frontmatter" || { fail "skill $name frontmatter name"; fm_ok=0; }
  grep -Eq '^description:' <<< "$frontmatter" || { fail "skill $name frontmatter description"; fm_ok=0; }
  grep -qi 'use when' <<< "$frontmatter" || { fail "skill $name description needs a Use when trigger"; fm_ok=0; }
  while IFS= read -r ref; do
    [ -e "$skill/$ref" ] || { fail "skill $name missing $ref"; fm_ok=0; }
  done < <(grep -Eo 'references/[A-Za-z0-9_.-]+\.md' "$skill/SKILL.md" | sort -u)
done
if (( fm_ok )); then pass "skill frontmatter + references"; fi
links_ok=1
while IFS= read -r md; do
  dir="$(dirname "$md")"
  while IFS= read -r raw; do
    [ -n "$raw" ] || continue
    link="${raw#](}"
    link="${link%)}"
    case "$link" in
      http*|'#'*|mailto:*|"") continue ;;
    esac
    target="${link%%#*}"
    [ -z "$target" ] && continue
    [ -e "$dir/$target" ] || { fail "broken link in $md -> $target"; links_ok=0; }
  done < <(grep -oE '[]][(][^)]+[)]' "$md" 2>/dev/null || true)
done < <(find . -name '*.md' -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null)
if (( links_ok )); then pass "markdown relative links resolve"; fi

if (( failed )); then echo "lint: FAIL"; exit 1; fi
echo "lint: OK"
