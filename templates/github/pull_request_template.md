<!--
The `policy` workflow reads this PR body and fails the PR when:
- `## Gates`, `## Deslop`, `## Risk` or `## How to revert` is missing or has
  no real content;
- `## Risk` is not `high` while the diff touches a high-risk path, or a
  high-risk change lacks two human approvals on its latest commit;
- `## Security` is missing while the diff touches auth, payments, secrets,
  uploads, webhooks, or .env files;
- `## Tests` is missing while the diff touches test files, or added test lines
  exceed twice the added production lines without a `Ratio:` line.

Paste real output. "Looks good" is not evidence. Replace each guidance comment
with facts, then delete the comments.
-->

<!-- One or two sentences. What changed and why. Link the issue if there is one. -->

## What changed

## Risk

<!--
Start with low, medium or high, then say why in one line. Risk follows what
the change touches, not who wrote it.
- low: docs, copy, internal-only features, additive changes behind a flag
- medium: ordinary product changes
- high: auth, payments, billing, secrets, uploads, webhooks, CI and release
  workflows, installers. Needs two human approvals on the latest commit.
-->

## How to revert

<!--
The one step that undoes this change: revert the merge commit, turn off
flag X, or roll back deploy Y. Name anything a revert does not undo, such as
data migrations, sent messages or published packages.
-->

## Gates

<!-- Paste the actual output of lint / typecheck / test / build, one block per command. -->

```text
$ npm run lint
...
```

## Deslop

<!--
Diff-scoped cleanup (the deslop skill): what narration, dead code, defensive
checks, or one-use helpers were removed? "n/a — docs only, no code diff" is a
valid answer, but say why.
-->

## Security

<!--
Required only when the diff touches auth, payments, secrets, uploads,
webhooks, or .env files. Otherwise write: n/a — no sensitive surface touched.
-->

## Tests

<!--
Required when test files change (the test-audit skill). For each new or
changed test: the regression it catches, and that you saw it fail before the
fix. Or: "No new tests: refactor only" / "already covered by <test name>".
When added test lines exceed twice the added production lines, add a line:
Ratio: <why this change needs that much test code>
-->
