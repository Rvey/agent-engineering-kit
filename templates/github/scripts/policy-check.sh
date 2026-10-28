#!/usr/bin/env bash
# policy-check.sh — no-AI pull-request policy gate for the agent loop.
# Copied by agent-engineering-kit bootstrap; configuration lives in
# .github/workflows/policy.yml (env block). See docs/07-loop-enforcement.md.
#
# Fails when:
#   1. the PR body is missing a non-empty required section
#      (Gates, Deslop, plus Security when sensitive paths changed, plus Tests
#      when test files changed);
#   2. added test lines exceed TEST_RATIO_MAX times the added production lines
#      without a `Ratio:` line in the Tests section;
#   3. added code lines introduce suppressions without a written reason;
#   4. AGENTS.md is missing or still the kit template;
#   5. RISK_SECTION is set and its first word is not low, medium or high, or
#      is below high while high-risk or sensitive paths changed;
#   6. HIGH_RISK_APPROVALS is set and a high-risk change has fewer human
#      approvals than that on HEAD_SHA (REVIEWS_FILE: login, user type,
#      state, commit id — tab-separated).
# Checks 5 and 6 are off unless policy.yml sets their variables, so an older
# policy.yml keeps its old behaviour with this script.
#
# Escape hatches: the `policy:skip` label (job-level), or an inline
# `policy:allow` on an added line.
set -uo pipefail

PR_BODY_FILE="${PR_BODY_FILE:?set PR_BODY_FILE to a file holding the PR body}"
BASE_SHA="${BASE_SHA:-}"
HEAD_SHA="${HEAD_SHA:-}"
REQUIRED_SECTIONS="${REQUIRED_SECTIONS:-Gates,Deslop}"
RISK_SECTION="${RISK_SECTION:-}"
HIGH_RISK_PATTERNS="${HIGH_RISK_PATTERNS:-}"
HIGH_RISK_APPROVALS="${HIGH_RISK_APPROVALS:-}"
REVIEWS_FILE="${REVIEWS_FILE:-}"
PR_AUTHOR="${PR_AUTHOR:-}"
SECURITY_SECTION="${SECURITY_SECTION:-Security}"
SENSITIVE_PATTERNS="${SENSITIVE_PATTERNS:-}"
SCAN_EXTENSIONS="${SCAN_EXTENSIONS:-}"
TESTS_SECTION="${TESTS_SECTION:-Tests}"
TEST_PATTERNS="${TEST_PATTERNS:-}"
TEST_RATIO_MAX="${TEST_RATIO_MAX:-2}"
TEST_RATIO_MIN_LINES="${TEST_RATIO_MIN_LINES:-40}"

FAILED=0
# Paths are printed raw (no git quoting), so flatten line breaks: a newline
# in a filename must not start a new ::workflow-command:: line.
oneline() { local s="${1//$'\n'/ }"; printf '%s' "${s//$'\r'/ }"; }
err()  { printf '::error::%s\n' "$(oneline "$1")"; FAILED=1; }
ok()   { printf '  ok: %s\n' "$(oneline "$1")"; }

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
      raw = content
      gsub(/[[:space:]-]/, "", content)
      gsub(/\[|\]/, "", content)
      if (length(content) < 3) { exit 1 }
      printf "%s", raw
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
  # Unquoted NUL-separated names (quoted names break the ^ anchors), and no
  # rename detection so a move out of a sensitive path still lists the source.
  if changed_files="$(git -c core.quotePath=false diff -z --name-only --no-renames "$BASE_SHA...$HEAD_SHA" 2>/dev/null | tr '\0' '\n')"; then
    have_diff=1
  else
    err "cannot compare base and head commits; diff checks did not run"
  fi
else
  err "base/head SHA unavailable — diff checks did not run"
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

# --- 1b. Risk follows what the change touches, not who wrote it ------------

# human_approvals — reviewers whose latest decision is APPROVED on HEAD_SHA,
# excluding bots and the PR author. Comments do not change a decision.
human_approvals() {
  awk -F'\t' -v head="$HEAD_SHA" -v author="$PR_AUTHOR" '
    $3 == "COMMENTED" || $3 == "PENDING" { next }
    { state[$1] = $3; commit[$1] = $4; kind[$1] = $2 }
    END {
      n = 0
      for (u in state) {
        if (state[u] != "APPROVED" || commit[u] != head) continue
        if (kind[u] == "Bot" || u ~ /\[bot\]$/ || u == author) continue
        n++
      }
      print n
    }
  ' "$REVIEWS_FILE"
}

# Paths that make a change high risk whatever its Risk section says.
forced=""
if (( have_diff )) && [[ -n "$changed_files" ]]; then
  for pattern in "$SENSITIVE_PATTERNS" "$HIGH_RISK_PATTERNS"; do
    [[ -n "$pattern" ]] || continue
    forced="$forced$(grep -iE "$pattern" <<< "$changed_files" || true)"$'\n'
  done
fi
forced="$(grep -v '^$' <<< "$forced" | sort -u | head -5 | paste -sd ', ' -)"

risk=""
if [[ -n "$RISK_SECTION" ]]; then
  # The tier is the section's first word, after an optional "Risk:" label.
  if risk_body="$(section_body "$RISK_SECTION" 2>/dev/null)"; then
    first="$(grep -m1 -v '^[[:space:]]*$' <<< "$risk_body" | tr '[:upper:]' '[:lower:]' \
      | sed -E 's/^[^a-z]*//; s/^risk[^a-z]+//')"
    if [[ "$first" =~ ^(low|medium|high)([^a-z]|$) ]]; then risk="${BASH_REMATCH[1]}"; fi
  fi
  if [[ -z "$risk" ]]; then
    err "PR body needs a '## $RISK_SECTION' section that starts with low, medium or high"
  else
    ok "risk: $risk"
  fi
  if [[ -n "$forced" && -n "$risk" && "$risk" != high ]]; then
    err "high-risk paths changed, so '## $RISK_SECTION' must be high (got $risk): $forced"
  fi
