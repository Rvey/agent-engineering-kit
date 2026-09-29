# AGENTS.md -- agent-engineering-kit

> Kit repo, not a product app. This file describes THIS repo (shell tooling, docs, vendored skills). The distributed template for other repos lives at templates/AGENTS.template.md -- do not copy this file into other projects. Bootstrap copies the template, then the agents-md skill generates project-specific instructions from target-repo evidence.

Shell + docs repo. No runtime, no build, no package manager. Gates below mirror .github/workflows/kit.yml.

## Skills

Skill lookup: the vendored copy at .agents/skills/<name>/SKILL.md is authoritative. Install the shared catalog once per machine only when a task needs a non-vendored skill (npx --yes skills@0.4.1 add addyosmani/agent-skills --list). When a task needs a skill neither installed nor vendored, ask the user whether to install or vendor it, then wait. Never start skill-governed work with no skill loaded.

### Task -> skill routing

| Task | Load before starting |
|---|---|
| Refresh this repo instructions | .agents/skills/agents-md/SKILL.md |
| Adopt kit into another repo end-to-end | .agents/skills/full-setup/SKILL.md |
| Vague request | .agents/skills/boost-prompt/SKILL.md |
| New skill scaffold or edit | scripts/new-skill.sh + docs/05-adding-a-skill.md |
| Touch input/auth/data/external/LLM paths | .agents/skills/security-and-hardening/SKILL.md |
| Add/change tests | .agents/skills/test-audit/SKILL.md |
| Feature done, before review | .agents/skills/deslop/SKILL.md |

React/FastAPI/perf skills are vendored examples for target repos, not for changes in this kit repo. Do not apply their stack rules here.

## Hard rules

1. Never clobber adopter files. Bootstrap fills missing files; --force overwrites only kit-owned paths, never extra local files. Hooks install refuses when a hook or core.hooksPath already exists.
2. Fail closed. Missing/invalid .agents/verify.sh or unavailable PR diff is a policy failure, never a pass.
3. Template stays template. templates/AGENTS.template.md keeps the template marker and placeholders. Root AGENTS.md never contains placeholders.
4. One source of truth. Routing lives here; skill detail lives in SKILL.md; behavior lives in scripts. Docs link, never restate.
5. Bash safety. Shell files start with set -euo pipefail, quote expansions, refuse symlink parents/destinations in install paths.

## Verification (required)

Run from repo root. All must pass:

- bash tests/setup-smoke.sh -- disposable-repo install, rerun, hooks, readiness, and policy regression (slow, authoritative).
- bash scripts/lint.sh -- syntax (bash -n), shellcheck, skill frontmatter + references check, markdown link check.
- actionlint .github/workflows/kit.yml -- workflow syntax when actionlint is installed.
- git diff --check -- no whitespace errors.

scripts/setup-check.sh . reports local readiness of THIS checkout; it is not a substitute for the smoke test.

Suppression rule: every shellcheck disable= must carry an explaining comment. Unexplained suppressions fail review.

## Where rules live

- Root AGENTS.md (this file) -- routing, gates, hard rules for this repo.
- templates/AGENTS.template.md -- shape shipped to other repos.
- .agents/skills/*/SKILL.md -- deep workflows.
- docs/ -- playbooks and runbooks. CONTRIBUTING.md -- contributor steps.
- scripts/ -- behavior. Instruction files point at scripts, never duplicate logic.

## Review protocol

1. Owning skill workflow followed, if skill-governed.
2. Gates above pass -- paste actual command output in handoff.
3. Deslop pass over branch diff (behavior-neutral edits only).
4. Security sign-off if sensitive paths changed.
5. Test audit if tests changed.
6. Handoff: what changed, gates with results, risks, follow-ups.
7. PR body carries Gates + Deslop (+ Security when relevant) or policy blocks merge.
