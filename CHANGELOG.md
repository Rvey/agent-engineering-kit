# Changelog

Notable changes to the Agent Engineering Kit. Versions follow semantic
versioning once tagged; entries land under Unreleased until then.

## Unreleased

### Added

- Vendored `context-engineering`, `frontend-ui-engineering` (with
  `references/accessibility-checklist.md`), and `documentation-and-adrs` from
  [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) (MIT).
  Bootstrap copies them into adopters via the existing skills loop; the
  template routing table, skill catalog, README, and CREDITS list them.
  `performance-optimization` was already vendored from the same catalog and
  verified current (only the intentional `references/` link rewrite differs).
- `templates/verify/` starters for shell, Node, and Python repositories, copied
  into adopters as `.agents/verify-templates/`. Each carries `SETUP:` markers
  on the lines a human still has to edit.
- `scripts/lint.sh` — shell syntax, shellcheck, skill frontmatter, and
  markdown link checks, all in one fast command.
- `docs/08-troubleshooting.md` — symptom-to-fix guide for adoption and CI
  failures.
- `CHANGELOG.md` (this file).

### Changed

- The kit now dogfoods its own setup. `AGENTS.md` at the repository root is
  this project's real instruction file, generated from its layout; the file
  shipped to other repositories moved to `templates/AGENTS.template.md` and
  keeps the `agent-engineering-kit:template` marker. Bootstrap copies the
  template.
- `scripts/bootstrap.sh` accepts `--dry-run`, which prints every copy and skip
  decision without writing to the target.
- `scripts/setup-check.sh` gained `--fix` (scaffold `verify.sh`, install the
  fast hook), `--strict` (require a clean tree and a configured remote), and
  `--kit` (check the kit checkout itself). Every `TODO` line now prints its fix.
- `scripts/setup-check.sh` treats a `.agents/verify.sh` containing `SETUP:` as
  incomplete, so an unedited starter cannot pass for a working gate.
- `.github/workflows/kit.yml` runs static checks, `actionlint` (pinned to
  `rhysd/actionlint:1.7.12`), the kit self-check, and the install smoke test.
- Four vendored skill descriptions gained an explicit `Use when` trigger:
  `boost-prompt`, `deslop`, `fastapi-python`, `test-audit`. The lint check now
  enforces one.

### Fixed

- `reference/advanced-patterns.md` link inside
  `.agents/skills/python-performance-optimization/references/details.md`
  resolved to a non-existent nested path.

### Verified

- `bash tests/setup-smoke.sh` covers reruns, force behaviour, hook conflicts,
  readiness, policy failure cases, `--dry-run`, the kit self-check, and
  `--fix` scaffolding.
