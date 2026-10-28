# Agent Engineering Kit

**Skills, instructions, and verification gates that keep AI coding agents shipping clean code, in any repository and any stack.**

[![kit](https://github.com/Rvey/agent-engineering-kit/actions/workflows/kit.yml/badge.svg)](https://github.com/Rvey/agent-engineering-kit/actions/workflows/kit.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

[Quickstart](#quickstart) · [Generate AGENTS.md](#generate-agentsmd) · [Usage](#usage) · [Updating](#updating-an-existing-install) · [How it works](#how-it-works) · [Skills](#skills) · [Why](#why-this-exists) · [Contributing](#contributing) · [What's inside](#whats-inside)

One command adds an `AGENTS.md`, a set of task skills, and CI gates to your repository. Agents read your rules before they write, load the skill that owns the task, and can't call the work done until lint, types, tests, and build pass.

## Quickstart

Run this from your project's root:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Rvey/agent-engineering-kit/main/scripts/install.sh)
```

Pick **install** and answer a few questions. Then ask your agent to finish the setup:

```text
Complete this repository's Agent Engineering Kit setup. Follow
.agents/skills/full-setup/SKILL.md. Derive facts from the repo and ask me
only for information you cannot determine. Verify both local and remote setup.
```

Check the result:

```bash
bash .agents/setup-check.sh .
```

It lists each missing step with its fix and exits non-zero until local setup is ready. From then on, start every agent session with `Read AGENTS.md and follow it.`

**Requirements:** bash 3.2 or newer, `curl`, `tar`, and `git`, on macOS or Linux. [`gum`](https://github.com/charmbracelet/gum) or [`fzf`](https://github.com/junegunn/fzf) give nicer pickers in the menu but aren't needed.

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

## Usage

### The menu

Run with no arguments to open the menu:

- **install**: guided setup. Pick a preset, the skills, and whether to add the `AGENTS.md` template, the `.github/` files, and the Cursor rules.
- **update**: bring an existing install up to date. See [Updating an existing install](#updating-an-existing-install).
- **list**: print the skills the kit ships.

It suggests **update** when the folder already has an install.

### Options

Pass options to skip the menu. Any argument turns it off, so scripts and CI never wait on a prompt.

| Command | What it installs |
|---|---|
| `bootstrap.sh .` | Everything: `AGENTS.md` template, `CLAUDE.md` and `REVIEW.md` starters, every skill, setup tools, `.github/` |
| `bootstrap.sh --preset minimal .` | `AGENTS.md` template, `agents-md` + `full-setup`, setup tools (no `.github/`) |
| `bootstrap.sh --preset standard .` | minimal + `boost-prompt`, `context-engineering`, `deslop`, `documentation-and-adrs`, `security-audit`, `test-audit`, and `.github/` |
| `bootstrap.sh --skills deslop,test-audit .` | Everything, but only those skills (`--list-skills` prints every name; add `--skills-only` to copy just the skills) |
| `bootstrap.sh --interactive .` | The guided install, without the first menu |

Add `--dry-run` to any of them to print every copy and skip without writing anything, `--with-cursor` for the Cursor rule templates, or `--no-github` for non-GitHub hosts. `bootstrap.sh --help` lists every option. The same options work after the one-liner, for example `bash <(curl -fsSL …/install.sh) --preset standard .`

### Run from a local clone

The one-liner downloads the kit into a temporary folder, runs `scripts/bootstrap.sh` from there, and deletes the download. To keep a copy instead:

```bash
git clone https://github.com/Rvey/agent-engineering-kit.git ~/agent-engineering-kit
cd /path/to/your-project
~/agent-engineering-kit/scripts/bootstrap.sh
```

### Pin a version

The one-liner installs from `main` by default. Set `AGENT_KIT_REF` to a tag or commit to pin it, and `AGENT_KIT_SHA256` to stop on a download that doesn't match:

```bash
AGENT_KIT_REF=<tag or commit> bash <(curl -fsSL https://raw.githubusercontent.com/Rvey/agent-engineering-kit/main/scripts/install.sh)
```

To read the script before running it: `curl -fsSL <url> | less`.

### Updating an existing install

From the project root, pick **update** in the menu, or go straight there:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Rvey/agent-engineering-kit/main/scripts/install.sh) --update .
```

From a local clone, run `git -C ~/agent-engineering-kit pull`, then `~/agent-engineering-kit/scripts/bootstrap.sh --update .`.

It compares your install with the kit and labels what it finds:

| Label | What it means | What `--update` does about it |
|---|---|---|
| `update <skill>` | An installed skill whose files differ from the kit's | Overwrites the files that differ; your extra files stay |
| `new <skill>` | A kit skill you don't have | Copies it in |
| `retired <skill>` | A skill the kit removed, shown with its replacement | Deletes the old folder, but only if every file in it is unedited kit content |
| `update .agents/skills/README.md` | An older kit copy of the skills README that you never edited | Replaces it with the current copy |
| `keep` | Something you edited or linked locally | Leaves it alone for you to fix by hand |

Then it asks what to do: update the installed skills, add all new ones, both, or go skill by skill. Deleting a retired skill and replacing the README each ask for their own yes. Without a terminal, decide up front: `--update --yes` does everything in the table, and `--update --skills deslop,bruh` handles just those skills (it only reports retired skills and the README). Add `--dry-run` to see the plan first.

`--update` touches only `.agents/skills/` and never edits `AGENTS.md`. Two follow-ups are yours:

- For each skill it added, copy its routing row from the kit's `templates/AGENTS.template.md` into your `AGENTS.md` (or ask your agent to).
- For a retired skill, it prints every `file:line` in `AGENTS.md` (and in a skills README it kept) that still names it. Point those lines at the replacement.

Then run `bash .agents/setup-check.sh .`. It fails while `AGENTS.md` points at a skill that isn't installed.

The older flag route still works: `bootstrap.sh . --skills-only` copies missing skill files, and adding `--force` also overwrites kit skill files that differ. It never deletes anything, never touches `AGENTS.md`, and leaves retired skills in place.

### After installing

Bootstrap copies the hook installer and the readiness check into `.agents/`, so your repository has the commands it needs. The `full-setup` prompt in the [Quickstart](#quickstart) has your agent generate project-specific instructions and gates, configure CI for your toolchain, install the fast commit hook, and check review enforcement. Remote branch protection needs a separate check.

Two shortcuts cover most missing steps: `bash .agents/setup-check.sh . --fix` creates a starter `.agents/verify.sh` and installs the fast pre-commit hook, and `.agents/verify-templates/` holds starters for shell, Node, and Python. Replace every `SETUP:` line with a real command; the readiness check keeps failing until you do.

To set it up by hand instead:

1. **Generate `AGENTS.md`.** Run the generation prompt in your agent; see [Generate `AGENTS.md`](#generate-agentsmd).
2. **Define your verification gates.** The copied `.github/workflows/gates.yml` runs `.agents/verify.sh`. Add your toolchain and dependency install, then require the gate and policy checks in branch protection. See [docs/03-verification-gates.md](docs/03-verification-gates.md).
3. **Write `REVIEW.md`.** Fill in the starter: what counts as a failure in this repo, the rules and owner for each area, and the paths reviewers skip. Every reviewer, human or AI, reads it. `CLAUDE.md` is a one-line import of `AGENTS.md`; leave it as is.
4. **Turn on loop enforcement.** Run `bash .agents/install-hooks.sh .`, rename `.github/CODEOWNERS.example` to `.github/CODEOWNERS` with real owners, and protect `main`: required checks, resolved conversations, dismissed stale approvals. Each setting and why it exists: [docs/07-loop-enforcement.md](docs/07-loop-enforcement.md).
5. **Start every session with** `Read AGENTS.md and follow it.`, then give the agent the task.

Every PR body then states its **risk** (low, medium or high) and **how to revert** it. Risk follows what the change touches, not who wrote it: the policy check forces `high` for auth, payments, secrets, CI, release and install paths, and a high-risk PR needs two human approvals on its latest commit. After the merge, [docs/09-shipping-and-rollback.md](docs/09-shipping-and-rollback.md) covers merge queues, feature flags, staged rollout, one-step reverts and turning incidents into the reviewer's test set.

Keep the skill set small: prune the skills you don't use, because agents load a short list and ignore a long one. Add a skill when the same workflow has gone wrong twice: vendor it, adapt its commands, and add it to the routing table ([docs/05-adding-a-skill.md](docs/05-adding-a-skill.md)).

## How it works

Every task follows the same loop. A vague request becomes a brief first; then the agent loads the one skill that owns the task, implements it, cleans up the diff, and proves it with the gates before handing off.

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

## Skills

| Skill | Load it when |
|---|---|
| `agents-md` | Setting up or refreshing a repo's `AGENTS.md`; template has placeholders; onboarding a project |
| `full-setup` | Completing kit adoption, including CI, hooks, and required review checks |
| `boost-prompt` | The request is vague or missing scope/deliverables/constraints |
| `context-engineering` | Starting a session, switching tasks, or output quality drops |
| `frontend-ui-engineering` | Building or modifying user-facing UI (design system, layout, a11y, anti-slop) |
| `documentation-and-adrs` | Recording a decision, changing a public API, shipping user-facing behavior |
| `react-next-performance` | Writing or reviewing React/Next client components, hooks, effects, streaming UI, canvas code |
| `fastapi-python` | Writing or reviewing FastAPI/Python API code |
| `python-performance-optimization` | Profiling or optimizing Python hot paths |
| `performance-optimization` | Any performance work, any layer — measure first |
| `security-audit` | Security sign-off on changes touching input, auth, data, external APIs, uploads, or LLMs; vulnerability review, audit, or pen test |
| `test-audit` | Writing, changing, reviewing, or pruning tests |
| `eslint-prettier-config` | Setting up or changing lint/format configuration |
| `deslop` | After a feature lands, before review — strip AI slop from the diff |
| `bruh` | A wall of LLM output, a spec, a log, or jargon needs a short, ADHD-friendly explanation that still teaches |

Details and provenance: [docs/02-skill-catalog.md](docs/02-skill-catalog.md) and [`.agents/skills/README.md`](.agents/skills/README.md).

## Hard rules

The eight performance guards in [docs/04-performance-guards.md](docs/04-performance-guards.md) (and summarized in `AGENTS.md`) each came from a real production incident — dep-less effects firing on every drag frame, `setState` per stream token, unstable callbacks resetting pollers, and friends. They are the highest-leverage part of this kit: every one of them is a bug class that agents reintroduce by default unless the rule is in front of them.

## Why this exists

AI agents write code fast, and they repeat the same mistakes just as fast. They skip tests, invent commands, miss conventions nobody wrote down, and call work done without running it. Better prompts don't fix that. Written structure that every session reads does:

- **Rules the agent reads first.** One `AGENTS.md` with your real commands and the incidents you never want repeated, instead of knowledge that lives in people's heads.
- **A playbook for each task.** Skills for the work that keeps going wrong: tests, performance, security, cleanup.
- **Proof instead of opinion.** Gates are commands. Work is done when lint, types, tests, and build pass, and the PR shows the output.
- **Review that starts clean.** A cleanup pass and a PR policy check catch AI slop before a reviewer spends time on it.

The kit grew out of a production Next.js + FastAPI monorepo where agents ship real work. The rules are stack-agnostic; the examples use that stack because that's where they were tested.

## Contributing

Changes to the kit go through the same loop it asks of everyone else, and [REVIEW.md](REVIEW.md) says what reviewers check here. Before you open a PR, run:

```bash
bash scripts/lint.sh              # syntax, shellcheck, skill frontmatter, links
bash tests/setup-smoke.sh         # install, update, hooks, readiness, policy (slow)
bash scripts/setup-check.sh --kit # kit self-check
actionlint .github/workflows/kit.yml
```

CI runs the same checks on every push ([`.github/workflows/kit.yml`](.github/workflows/kit.yml)).

Two data files keep `--update` safe for adopters:

- When you change `.agents/skills/README.md`, add the new version's hash to `scripts/shipped-files.txt`. The smoke test fails until you do.
- When you retire a skill, add one line for each file it ever shipped to `scripts/retired-skills.txt`, so `--update` can recognise unedited copies and remove them.

Contributor steps and review rules: [CONTRIBUTING.md](CONTRIBUTING.md).

## What's inside

| Path | What it is |
|---|---|
| `templates/AGENTS.template.md` | The starting shape for another repo's `AGENTS.md`: routing table, gates, hard rules, review protocol. **Generate the real file from your repo — don't keep the placeholders.** |
| `AGENTS.md`, `REVIEW.md` | This kit repo's own instructions and review rules, generated from its real layout and gates. Not the templates — see the rows above and below. |
| `.agents/skills/` | 15 vendored skills (`SKILL.md` + references) covering full setup, AGENTS.md generation, prompt refinement, context setup, UI engineering, ADRs/docs, React/Next perf, FastAPI, Python perf, performance work, security review and audits, tests, lint config, diff cleanup, and ADHD-friendly explanations |
| `.cursor/rules/` | Glob-scoped rule templates for Cursor-compatible agents (web app + Python runtime) |
| `templates/github/` | Loop-enforcement files copied by bootstrap: PR template (risk, revert, gates, deslop, security, tests), CI gate and policy workflows, check script, CODEOWNERS example |
| `templates/REVIEW.template.md`, `templates/CLAUDE.md` | Starters copied only when missing and never overwritten: what reviewers check, and a `CLAUDE.md` that imports `AGENTS.md` |
| `docs/` | The playbooks: agent workflow, skill catalog, verification gates, performance guards, adding skills, repo structure, loop enforcement, troubleshooting, shipping and rollback |
| `scripts/bootstrap.sh` | Installs and updates the kit in any repository: guided menu, presets, or flags |
| `scripts/install.sh` | Runs `bootstrap.sh` straight from GitHub, no clone needed |
| `scripts/install-hooks.sh` | Installs a pre-commit hook that runs the fast gates (`.agents/verify.sh --fast`) |
| `scripts/setup-check.sh` | Reports local setup status and names missing steps, including `AGENTS.md` rows that point at skills that aren't installed |
| `scripts/new-skill.sh` | Scaffolds a correctly shaped new skill |
| `scripts/lint.sh` | Fast static checks: shell syntax, shellcheck, skill frontmatter, markdown links |
| `scripts/retired-skills.txt`, `scripts/shipped-files.txt` | Kit-only data for `--update`: hashes of every file the kit shipped for retired skills and for the skills README, so it only deletes or replaces files you never edited |
| `templates/verify/` | Ready-to-edit `verify.sh` starters for shell, Node, and Python repos |
| `tests/setup-smoke.sh` | Disposable-repo regression test for install, update, remote install, hooks, readiness, and policy |
| `CREDITS.md` | Upstream sources and licenses for every vendored skill |

## Credits

Vendored skills come from public upstream catalogs (MIT / Apache-2.0) and are adapted with attribution. See [CREDITS.md](CREDITS.md).

## License

MIT — see [LICENSE](LICENSE). Vendored skills retain their upstream licenses (see [CREDITS.md](CREDITS.md)).
