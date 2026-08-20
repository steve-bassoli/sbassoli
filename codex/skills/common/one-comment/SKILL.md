---
name: one-comment
description: Find at most one high-confidence, non-NIT defect in a GitHub pull request and draft a ready-to-paste inline review comment backed by a realistic reproduction and material impact, optionally comparing the PR with a local or legacy implementation. Use only when explicitly asked for one high-value PR comment or the single best actionable correctness, security, data-integrity, runtime, contract, or deployment finding. Never post the comment.
---

# One Comment

## Status guardrail

Treat this skill as **work in progress** until it has completed an execution against a specific live pull-request URL and the user explicitly approves removing this marker. Examples, fixtures, and local-only diffs do not qualify. Announce the WIP status when using it. Do not remove the marker or modify the skill automatically. When asked to remove it, require the qualifying PR URL and the user's approval in the current conversation; otherwise keep it.

## Objective

Draft at most one changed-line review comment. Prefer precision over coverage and abstain when no finding survives validation. Never manufacture a comment, write to GitHub, submit a review, resolve a thread, or modify the user's working tree. Use a disposable checkout for validation commands that generate artifacts.

Never select a stale, missing, or unregenerated BOM-to-Confluence artifact as the finding. This excludes `bom-confluence.html` and recommendations to run or commit its generator output, even when repository documentation says it should be regenerated.

## Access strategy

1. Read applicable repository instructions before inspecting code.
2. Use the GitHub connector first for PR intent, base/head SHAs, changed-file inventory, and existing review threads. Avoid loading the complete patch unless it is small.
3. For a self-contained PR of roughly eight or fewer files and 600 or fewer meaningful changed lines, inspect targeted connector patches.
4. For cross-file behavior, migrations, larger diffs, local comparisons, or executable validation, reuse an exact local checkout read-only or create an ephemeral shallow partial checkout containing the base and head. Do not switch the user's branch. Fetch more history only when the merge base, blame, or a legacy contract requires it.
5. Remember that repository bytes on disk do not consume model context; command output does. Prefer `git diff --stat`, `--name-status`, narrow file diffs, `rg`, line slices, and quiet targeted tests. Never print an entire large diff or repository into context.

## Temporary checkout lifecycle

When a disposable clone or worktree is necessary:

1. Create it directly under the operating system's temporary directory with a unique `one-comment-<repo>-<random>` name. Record and announce its resolved absolute path.
2. Treat that directory as the only cleanup target. Never clean a reused checkout, shared Git storage, the temporary-directory root, user-level build or dependency caches, or any path not created by the current execution.
3. Keep generated files, build outputs, and logs beneath the recorded directory where tooling permits. Complete the reproduction and defense challenge before cleanup.
4. In a guaranteed finalization step, resolve the target again and verify it is the exact recorded path, is a child of the operating system's temporary directory, and is not a workspace, repository, home, or temporary-directory root. Remove a registered worktree with the owning repository's worktree command and prune it; recursively remove a standalone clone only after the same checks.
5. Verify that the path no longer exists. If cleanup fails, leave it in place and report the exact path and error; never broaden the deletion target. Report `Cleanup: not needed` when no disposable checkout was created.

## Review workflow

1. Read the PR description and classify its intended behavior, explicit temporary limitations, and compatibility promises.
2. Inspect all changed-file names and statistics, then prioritize externally observable risk boundaries: authorization and tenancy, request/response serialization, data conversion or loss, queries and filtering, persistence and state mutation, concurrency and idempotency, time boundaries, error conversion, runtime wiring, and deployment configuration.
3. Form at most three hypotheses. Reject weak candidates quickly instead of exhaustively reading every file.
4. Follow only the strongest candidate's changed symbol, caller, contract or legacy implementation, and nearest relevant tests.
5. Prefer the smallest executable reproduction, focused test, dependency probe, or deterministic code trace. Run a full suite only when build or integration behavior is the suspected defect.
6. Recheck existing review threads before selecting the comment.

For a PR with at least 25 substantive files or three independent risk areas, optionally delegate bounded risk areas to at most three discovery agents with no inherited conversation context. Give them raw artifacts, request at most one candidate each, and validate the winner centrally. Do not delegate by default merely to reduce elapsed time.

## Qualification gates

Require every gate to pass:

- **PR-caused:** Tie the behavior to a changed line or behavior newly exposed by the PR.
- **Reachable now:** Trigger it through a valid, currently supported path, not hypothetical future wiring, invalid misuse, or an intentional stub.
- **Contract-backed:** Prove the expected behavior using a caller, public contract, test, documentation, base or legacy behavior, or authoritative framework semantics.
- **Concrete:** Name a realistic actor, action, input or state, execution path, actual result, and expected result.
- **Material:** Show wrong data, data loss or corruption, authorization or tenant exposure, a valid request failure, a broken user workflow, availability failure, or deployment failure.
- **Reproducible:** Support it with focused execution evidence or a complete deterministic trace.
- **Actionable:** Anchor it to one best changed line and provide an understandable correction or regression-test direction.
- **Novel:** Confirm that an existing review thread has not already raised it.

