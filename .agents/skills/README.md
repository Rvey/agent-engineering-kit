# Skills

Vendored agent skills. Each directory holds a `SKILL.md` (frontmatter +
workflow + verification) and, where needed, a `references/` folder with the
tier-2 detail that would bloat the main file.

These copies are committed on purpose: **they travel with the repo and always
win over re-fetching upstream.** Agents read the committed `SKILL.md`
directly when an installed skill is not available.

## Catalog

| Skill | Load when | Tier-2 |
|---|---|---|
| `agents-md` | Setting up / refreshing a repo's `AGENTS.md`; template placeholders remain; onboarding a project | — |
| `full-setup` | Completing kit adoption, CI, hooks, and review enforcement in a target repo | — |
| `boost-prompt` | Request is vague / missing scope, deliverables, constraints, or success criteria | — |
| `context-engineering` | Starting a session, switching tasks, or output quality drops; configuring rules/context | — |
| `frontend-ui-engineering` | Building or modifying user-facing UI (design system, layout, a11y, anti-slop) | `references/accessibility-checklist.md` |
| `documentation-and-adrs` | Recording architecture decisions, changing public APIs, shipping user-facing behavior | — |
| `deslop` | Feature complete, pre-review: strip AI slop from the branch diff (behavior-neutral) | — |
| `eslint-prettier-config` | Setting up or changing ESLint/Prettier (flat config, integration, scripts, hooks) | — |
| `fastapi-python` | Writing or reviewing FastAPI + async Python API code | — |
| `performance-optimization` | Any performance work, any layer — measure → identify → fix → verify → guard | `references/performance-checklist.md` |
| `python-performance-optimization` | Profiling and optimizing Python hot paths | `references/details.md`, `references/advanced-patterns.md` |
| `react-next-performance` | React/Next client components, hooks, effects, stream UIs, canvas code | — |
| `security-and-hardening` | Input handling, auth/authz, sensitive data, external integrations, LLM features | `references/hardening-patterns.md`, `references/security-checklist.md` |
| `test-audit` | Writing/changing/reviewing tests; pruning low-value tests | `CAMPAIGN.md` (whole-subsystem prunes) |

## Provenance & adaptation

Full attribution and licenses: [`../../CREDITS.md`](../../CREDITS.md).

| Skill | Source | Adaptation |
|---|---|---|
| `agents-md` | Authored in-house | Generator workflow: brief or repo evidence → project-specific AGENTS.md, with anti-template verification gates |
| `full-setup` | Authored in-house | Complete adoption workflow with local and remote readiness checks |
| `boost-prompt` | github/awesome-copilot (MIT) | Native question tool + chat output instead of Joyride/VSCode; repo grounding + brief template |
| `context-engineering` | addyosmani/agent-skills (MIT) | Vendored; `../../references/` links rewritten to local `references/` where needed |
| `frontend-ui-engineering` | addyosmani/agent-skills (MIT) | Vendored with `references/accessibility-checklist.md` |
| `documentation-and-adrs` | addyosmani/agent-skills (MIT) | Vendored |
| `deslop` | openclaw/agent-skills (MIT) | Internal review-gate and linter references generalized |
| `test-audit` | openclaw/agent-skills (MIT) | Source-repo scripts generalized; campaign doc kept with real examples |
| `eslint-prettier-config` | patricio0312rev/skills (MIT) | Vendored |
| `fastapi-python` | Mindrally/skills (Apache-2.0) | Packaged as a skill with usage frontmatter |
| `performance-optimization` | addyosmani/agent-skills (MIT) | Vendored with checklist |
| `security-and-hardening` | addyosmani/agent-skills (MIT) | Vendored with shared checklist + patterns |
| `python-performance-optimization` | wshobson/agents (MIT) | Vendored with references |
| `react-next-performance` | Authored in-house | Written from production incidents |

## Installing more skills from upstream

```bash
npx skills add addyosmani/agent-skills            # full catalog
npx skills add addyosmani/agent-skills --list     # browse first
npx skills add addyosmani/agent-skills --skill <name>
```

Relevant catalog entries beyond this set: `using-agent-skills` (how to map
work → skill), `test-driven-development`, `debugging-and-error-recovery`,
`code-review-and-quality`,
`git-workflow-and-versioning`.

## Vendoring rules

1. Copy `SKILL.md` into `.agents/skills/<name>/` using the skill's own name.
2. Per-skill installs do **not** bring repo-level `references/` — copy any
   shared checklist the skill needs into its `references/` and fix links.
3. Frontmatter is required: `name` + `description` including "Use when…".
4. Adapt commands to this repo's real gates; keep the workflow.
5. Delete anything you would not enforce. Specific, minimal, verifiable.
6. Wire new skills into the routing table in `AGENTS.md` in the same change.
7. Keep the upstream attribution note inside the `SKILL.md`.