fi

if [[ -n "$HIGH_RISK_APPROVALS" ]] && [[ "$risk" == high || -n "$forced" ]]; then
  if [[ ! "$HIGH_RISK_APPROVALS" =~ ^[0-9]+$ ]]; then
    err "HIGH_RISK_APPROVALS must be a whole number"
  elif (( HIGH_RISK_APPROVALS > 0 )); then
    if [[ -z "$REVIEWS_FILE" || ! -f "$REVIEWS_FILE" || -z "$HEAD_SHA" ]]; then
      err "high-risk change: review list unavailable, so human approvals were not checked"
    else
      approvals="$(human_approvals)"
      if (( approvals >= HIGH_RISK_APPROVALS )); then
        ok "high-risk change has $approvals human approval(s) on the latest commit"
      else
        err "high-risk change needs $HIGH_RISK_APPROVALS human approvals on the latest commit (has $approvals; bot approvals and approvals before the last push do not count)"
      fi
    fi
  fi
fi

# --- 2. Test changes need a reason; test bloat needs a ratio note ------------

# Added lines per file from numstat; docs count as neither tests nor
# production, binary files (numstat "-") are skipped.
if (( have_diff )) && [[ -n "$TEST_PATTERNS" ]]; then
  if [[ ! "$TEST_RATIO_MAX" =~ ^[0-9]+$ || ! "$TEST_RATIO_MIN_LINES" =~ ^[0-9]+$ ]]; then
    err "TEST_RATIO_MAX and TEST_RATIO_MIN_LINES must be whole numbers"
  else
    test_lines=0
    prod_lines=0
    test_files=()
    while IFS= read -r -d '' rec; do
      added="${rec%%$'\t'*}"
      file="${rec#*$'\t'}"
      file="${file#*$'\t'}"
      [[ "$added" =~ ^[0-9]+$ ]] || continue
      if grep -qiE -- "$TEST_PATTERNS" <<< "$file"; then
        test_lines=$((test_lines + added))
        test_files+=("$file")
      elif ! grep -qiE '\.(md|mdx|rst|txt)$' <<< "$file"; then
        prod_lines=$((prod_lines + added))
      fi
    done < <(git -c core.quotePath=false diff -z --numstat --no-renames "$BASE_SHA...$HEAD_SHA" 2>/dev/null || true)

    if (( ${#test_files[@]} )); then
      hits="$(printf '%s\n' "${test_files[@]}" | head -5 | paste -sd ', ' -)"
      tests_body=""
      if tests_body="$(section_body "$TESTS_SECTION" 2>/dev/null)"; then
        ok "test files changed with ## $TESTS_SECTION evidence ($hits)"
      else
        err "test files changed without a '## $TESTS_SECTION' section (the regression each test catches): $hits"
      fi
      if (( test_lines >= TEST_RATIO_MIN_LINES && test_lines > TEST_RATIO_MAX * prod_lines )); then
        if grep -qiE '^[[:space:]*-]*ratio:' <<< "$tests_body"; then
          ok "test lines ($test_lines) over ${TEST_RATIO_MAX}x production lines ($prod_lines), with a Ratio: note"
        else
          err "added $test_lines test lines for $prod_lines production lines (over ${TEST_RATIO_MAX}x): trim the tests or add a 'Ratio: <why>' line under ## $TESTS_SECTION"
        fi
      fi
    fi
  fi
fi

# --- 3. Suppressions need a written reason -----------------------------------

# A reason is one of: inline after the directive, or a comment on the added
# line immediately above it. `policy:allow` exempts a line.
reason_above() {
  local pt="$1"
  pt="${pt#"${pt%%[![:space:]]*}"}"
  [[ ${#pt} -ge 5 ]] || return 1
  [[ "$pt" == "#"* || "$pt" == "//"* || "$pt" == "/*"* || "$pt" == "*"* ]]
}

if (( have_diff )) && [[ -n "$SCAN_EXTENSIONS" ]]; then
  # read -a splits without pathname expansion: '*.ts' must reach git as a
  # pathspec, not be globbed against files in the repo root.
  read -r -a exts <<< "$SCAN_EXTENSIONS"
  while IFS= read -r -d '' file; do
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
    done < <(git --literal-pathspecs diff --unified=0 "$BASE_SHA...$HEAD_SHA" -- "$file" 2>/dev/null | grep -E '^\+' | grep -vE '^\+\+\+' | sed 's/^+//')
  done < <(git -c core.quotePath=false diff -z --name-only --no-renames --diff-filter=ACM "$BASE_SHA...$HEAD_SHA" -- "${exts[@]}" 2>/dev/null || true)
fi

# --- 4. AGENTS.md must be generated, not copied ------------------------------

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

if [[ ! -f .agents/verify.sh ]] || ! bash -n .agents/verify.sh 2>/dev/null; then
  err ".agents/verify.sh is missing or invalid — generate it before opening a PR"
else
  ok "verification script exists and parses"
fi

# --- verdict -----------------------------------------------------------------

if (( FAILED )); then
  echo "policy check: FAILED"
else
  echo "policy check: PASSED"
fi
exit "$FAILED"
