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

echo 'outside the kit' > "$fixture/victim.txt"
rm "$target/.agents/skills/deslop/SKILL.md"
ln "$fixture/victim.txt" "$target/.agents/skills/deslop/SKILL.md"
expect_failure bash "$kit/scripts/bootstrap.sh" "$target" --force
grep -q 'hard-linked or non-regular destination' "$fixture/command.log"
grep -qx 'outside the kit' "$fixture/victim.txt"
rm "$target/.agents/skills/deslop/SKILL.md"
bash "$kit/scripts/bootstrap.sh" "$target" > "$fixture/command.log"
echo "Force refuses to write through a hard link: PASS"

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

# Shipped policy.yml config; each case commits one change on case_base and
# must fail with every listed message.
policy_yml="$kit/templates/github/workflows/policy.yml"
policy_env=(
  PR_BODY_FILE="$fixture/body.md"
  SENSITIVE_PATTERNS="$(sed -n "s/^ *SENSITIVE_PATTERNS: '\(.*\)'$/\1/p" "$policy_yml")"
  SCAN_EXTENSIONS="$(sed -n "s/^ *SCAN_EXTENSIONS: '\(.*\)'$/\1/p" "$policy_yml")"
  TEST_PATTERNS="$(sed -n "s/^ *TEST_PATTERNS: '\(.*\)'$/\1/p" "$policy_yml")"
)
policy_body="$fixture/body.md"
commit_all() {
  git -C "$target" add -A
  git -C "$target" -c user.name=Smoke -c user.email=smoke@example.invalid commit -q --no-verify -m "$1"
  git -C "$target" rev-parse HEAD
}
policy_fails_with() {
  local case_head message
  case_head="$(commit_all case)"
  (
    cd "$target"
    expect_failure env "${policy_env[@]}" PR_BODY_FILE="$policy_body" \
      BASE_SHA="$case_base" HEAD_SHA="$case_head" bash .github/scripts/policy-check.sh
  )
  for message in "$@"; do grep -qF "$message" "$fixture/command.log"; done
  git -C "$target" checkout -q --detach "$case_base"
}
policy_passes() {
  local case_head
  case_head="$(commit_all case)"
  (
    cd "$target"
    env "${policy_env[@]}" PR_BODY_FILE="$policy_body" \
      BASE_SHA="$case_base" HEAD_SHA="$case_head" bash .github/scripts/policy-check.sh > "$fixture/command.log"
  )
  git -C "$target" checkout -q --detach "$case_base"
}
git -C "$target" checkout -q --detach "$base"
git -C "$target" checkout -q "$base" -- .agents/verify.sh
mkdir "$target/auth" "$target/src"
printf 'export const step%s = %s;\n' 1 1 2 2 3 3 4 4 5 5 6 6 > "$target/auth/session.ts"
echo 'export default {};' > "$target/vite.config.ts"
echo 'export const b = 1;' > "$target/src/b.ts"
case_base="$(commit_all policy-cases)"

echo '// eslint-disable-next-line' >> "$target/src/b.ts"
policy_fails_with 'src/b.ts: eslint-disable without a reason'
mkdir "$target/lib"
git -C "$target" mv auth/session.ts lib/session.ts
policy_fails_with 'sensitive paths changed without'
echo '// @ts-ignore' > "$target/auth/"$'\303\251'".ts"
policy_fails_with 'sensitive paths changed without' $'auth/\303\251.ts: @ts-ignore'
echo '// @ts-ignore' > "$target/src/"$'x\n::warning::injected'".ts"
policy_fails_with '@ts-ignore'
if grep -q '^::warning::injected' "$fixture/command.log"; then
  echo "Expected filenames to stay on one ::error:: line" >&2
  exit 1
fi
echo "Policy scans nested, renamed, and non-ASCII paths: PASS"

