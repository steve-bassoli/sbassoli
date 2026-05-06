---
name: util-iterative-flat-file
description: Standardize flat-file tracking for iterative workflows by using an immutable queue file and a mutable status file. Use when creating or updating iterative skills that process one item at a time (for example PR comment queues, unit-test backlogs, abstraction checklists, or implementation steps) and need reliable status updates without rewriting large queue documents.
---

# Util Iterative Flat File

## Quick Start

1. Build queue items at `/codex/output/<invoking_skill>_items.txt` using [references/unified-item-attributes.md](references/unified-item-attributes.md).
2. Initialize or refresh state:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "<invoking_skill>"`
3. Process one `open` item at a time in queue `order`.
4. Update only state after each item:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "<invoking_skill>" -ItemId "<id>" -Status done -Notes "<short disposition>"`
5. Report progress:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1 -InvokingSkillName "<invoking_skill>"`

## Required Pattern

- Always name files as `/codex/output/<name_of_invoking_skill>_<use_for_skill>.txt`.
- Normalize `<name_of_invoking_skill>` to lowercase snake_case for filenames.
- Use `items` as the default queue `<use_for_skill>`.
- Use `items_status` as the default mutable-state `<use_for_skill>`.
- Keep `/codex/output/<invoking_skill>_items.txt` immutable after intake generation unless new intake data arrives.
- Keep mutable progress only in `/codex/output/<invoking_skill>_items_status.txt`.
- Use stable queue `id` values so state rows remain durable across turns.
- Use only these status values: `open`, `done`, `skipped`, `blocked`.
- Keep `notes` short and auditable.

## Unified Item Attributes

Use the queue attribute set in [references/unified-item-attributes.md](references/unified-item-attributes.md).

Required queue fields:
- `id`
- `order`
- `item_type`
- `description`

Recommended queue fields:
- `source_file`
- `source_line_start`
- `source_line_end`
- `code_context`
- `target_file`
- `priority`
- `risk_context`
- `reference_url`
- `metadata`

Fixed state columns:
- `id`
- `status`
- `notes`
- `updated_at_utc`

## Existing Iterative Skill Mapping

Use [references/iterative-skill-attribute-mapping.md](references/iterative-skill-attribute-mapping.md) to map existing iterative skill item formats into the unified queue schema.

## Single-File Fallback

If a workflow cannot use split queue/state files:

- Keep mutable status on one predictable line per item.
- Restrict edits to that status line only.
- Avoid multiline mutable fields.

## Resources

Scripts:
- [scripts/sync-iterative-state.ps1](scripts/sync-iterative-state.ps1)
- [scripts/set-iterative-item-status.ps1](scripts/set-iterative-item-status.ps1)
- [scripts/get-iterative-status-summary.ps1](scripts/get-iterative-status-summary.ps1)

References:
- [references/unified-item-attributes.md](references/unified-item-attributes.md)
- [references/iterative-skill-attribute-mapping.md](references/iterative-skill-attribute-mapping.md)
