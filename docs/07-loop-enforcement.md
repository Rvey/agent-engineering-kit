# Making the loop hard to skip

The loop in [docs/01-agent-workflow.md](01-agent-workflow.md) is
**instruction-governed**: an agent follows it because `AGENTS.md` and the
skills tell it to. That works for careful agents and breaks the moment a
junior (or a rushed senior) skips a stage. This page is the enforcement
ladder that makes skipping **visible and merge-blocking** instead of silent.

## The honest split

| Loop part | Can a machine force it? | How |
|---|---|---|
| Gates run (lint, types, tests, build) | **Yes, deterministically** | CI runs the commands; branch protection blocks red PRs |
| The gate commands match the repo | **Yes** | `.agents/verify.sh` is the single source; the hook and CI run it |
| Suppressions have reasons | **Yes, for the checkable classes** | `policy-check.sh` fails `eslint-disable` / `# noqa` / `@ts-ignore` without a written reason |
| `AGENTS.md` was generated, not copied | **Yes** | `policy-check.sh` fails on the template marker or placeholders |
| Deslop evidence exists | **Yes — evidence, not quality** | The PR body must carry a non-empty `## Deslop` section |
| Tests changed for a reason, not bloat | **Yes — evidence, not quality** | `## Tests` is required when test files change; a `Ratio:` note when added test lines exceed 2× production lines |
| Security sign-off happened | **Partly** | `## Security` is required when sensitive paths change; CODEOWNERS forces a human for those paths |
| Deslop was done *well*, threats reasoned about | **No** | Human review (or an AI reviewer — advisory only, see below) |

Design rule: **enforce the evidence deterministically; leave judgement to
humans and AI.** A machine check that pretends to judge quality fails PRs
randomly and gets disabled the first busy Friday.

## What ships in the kit

`scripts/bootstrap.sh` copies these into `<project>/.github/`:

| File | Role |
|---|---|
| `pull_request_template.md` | Requires `## Gates`, `## Deslop`, and (when needed) `## Security` and `## Tests` sections with real content |
| `workflows/policy.yml` | The no-AI CI job (`policy / loop evidence`) — runs the checks on PR open/edit/push |
| `workflows/gates.yml` | Runs `.agents/verify.sh`; add the target repo's toolchain and dependency installation |
| `scripts/policy-check.sh` | The check logic: PR evidence, test-change evidence and ratio, suppression reasons, generated `AGENTS.md` |
| `CODEOWNERS.example` | Rename to `CODEOWNERS` + real owners → security paths force human review |

The generator (`agents-md` skill) writes `.agents/verify.sh` — the gate
commands, lint/typecheck first, `test`/`build` behind `--fast`. One command
list for the hook, the agent, and CI. Start from the closest starter in
`.agents/verify-templates/` (`shell.sh`, `node.sh`, `python.sh`) and replace
every `SETUP:` line; a remaining marker fails `setup-check.sh` on purpose.

Install the pre-commit hook from the target repository:

```bash
bash .agents/install-hooks.sh .
# hook runs: bash .agents/verify.sh --fast  — fast gates before every commit
```

## Wiring branch protection (the part that makes it blocking)

In the repo settings, protect the main branch:

1. Require status checks: `policy / loop evidence` and
   `gates / verification gates` once the target toolchain is wired per
   [docs/03](03-verification-gates.md).
2. Require a pull request before merging, with at least one approval.
3. Enable **Require review from Code Owners** after renaming
   `CODEOWNERS.example`.
4. Require conversation resolution, so every review thread is answered
   before merge.
5. Dismiss stale approvals when new commits are pushed, and require approval
   of the most recent push.
6. Never let a bot satisfy a required approval: don't give apps or bot
   accounts permission to approve pull requests, and keep them out of
   `CODEOWNERS`. The policy job already ignores bot approvals when it counts
   approvals for high-risk changes.
7. Optional: turn on a merge queue, so each PR is tested against the latest
   main before it lands.

Without step 1 the policy job runs but nobody must obey it.

## Risk tiers: approvals follow what the change touches

Every PR body starts with `## Risk` (low, medium or high) and
`## How to revert`. The tier depends on the change, never on who wrote it:

