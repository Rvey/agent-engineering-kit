#!/usr/bin/env bash
# Exercise installation against a disposable repository, including regression cases.
set -euo pipefail

kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/agent-kit-smoke.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
target="$fixture/project"
mkdir "$target"
git -C "$target" init -q

expect_failure() {
  if "$@" > "$fixture/command.log" 2>&1; then
    echo "Expected failure: $*" >&2
    exit 1
  fi
}

bash "$kit/scripts/bootstrap.sh" "$target" > "$fixture/command.log"
test -f "$target/.agents/skills/full-setup/SKILL.md"
test -f "$target/.github/workflows/gates.yml"
test -f "$target/.agents/install-hooks.sh"
test -f "$target/.agents/setup-check.sh"
echo "local addition" > "$target/.agents/skills/deslop/local.md"
rm "$target/.agents/skills/deslop/SKILL.md"
bash "$kit/scripts/bootstrap.sh" "$target" > "$fixture/command.log"
test -f "$target/.agents/skills/deslop/SKILL.md"
test -f "$target/.agents/skills/deslop/local.md"
bash "$kit/scripts/bootstrap.sh" "$target" --force > "$fixture/command.log"
test -f "$target/.agents/skills/deslop/local.md"
echo "Installer reruns and force preserve local additions: PASS"

mkdir "$target/.githooks"
echo '# existing hook' > "$target/.githooks/pre-commit"
expect_failure bash "$target/.agents/install-hooks.sh" "$target"
grep -q '# existing hook' "$target/.githooks/pre-commit"
rm "$target/.githooks/pre-commit"
git -C "$target" config core.hooksPath .other-hooks
expect_failure bash "$target/.agents/install-hooks.sh" "$target"
git -C "$target" config --unset core.hooksPath
default_hook="$(git -C "$target" rev-parse --git-path hooks/pre-commit)"
[[ "$default_hook" == /* ]] || default_hook="$target/$default_hook"
echo '# default hook' > "$default_hook"
expect_failure bash "$target/.agents/install-hooks.sh" "$target"
grep -q '# default hook' "$default_hook"
rm "$default_hook"
bash "$target/.agents/install-hooks.sh" "$target" > "$fixture/command.log"
echo "Existing hooks remain intact; clean install succeeds: PASS"

expect_failure bash "$target/.agents/setup-check.sh" "$target"
cat > "$target/AGENTS.md" <<'EOF'
# AGENTS.md — Smoke project

Run the repository verification script before review.
EOF
cat > "$target/.agents/verify.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
test -f AGENTS.md
EOF
chmod +x "$target/.agents/verify.sh"
cat > "$target/.github/CODEOWNERS" <<'EOF'
/* @example-maintainer
EOF
awk '/# SETUP: replace this/ { print "      - name: Prepare fixture toolchain"; print "        run: echo ready"; next } { print }' "$target/.github/workflows/gates.yml" > "$fixture/gates.yml"
cp "$fixture/gates.yml" "$target/.github/workflows/gates.yml"
bash "$target/.agents/setup-check.sh" "$target" > "$fixture/check.log"
grep -q 'Local setup: READY' "$fixture/check.log"
echo "Readiness check distinguishes incomplete and ready setup: PASS"

git -C "$target" add .
git -C "$target" -c user.name=Smoke -c user.email=smoke@example.invalid commit -qm baseline
base="$(git -C "$target" rev-parse HEAD)"
echo 'feature' > "$target/feature.txt"
git -C "$target" add feature.txt
git -C "$target" -c user.name=Smoke -c user.email=smoke@example.invalid commit -qm feature
head="$(git -C "$target" rev-parse HEAD)"
cat > "$fixture/body.md" <<'EOF'
## Gates
Verification passed.

## Deslop
Reviewed the diff.
EOF
(
  cd "$target"
  PR_BODY_FILE="$fixture/body.md" BASE_SHA="$base" HEAD_SHA="$head" \
    bash .github/scripts/policy-check.sh > "$fixture/policy.log"
  rm .agents/verify.sh
  expect_failure env PR_BODY_FILE="$fixture/body.md" BASE_SHA="$base" HEAD_SHA="$head" \
    bash .github/scripts/policy-check.sh
  grep -q 'verify.sh is missing or invalid' "$fixture/command.log"
  expect_failure env PR_BODY_FILE="$fixture/body.md" BASE_SHA=invalid HEAD_SHA="$head" \
    bash .github/scripts/policy-check.sh
  grep -q 'diff checks did not run' "$fixture/command.log"
)
echo "Policy requires a valid diff and verification script: PASS"

dry_target="$fixture/dry"
mkdir "$dry_target"
git -C "$dry_target" init -q
bash "$kit/scripts/bootstrap.sh" "$dry_target" --dry-run > "$fixture/dry.log"
grep -q 'plan' "$fixture/dry.log"
test ! -e "$dry_target/AGENTS.md"
test ! -e "$dry_target/.agents"
echo "Dry-run reports the plan without writing: PASS"

bash "$kit/scripts/setup-check.sh" --kit > "$fixture/kit-check.log"
grep -q 'Kit self-check: READY' "$fixture/kit-check.log"
echo "Kit self-check passes on its own checkout: PASS"

fix_target="$fixture/fixtarget"
mkdir "$fix_target"
git -C "$fix_target" init -q
bash "$kit/scripts/bootstrap.sh" "$fix_target" > "$fixture/fix-bootstrap.log"
test -f "$fix_target/.agents/verify-templates/shell.sh"
test -f "$fix_target/.agents/verify-templates/node.sh"
cat > "$fix_target/AGENTS.md" <<'EOF'
# AGENTS.md — Fix project

Run the repository verification script before review.
EOF
(
  cd "$fix_target"
  bash .agents/setup-check.sh . --fix > "$fixture/fix.log" 2>&1 || true
)
grep -q 'FIXED .agents/verify.sh' "$fixture/fix.log"
test -x "$fix_target/.agents/verify.sh"
test "$(git -C "$fix_target" config --get core.hooksPath)" = ".githooks"
echo "--fix scaffolds the verification script and fast hook: PASS"
