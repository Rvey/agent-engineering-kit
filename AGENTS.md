# AGENTS.md — <Project Name>

> **This is a template. Adapt me.**
> Copy this file to your repository root, then replace every `<placeholder>`
> and every example command with your stack's real ones. The structure is
> what matters: one routing table that tells every AI agent where to start,
> which skill to load, and which command proves the work is done.

Repo-wide instructions for AI coding agents. Stack-specific rules live in
per-app `AGENTS.md` files (e.g. `apps/web/AGENTS.md`) and in
`.cursor/rules/*.mdc` (glob-scoped rules for Cursor-compatible agents).

## Skills

Skill lookup order: if a named skill is not installed in the agent's
environment, fall back to the vendored copy committed at
`.agents/skills/<name>/SKILL.md` (plus its `references/` subdirectory). Every
skill referenced below is tracked there — never skip a skill's workflow just
because the installer lookup failed; read the vendored `SKILL.md` directly.

Additional skills live upstream — install the shared catalog (one-time per
machine) so your agent can pull any of them when needed:

```bash
npx skills add addyosmani/agent-skills            # install the full catalog
npx skills add addyosmani/agent-skills --list     # browse before installing
npx skills add addyosmani/agent-skills --skill <name>  # one skill only
```

Source: `https://github.com/addyosmani/agent-skills` (`skills/` holds the
SKILL.md workflows, `references/` the shared checklists, `agents/` reviewer
personas). When a task needs a skill that is neither installed nor vendored,
ask the user via the native question tool whether to install it
(`npx skills add <source>`) or vendor it under `.agents/skills/` — then wait
for the answer. Do not silently proceed without the skill's workflow.

Vendoring rules: a per-skill install copies only `skills/<name>/`, not the
repo-level `references/` — so when vendoring, also copy any shared checklist
the skill needs into its `references/`. Every `SKILL.md` needs frontmatter
(`name`, `description` with a "Use when…") plus workflow steps and
verification gates. Keep vendored skills specific, verifiable, and minimal.

Skill selection: before starting work, identify which skill owns the task and
load only that one (plus its `references/` only when the SKILL.md tier is
insufficient). Never load unrelated skills speculatively, and never start
skill-governed work (UI, runtime, perf, tests, lint config, review) with no
skill loaded.

### Task → skill routing

| Task | Load before starting |
|---|---|
| Vague, ambiguous, or underspecified request | `.agents/skills/boost-prompt/SKILL.md` |
| React/Next UI work | `.agents/skills/react-next-performance/SKILL.md` |
| FastAPI / Python API work | `.agents/skills/fastapi-python/SKILL.md` |
| Python hot-path optimization | `.agents/skills/python-performance-optimization/SKILL.md` |
| Any performance work, any layer | `.agents/skills/performance-optimization/SKILL.md` |
| Writing, changing, reviewing, or pruning tests | `.agents/skills/test-audit/SKILL.md` |
| Lint/format configuration | `.agents/skills/eslint-prettier-config/SKILL.md` |
| Any feature delivered, before review | `.agents/skills/deslop/SKILL.md` |
| Anything touching input, auth, data, external services, or LLMs | `.agents/skills/security-and-hardening/SKILL.md` |

Add a row here the moment a second incident class appears. The routing table
is the single entry point; if it is not here, agents will not find it.

## Hard rules (learned from real incidents)

These are rules, not suggestions. Each one below bit a real production
codebase before it was written down. Replace the examples with the incidents
your own team should never repeat — and keep them short, concrete, and
testable. Full write-up: `docs/04-performance-guards.md`.

1. **No dep-less effects.** Every effect needs a complete dependency array.
   A mirror effect without deps fired on every canvas drag frame.
2. **No fresh-identity arrays/objects in dependency arrays.** Derive a scalar
   key first (`firstKey`, `hasActiveRun`, `arr.join("|")`,
   `JSON.stringify(obj)` into a named const). Never inline the key computation
   in the deps array.
3. **No `setState` per stream token / event / animation frame.** Accumulate
   locally, commit once per chunk. Cap growing lists (`slice(-N)`).
4. **No synchronous storage I/O per update.** If persistence is required, it
   must be debounced (≥500ms), never written per streaming token.
5. **No double `setState` for the same data in one flow.** If a fetcher sets
   state internally, don't set it again after awaiting it.
6. **Hot-path callback identity must be stable.** Handlers fed to canvas
   libraries or pollers read latest state via refs, never by closing over
   large arrays/objects.
7. **Polling timer deps are `[id, booleanFlag, stableCallbacks]`.** Selecting
   an item must not reset the interval; read selection via a ref inside the tick.
8. **Projections return input identity when there is no work**
   (`if (issues.length === 0) return nodes`) and clone only changed items.

## Verification (required)

Every gate is a command. "Looks good" is not a gate. Replace the examples
with your repo's real commands and keep this list in sync with CI.

- `<lint command>` — zero errors is the bar. Warn-level size/complexity
  budgets (`max-lines`, `max-lines-per-function`, `complexity`, …) are
  tracked refactoring debt, not gate failures; new code should stay inside
  the budgets.
- `<typecheck command>` — required after touching typed code.
- `<test command>` — required after touching the backend/runtime (example:
  `npm run test:runtime` → `uv run pytest`).
- `<format command>` — repo formatter stays authoritative.
- Every lint suppression (`eslint-disable`, `# noqa`, …) MUST carry a comment
  explaining why the exclusion is intentional. Unexplained suppressions are
  rejected in review.

Design the gates before the code: the command that proves "done" belongs in
this file and in CI on day one, not after the first regression.

## Where rules live (single source of truth)

- **Root `AGENTS.md`** (this file) — routing, gates, and repo-wide hard rules.
- **`apps/<app>/AGENTS.md`** — stack-specific rules that only apply in one app.
- **`.cursor/rules/*.mdc`** — glob-scoped rules for Cursor-compatible agents.
- **`.agents/skills/<name>/SKILL.md`** — deep on-demand workflows.
- **`docs/`** — decisions, reports, runbooks (ADR-style when decisions need a paper trail).

Never copy a rule into two places. If a rule is already enforced in code
(a registry, a compiler, a config file), instruction files point at it — they
do not restate it. When a rule changes, change it in its one home and let
everything else link to it.

## Review protocol

A change is not done until all of these are true:

1. The owning skill's workflow was followed (if the task is skill-governed).
2. The verification gates above pass — paste the actual command output in the
   handoff.
3. **Deslop**: run the diff-scoped cleanup pass
   (`.agents/skills/deslop/SKILL.md`) over the branch diff. Behavior-neutral
   edits only; report anything risky instead of touching it.
4. **Security sign-off**: if the change accepts input, touches auth/authz,
   stores or transmits sensitive data, integrates an external service, adds
   uploads/webhooks, handles PII/payments, or calls an LLM — walk
   `.agents/skills/security-and-hardening/references/security-checklist.md`.
5. **Test audit**: if tests were added or changed, they pass the authoring
   gate in `.agents/skills/test-audit/SKILL.md`.
6. **Handoff**: what changed, which gates ran with results, known risks,
   follow-ups. No silent scope creep.
