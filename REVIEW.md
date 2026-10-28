# REVIEW.md

What reviewers, human or AI, check in this repository. When the same problem
shows up in review twice, add it under "Recurring issues".

## What counts as a failure

- **An adopter file gets clobbered.** Bootstrap writes over a file the kit
  does not own, `--force` reaches beyond kit paths, or a write follows a
  symlink or hard link out of the target.
- **A gate fails open.** A missing `.agents/verify.sh`, an unreadable diff, an
  absent review list or a parse error makes a check pass instead of fail.
- **A shell script is unsafe.** It lacks `set -euo pipefail` (or the policy
  script's deliberate `set -uo pipefail`), leaves an expansion unquoted, or
  adds a `shellcheck disable=` without a comment saying why.
- **Docs disagree with behaviour.** A README, doc or SKILL.md describes a
  flag, path or step the scripts do not implement.
- **The template stops being a template.** `templates/AGENTS.template.md`
  loses its marker or placeholders, or root `AGENTS.md` gains placeholders.
- **A rule is restated instead of linked.** Routing lives in AGENTS.md, skill
  detail in SKILL.md, behaviour in scripts.

## Per area

| Path | What matters |
|---|---|
| `scripts/bootstrap.sh`, `scripts/install.sh` | Never clobber, fail closed, prompts read from the terminal and never block CI |
| `templates/github/` | Ships to every adopter: a regex or default change alters every adopter's merge rules |
| `scripts/retired-skills.txt`, `scripts/shipped-files.txt` | Hashes match the files the kit really shipped |
| `.agents/skills/` | Vendored: keep upstream text, attribution in CREDITS.md |
| `tests/setup-smoke.sh` | Each case fails before the fix; no network in CI |

## Ignore

- Vendored skill wording under `.agents/skills/` that matches upstream.
- `CHANGELOG.md` phrasing, unless an entry is wrong.

## How to report

- Cite a file and line for every finding (`scripts/bootstrap.sh:120`).
- Report only problems that would cause a failure above or break a rule in
  `AGENTS.md`. Skip style nitpicks that shellcheck and the lint script do not
  enforce.
- Flag changes that make `AGENTS.md`, the README or this file out of date.
- Start with a summary: the number of findings, or "No issues found."
- Stop after three review rounds. After that, review only the new diff.

## Recurring issues

- **Fail-open policy parsing** (`policy-check.sh`, October 2026): globbed
  pathspecs, git-quoted names and renames hid files from the checks. Read
  NUL-separated names with `--no-renames`, never glob pathspecs.
- **Write-through on `--force`** (`bootstrap.sh`, October 2026): `cp` followed
  a hard link outside the target. Refuse hard-linked and non-regular
  destinations.