| Risk | Examples | Human approvals |
|---|---|---|
| Low | Docs, copy, internal-only features, additive changes behind a flag | One (branch protection) |
| Medium | Ordinary product changes; sensitive areas such as caching or prompts | One (branch protection) |
| High | Auth, payments, billing, secrets, uploads, webhooks, CI and release workflows, installers | Two, checked by the policy job |

The policy job forces `high` when the diff touches `SENSITIVE_PATTERNS` or
`HIGH_RISK_PATTERNS` in `policy.yml`, and then counts human approvals on the
PR's latest commit. Bot approvals, the author, and approvals given before the
last push don't count. Until two people approve, the check stays red; it
re-runs on every review. In a repository with fewer than two maintainers,
lower `HIGH_RISK_APPROVALS` in `policy.yml`.

Start strict and relax with evidence. Once your revert and incident rates
show that low-risk changes are safe, you can let them merge with no approval
by moving them to a separate, lighter rule. Lenient paths are for authors you
already trust.

## Review context and review rounds

`REVIEW.md` tells every reviewer, human or AI, what matters in each part of
the repo: what counts as a failure, paths to ignore, and how to report (a file
and line for every finding, a count or "No issues found"). Bootstrap copies a
starter; `setup-check.sh` fails until you fill it in. Add a line under
"Recurring issues" whenever the same problem shows up in review twice.

Before opening a PR, the agent has a fresh-context reviewer read the diff
against `REVIEW.md` (`/code-review` and `/security-review` in Claude Code, or a
new subagent). Cap review at three rounds; after that, review only the new
diff. If you can't say what the automated checks would miss, ask for a real
review, not a quick thumbs-up.

The policy job runs on `pull_request`, so it executes the PR's own copy of
`policy.yml` and `.github/scripts/policy-check.sh`. A PR can rewrite the check
that judges it; step 3 is what stops that. Keep the `/.github/workflows/`,
`/.github/scripts/`, and `/.agents/` lines in `CODEOWNERS` owned by
maintainers.

What happens after the merge (merge queues, flags, staged rollout, one-step
revert, and incidents as the reviewer's test set) is in
[docs/09](09-shipping-and-rollback.md).

## Escape hatches (for maintainers)

- **`policy:skip` label** — skips the policy job. Anyone with triage/write can
  apply it; treat label access as a trust boundary.
- **`policy:allow` on an added line** — exempts that one suppression, visibly,
  in the diff. Prefer this over the label: it is scoped and reviewable.
- A human can always bypass a check with admin rights; that is an audit
  trail, not a hole.

## If you also want AI in the review loop

The evidence gate proves *that* the stage ran, not *how well*. Options, in
increasing cost:

1. **Reviewer discipline** — the review protocol in `AGENTS.md` tells the
   reviewer what to verify; the PR template makes the claims checkable.
2. **GitHub Copilot code review** — enable it in repo settings (Copilot
   subscription required, no key stored in the repo). It reviews PRs
   automatically and comments. Treat it as **advisory**: it does not
   reliably hard-block merges.
3. **A keyed AI action** — an OpenAI/Anthropic/Azure key in repo secrets
   running a deslop-style review. Works, but: costs per push, is
   nondeterministic (flaky gate), and the diff is **untrusted input** —
   prompt injection risk. If you do it: read-only token, no secrets in
   context, never let it write code or approve.
4. **No keyless option** — GitHub Models (AI in Actions via `GITHUB_TOKEN`)
   was retired on July 30, 2026. Do not plan around it.

## Adoption checklist

- [ ] `scripts/bootstrap.sh` run (copies the five `.github/` files)
- [ ] `AGENTS.md` generated (`agents-md` skill) so the policy's AGENTS.md check passes
- [ ] `.agents/verify.sh` written by the generator
- [ ] `gates.yml` installs the target repo's toolchain and successfully runs `.agents/verify.sh`
- [ ] `scripts/install-hooks.sh <project>` run
- [ ] Gate workflow wired and required (docs/03)
- [ ] `policy / loop evidence` and `gates / verification gates` required in branch protection
- [ ] `CODEOWNERS` renamed and owners set
- [ ] `REVIEW.md` filled in and its template comment removed
- [ ] Conversation resolution and dismiss-stale-approvals turned on
- [ ] `HIGH_RISK_APPROVALS` set for the team's size
- [ ] First PR opened to confirm the policy job fails on a blank body
