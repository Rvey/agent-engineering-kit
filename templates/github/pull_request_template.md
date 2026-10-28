<!--
The `policy` workflow reads this PR body and fails the PR when:
- `## Gates` or `## Deslop` is missing or has no real content;
- `## Security` is missing while the diff touches auth, payments, secrets,
  uploads, webhooks, or .env files;
- `## Tests` is missing while the diff touches test files, or added test lines
  exceed twice the added production lines without a `Ratio:` line.

Paste real output. "Looks good" is not evidence. Replace each guidance comment
with facts, then delete the comments.
-->

<!-- One or two sentences. What changed and why. Link the issue if there is one. -->

## What changed

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