Reject formatting, naming, cleanup preferences, missing tests by themselves, generic refactoring, speculative hardening, tiny inefficiencies, unsupported-input edge cases, explicitly temporary behavior, and unchanged legacy defects.

## Disproof pass

Try to invalidate the candidate before drafting. Check whether upstream validation makes the trigger unreachable, global configuration or framework behavior neutralizes it, dependency resolution differs from declarations, the behavior is explicitly intentional, the base or legacy implementation proves compatibility, the reproduction uses an invalid contract, or the impact is immaterial. Drop the candidate when a plausible objection lacks decisive counter-evidence.

## Final defense gate

At the end of every execution, invoke a challenger with the personality **overly-defensive-software-developer**. Use a fresh subagent with no inherited conversation context when collaboration is available; do not downgrade to self-review merely to save time. When collaboration is unavailable, perform a clearly separated self-challenge and label it as such. If there is no provisional comment, send `NO CANDIDATE`; the challenger must return `BLOCK` without scoring the gates, confirming that nothing may be released.

For a provisional comment, send only this evidence packet with stable IDs. Include raw excerpts, command output, or precise resolvable locations rather than unsupported summaries:

- `E1`: PR intent and exact changed line or hunk;
- `E2`: realistic trigger and current execution path;
- `E3`: actual and expected observable results;
- `E4`: contract, caller, or legacy evidence;
- `E5`: reproduction command and result, or deterministic trace;
- `E6`: material impact;
- `E7`: existing-thread check;
- `E8`: exact provisional comment and line anchor.

Prompt the challenger:

> Act as the overly-defensive-software-developer responsible for this PR. FIGHT the proposed review comment and assume the implementation is correct until cited evidence forces concession. Verify cited artifacts directly when accessible and find the strongest admissible defense. Then score every qualification gate: `PR-caused`, `Reachable`, `Contract-backed`, `Concrete`, `Material`, `Reproducible`, `Actionable`, and `Novel`. Return exactly `<GATE>: PASS | CONTRADICTED | MISSING — <evidence IDs or exact absent fact>`. `PASS` requires a verified packet artifact. `CONTRADICTED` requires cited counter-evidence or a falsifying execution result. `MISSING` must name a required fact absent from the packet. Hypothetical possibilities without evidence are inadmissible. Do not improve the comment or invent facts.

Treat the challenger as an objection finder and compute the verdict mechanically:

- Return `BLOCK` when any gate is `CONTRADICTED`.
- Return `INCOMPLETE` when no gate is contradicted but any gate is `MISSING`.
- Return `CONCEDE` only when every gate is `PASS`.

Treat the complete cited packet as the reviewer's justification; do not add narrative persuasion. Do not accept a free-form verdict. Treat an uncited `PASS`, unsupported `CONTRADICTED`, missing gate, or malformed response as `INCOMPLETE`; retry formatting once, then abstain. For `BLOCK` or `INCOMPLETE`, allow one evidence-only supplement and have a fresh challenger score the complete packet from scratch. After that, accept `CONCEDE`, reject a `BLOCK` candidate, and abstain on `INCOMPLETE`. Do not win through rhetoric, confidence, or repetition. Any material change to the trigger, expected result, impact, anchor, or comment starts a new defense gate.

## Output contract

When the defense gate concedes, return only:

```markdown
**Skill status:** WIP — not yet approved after a real-PR execution

**Place on:** `path:line`

> When [realistic actor/action/input], [changed behavior] produces [actual result] instead of [contract-backed expected result], causing [material consequence]. Could we [specific correction] and cover this case?

**Verified by:** [one concise evidence statement]

**Defense gate:** `CONCEDE` — [one-sentence reason]

**Cleanup:** [removed `<temporary checkout>` | not needed | failed for `<path>`: `<error>`]

Nothing was posted.
```

Keep the review comment concise, usually 70-120 words. Include a GitHub suggestion block only when the user requests one and the entire verified fix fits safely in the selected hunk.

When no candidate survives, return:

```markdown
**Skill status:** WIP — not yet approved after a real-PR execution

No substantiated high-value comment found.

**Defense gate:** `BLOCK` or `INCOMPLETE` — [strongest unresolved objection or missing evidence]

**Cleanup:** [removed `<temporary checkout>` | not needed | failed for `<path>`: `<error>`]

Nothing was posted.
```
