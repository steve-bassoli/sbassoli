---
name: iterative-unit-tests
description: Build and execute a lightweight unit-test plan from current local changes using importance-based test-gap estimation across multiple files. Persist a small backlog to `/codex/output/iterative_unit_tests_items.txt`, include `estimated_line_coverage` on every item, sync mutable status to `/codex/output/iterative_unit_tests_items_status.txt` using util-iterative-flat-file, then implement one queued test item at a time with user approval between items.
---

# Iterative Unit Tests

## Quick Start

1. Diff local changes against `HEAD` and list changed files.
2. Filter to behavior-impacting source changes.
3. Estimate high-value missing test coverage.
4. Build a small, risk-prioritized backlog with one queue item per unit test method/behavior.
5. Write `Essential` items to `/codex/output/iterative_unit_tests_items.txt` using util queue schema, including `estimated_line_coverage` for every item.
6. Read `/codex/output/iterative_unit_tests_items.txt` back and verify it is valid JSON using the same util queue schema.
7. Sync status for the queue:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-unit-tests"`
8. Present the queue and ask for approval before implementing tests.
9. Implement one open item from the queue, run the narrowest validation, update status with util script, and ask for approval for the next item.

## Canonical Files

- Queue intake and implementation source-of-truth:
  - `/codex/output/iterative_unit_tests_items.txt`
- Mutable progress state for the queue:
  - `/codex/output/iterative_unit_tests_items_status.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Step 1: Determine Changed Files

1. Use:
   - `git diff --name-status HEAD`
   - `git diff --name-only HEAD`
   - `git ls-files --others --exclude-standard`
2. Focus on executable logic and directly related tests.
3. Skip low-signal files unless requested:
   - docs/static assets/generated files
   - pure style/template changes with no behavior impact

## Step 2: Estimate Missing Important Coverage

1. Get changed ranges with:
   - `git diff -U0 HEAD -- <file>`
2. For new files, treat relevant new logic blocks as changed ranges.
3. Prioritize test-worthy changes:
   - branching/state transitions
   - user-visible behavior
   - data transformation/API contract logic
   - error/edge handling
4. For each source file, capture:
   - changed line range(s)
   - function/branch context
   - likely untested behavior
   - best target spec file
   - estimated lines of changed behavior the proposed test would cover

## Step 3: Build Backlog Queue

1. Build `Essential` + `Optional/Deferred` candidates.
2. Keep `Essential` intentionally small (1-5 by default).
3. Break backlog candidates down so each queue item represents exactly one unit test method or one narrow test behavior.
   - Do not group several test methods under one item, even when they target the same class.
   - Prefer item descriptions in the form `Add shouldDoSpecificBehavior`.
   - If a helper/class needs four tests, create four queue items.
4. Write/refresh `/codex/output/iterative_unit_tests_items.txt` with initial `Essential` items only.
5. Use util queue schema per item.
6. Required fields:
   - `id`
   - `order`
   - `item_type` (`unit_test`)
   - `description` (behavior to cover)
   - `estimated_line_coverage`
7. Recommended fields:
   - `source_file`
   - `source_line_start`
   - `source_line_end`
   - `code_context` (function/branch context)
   - `target_file` (test file target)
   - `priority` (`essential`)
   - `risk_context`
   - `metadata` (extra branch/range details)
8. In `metadata`, include `test_method` with the proposed test method name when the target framework uses named test methods.
9. Set `estimated_line_coverage` to a concise numeric estimate or bounded range for how many changed source lines the proposed test meaningfully covers.
10. If exact lines are unavailable, use best-known markers:
   - `source_line_start: "new"` for new blocks
   - `"unknown"` only when unavoidable; include reason in `risk_context`
11. If there are no `Essential` items, write an empty array (`[]`).

## Step 4: Validate and Sync Queue

1. Read `/codex/output/iterative_unit_tests_items.txt` and verify it is valid JSON using the same util queue schema.
2. Fix only queue-file formatting or required-field issues; do not implement tests during this step.
3. Sync state for the queue:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-unit-tests"`

## Step 5: Ask to Start Iteration

Ask:
`Would you like me to iteratively work through /codex/output/iterative_unit_tests_items.txt one test at a time and request approval after each item?`

Do not implement tests before approval.

## Step 6: Implement One Item

1. Read next `open` id from `/codex/output/iterative_unit_tests_items_status.txt`.
2. Resolve matching queue item in `/codex/output/iterative_unit_tests_items.txt`.
3. Announce item:
   - `Now updating test: <id> - <target_file>`
4. Implement minimum assertions needed for that behavior.
5. Run narrowest validation command possible (single spec/test-name when available).
6. Summarize:
   - files changed
   - command + result
   - behavior covered
7. Update status with util script:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "iterative-unit-tests" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
8. Ask:
   - `Please verify this result. Approve moving to the next test item?`

## Step 7: Continue Only With Approval

1. Move to next item only after explicit approval.
2. If user requests revision, update same item and revalidate.
3. Keep status file synced after each addressed item.

## Output Contract

1. Always write `/codex/output/iterative_unit_tests_items.txt` before coding tests.
2. Always create one queue item per unit test method or narrow test behavior; never group multiple test methods into one queue item.
3. Always include `estimated_line_coverage` on every queue item.
4. Always request approval between items.
5. Always include line ranges and function or branch context in queue entries.
6. Keep `/codex/output/iterative_unit_tests_items.txt` as the implementation intake source-of-truth.
7. Keep `/codex/output/iterative_unit_tests_items_status.txt` as mutable status source-of-truth.
8. End with completion summary:
   - total, completed, skipped, blocked, remaining open (+ reasons)
