#!/usr/bin/env bash
# policy-check.sh — no-AI pull-request policy gate for the agent loop.
# Copied by agent-engineering-kit bootstrap; configuration lives in
# .github/workflows/policy.yml (env block). See docs/07-loop-enforcement.md.
#
# Fails when:
#   1. the PR body is missing a non-empty required section
#      (Gates, Deslop, plus Security when sensitive paths changed);
#   2. added code lines introduce suppressions without a written reason;
#   3. AGENTS.md is missing or still the kit template.
#
# Escape hatches: the `policy:skip` label (job-level), or an inline
# `policy:allow` on an added line.
set -uo pipefail

PR_BODY_FILE="${PR_BODY_FILE:?set PR_BODY_FILE to a file holding the PR body}"
BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-}"
REQUIRED_SECTIONS="${REQUIRED_SECTIONS:-Gates,Deslop}"
SECURITY_SECTION="${SECURITY_SECTION:-Security}"
SENSITIVE_PATTERNS="${SENSITIVE_PATTERNS:-}"
SCAN_EXTENSIONS="${SCAN_EXTENSIONS:-}"

FAILED=0
err()  { printf '::error::%s\n' "$1"; FAILED=1; }
warn() { printf '::warning::%s\n' "$1"; }
ok()   { printf '  ok: %s\n' "$1"; }

echo "policy check: loop evidence"

# section_body <title> — prints the content under a "## <title>" heading
# (case-insensitive prefix; heading levels 1-4). Exits non-zero when the
# section is absent or has no content beyond whitespace, dashes, brackets,
# or HTML comments.
section_body() {
  awk -v want="$1" '
    function norm(s) { gsub(/[^a-zA-Z]/, "", s); return tolower(s) }
    BEGIN { w = norm(want); on = 0; content = "" }
    /^#{1,4}[ \t]/ {
      if (on) { exit }
      h = $0
      sub(/^#+[ \t]*/, "", h)
      if (index(norm(h), w) == 1) { on = 1 }
      next
    }
    on { content = content $0 "\n" }
    END {
      gsub(/<!--[^>]*-->/, "", content)
      gsub(/[[:space:]-]/, "", content)
      gsub(/\[|\]/, "", content)
      if (length(content) < 3) { exit 1 }
    }
  ' "$PR_BODY_FILE"
}

# --- 1. PR body evidence -----------------------------------------------------

IFS=',' read -r -a required <<< "$REQUIRED_SECTIONS"
for raw in "${required[@]}"; do
  title="$(printf '%s' "$raw" | xargs)"
  [[ -z "$title" ]] && continue
  if section_body "$title" >/dev/null 2>&1; then
    ok "PR body section: ## $title"
  else
    err "PR body needs a non-empty '## $title' section (see .github/pull_request_template.md)"
  fi
done

changed_files=""
have_diff=0
if [[ -n "$BASE_SHA" && -n "$HEAD_SHA" ]] \
  && git rev-parse -q --verify "${BASE_SHA}^{commit}" >/dev/null 2>&1 \
  && git rev-parse -q --verify "${HEAD_SHA}^{commit}" >/dev/null 2>&1; then
  changed_files="$(git diff --name-only "$BASE_SHA...$HEAD_SHA" 2>/dev/null || true)"
  have_diff=1
else
  warn "base/head SHA unavailable — skipping diff-based checks"
fi

if (( have_diff )) && [[ -n "$SENSITIVE_PATTERNS" && -n "$changed_files" ]] \
  && grep -qiE "$SENSITIVE_PATTERNS" <<< "$changed_files"; then
  hits="$(grep -iE "$SENSITIVE_PATTERNS" <<< "$changed_files" | head -5 | paste -sd ', ' -)"
  if section_body "$SECURITY_SECTION" >/dev/null 2>&1; then
    ok "sensitive paths changed with ## $SECURITY_SECTION evidence ($hits)"
  else
    err "sensitive paths changed without a '## $SECURITY_SECTION' section: $hits"
  fi
fi

# --- 2. Suppressions need a written reason -----------------------------------

# A reason is one of: inline after the directive, or a comment on the added
# line immediately above it. `policy:allow` exempts a line.
reason_above() {
  local pt="$1"
  pt="${pt#"${pt%%[![:space:]]*}"}"
  [[ ${#pt} -ge 5 ]] || return 1
  [[ "$pt" == "#"* || "$pt" == "//"* || "$pt" == "/*"* || "$pt" == "*"* ]]
}

if (( have_diff )) && [[ -n "$SCAN_EXTENSIONS" ]]; then
  exts=()
  for e in $SCAN_EXTENSIONS; do exts+=("$e"); done
  files="$(git diff --name-only --diff-filter=ACMR "$BASE_SHA...$HEAD_SHA" -- "${exts[@]}" 2>/dev/null || true)"
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    prev=""
    while IFS= read -r line; do
      if [[ -n "$line" && "$line" != *"policy:allow"* ]]; then
        if [[ "$line" == *"eslint-disable"* ]] \
          && ! grep -qE -- '--[[:space:]]*[[:alnum:]]' <<< "$line" \
          && ! reason_above "$prev"; then
          err "$file: eslint-disable without a reason — '// eslint-disable… -- why'"
        fi
        if [[ "$line" == *"noqa"* ]] \
          && ! grep -qE '#[[:space:]]*noqa[^#]*#[[:space:]]*[[:alnum:]]' <<< "$line" \
          && ! reason_above "$prev"; then
          err "$file: # noqa without a reason — '# noqa: CODE  # why'"
        fi
        if [[ "$line" == *"@ts-ignore"* || "$line" == *"@ts-expect-error"* ]] \
          && grep -qE '@ts-(ignore|expect-error)[[:space:]]*(\*/)?[[:space:]]*$' <<< "$line" \
          && ! reason_above "$prev"; then
          err "$file: @ts-ignore/@ts-expect-error without a description — '@ts-expect-error: why'"
        fi
      fi
      prev="$line"
    done < <(git diff --unified=0 "$BASE_SHA...$HEAD_SHA" -- "$file" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//')
  done <<< "$files"
fi

# --- 3. AGENTS.md must be generated, not copied ------------------------------

if [[ ! -f AGENTS.md ]]; then
  err "AGENTS.md is missing — generate it with the agents-md skill (README -> Generate AGENTS.md)"
elif grep -q 'agent-engineering-kit:template' AGENTS.md; then
  err "AGENTS.md is still the kit template — run the agents-md generator"
elif matches="$(grep -nE '<Project Name>|<lint command>|<typecheck command>|<test command>|<format command>|<build command>|<real path>|This is a template|Adapt me' AGENTS.md)"; then
  err "AGENTS.md still has template placeholders:"
  printf '%s\n' "$matches" | while IFS= read -r m; do printf '::error::  AGENTS.md:%s\n' "$m"; done
else
  ok "AGENTS.md generated"
fi

[[ -f .agents/verify.sh ]] || warn ".agents/verify.sh missing — regenerate AGENTS.md so hooks and CI run the same gate commands"

# --- verdict -----------------------------------------------------------------

if (( FAILED )); then
  echo "policy check: FAILED"
else
  echo "policy check: PASSED"
fi
exit "$FAILED"
