---
name: test-audit
description: "Decides whether a change needs a test at all, then writes the fewest, smallest tests that prove it, each seen failing first. Use when writing, changing, or reviewing tests, fixing a bug, or adding behavior; for pruning an existing suite, read AUDIT.md."
---

# Test Audit

Every test costs reading time, run time, and upkeep for as long as it lives.
Write one only when it catches a regression nothing else catches, and prove it
by watching it fail. **"No new test" is a correct and common answer.**

Fail-first writing rules adapted from obra/superpowers
`test-driven-development` (MIT); the value and pruning rules from
openclaw/agent-skills (MIT).

## 1. Decide whether the change needs a test

| Change | New tests |
|---|---|
| Refactor, rename, move, formatting | None. Existing tests pass unchanged; one that must change was testing implementation |
| Docs, comments, copy, config values, dependency bumps | None |
| Bug fix | One regression test, where the bug lives |
| New or changed behavior that nothing tests today | One per behavior, not one per function |
| Public contract: API, CLI flag, config schema, migration, storage format, security check | One per contract rule |

Before adding a test, search the existing ones. When a test already exercises
the behavior, extend it (a row in its table, a case in its loop) instead of
writing another. If you cannot name, in one sentence, the regression a test
catches, do not write it.

## 2. Write it fail-first

1. Write one test. Its name states the behavior: `rejects an expired token`,
   not `test_validate_2`. A name that needs "and" holds two behaviors.
2. Run it against the current code. It must **fail, for the reason you
   expect**. If it passes, it tests something that already works: rewrite it
   or drop it. An error (import, typo) is not a failure; fix it and rerun.
3. Write the smallest code that makes it pass. Nothing extra.
4. Run the file's tests, then the repo's test gate. Clean up only while green.

A bug-fix test reproduces the bug and fails on the unfixed code. A regression
test never seen failing proves the mock, not the fix.

Code that already exists without a test: do not delete it to start over.
Write the test, break the code on purpose (revert the fix line), watch the
test fail, then restore the code.

## 3. Keep it small

- One behavior per test; every assertion is about that one outcome.
- About 30 lines per test, setup included. Longer means a shared fixture used
  by at least two tests, or a test doing too much.
- Real code over mocks. Mock only the network, clock, filesystem, randomness,
  or a paid service. Assert on what the code returns or does, never that a
  mock was called, unless the call is the behavior ("sends one email").
- No snapshots of large objects or whole pages; assert the fields that matter.
- No export, flag, or hook in production code that only a test uses. Test
  through the public entry point instead.
- Edge cases only for input the code will really see (empty list, missing
  field), not every permutation.

Do not write:

- tests with no assertion, or that compare a value with itself;
- tests that copy a production list, config, or export set and compare it;
- tests that grep source for a string or an import;
- expected values computed by the code under test;
- the same scenario again at another layer;
- tests that a behavior-preserving refactor would break.

## 4. Report it

The PR body's `## Tests` section (the `policy` job requires it when test files
change) gives:

- for each new or changed test: the regression it catches, and that you saw
  it fail;
- or `No new tests: <reason>` (refactor only, docs only, already covered by
  `<test name>`);
- when added test lines exceed twice the added production lines, a line
  `Ratio: <why this change needs that much test code>`.

## Pruning an existing suite

Read [AUDIT.md](AUDIT.md) for focused sweeps of low-value tests, and
[CAMPAIGN.md](CAMPAIGN.md) to prune one subsystem's whole suite in one PR.
