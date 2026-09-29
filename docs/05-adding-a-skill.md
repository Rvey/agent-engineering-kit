# Adding a skill

Add a skill when a workflow has burned you **twice** — that second fire is
the signal that the knowledge needs to live outside someone's head. A skill
is cheaper than a wiki page because agents actually load it.

## Where skills live

| Location | Purpose |
|---|---|
| `.agents/skills/<name>/SKILL.md` | Vendored, committed, travels with the repo — the canonical home |
| `.agents/skills/<name>/references/` | Tier-2 detail loaded only when the SKILL.md tier is insufficient |
| Agent-specific dirs (`.claude/skills/`, …) | Optional symlinks/copies for tools that expect their own path |
| Upstream catalogs | Installed per machine via `npx skills add <source>` — not required by the repo |

## Add workflow

1. **Pick the source.** Prefer vendoring a battle-tested upstream skill
   ([addyosmani/agent-skills](https://github.com/addyosmani/agent-skills) is a
   good catalog) over writing from scratch. Browse with
   `npx skills add addyosmani/agent-skills --list`.
2. **Vendor it.** Copy `SKILL.md` into `.agents/skills/<name>/` using the
   skill's own name. Per-skill installs do **not** copy repo-level
   `references/` — copy any checklist the skill needs into its
   `references/` and fix relative links.
3. **Adapt the commands.** Replace upstream commands/paths with your repo's
   real gates. Keep the workflow intact; change the wiring.
4. **Check the frontmatter.** `name` + a `description` that starts with what
   it does and includes "Use when…" triggers. The description is the trigger
   an agent matches against — write it for that decision.
5. **Keep it minimal and verifiable.** Steps a human maintainer would accept,
   plus a verification gate. Delete anything you would not enforce.
6. **Wire it into `AGENTS.md`.** Add a row to the routing table with *when*
   to load it. A skill that is not in the table does not exist.
7. **Smoke-test it.** Give the agent a real task that should trigger it; if
   the agent doesn't load it, the description or the table is wrong — fix
   those, not the agent.
8. **Commit the skill and the table together.** One change, one review.

## Scaffold

```bash
scripts/new-skill.sh my-skill-name
# creates .agents/skills/my-skill-name/SKILL.md with frontmatter + skeleton
```

## Template

```markdown
---
name: my-skill-name
description: "What it does in one line. Use when <trigger 1>, <trigger 2>, or <trigger 3>."
---

# My Skill Name

One paragraph on the philosophy / why this workflow exists.

## When to use

- <concrete trigger>
- <concrete trigger>

## When NOT to use

- <case that belongs to another skill>

## Workflow

1. <step with a deliverable>
2. <step with a deliverable>

## Verification

- <command that proves the work is done>
```

## Rules

- **One skill per workflow.** If two skills both claim "tests", agents flip a
  coin. Merge or rename until ownership is unambiguous.
- **Specific beats generic.** "Batch SSE updates into one commit per chunk"
  beats "write performant code".
- **No frozen commands from another repo.** A command that doesn't exist in
  this repo erodes trust in the whole skill; adapt or delete it.
- **No secrets, no client names, no internal URLs** in a vendored skill.
- **References are the tier-2 escape hatch.** Keep the main file skimmable;
  move long tables and exhaustive checklists into `references/`.
- **Prune.** A skill nobody loads is dead weight. If a workflow stopped
  mattering, delete the skill and its routing row in one commit.

## Attribution

Keep the upstream source note in the `SKILL.md` (and add a row to
`CREDITS.md` when vendoring into a repo that tracks credits). MIT/Apache-2.0
skills can be vendored with attribution; state what you changed.
