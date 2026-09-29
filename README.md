# Agent Engineering Kit

**A copy-paste operating system for building software with AI coding agents: skills, instructions, verification gates, and hard-won rules that keep quality high as a codebase grows.**

Distilled from the day-to-day workflow of a production monorepo (Next.js + FastAPI) where agents do real shipping work. Everything here is stack-agnostic — the examples use that stack because that's where the rules were battle-tested. Swap in your own commands and keep the structure.

---

## Why this exists

Ad-hoc prompting produces ad-hoc codebases. The moment a second person (or a second agent session) touches a repo, you need:

- **Shared standards** the agent actually reads before it writes — not tribal knowledge
- **Repeatable workflows** for the tasks that keep going wrong (tests, perf, security, cleanup)
- **Verification gates** that are commands, not opinions — so "done" is provable
- **A review protocol** that catches AI slop before a human reviewer wastes time on it

This kit packages all four into files you drop into any new project.

## What's inside

| Path | What it is |
|---|---|
| `AGENTS.md` | The routing table for agents: skill selection, verification gates, hard rules, review protocol. **Adapt this first.** |
| `.agents/skills/` | 9 vendored skills (`SKILL.md` + references) covering prompt refinement, React/Next perf, FastAPI, Python perf, performance work, security, tests, lint config, and diff cleanup |
| `.cursor/rules/` | Glob-scoped rule templates for Cursor-compatible agents (web app + Python runtime) |
| `docs/` | The playbooks: agent workflow, skill catalog, verification gates, performance guards, adding skills, repo structure |
| `scripts/bootstrap.sh` | Installs the kit into any repository in one command |
| `scripts/new-skill.sh` | Scaffolds a correctly shaped new skill |
| `CREDITS.md` | Upstream sources and licenses for every vendored skill |

## Quickstart (5 minutes)

```bash
git clone https://github.com/Rvey/agent-engineering-kit.git ~/agent-engineering-kit

cd /path/to/your-project
~/agent-engineering-kit/scripts/bootstrap.sh .

# Optional: include the Cursor rule templates
~/agent-engineering-kit/scripts/bootstrap.sh . --with-cursor
```

Then, in order:

1. **Adapt `AGENTS.md`** — replace every `<placeholder>` and every example command with your stack's real commands. This is the single highest-value 15 minutes you will spend.
2. **Define your verification gates** — see [docs/03-verification-gates.md](docs/03-verification-gates.md). Wire the same commands into CI.
3. **Start a session with**: `Read AGENTS.md and follow it.` Then give the agent the task.
4. When the task is vague, the agent should load `boost-prompt` and produce a brief before writing code. When it isn't, it should load the owning skill and go.

## The loop

```
        vague task                              clear task
            │                                       │
            ▼                                       │
    ┌───────────────┐                               │
    │ boost-prompt  │  → structured brief →         │
    └───────────────┘                               ▼
                                            ┌─────────────────┐
              ┌────────────────────────────▶│  load ONE skill │
              │                             │  (owner of task)│
              │                             └────────┬────────┘
              │                                      ▼
              │                             ┌─────────────────┐
              │                             │    implement    │
              │                             └────────┬────────┘
              │                                      ▼
              │     ┌────────────┐   ┌───────────────────────┐
              │     │   deslop   │◀──│ feature complete      │
              │     └──────┬─────┘   └───────────┬───────────┘
              │            ▼                     ▼
              │     ┌────────────┐   ┌───────────────────────┐
              │     │ security   │   │ verification gates    │
              │     │ sign-off   │   │ lint/types/tests/build│
              │     └──────┬─────┘   └───────────┬───────────┘
              │            └──────────┬──────────┘
              │                       ▼
              │              ┌─────────────────┐
              └──────────────│  report + hand  │
                 follow-ups  │  off to review  │
                             └─────────────────┘
```

Full walkthrough: [docs/01-agent-workflow.md](docs/01-agent-workflow.md).

## The skills

| Skill | Load it when |
|---|---|
| `boost-prompt` | The request is vague or missing scope/deliverables/constraints |
| `react-next-performance` | Writing or reviewing React/Next client components, hooks, effects, streaming UI, canvas code |
| `fastapi-python` | Writing or reviewing FastAPI/Python API code |
| `python-performance-optimization` | Profiling or optimizing Python hot paths |
| `performance-optimization` | Any performance work, any layer — measure first |
| `security-and-hardening` | Input handling, auth, data storage, external APIs, uploads, LLM features, dependency audits |
| `test-audit` | Writing, changing, reviewing, or pruning tests |
| `eslint-prettier-config` | Setting up or changing lint/format configuration |
| `deslop` | After a feature lands, before review — strip AI slop from the diff |

Details and provenance: [docs/02-skill-catalog.md](docs/02-skill-catalog.md) and [`.agents/skills/README.md`](.agents/skills/README.md).

## The hard rules

The eight performance guards in [docs/04-performance-guards.md](docs/04-performance-guards.md) (and summarized in `AGENTS.md`) each came from a real production incident — dep-less effects firing on every drag frame, `setState` per stream token, unstable callbacks resetting pollers, and friends. They are the highest-leverage part of this kit: every one of them is a bug class that agents reintroduce by default unless the rule is in front of them.

## Adopting this in an existing repo

1. Run the bootstrap.
2. Adapt `AGENTS.md` — commands, paths, and the incidents your team never wants to repeat.
3. Prune the skills you don't need. A smaller skill set that agents actually load beats a big one they ignore.
4. Add a skill whenever a workflow has burned you twice: vendor it, adapt the commands, wire it into the routing table. See [docs/05-adding-a-skill.md](docs/05-adding-a-skill.md).

## Credits

Vendored skills come from public upstream catalogs (MIT / Apache-2.0) and are adapted with attribution. See [CREDITS.md](CREDITS.md).

## License

MIT — see [LICENSE](LICENSE). Vendored skills retain their upstream licenses (see [CREDITS.md](CREDITS.md)).