echo 'export const b = 2;' > "$target/src/b.ts"
mkdir -p "$target/tests"
echo 'def test_b(): assert True' > "$target/tests/test_b.py"
policy_fails_with "test files changed without a '## Tests' section" 'tests/test_b.py'
cp "$fixture/body.md" "$fixture/body-tests.md"
printf '\n## Tests\nb.test.ts catches a wrong b value; seen failing first.\n' >> "$fixture/body-tests.md"
policy_body="$fixture/body-tests.md"
echo 'export const b = 2;' > "$target/src/b.ts"
seq 1 50 | sed 's/^/expect(b).toBe(2); \/\/ /' > "$target/src/b.test.ts"
policy_fails_with 'added 50 test lines for 1 production lines'
printf 'Ratio: b is a parser contract; each line is one input.\n' >> "$fixture/body-tests.md"
echo 'export const b = 2;' > "$target/src/b.ts"
seq 1 50 | sed 's/^/expect(b).toBe(2); \/\/ /' > "$target/src/b.test.ts"
policy_passes
grep -q 'with a Ratio: note' "$fixture/command.log"
policy_body="$fixture/body.md"
echo "Policy requires test evidence and a ratio note for test-heavy diffs: PASS"

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

bash "$kit/scripts/bootstrap.sh" --list-skills > "$fixture/list.log"
grep -q '^agents-md$' "$fixture/list.log"
grep -q '^test-audit$' "$fixture/list.log"
echo "--list-skills reports available skills: PASS"

preset_target="$fixture/preset-minimal"
mkdir "$preset_target"
git -C "$preset_target" init -q
bash "$kit/scripts/bootstrap.sh" --preset minimal "$preset_target" > "$fixture/preset.log"
test -f "$preset_target/.agents/skills/agents-md/SKILL.md"
test -f "$preset_target/.agents/skills/full-setup/SKILL.md"
test ! -e "$preset_target/.agents/skills/deslop/SKILL.md"
test ! -e "$preset_target/.github"
echo "--preset minimal installs the minimal bundle without .github/: PASS"

subset_target="$fixture/preset-subset"
mkdir "$subset_target"
git -C "$subset_target" init -q
bash "$kit/scripts/bootstrap.sh" --skills deslop,test-audit --dry-run "$subset_target" > "$fixture/subset.log"
grep -q 'plan   .agents/skills/deslop/SKILL.md' "$fixture/subset.log"
grep -q 'plan   .agents/skills/test-audit/SKILL.md' "$fixture/subset.log"
test ! -e "$subset_target/AGENTS.md"
bash "$kit/scripts/bootstrap.sh" --preset standard --skills deslop "$subset_target" > "$fixture/subset-install.log"
test -f "$subset_target/.agents/skills/deslop/SKILL.md"
test ! -e "$subset_target/.agents/skills/test-audit/SKILL.md"
expect_failure bash "$kit/scripts/bootstrap.sh" --skills nope "$subset_target"
echo "--skills filters the installed subset and rejects unknown names: PASS"

update_target="$fixture/update"
mkdir "$update_target"
git -C "$update_target" init -q
expect_failure bash "$kit/scripts/bootstrap.sh" --update --yes "$update_target"
grep -q 'no kit install found' "$fixture/command.log"
bash "$kit/scripts/bootstrap.sh" --skills deslop "$update_target" > "$fixture/update.log"
echo 'local edit' >> "$update_target/.agents/skills/deslop/SKILL.md"
echo 'local addition' > "$update_target/.agents/skills/deslop/local.md"
AGENT_KIT_NO_TTY=1 expect_failure bash "$kit/scripts/bootstrap.sh" --update "$update_target"
grep -q -- '--update without --yes or --skills needs a terminal' "$fixture/command.log"
bash "$kit/scripts/bootstrap.sh" --update --dry-run --yes "$update_target" > "$fixture/update.log"
grep -q 'update deslop (1 file(s) differ' "$fixture/update.log"
grep -q 'new    test-audit' "$fixture/update.log"
grep -q 'local edit' "$update_target/.agents/skills/deslop/SKILL.md"
bash "$kit/scripts/bootstrap.sh" --update --skills deslop,test-audit "$update_target" > "$fixture/update.log"
cmp -s "$kit/.agents/skills/deslop/SKILL.md" "$update_target/.agents/skills/deslop/SKILL.md"
test -f "$update_target/.agents/skills/deslop/local.md"
test -f "$update_target/.agents/skills/test-audit/SKILL.md"
test ! -e "$update_target/.agents/skills/bruh"
bash "$kit/scripts/bootstrap.sh" --update --yes "$update_target" > "$fixture/update.log"
test -f "$update_target/.agents/skills/bruh/SKILL.md"
AGENT_KIT_NO_TTY=1 bash "$kit/scripts/bootstrap.sh" --update "$update_target" > "$fixture/update.log"
grep -q 'Everything is up to date.' "$fixture/update.log"
echo "--update refreshes changed skills, adds selected ones, and keeps local files: PASS"

