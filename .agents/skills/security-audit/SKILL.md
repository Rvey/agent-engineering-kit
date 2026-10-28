---
name: security-audit
description: Finds real, provable security bugs in source code and gives the smallest fix. Use when a change touches input, auth, sensitive data, external services, uploads, or LLM calls (security sign-off before merge), when asked whether code is safe, for a focused vulnerability review, or for a full security audit or pen test of a codebase. Run the complete six-phase workflow only for an explicit full audit, pen test, or requested report files.
---

# Security Audit

> Vendored from [cloudflare/security-audit-skill](https://github.com/cloudflare/security-audit-skill) `skills/security-audit` (MIT, commit `c1c8a8c`). The kit trimmed this file and moved full-audit setup to [FULL-AUDIT.md](FULL-AUDIT.md); phase rules, the report schema, and the validators are unchanged. See `CREDITS.md` for the full list of edits.

Find bugs where someone gets past a real security boundary, prove each one from source and a small local check, and give the owner the evidence, priority, and smallest fix. Read source first; run code only in a sandbox. A suspicion with no concrete victim, resource, or result is not a finding.

**Not for:** general code review, style, or performance work. Do not use it to invent hardening advice for code with no reachable boundary violation.

## Words used here

- **Boundary**: a check that should stop a less-trusted caller (anonymous user, other tenant, plugin, model output) from reaching something it should not.
- **Parent**: the agent coordinating the work. **`research` agent**: a sub-agent that reads source and reports facts. **`general` agent**: a sub-agent that investigates and may run bounded local checks. Use whatever delegation your platform offers.
- **Verdicts**: `confirmed` (proven, gets a severity), `needs_validation` (source points at a bug but one fact outside the repo decides it; no severity), `rejected` (disproved).
- **Fingerprint**: a stable ID for one root cause, reused across runs.

## Pick a mode

Loading this skill does not authorize a full audit or creating files.

- **Guidance mode** (default): a security question, a focused review, triage of one finding, or sign-off on a change. Use only the parts you need. Do not run all six phases, create an output directory, or write audit files. Focused sub-agents are fine; they report back to you.
- **Security sign-off on a change**: guidance mode over the diff. For each place the change accepts input, checks identity or permissions, stores or sends sensitive data, calls an outside service, or uses LLM output, name the less-trusted caller and the control that should stop it, then check that control against the matching class in [ATTACK-CLASSES.md](ATTACK-CLASSES.md) (plus a domain companion it points to, when one fits). Grep the staged diff for secrets. Report findings, or "no boundary violation found" with what you checked, in the PR's `## Security` section.
- **Full audit mode**: only when the user explicitly asks to audit or pen-test a codebase, asks for a full or end-to-end security review, or asks for report files. Read [FULL-AUDIT.md](FULL-AUDIT.md), then run all six phases.

If the request could mean either guidance or full audit, ask one question before creating files.

## Execution safety (every mode)

Reading source is always allowed. Run target code (builds, tests, processes, browsers, emulators, fuzzers, fixtures) only inside an OS-enforced sandbox with all of:

- no external network (an isolated loopback namespace only when the check needs local client/server traffic);
- an empty environment filled from an explicit allowlist with safe values, and scratch-local `HOME`, temp, and cache directories;
- a read-only target and toolchain; the target process writes only inside its assigned `scratch/` directory;
- explicit low CPU, memory, process, file-size, disk, and wall-clock limits.

The agent itself may copy source into its `scratch/` directory when a build must write beside source. Never expose other output directories, other agents' directories, the host home directory, credentials, sockets, or shared services to target code. Do not install dependencies or let builds fetch them. If any control cannot be enforced, do not run target code: record the missing control as a `needs_validation` blocker with a safe plan. In guidance mode, keep no target-produced files.

Use dummy users, fixtures, and secrets. Never probe deployed endpoints, external or shared services, production identities, other users' data, or live control planes. Never test availability against a live or shared process, publish anything, alter releases, spend paid API quota, or go past the smallest local effect that proves the bug. If the deciding fact is outside source and the sandbox, report it as `needs_validation`.

## Core principles

**Name the boundary and the result.** For every candidate state: the less-trusted caller, the input or action it controls, the control that should stop it, the boundary crossed, who or what is affected, and the concrete result. A missing best practice, guessed deployment behavior, generic parser crash, or harm only to yourself is not a finding.

**Prove it locally, minimally.** Source establishes the path. A sandboxed check settles behavior: a small harness, an existing test, a fixture, a dummy-tenant integration test, a locally rendered config, or a loopback client. Stop at the first wrong return value, unauthorized dummy record, sanitizer hit, or policy difference. Never build persistence, post-exploitation, or concealment material.

**Don't guess what the repo can't show.** Proxies, provider settings, browser headers, identity policy, broker ACLs, packaging, and topology are real controls. If one decides the outcome and is not in the repo, assume neither presence nor absence: use `needs_validation` with the exact missing fact and a safe check the owner can run.

**Severity only for proven bugs.** Only `confirmed` records get severity, and overall severity never exceeds the demonstrated impact.

- **critical**: an unauthenticated actor gains code execution, full data-store access, or takeover of arbitrary accounts.
- **high**: an actor fully defeats an explicit security control with real consequences: auth bypass, cross-tenant read or write, stored script execution affecting other users, authenticated code execution, or an unauthenticated remote stop of a shared service.
- **medium**: a real boundary violation with limited blast radius, uncommon preconditions, or a narrow set of affected resources.
- **low**: disclosure of non-secret internals, or an effect needing sustained effort for minimal gain.
- **informational**: a confirmed but minimal-impact observation, mostly useful as a step inside a larger finding.

High vs medium: does the result fully defeat an explicit control for an action with real consequences, or only weaken it? If you cannot state the concrete damage, it is lower than it feels.

**Smallest source fix.** Name the rule the code must enforce and the narrowest change that enforces it at the last trusted decision point, with a regression test. The audit describes fixes; it does not edit target source.

## Full audit workflow

Read [FULL-AUDIT.md](FULL-AUDIT.md) first (output directory, write isolation, prior runs, profiles, budget). Then run the six phases in order:

1. **Reconnaissance**: map source, trust boundaries, local build paths, companion files, prior evidence, and the coverage ledger. [RECONNAISSANCE.md](RECONNAISSANCE.md)
2. **Hunting waves**: assign isolated hunters from the ledger and collect structured candidates. [HUNTING.md](HUNTING.md), [ATTACK-CLASSES.md](ATTACK-CLASSES.md), and the selected domain companions.
3. **Candidate validation**: a fresh verifier tries to refute every candidate. [VALIDATION-AND-REPORTING.md](VALIDATION-AND-REPORTING.md)
4. **Structured output**: write `findings.json`, then run `node <skill-dir>/validate-findings.cjs` on it and `node <skill-dir>/validate-coverage-ledger.cjs` on the ledger. Both check against `report-schema.json`.
5. **Record verification**: fresh agents re-check every final record.
6. **Report**: write `REPORT.md`, `FINDINGS-DETAIL.md`, and `NEEDS-VALIDATION.md` from the final records, with no live-probe instructions.

End the run in exactly one of two states: all Phase 6 files written and both validators pass, or `run_status: "incomplete"` recorded with its exact reason and the gap stated in the report. Never stop mid-phase.

## Anti-patterns

1. Checklist deviations presented as vulnerabilities.
2. Defense-in-depth advice with no reachable boundary violation.
3. Live or shared-environment testing where bounded local evidence is insufficient.
4. Guessing provider, proxy, browser, identity, or deployment behavior not present in source.
5. Treating a caller's own intended authority, or harm only to itself, as a cross-boundary result.
6. Reporting a parser or runtime effect stronger than the observed effect.
7. Prose-only hunter results that cannot be deduplicated or verified.
8. Re-reporting carried same-source prior confirmed records, or using them as examples that anchor the hunt.
9. Assigning severity to `needs_validation` records.
10. Writing the report before independent verification, or letting prose and JSON disagree.
