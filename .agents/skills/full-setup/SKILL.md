---
name: full-setup
description: "Complete Agent Engineering Kit adoption in an existing repository. Use when asked to set up the kit end to end, make a repository agent ready, or finish onboarding after bootstrap."
---

# Complete repository setup

The deliverable is a working local verification loop and, on GitHub, CI and
required checks. A copied template or green policy check alone is incomplete.

## Workflow

1. **Inspect the target.** Read its existing `AGENTS.md`, repo instructions,
   manifests, lockfiles, CI, hooks, and Git remote. Record real lint, type,
   test, and build commands. Read-only inspection comes before installation.
2. **Install safely.** If needed, run the kit's `scripts/bootstrap.sh` against
   the repository. Existing files are preserved; a rerun fills missing skill
   files. Do not use `--force` on authored instructions, workflow files, or
   custom skills without comparing them first. If a file conflicts, merge it.
3. **Generate instructions and gates.** Follow
   `.agents/skills/agents-md/SKILL.md` to write project-specific `AGENTS.md`
   and executable `.agents/verify.sh`. Ask the user only for facts the repo
   cannot answer. Never invent commands or retain template placeholders. If a
   gate class has no real command yet, report that gap explicitly.
4. **Wire CI.** The copied `.github/workflows/gates.yml` runs the full
   verification script. Add only the toolchain setup the repo actually needs,
   including a reproducible dependency install from its lockfile. Keep policy
   and gates separate, and run both in CI. On a non-GitHub host, use its
   equivalent pipeline instead.
5. **Install the local fast gate.** Run `.agents/install-hooks.sh`
   after `.agents/verify.sh` works. If another hook manager or hook already
   exists, integrate `bash .agents/verify.sh --fast` there instead of
   replacing it.
6. **Configure review ownership.** For GitHub, copy
   `.github/CODEOWNERS.example` to `.github/CODEOWNERS` with real handles.
   Derive those from existing CODEOWNERS or repository teams when possible;
   ask if ownership is unknown. Remove irrelevant example paths.
7. **Verify locally.** Run the full verification script, the fast hook gate,
   and `.agents/setup-check.sh .`. Fix failures before
   declaring local setup ready. Review the generated instructions for
   commands that have no config source.
8. **Verify remote enforcement.** With the user's repository access, require
   `gates / verification gates` and `policy / loop evidence` in branch
   protection, plus pull requests and code owner review where configured.
   Read settings back through the host API or UI; a workflow file alone does
   not make a check required. If access is missing, report the exact setting,
   repository, and reason it remains open. Never claim remote readiness from
   local checks alone.

## Handoff

Report the evidence map for gate commands, the actual local check output,
whether both CI jobs ran, remote settings verified, and any remaining work.
Use `LOCAL READY` and `REMOTE READY` only when each has been observed.
