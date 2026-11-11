---
name: boost-prompt
description: "Routes every task to a model, effort, helper agents and sessions, and turns vague requests into a structured brief before coding. Route mode: one line per task (Claude model, effort, scouts/workers/reviewers, separate sessions). Brief mode: interrogate scope, ground in repo, emit a markdown brief with that execution plan for the user to confirm. Never writes code. Use when starting any task, when a request is underspecified or ambiguous, or when choosing a model, effort level, subagents or sessions."
---

# Boost Prompt — Route Every Task, Brief the Vague Ones

Two modes:

- **Route** — every task, before the first tool call: one line naming the
  model, effort, helpers and sessions. Clear requests stop here and run once
  the user agrees.
- **Brief** — vague tasks only: questions, a written brief, then the same
  execution plan. DO NOT WRITE ANY CODE during refinement.

## When to use

- **Route:** the start of any task that edits files or runs more than one
  command. The routing line in `AGENTS.md` points here.
- **Brief:** scope, deliverables, constraints, repo area, or success
  criteria are vague, ambiguous, or missing; the request could span several
  areas; or it is a one-liner ("fix auth", "make it faster") with no
  acceptance criteria.

## When NOT to use

- A pure question or a one-line answer: no route line needed.
- Brief mode when the request already names scope, deliverables and
  verification: route it and proceed.
- Emergency hotfix where the user says "skip questions, just do it": skip
  the brief, still show the route line and wait for a yes.

## Route mode

Before the first edit, state one line and wait for the user's yes:

```text
Route: <model> · <effort> · <agents> · <sessions> — <reason, at most 8 words>
```

Example: `Route: sonnet · medium · worker + reviewer (sonnet) · own session — spec'd flag, own commit`.

