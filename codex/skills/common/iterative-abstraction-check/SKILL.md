---
name: iterative-abstraction-check
description: Run an iterative abstraction gate on local changes by detecting duplicate logic and likely scaffolding artifacts, persisting analysis history, and exporting open remediation items to util-iterative-flat-file artifacts at `/codex/output/iterative_abstraction_check_items.txt` with mutable status in `/codex/output/iterative_abstraction_check_items_status.txt`. Use before commit/PR, after AI-assisted implementation, or when repeated code and temporary guard patterns are likely.
---

# Iterative Abstraction Check

## Quick Start

1. Read [references/abstraction-rules.md](references/abstraction-rules.md).
2. Read [references/scaffolding-artifact-patterns.md](references/scaffolding-artifact-patterns.md).
3. Run duplicate scan:
   `powershell -File C:\work\sbassoli\codex\skills\common\iterative-abstraction-check\scripts\check-diff-abstractions.ps1 -RepoRoot . -CompareRef <default-branch> -PersistPath "codex/output/iterative_abstraction_check_run_log.txt" -ChecklistPath "codex/output/iterative_abstraction_check_candidates.txt" -QueuePath "codex/output/iterative_abstraction_check_items.txt" -NoFailOnHighConfidence`
4. Run scaffolding pattern searches from the reference file within changed-file scope and append/update scaffolding items in `/codex/output/iterative_abstraction_check_items.txt`, then resync status:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-abstraction-check"`
5. Ask for approval before fixes.
6. Address one open item at a time (duplicate candidate or scaffolding item), validate, update util status, then ask for approval before the next item.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/iterative_abstraction_check_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_abstraction_check_items_status.txt`
- Analysis history and machine queue artifacts:
  - `/codex/output/iterative_abstraction_check_run_log.txt`
  - `/codex/output/iterative_abstraction_check_candidates.txt`
  - `/codex/output/iterative_abstraction_check_scaffolding.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Required Persistence

- Always append duplicate-scan runs to `/codex/output/iterative_abstraction_check_run_log.txt`.
- Keep duplicate candidates in `/codex/output/iterative_abstraction_check_candidates.txt` (JSON queue managed by script).
- Keep scaffolding findings in `/codex/output/iterative_abstraction_check_scaffolding.txt`.
- Keep actionable queue items in `/codex/output/iterative_abstraction_check_items.txt`.
- Keep mutable processing status in `/codex/output/iterative_abstraction_check_items_status.txt`.
- Never discard history unless the user explicitly asks.

## Workflow

1. Resolve scan scope:
   - Preferred: `-CompareRef <branch-or-ref>` (for example `main` or `master`) to diff merge-base to current worktree.
   - Fallback: no compare ref means staged/unstaged/untracked only.
2. Run duplicate abstraction script and record result (`pass`, `warn`, `fail`) plus next pending candidate.
3. Run scaffolding artifact detection on changed files using the reference searches:
   - top-of-method immediate-return guards
   - optional constructor dependencies
   - constructor overload scaffolding
   - nullable DI/service calls that mask required dependencies
   - temporary markers tied to scaffolding
4. Build or refresh `/codex/output/iterative_abstraction_check_items.txt` before edits, including any scaffolding items not emitted by the duplicate script.
5. Re-sync util status after queue updates:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-abstraction-check"`
6. Ask:
   - `I prepared abstraction and scaffolding checklists. Would you like me to address items one by one?`
7. Process one item at a time after approval:
   - read next open id from `/codex/output/iterative_abstraction_check_items_status.txt`
   - resolve the matching queue item in `/codex/output/iterative_abstraction_check_items.txt`
   - apply the minimal fix for a single checklist item
   - run targeted validation
   - update item status with util script (`done`, `skipped`, or `blocked`) and a short note
   - ask:
     - `Please verify this item. Approve moving to the next open item?`
8. Continue only with explicit approval between items.
9. End with a full status summary and any remaining open items.

## Scaffolding Triage Rules

Mark as `high confidence artifact` when both signals exist:
- constructor dependency became optional mainly for compatibility scaffolding
- core method added top-level `if (dependencyMissing) return ...` guard

Mark as `possible artifact` when one signal exists but intent is unclear. Ask before refactor.

Do not flag as artifact when guard is domain-valid:
- argument validation
- lifecycle/subscription safety checks with clear intent
- explicit authorization behavior

## Output Requirements

Report:

- duplicate scan result and severity counts (`high`, `medium`, `low`)
- number of queue status items (`done`, `skipped`, `blocked`, `open`)
- top open items with locations
- files changed and validation executed for addressed item
- explicit note when processing stops early with remaining open items

## Validation

Run at least:

- duplicate scan smoke command:
  `powershell -File C:\work\sbassoli\codex\skills\common\iterative-abstraction-check\scripts\check-diff-abstractions.ps1 -RepoRoot . -CompareRef <default-branch> -PersistPath "codex/output/iterative_abstraction_check_run_log.txt" -ChecklistPath "codex/output/iterative_abstraction_check_candidates.txt" -QueuePath "codex/output/iterative_abstraction_check_items.txt" -NoFailOnHighConfidence`
- targeted lint/test commands for each addressed queue item

## Resources

- Script: [scripts/check-diff-abstractions.ps1](scripts/check-diff-abstractions.ps1)
- Rules: [references/abstraction-rules.md](references/abstraction-rules.md)
- Allowlist format: [references/abstraction-allowlist.md](references/abstraction-allowlist.md)
- Scaffolding patterns: [references/scaffolding-artifact-patterns.md](references/scaffolding-artifact-patterns.md)
