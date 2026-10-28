<!-- agent-engineering-kit:template — replace every line below with this repo's facts, then delete this comment. -->
# REVIEW.md

What reviewers, human or AI, check in this repository. Code owners keep it
short and current. When the same problem shows up in review twice, add it
under "Recurring issues".

## What counts as a failure

<!-- The bugs that would hurt here. Examples: docs that are wrong; config that
misroutes traffic; a migration without a rollback; a public API change
without a version bump. -->

-

## Per area

<!-- One line per directory that has its own rules, and who owns it. -->

| Path | What matters | Owner |
|---|---|---|
| | | |

## Ignore

<!-- Generated files, vendored code and fixtures reviewers should skip. -->

-

## How to report

- Cite a file and line for every finding (`src/api/user.ts:42`). Never guess
  a file name.
- Report only problems that would cause a failure listed above, or break a
  rule in `AGENTS.md`. Skip style nitpicks the linters do not enforce.
- Flag changes that make `AGENTS.md` or this file out of date.
- Start with a summary: the number of findings, or "No issues found."
- Stop after three review rounds. After that, review only the new diff.

## Recurring issues

<!-- Each entry: the pattern, where it bit, and the rule that prevents it. -->

-
