---
name: iterative-unit-tests
description: Build and execute a lightweight unit-test plan from current local changes using importance-based test-gap estimation across multiple files. Persist initial backlog items to `/codex/output/iterative_unit_tests_items.txt`, spawn an efficiency agent to reduce oversized test scope and write `/codex/output/efficient_unit_tests_items.txt`, sync mutable status to `/codex/output/efficient_unit_tests_items_status.txt` using util-iterative-flat-file, then implement one efficient test item at a time with user approval between items.
---

# Iterative Unit Tests

## Quick Start

1. Diff local changes against `HEAD` and list changed files.
2. Filter to behavior-impacting source changes.
3. Estimate high-value missing test coverage.
4. Build a small, risk-prioritized backlog.
5. Write initial `Essential` items to `/codex/output/iterative_unit_tests_items.txt` using util queue schema.
6. Spawn an efficiency agent to reduce scope and write `/codex/output/efficient_unit_tests_items.txt`.
7. Sync status file for the efficient queue:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "efficient-unit-tests"`
8. Present the efficient queue and ask for approval before implementing tests.
9. Implement one open item from the efficient queue, run the narrowest validation, update status with util script, and ask for approval for the next item.

## Canonical Files

- Initial queue intake (pre-efficiency review):
  - `/codex/output/iterative_unit_tests_items.txt`
- Efficiency-reviewed queue intake (implementation source-of-truth):
  - `/codex/output/efficient_unit_tests_items.txt`
- Mutable progress state for the efficiency-reviewed queue:
  - `/codex/output/efficient_unit_tests_items_status.txt`
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

## Step 3: Build Backlog Queue

1. Build `Essential` + `Optional/Deferred` candidates.
2. Keep `Essential` intentionally small (1-5 by default).
3. Write/refresh `/codex/output/iterative_unit_tests_items.txt` with initial `Essential` items only.
4. Use util queue schema per item:
   - Required:
     - `id`
     - `order`
     - `item_type` (`unit_test`)
     - `description` (behavior to cover)
   - Recommended:
     - `source_file`
     - `source_line_start`
     - `source_line_end`
     - `code_context` (function/branch context)
     - `target_file` (test file target)
     - `priority` (`essential`)
     - `risk_context`
     - `metadata` (extra branch/range details)
5. If exact lines are unavailable, use best-known markers:
   - `source_line_start: "new"` for new blocks
   - `"unknown"` only when unavoidable; include reason in `risk_context`
6. If there are no `Essential` items, write an empty array (`[]`) and continue through the efficiency review so the final queue is explicit.

## Step 4: Run Efficiency Agent

1. After `/codex/output/iterative_unit_tests_items.txt` is written and before prompting the user for implementation, spawn an efficiency agent when subagents are available.
2. The efficiency agent must not edit source or test files. Its only output is `/codex/output/efficient_unit_tests_items.txt`.
3. Give the efficiency agent this mission:
   - Review `/codex/output/iterative_unit_tests_items.txt`, current local diffs, and relevant existing tests.
   - Reduce the list to the smallest unit-test implementation scope with the highest behavior-risk impact.
   - Prefer limited assertions that cover user-visible behavior, branching, data transformation, or error handling.
   - Drop broad, brittle, duplicated, implementation-detail, low-value, or out-of-scope tests.
   - Split an item only when a smaller independently valuable test can be implemented and validated.
   - Keep retained item ids stable when possible; use clear new ids only for meaningfully reshaped items.
   - Write valid util queue JSON to `/codex/output/efficient_unit_tests_items.txt`.
   - Add `metadata.efficiency_notes` to explain why each retained or reshaped item is worth implementing.
   - If no test remains essential, write an empty array (`[]`).
4. If subagent spawning is unavailable, perform the same efficiency pass locally and state that fallback before continuing.
5. Read `/codex/output/efficient_unit_tests_items.txt` and verify it is valid JSON using the same util queue schema. Fix only queue-file formatting or required-field issues; do not implement tests during this step.
6. Sync state for the efficient queue:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "efficient-unit-tests"`

## Step 5: Ask to Start Iteration

Ask:
`Would you like me to iteratively work through /codex/output/efficient_unit_tests_items.txt one test at a time and request approval after each item?`

Do not implement tests before approval.

## Step 6: Implement One Item

1. Read next `open` id from `/codex/output/efficient_unit_tests_items_status.txt`.
2. Resolve matching queue item in `/codex/output/efficient_unit_tests_items.txt`.
3. Announce item:
   - `Now updating test: <id> - <target_file>`
4. Implement minimum assertions needed for that behavior.
5. Run narrowest validation command possible (single spec/test-name when available).
6. Summarize:
   - files changed
   - command + result
   - behavior covered
7. Update status with util script:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "efficient-unit-tests" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
8. Ask:
   - `Please verify this result. Approve moving to the next test item?`

## Step 7: Continue Only With Approval

1. Move to next item only after explicit approval.
2. If user requests revision, update same item and revalidate.
3. Keep status file synced after each addressed item.

## Output Contract

1. Always write `/codex/output/iterative_unit_tests_items.txt` before efficiency review.
2. Always run the efficiency review and present `/codex/output/efficient_unit_tests_items.txt` before coding tests.
3. Always request approval between items.
4. Always include line ranges + function/branch context in queue entries.
5. Keep `/codex/output/iterative_unit_tests_items.txt` as the initial backlog record.
6. Keep `/codex/output/efficient_unit_tests_items.txt` as the implementation intake source-of-truth.
7. Keep `/codex/output/efficient_unit_tests_items_status.txt` as mutable status source-of-truth.
8. End with completion summary:
   - total, completed, skipped, blocked, remaining open (+ reasons)