Pick each field with [Execution plan](#execution-plan). Changing the plan
later follows [Confirm before running](#confirm-before-running) step 5.

## Brief workflow

1. **Detect ambiguity, stop before coding.** Do not edit, scaffold, or run
   repo-wide exploration loops yet. One cheap grounding pass only (`read` /
   `glob` / `grep` the likely owner area), or one scout helper, to ask
   informed questions.
2. **Ground in repo.** Identify the probable owner boundary and constraints:
   the rules that already govern that area (registries, shared contracts,
   layer boundaries) and the existing verification gates. Never assume —
   verify files and imports exist.
3. **Ask specific questions via the native question tool.** Cover only what is
   missing, max 4 per round:
   - scope + objectives (what is in / out);
   - deliverables + success criteria (observable behavior);
   - technical constraints (repo area, API contracts, UX surface, perf/security);
   - verification (which gate proves done — the repo's lint, typecheck, and
     test commands — or the manual steps).
4. **Organize into a brief.** Keep it short, ordered, no implementation detail.
5. **Size the execution plan** from the agreed scope, using the rules in
   [Execution plan](#execution-plan). Never ask the user for it; recommend.
6. **Emit the brief as markdown in chat, then ask for changes.** Repeat
   emit + ask after every revision. Chat output is the delivery channel.
7. **Confirm the setup before anything runs.** See
   [Confirm before running](#confirm-before-running). No code, no subagent,
   no new session and no model or effort change until the user says run.

## Brief template

```markdown
## Objective
<1-2 sentences>

## Scope
- In: <areas/files>
- Out: <explicit non-goals>

## Deliverables
- <observable behavior 1>
- <observable behavior 2>

## Constraints
- <repo area, API contract, UX, perf/security>

## Verification
- <lint / typecheck / test:runtime / manual>

## Execution plan
- Model: <haiku | sonnet | opus> — <reason, at most 8 words>
- Effort: <low | medium | high> — <reason>
- Agents: <helpers: each one's job, agent (scout | worker | reviewer) and model> — <reason>
- Sessions: <each session's job, model + effort, files; or "this one"> — <reason>
- Unsure: <fields the user should check, or "none">

## Open questions
- <only what still blocks execution>
```

## Execution plan

A recommendation for the sessions and helpers that will do the work. Pick
the cheapest model that still does the job well, and split the work
wherever the task has pieces.

### House rules

These override every table below and any model guide:

1. **Never Fable.** Do not use or recommend any Fable model, for a session
   or a helper. The top tier is Opus.
2. **Opus runs at medium.** High effort or above on Opus needs the user's
   explicit yes first. Put it under Unsure, ask, and wait; never pick it
   silently, even for "think hard".
3. **Split by default.** Recommend separate sessions and helpers whenever
   the task has pieces ([Agents and sessions](#agents-and-sessions)).
   Single is the exception, and every split still needs the user's yes.

### Judge the work, not the message

- Size by amount of work and cost of a mistake, not message length or whether
  it is code. "Review the whole repo" is short and never low.
- Low effort is only for work that needs no planning: a direct answer, or one
  or two trivial tool calls (a lookup, a rename, a one-line fix).
- An answer to a question in the last reply ("B", "yes", "option 2") takes the
  effort of the work it starts, not of the word. "Yes" to one small action is
  low; approving a plan takes the plan's effort.
- Pushback, a correction, or an addition to work in progress keeps that work's
  effort. Never drop to low for it.
- The user's own words win, within the house rules: "quick question" means
  low; a named model or effort is used as given, except Fable (refuse) and
  Opus at high (confirm first).

### Model

| Model | Claude | Use for |
|---|---|---|
| haiku | Haiku 5.5 | Scout helpers: search files, read logs, summarize, classify. Lookups and renames. Work where a wrong answer is cheap to spot |
| sonnet | Sonnet 5.5 | Well-scoped work against a clear spec: a bug fix, a flag, a feature iteration. Docs, release notes, repeated reviews. Half the Opus price |
| opus | Opus 5.5 | Default when unsure. Unclear root cause, multi-PR features, architecture, large refactors and migrations, careful reviews, security or data paths, hard-to-revert work, computer use |

A clear spec alone does not mean sonnet: migrations and performance work
stay on opus. Other tools: map the three rows to their own small, default
and largest allowed model.

The model is for the session or helper that **starts** the work. Do not
switch models mid-session: each model keeps its own prompt cache, so the
first request on the new model re-reads the whole chat at full price. When
the plan names a different model from the current chat, start a new
session on it with a handoff. A fresh chat with nothing cached yet may
switch for free. Low-effort single tasks (a lookup, a rename, a one-line
fix) run in the current chat on its model: a new session costs more than
the task.

### Effort

| Effort | Use for |
|---|---|
| low | Quick answer or a trivial edit, no planning |
| medium | Normal work, and every Opus session or helper by default |
| high | Haiku or Sonnet on a large multi-step job or a costly mistake. On Opus only after the user's yes |

### When the result is not good enough

Escalate in this order, one step at a time:

1. Make the agent check its own work: run the test, the build, or the gate.
2. Raise Haiku or Sonnet one effort step, or move up to Opus at medium.
3. At Opus medium, stop and ask the user before Opus at high. There is no
   step past Opus.

### Agents and sessions

Look at the shape of the task and recommend a split for every piece that
fits a row. Helpers come back into this chat; a session has its own context
and its own outcome (a branch, a PR).

| When the task has… | Recommend |
|---|---|
| A search or read where only the answer matters | `scout` helpers (haiku), one per area, in parallel |
| Independent pieces in different files | One `worker` helper (sonnet) or session per piece, each in its own worktree |
| Any code change | A `reviewer` helper with a fresh context after the edit: sonnet for spec'd work, opus at medium for sensitive paths |
| A piece that ends in its own commit or PR | Its own session with a self-contained handoff |
| Next work that differs from what this chat just finished | A new session instead of this chat |
| One answer, one tiny edit, or one change across shared files | Single, in this chat: splitting would cost more than the work |

Pinned helpers live in `.claude/agents/`: `scout` and `Explore` (haiku,
read-only), `worker` (sonnet), `reviewer` (opus, medium). Any other helper
must be started with an explicit model. Never start a Fable helper, and ask
the user before an Opus helper at high effort.

Rules for every split:

- Code edits and judgment calls stay with the main session or a worker; a
  scout's answer comes back unchecked, so it never decides.
- Each session gets a self-contained handoff, since it does not see this
  chat: objective, files in scope, constraints, verification, and what done
  looks like. Copy them from the brief; do not write "see above".
- Writers that touch the same files never run at the same time.
- Name where the pieces meet: which session merges or checks the combined
  result, and in what order.

Tool names: Claude Code — a new session (worktree for writers) or `/clear`
with a handoff note; other tools — a new chat or agent run started from the
handoff.

### When unsure

Pick opus at medium, keep the split the task shape suggests, and list the
field under Unsure. Never inflate effort "to be safe". Worked examples:
[CASES.md](CASES.md).

## Confirm before running

The user approves the setup, not just the brief. After the route line or
the brief is agreed:

1. Show the execution plan as a short table: model, effort, each helper,
   and each session with its job and files. Mark the Unsure fields.
2. Ask with the native question tool, one question, three options:
   **Run as planned**, **Change the setup**, **Change the brief** (for a
   route line: **Run as planned**, **Change the setup**).
3. On a change, revise, show the plan again, and ask again. Never run on a
   partial answer, silence, or an approval given for an earlier version.
4. Splits need their own yes: list every helper and session in the
   question, and start only the ones the user approved. Each handoff is
   shown before its session starts.
5. Mid-run, ask again before anything the approved plan did not name: an
   extra session or helper, a bigger model, Opus above medium, or files
   outside Scope.

For a "just do it" hotfix, show the route line and wait for a yes.

## Rules

- Never write code, edit files, or run mutating commands during refinement.
- Prefer extending existing owner-boundary coverage over new scaffolding;
  say so in Constraints when relevant.
- If the user answers "use your judgment", fill the gap explicitly in the
  brief and move on — don't re-ask that question. The run still waits for
  the confirmation step.
- Never inflate the plan "to be safe": bigger models and higher effort cost
  more on every request. Splits are recommended for the task's shape, not
  for safety.
- Upstream source: `github/awesome-copilot` `skills/boost-prompt/SKILL.md`
  (Joyride `joyride_request_human_input` + VSCode clipboard replaced with
  native question tool + chat output; repo grounding + verification added).
  Execution-plan rules adapted from `HeyCubit/effortless` (MIT) judge prompts
  and benchmarks, and from Anthropic's "Which Claude model should you build
  with?" (November 2026), with the house rules above.
