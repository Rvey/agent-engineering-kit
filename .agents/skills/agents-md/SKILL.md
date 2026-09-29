---
name: agents-md
description: "Generate or refresh a project-specific AGENTS.md from a user brief or from the repository itself — real commands, real paths, no template text. Use when setting up AGENTS.md for a repo, adapting the Agent Engineering Kit template, onboarding a project to the agent kit, or when an AGENTS.md still contains <placeholders> or generic template sections."
---

# AGENTS.md — Generate From the Project

An AGENTS.md that could describe any repository describes none. This skill
turns (a) a user brief or (b) an existing repo into the one file agents read
first: a routing table with real skill paths, verification gates that are real
commands, and rules this project actually earned.

**The failure this prevents:** an agent asked to "set up AGENTS.md" copies the
kit template verbatim, leaving `<placeholders>`, example stack names, and eight
performance rules from another codebase. That output is worse than no file —
it trains every future session to ignore the routing table.

## When to use

- User asks to create, adapt, refresh, fix, or "fill in" `AGENTS.md` /
  `CLAUDE.md`.
- A repo is being onboarded to the Agent Engineering Kit.
- `AGENTS.md` contains `<placeholders>` or kit-template prose left in a real
  project.
- User provides a brief ("here's what I built") together with a repo.

## When NOT to use

- The user is editing the kit's own template upstream — that is an edit in the
  kit repo, not a generation.
- `AGENTS.md` is already project-specific and correct — merge missing facts
  only; do not regenerate what is working.

## Invocation (what the user pastes)

Brief known:

```text
Generate this repo's AGENTS.md. Follow .agents/skills/agents-md/SKILL.md.

Brief: we built <what it is>. Stack: <stack>. Layout: <where things live>.
Commands: lint=<cmd>, typecheck=<cmd>, test=<cmd>, build=<cmd>.
Things agents keep getting wrong: <incidents, if any>.
Existing instruction files: <paths, if any>.
```

No brief available:

```text
Generate this repo's AGENTS.md. No brief — derive everything from the repo.
Follow .agents/skills/agents-md/SKILL.md.
```

## Workflow

1. **Detect mode.** Repo has real code → **evidence mode** (default). Empty or
   new repo, or a user brief only → **brief mode**. Both → evidence wins for
   every fact the repo can answer.
2. **Read before writing.** Evidence mode: existing `AGENTS.md`/`CLAUDE.md`/
   `.cursor/rules/`, `README`, manifests (`package.json`, `pyproject.toml`,
   `Makefile`, `justfile`, `Taskfile`, `Cargo.toml`, `*.csproj`, `go.mod`),
   CI workflows, and lint/format/type configs. Collect every candidate gate
   command with its source (`file:line`). If the existing `AGENTS.md` carries
   the marker `agent-engineering-kit:template`, treat the file as replaceable
   — but show the user what changes.
3. **Ask only what the repo cannot answer** (native question tool, max 4):
   product name + one-line purpose; which top-level dir owns which surface;
   which of the discovered commands is the real gate (repos often have stale
   scripts); incidents the user never wants repeated. If the user says "use
   your judgment", decide, and state the decision in the handoff.
4. **Draft from project facts only.** Keep the kit's section order (title +
   what the project is → Skills routing table → Hard rules → Verification →
   Where rules live → Review protocol), but write only sections this project
   has content for. Delete empty sections — never leave a section skeleton
   behind as an invitation. Route only to skills that exist under
   `.agents/skills/`; check the directory, do not assume.
5. **Run the anti-slop gate** (below) before writing.
6. **Write `AGENTS.md`** at the repo root. If one exists: merge — never clobber
   user-authored content; list what you removed and why.
7. **Report** the evidence map (each command → source file:line) and the open
   items in chat. Unknowns live in the handoff, not as placeholders in the
   file.

## Output skeleton

Delete any section you cannot fill with project facts. 40–120 lines is the
normal range; longer means padding.

```markdown
# AGENTS.md — <real project name>

<2–3 sentences: what this product is, the stack, where the code lives.>

## Skills
Skill lookup order: <repo rule; default: vendored .agents/skills/ wins>.
| Task | Load before starting |
|---|---|
| <real task> | `.agents/skills/<existing-skill>/SKILL.md` |

## Hard rules
1. <rule from an incident the user reported, or one a config enforces>

## Verification
- `<real command>` — <what it proves>
<Only gates that exist in this repo. Every suppression carries a reason.>

## Where rules live
- Root `AGENTS.md` — <scope>; per-app rules in `<real path>`; docs in `<real path>`.

## Review protocol
<Only the steps this repo can actually run.>
```

## Verification — anti-slop gate

Run all four before declaring the file done:

```bash
# 1. No unfilled facts. Allowed matches: notation inside path/code patterns
#    (`<name>`, `<source>`) and literal code examples (a shell `<`).
#    Failures: stand-ins like `<Project Name>`, `<lint command>`, `<path>`.
grep -nE '<[A-Za-z][^>]*>' AGENTS.md

# 2. No kit-template banner or hedge prose survived.
grep -nE 'agent-engineering-kit:template|This is a template|Adapt me' AGENTS.md

# 3. Every skill path in the routing table exists.
grep -oE '\.agents/skills/[a-z0-9-]+' AGENTS.md | sort -u | while read -r p; do
  [ -f "$p/SKILL.md" ] || echo "MISSING: $p"
done

# 4. Every gate command traces to real config (spot-check each one).
grep -nE '`[a-z].*`' AGENTS.md   # then confirm each command in package.json / Makefile / CI / pyproject
```

**Stranger test:** strip the project name from the file. If every remaining
sentence would still be true in the kit template repo, it is filler — delete
it. The file must be false for at least one other repository.

Also report: line count, and the evidence map (command → source).

## Rules

- **Never copy template text.** The template is a shape, not content. If a
  sentence came from the template, rewrite it as a project fact or cut it.
- **Never invent a command.** No command goes in the file unless it exists in
  a manifest, Makefile, CI step, or tool config. Unknown → ask; still unknown →
  leave it out and list it in the handoff.
- **Never carry over incident rules the user did not tell you about.** The
  kit's eight performance guards are another codebase's scars.
- **Placeholders mean "unknown — ask or omit", never "keep me".** A file that
  ships with `<lint command>` is not done.
- **One owner per rule.** Do not restate a rule that a config or script
  already enforces; point at the file that enforces it.
- **Merge, don't clobber.** Preserve existing user-authored instructions;
  show a diff summary for anything removed.
- **The generated file is the deliverable, not a proposal.** Write it in the
  same turn the gate passes.

## Anti-patterns

| Anti-pattern | What it looks like | The fix |
|---|---|---|
| Template transplant | Kit text with names swapped | Evidence mode + stranger test |
| Placeholder debt | `<Project Name>`, `<test command>` shipped | Gate 1; omit or ask |
| Phantom gates | `npm test` when no test script exists | Gate 4; trace every command |
| Skill ghost | Routing row to a skill not in the repo | Gate 3 |
| Rule inflation | Generic rules nobody enforces | Cut unless user-reported or config-enforced |
| Section padding | Nine headings with one line each | Delete empty sections |
