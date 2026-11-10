# Execution plan cases

Labelled examples for the [execution plan](SKILL.md#execution-plan) rules.
Each row lists what a careful person would accept; where two answers are
fine, the cheaper one comes first. Use them to check a change to the rules:
read each request, decide, compare.

Rows marked **held out** are kept out of rule tuning: never change a rule to
make one of them pass. Report how many held-out rows a changed rule gets
right separately from the rest. They were written alongside the rules, so
they check for regressions, not how well the rules generalise. A change of
house rule (a model removed, an effort cap, a new split default) relabels
every row it touches, held-out rows included; say so in the changelog.

Helpers: `scout` (haiku, read-only), `worker` (sonnet), `reviewer` (opus at
medium unless the row says sonnet).

| # | Request (and context) | Model | Effort | Agents / sessions |
|---|---|---|---|---|
| 1 | "What does `set -u` do?" | haiku | low | single, no route line |
| 2 | "Rename `usr` to `user` in `auth.ts`" | haiku | low | single |
| 3 | "Thanks, that worked" | haiku | low | single, no route line |
| 4 | "Add a `--dry-run` flag to the install script" | sonnet | medium | own session (sonnet, medium) + reviewer (sonnet) |
| 5 | "Fix auth" (login returns 500 since yesterday's deploy, cause unknown) | opus | medium; ask before high | scout reads deploy logs + reviewer after the fix |
| 6 | "Review the entire repo for dead code" | opus | medium | one scout per top-level area, then the main session merges |
| 7 | "Migrate every service from REST client v1 to v2" (12 services, separate dirs) | opus | medium | one worker session per service dir (sonnet, medium), each with a reviewer (sonnet) |
| 8 | "B" (last reply offered: A rename a flag, B rewrite the policy checker) | opus | medium | single writer + reviewer |
| 9 | "Yes" (last reply asked: "Delete the stale branch too?") | haiku | low | single |
| 10 | "No, keep the old flag working too" (during a sonnet, medium CLI change) | sonnet | medium | keeps the running setup |
| 11 | "Quick question: is this repo using bats?" | haiku | low | single, no route line |
| 12 | "Think hard about why CI is flaky on macOS only" | opus | medium; ask before high | scouts read CI logs per job |
| 13 | "Make the dashboard faster" (one page, no profile yet) | opus | medium | scout profiles first + reviewer (sonnet) |
| 14 | "Change the token check in the PR policy script" (sensitive path) | opus | medium | single writer + reviewer |
| 15 | "Find where we parse `.env` files" | haiku | low or medium | single scout, or one per area |
| 16 | **held out** — "Write release notes from the last 40 commits" | sonnet | medium | single, or a scout summarizes the commits |
| 17 | **held out** — "Go" (last reply: a 5-step plan touching docs and the template) | sonnet | medium | the plan's split: one worker per independent step, one reviewer at the end |
| 18 | **held out** — "Update the README and the bootstrap script for the new preset" | sonnet | medium | single (same change, shared context) + reviewer (sonnet) |
| 19 | **held out** — "Audit all skills for broken frontmatter and stale links" | haiku | medium | scouts in parallel, one per skill group |
| 20 | **held out** — "Why is this function slow?" (pasted, 30 lines, no tools needed) | sonnet | medium | single, no route line |
| 21 | "Add the `lean` preset to bootstrap, then write a blog post announcing it" | sonnet | medium | sessions: bootstrap change here + reviewer; blog post in its own session (sonnet, medium) after the change lands |
| 22 | "Now set up the release workflow" (this chat: 70% full, the last task just finished) | sonnet | medium | new session with a handoff + reviewer |
| 23 | "Migrate the whole kit from bash to Python" | opus | medium | one session per area (scripts, tests, templates), each with a reviewer; never Fable |
| 24 | "Use Fable for this refactor" | opus | medium | refuse Fable (house rule 1), offer opus at medium |
| 25 | "Use Opus at max effort" | opus | medium until the user confirms high in the question tool | single |
| 26 | "Update the changelog for this release" | sonnet | low or medium | single |

Notes on the harder rows:

- **5, 12, 25** — Opus stays at medium; "think hard" or a named higher
  effort is a question for the user, never a silent upgrade.
- **6, 7, 23** — big and splittable: the pieces touch different files and
  need no shared result, so each gets its own scout, worker or session.
- **8, 9** — a one-word answer takes the setup of the work it starts.
- **10** — pushback keeps the setup of the work under way.
- **13** — performance work stays on opus even when the ask is short.
- **14, 8** — a sensitive path keeps a fresh-context reviewer.
- **18** — two files, but one change: splitting it would lose context.
- **21** — the blog post is its own deliverable and needs none of this
  chat's code context; it waits for the change because it describes it.
- **22** — the old task is done and the next is different work, so a heavy
  chat is dead weight. Mid-task, 70% alone would not be a reason.
- **24** — the user's named model wins except where a house rule forbids it.
