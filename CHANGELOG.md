# Changelog

Notable changes to the Agent Engineering Kit. Versions follow semantic
versioning once tagged; entries land under Unreleased until then.

## Unreleased

### Added

- `scripts/install.sh`: one-line remote install
  (`bash <(curl -fsSL …/scripts/install.sh)`). Downloads the kit tarball to a
  temp dir, runs `bootstrap.sh` with the given arguments, and cleans up.
  `AGENT_KIT_REF` pins a version, `AGENT_KIT_SHA256` verifies the download,
  `AGENT_KIT_TARBALL` uses a local tarball (offline and tests).
- Running `bootstrap.sh` with no arguments in a terminal opens a menu
  (install, update skills, list skills); any argument keeps it
  non-interactive. `AGENT_KIT_NO_TTY=1` forces the no-terminal path.
- `bootstrap.sh --update`: compares an existing install's skills with the
  kit and prompts to update changed skills, add all new skills, do both, or
  choose skill by skill. Non-interactive with `--yes` or `--skills`; honours
  `--dry-run`; touches only `.agents/skills/` and keeps local extra files.
- Vendored `security-audit` from
  [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill)
  (MIT, commit `c1c8a8c`) with its phase docs, domain companions,
  report schema, and zero-dependency Node validators.
  Listed in the template routing table, skill catalogs, README, and CREDITS.
- `bruh` skill: turns dense LLM output, specs, logs, and unfamiliar-domain
  jargon into short, ADHD-friendly explanations for engineers. It keeps the
  real terms and explains the mechanism so the reader learns, with each rule
  tied to research in `references/research.md`.
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

- `security-audit` is now the kit's only security skill; the vendored
  `security-and-hardening` skill (addyosmani/agent-skills) and its two
  reference files are removed. `security-audit` adds a "security sign-off on a
  change" step in guidance mode, which the template routing row, review
  protocol, workflow Stage 6, and root `AGENTS.md` now point at. Its
  `SKILL.md` drops from 194 to about 90 lines: full-audit setup, write
  isolation, prior runs, profiles, and budget moved verbatim to `FULL-AUDIT.md`;
  the unused `subagent_type` heading tags and platform-terminology section are
  gone; the default output directory is `~/.security-audit/<repo>/run-<N>`.
  Phase rules, `report-schema.json`, and the validators are unchanged. The
  `standard` bootstrap preset installs `security-audit` instead. Existing
  installs keep their old `security-and-hardening` copy until
  `bootstrap.sh --update` removes it: it does so only with `--yes` or a yes at
  the prompt, and only when every file matches a hash the kit shipped
  (`scripts/retired-skills.txt`); edited copies stay. The same rule
  refreshes `.agents/skills/README.md` when it is an unedited older kit
  version (`scripts/shipped-files.txt`). It then lists the `AGENTS.md` and
  kept README lines that still name the old skill, and `setup-check.sh` fails
  while `AGENTS.md` routes to a missing `SKILL.md`.
- `test-audit` rewritten to stop test bloat. `SKILL.md` is now a short
  writing guide: decide first whether the change needs a test ("no new test"
  is the default for refactors, docs, and config), write each test fail-first
  (ideas from obra/superpowers `test-driven-development`, MIT), one behavior
  per test at about 30 lines, real code over mocks. The pruning workflow moved
  to `AUDIT.md`; `CAMPAIGN.md` only has its links and one
  source-repo path updated.
- The `policy` job requires a `## Tests` PR section when test files change,
  and a `Ratio:` line when added test lines exceed twice the added production
  lines (`TEST_PATTERNS`, `TEST_RATIO_MAX`, `TEST_RATIO_MIN_LINES` in
  `policy.yml`). The PR template and template review protocol ask for it.
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

- `policy-check.sh` failed open in three ways: a root-level file such as
  `vite.config.ts` globbed `*.ts` down to that one file and skipped nested
  suppressions; git-quoted non-ASCII paths dodged the sensitive-path match
  and the suppression scan; and renaming a file out of `auth/` listed only the
  new path. It now reads unquoted NUL-separated names with `--no-renames`,
  splits `SCAN_EXTENSIONS` without globbing, and keeps raw filenames on one
  `::error::` line.
- `bootstrap.sh --force` wrote through a hard-linked destination, overwriting
  the linked file even outside the target. It now refuses hard-linked and
  non-regular destinations.
- `CODEOWNERS.example` and docs/07 now cover `/.github/scripts/`: the policy
  job runs the PR's own checker, so only Code Owner review stops a PR from
  rewriting it.
- `reference/advanced-patterns.md` link inside
  `.agents/skills/python-performance-optimization/references/details.md`
  resolved to a non-existent nested path.

### Verified

- `bash tests/setup-smoke.sh` covers reruns, force behaviour, hook conflicts,
  readiness, policy failure cases, `--dry-run`, the kit self-check, and
  `--fix` scaffolding.
