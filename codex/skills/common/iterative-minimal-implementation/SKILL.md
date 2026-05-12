---
name: iterative-minimal-implementation
description: Create and execute minimal happy-path implementation plans using util-iterative-flat-file queue/status artifacts. Use when Codex needs to implement the smallest viable code change, avoid unit tests, avoid defensive or extraneous error handling, and remove any added code that is not required for the bare implementation.
---

# Iterative Minimal Implementation

## Quick Start

1. Convert the user request into the fewest ordered happy-path implementation steps.
2. Write the plan queue to `/codex/output/iterative_minimal_implementation_items.txt`.
3. Ensure every queue item states the smallest required code change and explicitly excludes unit tests and nonessential robustness work.
4. Sync status file:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-minimal-implementation"`
5. Execute only one open step at a time.
6. Before marking a step done, run the Bare Implementation Gate below and remove anything that fails it.
7. After each completed step, ask the user to verify and explicitly confirm whether to continue to the next step.

## Canonical Files

- Queue intake:
  - `/codex/output/iterative_minimal_implementation_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_minimal_implementation_items_status.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Minimality Rules

1. Implement only the direct success path needed by the user's request.
2. Prefer editing existing code in place over adding helpers, abstractions, wrappers, configuration, or new modules.
3. Do not add or modify unit tests.
4. Do not add test-only scaffolding, mocks, fixtures, snapshot updates, or coverage changes.
5. Do not add retries, fallbacks, guards, validation layers, telemetry, analytics, generalized state machines, or edge-case UI unless the user explicitly requires that behavior.
6. Use no error handling by default. Add only the simplest `catch`/failure branch when required by the surrounding API or existing local pattern.
7. Keep any allowed catch small: surface the failure, set one obvious failure state, or rethrow. Do not add recovery flows.
8. Remove any added code that is not necessary for the bare happy path before marking the step done.

## Queue Item Requirements

Each queue item must include:

1. Required util fields:
   - `id`
   - `order`
   - `item_type` (`implementation_step`)
   - `description` (clear step action title/objective)
2. Recommended util fields:
   - `source_file` (`unknown` if not step-specific)
   - `source_line_start` (`unknown` unless known)
   - `source_line_end` (`unknown` unless known)
   - `code_context` (minimal constraints/prerequisites summary)
   - `target_file` (primary target if known)
   - `priority` (`essential`)
   - `risk_context` (only risks that affect the happy-path implementation)
   - `metadata` containing:
     - `objective`
     - `minimal_change`
     - `explicit_non_goals`
     - `implementation_details`
     - `validation`
     - `bare_implementation_gate`
     - `user_verification_checkpoint`
     - `next_step_prompt`

## Validation Rules

1. Validate with the smallest non-unit-test check that can show the happy path works.
2. Prefer existing build, lint, typecheck, compile, or manual smoke verification over adding any test artifact.
3. Do not create, update, or run unit tests as part of this skill's workflow.
4. If the only available validation is a unit test command, skip it and state that validation was skipped because unit tests are outside the skill scope.

## Bare Implementation Gate

Before setting any item to `done`, inspect the diff and answer these checks:

1. Does every added line directly support the requested happy path?
2. Did the change avoid unit tests and test-only artifacts?
3. Did the change avoid extra defensive handling, retries, fallbacks, abstractions, and generalized edge-case support?
4. Is any allowed catch the simplest viable branch for the surrounding code?

If any answer is no, remove the offending code first. Do not mark the item done until the diff passes this gate.

## Status Rules

Use `/codex/output/iterative_minimal_implementation_items_status.txt` with status values:

- `open`
- `done`
- `blocked`
- `skipped`

Guidance:

1. Initialize all queue items as `open` via util sync.
2. Use `done` only for steps already completed, validated without unit tests, and passed through the Bare Implementation Gate.
3. Use `blocked` only when a missing dependency or input prevents the happy-path implementation; include the unblock condition in `notes`.
4. Use `skipped` only when explicitly excluded by scope or when the step would require non-minimal code.

## Interactive Execution Loop

1. Pick the earliest `open` id from the status file.
2. Resolve the matching queue item in `/codex/output/iterative_minimal_implementation_items.txt`.
3. Execute only that step.
4. Run non-unit-test validation when available.
5. Apply the Bare Implementation Gate and remove non-bare code.
6. Update step status:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "iterative-minimal-implementation" -ItemId "<id>" -Status done|blocked|skipped -Notes "<short disposition>"`
7. Ask the user to verify outcomes for that step.
8. Ask an explicit next-step prompt and wait for user confirmation before proceeding.

## Completion

After writing or executing against the queue, provide a brief response with:

1. Confirmation that queue/status files were written or updated.
2. Number of steps generated or completed.
3. Confirmation that no unit tests were added or modified.
4. Any blocked items that need user input.
5. During execution mode, a verification prompt after each completed step before continuing.
