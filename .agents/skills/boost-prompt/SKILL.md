---
name: boost-prompt
description: "Intent-to-brief refinement before coding: when scope, deliverables, constraints, or success criteria are vague, interrogate scope, ground in repo, then emit a structured markdown brief with an execution plan (model tier, reasoning effort, single vs multi-agent). Never writes code. Use when a request is underspecified, ambiguous, or arrives without scope or acceptance criteria."
---

# Boost Prompt — Intent to Coding Brief

Refine a vague user request into an executable coding brief before any
implementation. DO NOT WRITE ANY CODE during refinement.

## When to use

- Task scope, deliverables, constraints, repo area, or success criteria are
  vague, ambiguous, or missing.
- Request could span multiple areas (web app, runtime/backend, shared
  packages) and the target is unclear.
- User pastes a one-liner ("fix auth", "make it faster", "add WhatsApp")
  with no acceptance criteria.

## When NOT to use

- Request already names scope + deliverables + verification — proceed directly.
- Pure question / diagnosis with no build step — answer, don't brief.
- Emergency hotfix where the user explicitly says "skip questions, just do it".

## Workflow

1. **Detect ambiguity, stop before coding.** Do not edit, scaffold, or run
   repo-wide exploration loops yet. One cheap grounding pass only (`read` /
   `glob` / `grep` the likely owner area) to ask informed questions.
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
   emit + ask after every revision. No clipboard extension, no VSCode API —
   chat output is the delivery channel.

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
- Model: <fast | balanced | deep> — <reason, at most 8 words>
- Effort: <low | medium | high | xhigh> — <reason>
- Agents: <single | multi: what each agent does, with its model + effort> — <reason>
- Unsure: <fields the user should check, or "none">

## Open questions
- <only what still blocks execution>
```

## Execution plan

A recommendation for the session or subagents that will do the work. Pick the
cheapest setting that still does the job well.

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
- The user's own words win: "think hard", "be thorough" means at least high;
  "quick question" means low; a named model or effort is used as given.

### Model tier

| Tier | Claude | Use for |
|---|---|---|
| fast | haiku | Lookups, renames, small edits in one or two files, summaries — any small, well-defined job |
| balanced | sonnet | Default. Normal features and fixes, edits across a few files, explanations, writing |
| deep | opus | Hard debugging, unclear root cause, architecture, large refactors, careful reviews, security or data paths, hard-to-revert work |

Other tools: map tiers to their own small / default / largest model.

The tier is for the session or subagent that **starts** the work. Do not
recommend switching models mid-session: each model keeps its own prompt
cache, so the first request on the new model re-reads the whole chat at full
price and usually costs more than it saves. Switching pays only in a fresh
session or a subagent.

### Effort

| Effort | Use for |
|---|---|
| low | Quick answer or a trivial edit, no planning |
| medium | Normal work: a few tool calls or edits |
| high | Large multi-step job, many tool calls, costly mistakes, or a high-risk change |
| xhigh | Very hard: a long investigation. Rare |

Effort is relative to the model: a stronger model needs less for the same
job. On deep, pick one step lower than on balanced, except that costly
mistakes or a high-risk change take at least high on any tier.

### Single or multi-agent

Default **single**. Recommend **multi** only when at least one holds:

- two or more independent pieces that touch different files and do not need
  each other's results;
- a broad search or read where only the conclusion matters;
- a review that needs a fresh context (no anchoring on the author's reasoning).

For each subagent, name its job, tier, and effort. A subagent's answer comes
back unchecked, so its effort is **never below medium**. Read-only search
subagents can run on fast; writers that share files run one at a time.

### When unsure

Pick the smaller option (balanced, medium, single) and list the field under
Unsure. A wrong upgrade costs more than a missed one. Worked examples:
[CASES.md](CASES.md).

## Rules

- Never write code, edit files, or run mutating commands during refinement.
- Prefer extending existing owner-boundary coverage over new scaffolding;
  say so in Constraints when relevant.
- If the user answers "use your judgment", fill the gap explicitly in the
  brief and proceed — don't re-ask.
- Never inflate the execution plan "to be safe": higher tiers, effort, and
  extra agents cost more on every request.
- Upstream source: `github/awesome-copilot` `skills/boost-prompt/SKILL.md`
  (Joyride `joyride_request_human_input` + VSCode clipboard replaced with
  native question tool + chat output; repo grounding + verification added).
  Execution-plan rules adapted from `HeyCubit/effortless` (MIT) judge prompts
  and benchmarks.
