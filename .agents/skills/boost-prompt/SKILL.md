---
name: boost-prompt
description: "Intent-to-brief refinement before coding: when scope, deliverables, constraints, or success criteria are vague, interrogate scope, ground in repo, then emit a structured markdown brief. Never writes code."
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
5. **Emit the brief as markdown in chat, then ask for changes.** Repeat
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

## Open questions
- <only what still blocks execution>
```

## Rules

- Never write code, edit files, or run mutating commands during refinement.
- Prefer extending existing owner-boundary coverage over new scaffolding;
  say so in Constraints when relevant.
- If the user answers "use your judgment", fill the gap explicitly in the
  brief and proceed — don't re-ask.
- Upstream source: `github/awesome-copilot` `skills/boost-prompt/SKILL.md`
  (Joyride `joyride_request_human_input` + VSCode clipboard replaced with
  native question tool + chat output; repo grounding + verification added).
