# Maintaining the kit

This repository distributes the root `AGENTS.md` as a template. Keep its
`agent-engineering-kit:template` marker: an adopting agent replaces it with
instructions derived from the target project. Contributor instructions for
the kit live here so they cannot be confused with the distributed template.

The kit is shell tooling, documentation, and vendored skills. For changes to
installation or policy behavior, run `bash tests/setup-smoke.sh`, then check
shell syntax with `bash -n` on the changed scripts. The smoke test creates a
temporary Git repository and checks reruns, hook conflicts, readiness, and
policy failure cases using the setup tools copied into the target. CI runs
the same checks in `.github/workflows/kit.yml`.

If a change adds or edits a skill, update the routing table in `AGENTS.md`,
the skill catalog in `.agents/skills/README.md`, and the public README. Keep
the kit's workflow examples distinct from actual target-repository commands.
