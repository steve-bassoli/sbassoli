---
name: iterative-unit-tests
description: Build and execute a lightweight unit-test plan from current local changes using importance-based test-gap estimation across multiple files. Persist backlog items to `/codex/output/iterative_unit_tests_items.txt` and mutable status to `/codex/output/iterative_unit_tests_items_status.txt` using util-iterative-flat-file, then implement one open test item at a time with user approval between items.
---

# Iterative Unit Tests

## Quick Start

1. Diff local changes against `HEAD` and list changed files.
2. Filter to behavior-impacting source changes.
3. Estimate high-value missing test coverage.
4. Build a small, risk-prioritized backlog.
5. Write `Essential` items to `/codex/output/iterative_unit_tests_items.txt` using util queue schema.
6. Sync status file:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1 -InvokingSkillName "iterative-unit-tests"`
7. Ask for approval before implementing tests.
8. Implement one open item, run the narrowest validation, update status with util script, and ask for approval for the next item.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/iterative_unit_tests_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_unit_tests_items_status.txt`
- Utility scripts:
  - `codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/get-iterative-status-summary.ps1`

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
3. Write/refresh `/codex/output/iterative_unit_tests_items.txt` with `Essential` items only.
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
6. If there are no `Essential` items, write an empty array (`[]`) and sync state to keep the record explicit.

## Step 4: Ask to Start Iteration

Ask:
`Would you like me to iteratively work through this list one test at a time and request approval after each item?`

Do not implement tests before approval.

## Step 5: Implement One Item

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
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1 -InvokingSkillName "iterative-unit-tests" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
8. Ask:
   - `Please verify this result. Approve moving to the next test item?`

## Step 6: Continue Only With Approval

1. Move to next item only after explicit approval.
2. If user requests revision, update same item and revalidate.
3. Keep status file synced after each addressed item.

## Output Contract

1. Always present backlog queue before coding tests.
2. Always request approval between items.
3. Always include line ranges + function/branch context in queue entries.
4. Keep `/codex/output/iterative_unit_tests_items.txt` as intake source-of-truth.
5. Keep `/codex/output/iterative_unit_tests_items_status.txt` as mutable status source-of-truth.
6. End with completion summary:
   - total, completed, skipped, blocked, remaining open (+ reasons)
