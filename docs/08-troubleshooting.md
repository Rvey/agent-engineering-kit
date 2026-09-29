# Troubleshooting

Symptoms you will hit during adoption, what they mean, and the command that
fixes them. Run `bash .agents/setup-check.sh .` first — it names the missing
step and prints its own fix.

## `bootstrap.sh` says `skip AGENTS.md (exists)`

Working as intended. Bootstrap never overwrites an instruction file that is
already there, because yours may contain real project rules. The copied
`AGENTS.md` was the template, so the next step is generating the real one:

```text
Read AGENTS.md, then load .agents/skills/agents-md/SKILL.md and follow it.
Generate this repo's AGENTS.md from real evidence.
```

Re-run bootstrap only for the other files; it fills in what is missing. Use
`--force` only after diffing, and never on a file you have edited.

## `install-hooks.sh` refuses to install

Three refusals, all deliberate:

- `core.hooksPath is already '<path>'` — another hook manager (husky, lefthook,
  pre-commit) owns your hooks. Add `bash .agents/verify.sh --fast` to that
  hook instead of replacing the manager.
- `a Git pre-commit hook already exists at '<path>'` — you have a hook at the
  default location. Add the fast-gate line to it; do not delete it.
- `existing pre-commit hook differs` — `.githooks/pre-commit` exists and is not
  ours. Merge the line by hand.

To undo the kit's hook later: `git config --unset core.hooksPath`.

## `setup-check.sh` stays INCOMPLETE

Each `TODO` line prints its fix. Two shortcuts:

```bash
bash .agents/setup-check.sh . --fix    # scaffolds verify.sh, installs the hook
bash .agents/setup-check.sh . --strict # also requires a clean tree and a remote
```

A `.agents/verify.sh` that still contains `SETUP:` counts as missing, on
purpose: replace every `SETUP:` line with a command your repo actually runs.
Copy a starter from `.agents/verify-templates/` (`shell.sh`, `node.sh`,
`python.sh`) when you have none.

## The `policy` job fails on a pull request

`verify.sh is missing or invalid` — the policy job requires an executable
`.agents/verify.sh` that passes `bash -n`. Commit it. The check fails closed
on purpose so a missing gate can never read as a pass.

`diff checks did not run` — the job could not compute the pull request diff,
usually because `BASE_SHA`/`HEAD_SHA` were not passed or the branch was
force-pushed mid-run. Re-run the job; if it repeats, check the workflow's env
wiring.

`Gates` or `Deslop` section missing — the pull request body needs those
headings. Copy `.github/pull_request_template.md` and fill it in; the check
reads the body text, so an empty template is not enough.

## The `gates` job fails in CI but passes locally

Almost always a missing toolchain step. The copied `gates.yml` runs
`bash .agents/verify.sh`, and `.agents/verify.sh` is also responsible for
installing dependencies from the lockfile. If it works on your machine, it is
using tools you installed by hand. Add the setup to `gates.yml`, or better,
put the locked install inside `.agents/verify.sh` so CI and the hook run the
same steps.

## `npx skills add ...` fails

The catalog install is a convenience, not a dependency. Vendored skills under
`.agents/skills/` always work offline: when a lookup fails, read the local
`SKILL.md` directly. With no network, skip the install and use what is
committed. If a task genuinely needs an unvendored skill, ask the user whether
to install it later or vendor it now.

## Windows

The kit is bash and is tested on macOS, Linux, and GitHub Actions
(`ubuntu-latest`). On Windows, run it under WSL2; Git Bash is untested:

```bash
wsl --install
```

Work inside the WSL filesystem (`~/`) rather than `/mnt/c/...` to avoid
line-ending and permission surprises. There is no native PowerShell port yet.

## The agent ignored `AGENTS.md`

Two usual causes: the session never read it, or the file still holds template
placeholders, so the agent treated it as shape rather than rules. Start
sessions with `Read AGENTS.md and follow it.` Then confirm the file is real:

```bash
bash .agents/setup-check.sh .   # first line should say: Project-specific AGENTS.md
```

## Where to look next

- [docs/01-agent-workflow.md](01-agent-workflow.md) — the loop and who owns each step
- [docs/03-verification-gates.md](03-verification-gates.md) — choosing gate commands
- [docs/07-loop-enforcement.md](07-loop-enforcement.md) — making the loop unskippable
