# Shipping and rollback

The loop in [docs/07](07-loop-enforcement.md) decides what may merge. This
page covers what happens after: landing changes safely, undoing them fast, and
learning from the ones that went wrong. None of it is a file the kit can copy
in. These are team and product habits, and they are what make it safe to
review less than every line.

## You land it, you own it

Whoever merges a small or medium change fixes it if it breaks, because they
have the most context. That stays manageable when:

- **Changes are small**, so they are easy to review, debug and revert.
- **Everything can be reverted** in minutes: a revert commit, a feature flag,
  or a rollback of the last deploy.
- **Blast radius sets the bar.** Riskier code gets more reviewers and more
  validation; see the risk tiers in [docs/07](07-loop-enforcement.md).
- **Regressions surface fast**, through telemetry and internal use.
- **It isn't about blame.** Incident reviews look at the system, not the
  person.
- **Work happens in the open.** Anyone can see what others are building and
  flag a wrong direction early, while closing the PR is still cheap.

## Landing changes

| Practice | What it buys you | Where to start |
|---|---|---|
| Merge queue | Each PR is tested against the latest main before it lands, so two green PRs can't combine into a red main | Turn on the merge queue in branch protection and keep the `gates` check required |
| Feature flags | New behaviour ships dark and turns off without a deploy | Put any change that alters what users see behind a flag your team can flip |
| Internal users first | Your own team hits the bug before customers do | Enable new flags for the team, then widen |
| Staged rollout | A bad change reaches a few users, not all of them | Roll out by percentage or region; watch error rates at each step |

## Reverting in one step

Every PR body has a `## How to revert` section, so the undo is written down
before the change lands. Make that step real:

- Keep main revertable: one PR, one merge commit (or one squashed commit), so
  `git revert <sha>` undoes exactly one change.
- Say what a revert does **not** undo: data migrations, sent messages,
  published packages, external API calls. Ship those behind a flag or with a
  forward fix ready.
- Practise it. A revert path nobody has used is a guess.

## Incidents and reverts as the reviewer's test set

Your own incidents are the best test of any review process, human or AI.

1. Log every revert and incident fix: the PR that caused it, the fix, and
   where the bug was.
2. Have someone who knows that code confirm the bug was real and in that PR.
3. Score the reviewer against the set: would it have flagged each bug? Do this
   on a schedule, and every time you change its prompts, tools, model or
   `REVIEW.md`. Keep a change only if the score goes up.
4. Turn each confirmed bug class into a line in `REVIEW.md` under
   "Recurring issues", and into a hard rule in `AGENTS.md` once it repeats.

## Measuring it

Track how much human review time the process costs, and use the revert rate
and incident rate as guardrails. Lower the review bar only while those stay
flat; raise it again when they climb.
