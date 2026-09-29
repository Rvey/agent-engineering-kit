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
| `AGENTS.md` | The routing table for agents: skill selection, verification gates, hard rules, review protocol. **Generate it from your repo first — don't copy the template.** |
| `.agents/skills/` | 11 vendored skills (`SKILL.md` + references) covering full setup, AGENTS.md generation, prompt refinement, React/Next perf, FastAPI, Python perf, performance work, security, tests, lint config, and diff cleanup |
| `.cursor/rules/` | Glob-scoped rule templates for Cursor-compatible agents (web app + Python runtime) |
| `templates/github/` | Loop-enforcement files copied by bootstrap: PR template, CI gate and policy workflows, check script, CODEOWNERS example |
| `docs/` | The playbooks: agent workflow, skill catalog, verification gates, performance guards, adding skills, repo structure, loop enforcement |
| `scripts/bootstrap.sh` | Installs the kit into any repository in one command |
| `scripts/install-hooks.sh` | Installs a pre-commit hook that runs the fast gates (`.agents/verify.sh --fast`) |
| `scripts/setup-check.sh` | Reports local setup status and names missing steps |
| `scripts/new-skill.sh` | Scaffolds a correctly shaped new skill |
| `CREDITS.md` | Upstream sources and licenses for every vendored skill |

## Quickstart

```bash
git clone https://github.com/Rvey/agent-engineering-kit.git ~/agent-engineering-kit

cd /path/to/your-project
~/agent-engineering-kit/scripts/bootstrap.sh .

# Optional: include the Cursor rule templates
~/agent-engineering-kit/scripts/bootstrap.sh . --with-cursor
```

Then ask your agent in the target repository:

```text
Complete this repository's Agent Engineering Kit setup. Follow
.agents/skills/full-setup/SKILL.md. Derive facts from the repo and ask me
only for information you cannot determine. Verify both local and remote setup.
```

Bootstrap also copies the hook installer and readiness check into `.agents/`,
so the target repository has the commands it needs after adoption. The agent
generates project-specific instructions and gates, configures CI
for the repository's toolchain, integrates the fast commit hook, and checks
review enforcement. Run `bash .agents/setup-check.sh .`
to check local readiness. It lists missing steps and exits nonzero until
local setup is ready. Remote branch protection needs separate verification.

If you prefer to set up each part yourself:

1. **Generate `AGENTS.md`** — open your agent in the project and run the
   generation prompt. Full instructions and copy-paste prompts:
   [Generate `AGENTS.md`](#generate-agentsmd).
2. **Define your verification gates** — see [docs/03-verification-gates.md](docs/03-verification-gates.md). The copied `gates.yml` runs `.agents/verify.sh`; add your repo's toolchain and dependency install, then require both gate and policy checks in branch protection.
3. **Turn on loop enforcement** — install the pre-commit hook
   (`~/agent-engineering-kit/scripts/install-hooks.sh .`), require the
   `policy / loop evidence` check in branch protection, and rename
   `.github/CODEOWNERS.example` to `.github/CODEOWNERS` with real owners.
   Why each layer exists: [docs/07-loop-enforcement.md](docs/07-loop-enforcement.md).
4. **Start a session with**: `Read AGENTS.md and follow it.` Then give the agent the task.
5. When the task is vague, the agent should load `boost-prompt` and produce a brief before writing code. When it isn't, it should load the owning skill and go.

## Generate `AGENTS.md`

`AGENTS.md` is the one file every agent session reads first. The kit ships a
template full of `<placeholders>` — **do not copy it**. Generate the
project-specific file instead: the `agents-md` skill traces every command to
real config, asks about what the repo cannot answer, and refuses to ship
placeholders or another codebase's rules.

### 1. Paste a prompt in your agent

**With a brief** — you already know what you built:

```text
Read AGENTS.md, then load .agents/skills/agents-md/SKILL.md and follow it.

Generate this repo's AGENTS.md from real evidence.

Brief: we built <what it is>. Stack: <stack>. Layout: <where things live>.
Commands: lint=<cmd>, typecheck=<cmd>, test=<cmd>, build=<cmd>.
Things agents keep getting wrong: <incidents, if any>.
Existing instruction files: <paths, if any>.
```

**Without a brief** — let the skill read the repo and ask what it needs:

```text
Read AGENTS.md, then load .agents/skills/agents-md/SKILL.md and follow it.
Generate this repo's AGENTS.md. No brief — derive everything from the repo.
Ask me only what the config can't answer.
```

Fill in what you know and delete the lines you don't — the skill asks for
anything missing instead of guessing. You can also paste the brief as free
text; the skill extracts the facts either way.

### 2. Answer its questions

At most 4, and only about things the repo cannot answer: product name and
purpose, which directory owns which surface, which discovered commands are the
real gates, and incidents you never want repeated. "Use your judgment" is a
valid answer — the skill decides and records the decision in its handoff.

### 3. Check the handoff — done means you saw

- the **evidence map**: every command in the file traced to a source
  (`package.json:7`, `.github/workflows/ci.yml:9`, `Makefile:12`, …);
- the **anti-slop gate output**: no placeholders, no template prose, every
  routing-table skill path exists on disk;
- the **line count** — 40–120 lines is normal; longer means padding;
- **open items**: facts the skill could not verify, left out of the file on
  purpose and listed for you.

Anything else ("I adapted the template") is a failed generation — reject it
and re-run the prompt.

### 4. Already have an `AGENTS.md`?

| Situation | What the skill does |
|---|---|
| Still the untouched template (has the `agent-engineering-kit:template` marker) | Replaces it wholesale, showing you what changed |
| You already edited it | Merges: keeps your content, adds missing facts, lists removals |
| No repo yet, brief only | Builds from the brief; unanswered facts stay out of the file until you confirm them |

Re-run the generation whenever the stack changes or an incident class appears.
Then wire the same gates into CI and start sessions with `Read AGENTS.md and
follow it.`

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
| `agents-md` | Setting up or refreshing a repo's `AGENTS.md`; template has placeholders; onboarding a project |
| `full-setup` | Completing kit adoption, including CI, hooks, and required review checks |
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
2. Generate `AGENTS.md` with the `agents-md` skill (see [Generate `AGENTS.md`](#generate-agentsmd)) — commands, paths, and the incidents your team never wants to repeat.
3. Turn on enforcement: `scripts/install-hooks.sh .`, require the `policy / loop evidence` check, set CODEOWNERS — see [docs/07-loop-enforcement.md](docs/07-loop-enforcement.md).
4. Prune the skills you don't need. A smaller skill set that agents actually load beats a big one they ignore.
5. Add a skill whenever a workflow has burned you twice: vendor it, adapt the commands, wire it into the routing table. See [docs/05-adding-a-skill.md](docs/05-adding-a-skill.md).

## Credits

Vendored skills come from public upstream catalogs (MIT / Apache-2.0) and are adapted with attribution. See [CREDITS.md](CREDITS.md).

## License

MIT — see [LICENSE](LICENSE). Vendored skills retain their upstream licenses (see [CREDITS.md](CREDITS.md)).
