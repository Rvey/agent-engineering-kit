# Verification gates

**Every gate is a command. "Looks good" is not a gate.** Gates are how agents
prove work instead of asserting it, and how reviewers know what was actually
checked. Define them before the code exists.

## Principles

1. **A gate is a command with an unambiguous bar.** Zero errors. Exact tests.
   A build that exits 0.
2. **Warn-level budgets are tracked debt, not gate failures.** Size,
   complexity, and similar limits warn; new code stays inside them, old code
   gets refactored deliberately.
3. **Suppressions must explain themselves.** Every lint-silence comment names
   why the exception is intentional (one-shot baseline, ref-by-design, …).
   Unexplained suppressions are rejected in review.
4. **Gates appear in the handoff with their real output.** No paraphrasing.
5. **The same commands run locally and in CI.** A gate that only exists in CI
   slows the loop; a gate that only exists locally is not a gate.

## The four gate classes

| Class | What it proves | Example commands |
|---|---|---|
| Lint / format | Style, imports, hooks rules, budget warnings | `npm run lint`, `ruff check .`, `prettier --check .` |
| Types | Contracts still line up across modules | `npm run typecheck`, `tsc --noEmit`, `mypy` |
| Tests | Behavior at the owner boundary still holds | `npm run test:runtime`, `pytest -q`, `vitest run` |
| Build / runtime | The app compiles and boots | `npm run build`, `docker build .`, smoke script |

## Example matrix (from the source setup)

Adapt names to your stack; keep the shape — one command per concern, one
place that lists them:

```bash
npm run lint                 # ESLint, zero errors
npm run lint:runtime         # ruff check, line-length 120, clean
npm run typecheck --workspace=web
npm run test:runtime         # uv run pytest
npm run build:web
```

Mapped into `AGENTS.md` as: "after touching X, run Y". The mapping matters —
an agent that doesn't know which gate covers which area will run none of them.

## Setting up gates in a new repo

1. **Pick the smallest honest commands** for lint, types, tests, build —
   before writing feature code. If a gate doesn't exist yet (no test runner),
   say so explicitly in `AGENTS.md` instead of pretending (see the test-audit
   example: "web `*.test.ts` has no runner — prefer runtime pytest at the
   owner boundary; do not add new web test files without a runner").
2. **Wire them into CI** in the same commit as the branch protection.
3. **Keep them fast by default.** Slow proof (full E2E, concurrency) belongs
   in a separate gate invoked deliberately.
4. **Record before/after numbers for performance work** — the
   `performance-optimization` skill requires a baseline and re-measurement;
   an optimization without numbers gets reverted.
5. **Write them once, in one file.** `.agents/verify.sh` holds the commands:
   fast gates run for `--fast`, slow gates only in the full pass. The hook,
   CI, and the agent all call that one script, so a gate cannot drift between
   them. Starters for shell, Node, and Python repos live in
   `.agents/verify-templates/`; replace every `SETUP:` line before you trust
   the result.

## PR readiness checklist

- [ ] Lint clean (zero errors; warnings inside budget)
- [ ] Types check after any typed-code change
- [ ] Tests pass at the touched boundary
- [ ] Build/boot passes after app-level changes
- [ ] Performance changes have before/after numbers
- [ ] Suppressions each carry a reason
- [ ] Handoff lists the gates actually run, with output
