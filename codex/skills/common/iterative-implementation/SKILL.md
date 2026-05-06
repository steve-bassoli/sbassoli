---
name: iterative-implementation
description: Create and persist implementation-step plans as util-iterative-flat-file artifacts by writing queue items to `/codex/output/iterative_implementation_items.txt` and mutable status to `/codex/output/iterative_implementation_items_status.txt`, then execute one open step at a time with explicit user verification before continuing.
---

# Iterative Implementation

## Quick Start

1. Read [references/implementation-steps-template.md](references/implementation-steps-template.md).
2. Convert the user request into an ordered implementation sequence.
3. Write the plan queue to `/codex/output/iterative_implementation_items.txt`.
4. Ensure every queue item contains execution context and validation details.
5. Sync status file:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1 -InvokingSkillName "iterative-implementation"`
6. When executing, complete only one open step at a time.
7. After each completed step, ask the user to verify and explicitly confirm whether to continue to the next step.
8. Return a short response that confirms file output and summarizes the sequence.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/iterative_implementation_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_implementation_items_status.txt`
- Utility scripts:
  - `codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/get-iterative-status-summary.ps1`

## Required Behavior

1. Treat `/codex/output/iterative_implementation_items.txt` as the primary artifact for implementation planning requests.
2. Overwrite the queue for a new implementation request unless the user explicitly asks to append or preserve existing content.
3. Include all context required for execution inside each step item so an engineer can execute without revisiting earlier chat messages.
4. Keep wording concrete and execution-oriented; avoid vague placeholders.
5. During execution, stop after every completed step and wait for user verification before starting the next step.
6. Prompt explicitly for continuation (for example: "Step 2 is complete. Please verify. Continue to Step 3?").

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
   - `code_context` (core constraints/prerequisites summary)
   - `target_file` (primary target if known)
   - `priority` (`high` or `essential`)
   - `risk_context` (dependency and execution risk summary)
   - `metadata` containing:
     - `objective`
     - `context`
     - `implementation_details`
     - `validation`
     - `user_verification_checkpoint`
     - `next_step_prompt`

## Status Rules

Use `/codex/output/iterative_implementation_items_status.txt` with status values:

- `open`
- `done`
- `blocked`
- `skipped`

Guidance:

1. Initialize all queue items as `open` via util sync.
2. Use `done` only for steps already completed and verified.
3. Use `blocked` only when an external dependency or missing input prevents execution; include unblock condition in `notes`.
4. Use `skipped` only when explicitly excluded by scope or user decision.

## Interactive Execution Loop

1. Pick the earliest `open` id from status file.
2. Resolve the matching queue item in `/codex/output/iterative_implementation_items.txt`.
3. Execute only that step.
4. Run the step validation and update step status:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1 -InvokingSkillName "iterative-implementation" -ItemId "<id>" -Status done|blocked|skipped -Notes "<short disposition>"`
5. Ask the user to verify outcomes for that step.
6. Ask an explicit next-step prompt and wait for user confirmation before proceeding.
7. Do not start the next `open` step until user confirmation is received.

## Completion

After writing or executing against the queue, provide a brief response with:

1. Confirmation that queue/status files were written or updated.
2. Number of steps generated.
3. Any blocked items that need user input.
4. During execution mode, a verification prompt after each completed step before continuing.
