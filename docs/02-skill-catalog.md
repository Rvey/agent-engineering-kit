# Skill catalog

A skill is a `SKILL.md` file with YAML frontmatter (`name`, `description` with
a "Use when…") plus a workflow and verification gates. Agents load the one
skill that owns the task instead of guessing a process. The catalog below is
what ships in this kit; the routing table in `AGENTS.md` is what makes agents
actually find them.

## What ships

| Skill | Owns | Tier-2 references |
|---|---|---|
| `boost-prompt` | Turning vague requests into a structured brief before any code is written | — |
| `deslop` | Diff-scoped cleanup of AI slop after a feature lands, before review | — |
| `react-next-performance` | React 19 / Next.js client work: effects, memo discipline, streaming UI, canvas code | — |
| `fastapi-python` | FastAPI + async Python API conventions | — |
| `python-performance-optimization` | Profiling-first Python optimization | `references/details.md`, `references/advanced-patterns.md` |
| `performance-optimization` | Measure → identify → fix → verify → guard, any layer | `references/performance-checklist.md` |
| `security-and-hardening` | Threat-model-first hardening: OWASP Top 10 + LLM Top 10, secrets, supply chain, privacy | `references/hardening-patterns.md`, `references/security-checklist.md` |
| `test-audit` | Test authoring gate + pruning audits | `CAMPAIGN.md` (subsystem-wide prunes) |
| `eslint-prettier-config` | ESLint flat config + Prettier integration | — |

## How loading works

1. The agent reads the routing table in `AGENTS.md` and picks the **one**
   skill that owns the task.
2. It reads that `SKILL.md` in full.
3. Only when the SKILL.md tier is insufficient does it open specific
   `references/` sections (not whole files, not unrelated skills).
4. Skill-governed work never starts without the skill loaded. If a needed
   skill is missing, the agent asks before improvising.

## Installed vs vendored

- **Vendored** — committed under `.agents/skills/`, travels with the repo.
  These always win: read the committed copy, never re-fetch upstream.
- **Installed** — pulled from a public catalog into the agent environment
  (`npx skills add addyosmani/agent-skills`). Use for skills that are useful
  but not required by the repo's rules.

When a skill proves essential to a repo, vendor it (copy `SKILL.md` + the
`references/` it needs) and wire it into `AGENTS.md`. See
[05-adding-a-skill.md](05-adding-a-skill.md).

## Frontmatter shape

```yaml
---
name: skill-name
description: "One or two sentences. Use when <trigger conditions>."
---
```

The description is the trigger. Write it for the agent that has to decide
whether to load the skill — name the task, not the topic.
