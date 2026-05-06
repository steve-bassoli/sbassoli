---
name: best-practices-angular
description: "Audit Angular best-practice compliance for changed component files in the active repository. Persist findings to `/codex/output/best_practices_angular_items.txt` and mutable status to `/codex/output/best_practices_angular_items_status.txt` using util-iterative-flat-file, then remediate one open finding at a time with user confirmation."
---

# Angular Best Practices

## Workflow

1. Determine the comparison base branch (use the repository default branch unless the user specifies one) and compute changed files with `git diff --name-only <base-branch>...HEAD`.
2. Restrict scope to changed Angular component files (`*.component.ts`, `*.component.html`, `*.component.scss`).
3. Review each changed component file in full, not only changed hunks.
4. Record best-practice findings to `/codex/output/best_practices_angular_items.txt` using util queue schema.
5. Sync mutable status file:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1 -InvokingSkillName "best-practices-angular"`
6. Fix one open finding at a time.
7. After each fix, stop and ask the user whether to continue to the next fix.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/best_practices_angular_items.txt`
- Mutable progress state:
  - `/codex/output/best_practices_angular_items_status.txt`
- Utility scripts:
  - `codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/get-iterative-status-summary.ps1`

## Angular Review Rules

1. Prefer `ChangeDetectionStrategy.OnPush` for container/presentational components unless there is a clear reason not to use it.
2. Avoid function calls in templates that run every change detection cycle when values can be precomputed.
3. Use strongly typed models; avoid `any` and unsafe type assertions without guards.
4. Favor `readonly` for dependencies and immutable fields that are not reassigned.
5. Avoid manual subscriptions without cleanup; prefer `async` pipe or controlled teardown patterns.
6. Keep side effects out of constructors; use lifecycle hooks and explicit handlers.
7. Keep template logic simple; move branching/computation to component properties when it improves readability/testability.
8. Use stable tracking (`trackBy`/`track`) for repeated lists where applicable.
9. Follow existing project conventions for signals, observables, and RxJS composition.

## Findings Queue Contract

Write to `/codex/output/best_practices_angular_items.txt` using util queue schema.

Per finding item include:

- Required:
  - `id`
  - `order`
  - `item_type` (`angular_best_practice_issue`)
  - `description` (concise issue statement)
- Recommended:
  - `source_file`
  - `source_line_start`
  - `source_line_end`
  - `code_context` (short excerpt/summary)
  - `target_file`
  - `priority` (`high` or `medium`)
  - `risk_context` (maintainability/correctness/performance impact)
  - `metadata` (rule id, suggested fix, reviewer notes)

Include only findings that are meaningfully actionable for the current repository.

## Remediation Loop

1. Read next `open` id from `/codex/output/best_practices_angular_items_status.txt`.
2. Resolve the matching finding in `/codex/output/best_practices_angular_items.txt`.
3. Apply one fix.
4. Run targeted validation for the modified file(s), typically a focused lint command.
5. Update finding status with util script:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1 -InvokingSkillName "best-practices-angular" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
6. Report the change briefly.
7. Prompt user: `Issue <id> fixed. Continue to next open issue?`
8. Continue only after user confirmation.

## Constraints

1. Keep scope limited to changed component files for the scan.
2. Assess the entire changed component files, not just line-level diff hunks.
3. Do not include low-signal stylistic nits; focus on maintainability, correctness, and performance-impacting practices.
4. Keep fixes minimal and aligned with existing project patterns.
