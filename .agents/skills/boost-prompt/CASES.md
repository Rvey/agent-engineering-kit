# Execution plan cases

Labelled examples for the [execution plan](SKILL.md#execution-plan) rules.
Each row lists what a careful person would accept; where two answers are
fine, the cheaper one comes first. Use them to check a change to the rules:
read each request, decide, compare.

Rows marked **held out** are kept out of rule tuning: never change a rule to
make one of them pass. Report how many held-out rows a changed rule gets
right separately from the rest. They were written alongside the rules, so
they check for regressions, not how well the rules generalise.

| # | Request (and context) | Model | Effort | Agents |
|---|---|---|---|---|
| 1 | "What does `set -u` do?" | fast | low | single |
| 2 | "Rename `usr` to `user` in `auth.ts`" | fast | low | single |
| 3 | "Thanks, that worked" | fast | low | single |
| 4 | "Add a `--dry-run` flag to the install script" | balanced | medium | single |
| 5 | "Fix auth" (login returns 500 since yesterday's deploy, cause unknown) | deep | high | single |
| 6 | "Review the entire repo for dead code" | balanced or deep | high | multi: one search subagent per top-level area (fast, medium), then one merge |
| 7 | "Migrate every service from REST client v1 to v2" (12 services, separate dirs) | balanced | high | multi: one writer per service dir (balanced, medium) |
| 8 | "B" (last reply offered: A rename a flag, B rewrite the policy checker) | deep | high | single |
| 9 | "Yes" (last reply asked: "Delete the stale branch too?") | fast | low | single |
| 10 | "No, keep the old flag working too" (during a medium CLI change) | balanced | medium | single |
| 11 | "Quick question: is this repo using bats?" | fast | low | single |
| 12 | "Think hard about why CI is flaky on macOS only" | deep | high | single |
| 13 | "Make the dashboard faster" (one page, no profile yet) | balanced | medium | single |
| 14 | "Change the token check in the PR policy script" (sensitive path) | deep | high | multi: fresh-context reviewer after (deep, medium) |
| 15 | "Find where we parse `.env` files" | fast | low or medium | single |
| 16 | **held out** — "Write release notes from the last 40 commits" | balanced | medium | single |
| 17 | **held out** — "Go" (last reply: a 5-step plan touching docs and the template) | balanced | medium or high | single |
| 18 | **held out** — "Update the README and the bootstrap script for the new preset" | balanced | medium | single (same change, shared context) |
| 19 | **held out** — "Audit all skills for broken frontmatter and stale links" | fast | medium | multi: read-only search subagents (fast, medium) |
| 20 | **held out** — "Why is this function slow?" (pasted, 30 lines, no tools needed) | balanced | medium | single |

Notes on the harder rows:

- **6, 7** — big but splittable: the pieces touch different files and need
  no shared result. Subagents stay at medium or above.
- **8, 9** — a one-word answer takes the effort of the work it starts.
- **10** — pushback keeps the effort of the work under way.
- **5, 14** — costly mistakes keep high even on deep; 14 also gets a
  fresh-context review because it touches a sensitive path.
- **18** — two files, but one change: splitting it would lose context.
