---
name: iterative-minimal-diff
description: Reduce noisy diffs iteratively while preserving behavior by building an immutable queue at `/codex/output/iterative_minimal_diff_items.txt` and mutable status at `/codex/output/iterative_minimal_diff_items_status.txt` using util-iterative-flat-file, then processing one open file/item at a time with explicit user approval between items.
---

# Iterative Minimal Diff

## Quick Start

1. Select compare reference and scope:
   - Default compare ref: `master` (or user-specified branch/ref).
   - Scope example: `git diff --name-only <compare-ref> -- "*.html"`.
2. Identify files with likely reducible diff noise.
3. Build a small prioritized backlog of diff-minimization items.
4. Write queue items to `/codex/output/iterative_minimal_diff_items.txt`.
5. Sync status file:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-minimal-diff"`
6. Ask for approval before edits.
7. Process one open item at a time, validate, update status, and ask approval before the next item.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/iterative_minimal_diff_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_minimal_diff_items_status.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Step 1: Determine Candidate Files

1. Gather changed files against compare ref:
   - `git diff --name-only <compare-ref>`
   - `git diff --name-status <compare-ref>`
2. For each candidate file, inspect:
   - `git diff --numstat <compare-ref> -- <file>`
   - `git diff <compare-ref> -- <file>`
3. Mark reducible-noise candidates:
   - indentation/formatting-only churn
   - wrapper/markup rearrangements that can be rewritten with less textual churn
   - avoidable reorder-only changes not required for behavior
4. Mark non-reducible candidates:
   - net-new files
   - fundamentally new behavior/UI structure where large diff is expected
   - broad dependency-driven migrations

## Step 2: Build Backlog Queue

1. Build `Essential` items only (typically 1-10).
2. Write/refresh `/codex/output/iterative_minimal_diff_items.txt`.
3. Required fields per queue item:
   - `id`
   - `order`
   - `item_type` (`minimal_diff`)
   - `description`
4. Recommended fields:
   - `source_file`
   - `source_line_start`
   - `source_line_end`
   - `code_context`
   - `target_file`
   - `priority` (`essential`)
   - `risk_context`
   - `metadata` (compare ref, baseline diff stats, constraints)
5. If there are no essential items, write `[]` and still sync status for explicit tracking.

## Step 3: Ask to Start Iteration

Ask:
`Would you like me to iteratively minimize these diffs one item at a time and request approval after each item?`

Do not start edits before approval.

## Step 4: Process One Item

1. Read next `open` id from `/codex/output/iterative_minimal_diff_items_status.txt`.
2. Resolve matching queue item in `/codex/output/iterative_minimal_diff_items.txt`.
3. Announce item:
   - `Now minimizing diff: <id> - <target_file>`
4. Apply minimal edits that reduce diff size without changing behavior.
5. Re-check diff:
   - `git diff --numstat <compare-ref> -- <file>`
   - `git diff <compare-ref> -- <file>`
6. Run narrow validation for touched files (formatter/lint/tests as appropriate to file type and risk).
7. Summarize:
   - files changed
   - before/after diff stats (if available)
   - validation command + result
8. Update status:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "iterative-minimal-diff" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
9. Ask:
   - `Please verify this diff reduction. Approve moving to the next item?`

## Step 5: Continue Only With Approval

1. Continue only after explicit user approval.
2. If user asks for revision, rework the same item and revalidate.
3. Keep status file current after each addressed item.

## Guardrails

1. Preserve behavior; do not remove required functional changes just to shrink diff.
2. Prefer minimal textual edits over broad rewrites.
3. If an item is not safely reducible, mark `skipped` with concise reason.
4. Do not close as complete while `open` items remain unless user explicitly stops.

## Output Contract

1. Always show the backlog queue before iterative edits.
2. Always request approval between items.
3. Keep queue file as intake source-of-truth and status file as mutable source-of-truth.
4. End with status summary:
   - total, done, skipped, blocked, remaining open
   - brief note for any skipped/blocked/open item
