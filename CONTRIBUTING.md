# Maintaining the kit

Two `AGENTS.md` files, two jobs. `templates/AGENTS.template.md` is what gets
copied into other repositories: keep its `agent-engineering-kit:template`
marker and its placeholders. The root `AGENTS.md` is this repository's real
instructions — no placeholders, no another-project examples, gates that
actually run here. Contributor instructions therefore live in this file, not
in the root `AGENTS.md`.

## Gates before a PR

Run all four from the repository root:

```bash
bash scripts/lint.sh              # shell syntax, shellcheck, skill frontmatter, markdown links
bash tests/setup-smoke.sh         # install, reruns, hook conflicts, readiness, policy (slow)
bash scripts/setup-check.sh --kit # kit dogfood check: template intact, root AGENTS.md real
actionlint .github/workflows/kit.yml templates/github/workflows/*.yml
```

`.github/workflows/kit.yml` runs the same set on every push and pull request.
The smoke test builds a throwaway Git repository in the temp directory and
exercises the scripts the way an adopter would, including the copied
`.agents/` tools, so behaviour changes get caught before release.

## Changing install or policy behaviour

Add a case to `tests/setup-smoke.sh` that fails before your change and passes
after it. A behaviour change without a new smoke case will regress quietly:
the script is the only thing that exercises bootstrap and the hook installer
end to end.

When you add an option to a copied tool, teach both copies. `scripts/setup-check.sh`
ships to adopters as `.agents/setup-check.sh`, so anything it reads must exist
in the target: resolve starters through `.agents/verify-templates/` first and
fall back to the kit checkout only for local `--kit` runs.

Vendor nothing by hand. Fetching a skill, copying a reference, or changing an
upstream file means updating [CREDITS.md](CREDITS.md) with the source and
licence in the same change.

## Adding or editing a skill

1. `scripts/new-skill.sh <name>` scaffolds the frontmatter and workflow
   skeleton, or edit the existing `SKILL.md`.
2. The description must carry a `Use when` trigger — `scripts/lint.sh` fails
   without one. That clause is how an agent decides to load the skill at all.
3. Every `references/*.md` path named in the skill must exist on disk; the
   lint check verifies both directions.
4. Update the routing table in `templates/AGENTS.template.md`, the catalog in
   `.agents/skills/README.md`, and the skill table in `README.md`.

## Verifying templates you ship

`templates/verify/*.sh` are copied into adopter repositories, so they must be
syntax-clean and shellcheck-clean, and they must keep a `SETUP:` marker on
every line a human still has to edit. `.agents/setup-check.sh` treats a
remaining `SETUP:` marker as an incomplete setup, which is the point.
