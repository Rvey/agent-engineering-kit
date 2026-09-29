# The agent workflow

This is the loop every task follows in a repo using this kit. It exists to
make agent work **predictable**: same intake, same skill selection, same
proof of done. The details matter less than the order.

```
intake → brief (if vague) → load ONE skill → ground → implement
      → deslop → security sign-off → verification gates → handoff
```

## Stage 0 — Setup (once per repo)

1. Drop the kit in (`scripts/bootstrap.sh`).
2. Generate `AGENTS.md` with the `agents-md` skill — brief or repo evidence
   in, real commands and the project's own incident rules out. Never copy the
   template; the skill's anti-slop gate rejects placeholder or generic output.
3. Wire the verification gates into CI.
4. Install the pre-commit hook (`scripts/install-hooks.sh .`), require the
   `policy / loop evidence` check in branch protection, and set CODEOWNERS.
   See [docs/07-loop-enforcement.md](07-loop-enforcement.md).
5. Tell every session to start with: `Read AGENTS.md and follow it.`

## Stage 1 — Intake

Two kinds of tasks:

| Kind | Signal | Action |
|---|---|---|
| **Clear** | Names scope, deliverables, constraints, verification | Load the owning skill and go |
| **Vague** | "fix auth", "make it faster", "add billing", one-liners | Load `boost-prompt` first — **no code until the brief is agreed** |

A good brief is short and testable:

```markdown
## Objective
Let users export their flow runs as CSV.

## Scope
- In: apps/web run history page, apps/runtime runs API
- Out: scheduled exports, email delivery

## Deliverables
- "Export CSV" button on the run history table
- GET /runs/{id}/export returns text/csv with all run steps

## Constraints
- Must not block the API; stream the response
- Reuse the existing runs repository; no new tables

## Verification
- npm run test:runtime, npm run lint --workspace=web, manual download check

## Open questions
- CSV column set: reuse the UI table columns?
```

The agent emits the brief in chat, asks for changes, and only then starts.

## Stage 2 — Skill selection

One skill owns the task. Load only that one; open its `references/` only when
the SKILL.md tier is not enough. The routing table is in `AGENTS.md`.

Rules that keep this honest:

- **Never start skill-governed work with no skill loaded.** UI, runtime, perf,
  tests, lint config, and review all have owners.
- **Never load skills speculatively.** Loading five skills "just in case"
  dilutes attention and produces mush.
- **Missing skill?** Ask the user via the question tool whether to install it
  or vendor it. Do not proceed without it and do not silently improvise a
  workflow the team already has.

## Stage 3 — Ground before writing

Before the first edit, the agent reads the actual owner boundary — not the
idea of it:

- the file(s) that own the behavior, their entry points, callers, callees;
- existing tests at that boundary;
- the project's rules that already govern it (registry, compiler, config);
- recent history for the area (`git log --oneline -- <path>`).

**Never assume — verify imports and files exist.** Most agent mistakes are
confident guesses about code the agent never opened.

## Stage 4 — Implement

- Small, verifiable slices. Prefer extending the owner boundary over creating
  a parallel path.
- Respect existing structure; a new helper file is a design decision, not a
  reflex.
- Keep the change behavior-scoped: no drive-by refactors, no speculative
  abstractions, no fallback code for states that cannot happen.
- When you touch a shared contract, search for every consumer before changing
  its shape.

## Stage 5 — Deslop (`deslop` skill)

After the feature works and before review, run a **diff-scoped** cleanup pass
over `git diff` vs the merge base:

- comment narration a human maintainer would not write
- defensive checks and `try/catch` abnormal for the module
- type laundering (`as any`, widen-then-assert)
- one-use helpers, redundant intermediates
- compatibility shims without a named contract and removal plan
- style that conflicts with the surrounding file

Behavior-neutral edits only. Anything risky gets reported, not touched.
Deslop never replaces the review gate.

## Stage 6 — Security sign-off (`security-and-hardening` skill)

Trigger it when the change touches: user input, auth/authz, stored or
transmitted sensitive data, external integrations, uploads/webhooks/callbacks,
PII/payments, or LLM calls.

Walk `references/security-checklist.md` and run the skill's verification
list. Treat LLM output as untrusted input. Grep the staged diff for secrets
before committing.

## Stage 7 — Verification gates

Every gate is a command; run all that apply and paste the real output:

- lint (zero errors)
- typecheck (after typed code changes)
- tests (after backend/runtime changes)
- build (after app-level changes)

New code stays inside the size/complexity budgets even when they are warn-level
debt. Every suppression carries a comment explaining itself — unexplained
suppressions are rejected.

## Stage 8 — Handoff

Report:

- what changed and where;
- which gates ran, with results;
- what was left risky or deferred, and why;
- follow-ups, named.

No silent scope creep. If the diff grew beyond the brief, say so.

## Anti-patterns

| Anti-pattern | What it looks like | The fix |
|---|---|---|
| Leap before looking | Edits before opening the owner file | Grounding pass (Stage 3) |
| Skill-blind work | "I'll just write the tests quickly" | Routing table is mandatory |
| Big-bang diffs | One PR touches five subsystems | Slice by owner boundary |
| Fallback fetishism | Retries/shims for impossible states | Delete; report if unsure |
| Green-by-suppression | New `eslint-disable`/`# noqa` with no comment | Comment or fix |
| Phantom "done" | "All tests pass" with no output | Paste the command output |
| Zombie branch | Stale for days, conflicts everywhere | Merge main, re-run gates |