(cd "$update_target" && AGENT_KIT_NO_TTY=1 expect_failure bash "$kit/scripts/bootstrap.sh")
grep -q 'error: usage:' "$fixture/command.log"
echo "Bare run without a terminal prints usage instead of prompting: PASS"

file_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# Remote installer: feed it a local tarball of this checkout so CI needs no network.
pkg="$fixture/pkg/agent-engineering-kit-main"
mkdir -p "$pkg" "$fixture/wrapper-tmp"
tar -C "$kit" --exclude=.git -cf - . | tar -C "$pkg" -xf -
tar -C "$fixture/pkg" -czf "$fixture/kit.tar.gz" agent-engineering-kit-main
remote_target="$fixture/remote"
mkdir "$remote_target"
git -C "$remote_target" init -q
(cd "$remote_target" && TMPDIR="$fixture/wrapper-tmp" AGENT_KIT_TARBALL="$fixture/kit.tar.gz" \
  bash "$kit/scripts/install.sh" --skills deslop .) > "$fixture/remote.log"
test -f "$remote_target/.agents/skills/deslop/SKILL.md"
test -z "$(ls -A "$fixture/wrapper-tmp")"
AGENT_KIT_TARBALL="$fixture/kit.tar.gz" AGENT_KIT_SHA256=0000 \
  expect_failure bash "$kit/scripts/install.sh" --update --yes "$remote_target"
grep -q 'checksum mismatch' "$fixture/command.log"
test ! -e "$remote_target/.agents/skills/bruh"
kit_sum="$(file_sha256 "$fixture/kit.tar.gz")"
AGENT_KIT_TARBALL="$fixture/kit.tar.gz" AGENT_KIT_SHA256="$kit_sum" \
  bash "$kit/scripts/install.sh" --update --yes "$remote_target" > "$fixture/remote.log"
test -f "$remote_target/.agents/skills/bruh/SKILL.md"
AGENT_KIT_REF='../evil' expect_failure bash "$kit/scripts/install.sh" --list-skills
grep -q 'invalid AGENT_KIT_REF' "$fixture/command.log"
echo "install.sh runs bootstrap from a tarball, verifies checksums, and cleans up: PASS"

while read -r retired_name replacement retired_path retired_hash; do
  case "$retired_name" in ''|'#'*) continue ;; esac
  test ! -e "$kit/.agents/skills/$retired_name"
  test -f "$kit/.agents/skills/$replacement/SKILL.md"
  [[ -n "$retired_path" && "$retired_hash" =~ ^[0-9a-f]{64}$ ]]
done < "$kit/scripts/retired-skills.txt"
echo "retired-skills.txt names removed skills with live replacements: PASS"

# Retired skills: a fake entry in the kit copy keeps this independent of git history.
mkdir -p "$fixture/old-skill/references"
echo 'old skill' > "$fixture/old-skill/SKILL.md"
echo 'old reference' > "$fixture/old-skill/references/a.md"
for f in SKILL.md references/a.md; do
  echo "old-skill deslop $f $(file_sha256 "$fixture/old-skill/$f")" >> "$pkg/scripts/retired-skills.txt"
