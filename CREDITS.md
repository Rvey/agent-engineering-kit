# Credits & upstream sources

This kit is an extraction and adaptation of workflows used in production. The
vendored skills under `.agents/skills/` come from public upstream catalogs and
are adapted (mostly command/path references) for reuse across projects. Each
upstream project keeps its own license; when adapting a skill, keep its
attribution note in the `SKILL.md`.

## Vendored skills

| Skill | Upstream source | License | Notes |
|---|---|---|---|
| `boost-prompt` | [github/awesome-copilot](https://github.com/github/awesome-copilot) `skills/boost-prompt` | MIT | Adapted: Joyride/VSCode APIs replaced with native question tool + chat output; repo grounding and verification steps added |
| `deslop` | [openclaw/agent-skills](https://github.com/openclaw/agent-skills) | MIT | Adapted: internal review-gate and linter references generalized |
| `test-audit` | [openclaw/agent-skills](https://github.com/openclaw/agent-skills) | MIT | Adapted: source-repo scripts/commands generalized; campaign doc retained with real examples |
| `eslint-prettier-config` | [patricio0312rev/skills](https://github.com/patricio0312rev/skills) | MIT | Vendored |
| `fastapi-python` | [Mindrally/skills](https://github.com/Mindrally/skills) | Apache-2.0 | Vendored (changed: packaged as a skill with usage frontmatter) |
| `performance-optimization` | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | MIT | Vendored with its checklist |
| `security-and-hardening` | [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) | MIT | Vendored with shared checklist + hardening patterns |
| `python-performance-optimization` | [wshobson/agents](https://github.com/wshobson/agents) `plugins/python-development/skills` | MIT | Vendored with `references/` |
| `react-next-performance` | Authored in-house | MIT (this repo) | Written from real production incidents; React Flow section is canvas-specific but generalizes to any canvas library |

## Instruction layer

The `full-setup` skill is authored in this repository and covered by its MIT license.

The structure of `AGENTS.md` — skill lookup order, task→skill routing,
verification gates, hard rules, review protocol — and the eight performance
guards in `docs/04-performance-guards.md` are extracted from a production
monorepo's agent workflow and generalized for reuse.

## Tooling referenced

- [skills CLI](https://github.com/vercel-labs/skills) (`npx skills add …`) for installing upstream skill catalogs
- [addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) — the upstream catalog referenced by the routing rules

## License handling

- Original text in this repository: MIT (see [LICENSE](LICENSE)).
- Vendored skills: their upstream licenses (MIT / Apache-2.0) apply to the
  adapted portions; attribution is preserved in each `SKILL.md` where the
  upstream provided one.