done
retired_target="$fixture/retired"
retired_skill="$retired_target/.agents/skills/old-skill"
mkdir "$retired_target"
git -C "$retired_target" init -q
bash "$pkg/scripts/bootstrap.sh" --skills agents-md "$retired_target" > "$fixture/retired.log"
cp -R "$fixture/old-skill" "$retired_skill"
echo '| Old task | `.agents/skills/old-skill/SKILL.md` |' > "$retired_target/AGENTS.md"
bash "$pkg/scripts/bootstrap.sh" --skills-only --skills agents-md "$retired_target" > "$fixture/retired.log"
grep -q 'note   .agents/skills/old-skill is retired (replaced by deslop)' "$fixture/retired.log"

bash "$pkg/scripts/bootstrap.sh" --update --yes --dry-run "$retired_target" > "$fixture/retired.log"
grep -q 'retired old-skill (replaced by deslop)' "$fixture/retired.log"
grep -q 'plan   remove .agents/skills/old-skill/' "$fixture/retired.log"
test -f "$retired_skill/SKILL.md"
test ! -e "$retired_target/.agents/skills/deslop"

echo 'local edit' >> "$retired_skill/references/a.md"
bash "$pkg/scripts/bootstrap.sh" --update --yes "$retired_target" > "$fixture/retired.log"
grep -q 'keep   old-skill (1 file(s) edited or added locally, remove by hand)' "$fixture/retired.log"
test -f "$retired_skill/references/a.md"
test -f "$retired_target/.agents/skills/deslop/SKILL.md"
grep -q '^  AGENTS.md:1$' "$fixture/retired.log"

cp "$fixture/old-skill/references/a.md" "$retired_skill/references/a.md"
bash "$pkg/scripts/bootstrap.sh" --update --yes "$retired_target" > "$fixture/retired.log"
grep -q 'remove .agents/skills/old-skill/' "$fixture/retired.log"
test ! -e "$retired_skill"
grep -q 'old-skill' "$retired_target/AGENTS.md"

expect_failure bash "$kit/scripts/setup-check.sh" "$retired_target"
grep -q 'AGENTS.md routes to missing skills: .agents/skills/old-skill/SKILL.md' "$fixture/command.log"
echo "--update removes pristine retired skills, keeps edited ones, and setup-check flags dangling rows: PASS"

awk '!/^#/ && $1 == ".agents/skills/README.md" { print $2 }' "$kit/scripts/shipped-files.txt" \
  | grep -qxF "$(file_sha256 "$kit/.agents/skills/README.md")"
echo "shipped-files.txt records the current skills README: PASS"

# Kit-owned README: a fake recorded old version stands in for git history.
skills_readme="$retired_target/.agents/skills/README.md"
printf '# Old skills README\n| `old-skill` | retired |\n' > "$fixture/old-readme.md"
echo ".agents/skills/README.md $(file_sha256 "$fixture/old-readme.md")" >> "$pkg/scripts/shipped-files.txt"
cp "$fixture/old-readme.md" "$skills_readme"
bash "$pkg/scripts/bootstrap.sh" --update --yes --dry-run "$retired_target" > "$fixture/readme.log"
grep -q 'update .agents/skills/README.md (unedited older kit version)' "$fixture/readme.log"
grep -q 'plan   .agents/skills/README.md' "$fixture/readme.log"
cmp -s "$fixture/old-readme.md" "$skills_readme"
bash "$pkg/scripts/bootstrap.sh" --update --yes "$retired_target" > "$fixture/readme.log"
cmp -s "$pkg/.agents/skills/README.md" "$skills_readme"

printf '# Team notes\n| `old-skill` | still here |\n' > "$skills_readme"
bash "$pkg/scripts/bootstrap.sh" --update --yes "$retired_target" > "$fixture/readme.log"
grep -q 'keep   .agents/skills/README.md (edited or linked locally' "$fixture/readme.log"
grep -q '^  .agents/skills/README.md:2$' "$fixture/readme.log"
grep -q 'Team notes' "$skills_readme"
echo "--update refreshes an unedited old skills README and keeps an edited one: PASS"
