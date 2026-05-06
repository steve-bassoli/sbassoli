# Iterative Skill Attribute Mapping

This mapping is derived from local iterative skills in `codex/skills/common`:

- `iterative-github-comments`
- `iterative-unit-tests`
- `iterative-abstraction-check`
- `iterative-implementation`

Canonical file naming for all mapped workflows:

- Queue: `/codex/output/<invoking_skill>_items.txt`
- Status: `/codex/output/<invoking_skill>_items_status.txt`

## Chosen Cross-Skill Attribute Set

Use this set for queue items intended to work across all iterative skills:

- `id`
- `order`
- `item_type`
- `description`
- `source_file`
- `source_line_start`
- `source_line_end`
- `code_context`
- `target_file`
- `priority`
- `risk_context`
- `reference_url`
- `metadata`

Use `status` only in the separate state file (`open`, `done`, `skipped`, `blocked`).

## Skill-by-Skill Mapping

| Source skill | Existing item fields | Mapping guidance |
| --- | --- | --- |
| `iterative-github-comments` | `status`, `file`, `line`, `url`, `comment`, `context`, optional `notes` | Map `comment` -> `description`; `file` -> `source_file` and `target_file`; `line` -> `source_line_start`/`source_line_end`; `context` -> `code_context`; `url` -> `reference_url`; extra fields (`author`, `created_at`) -> `metadata`. |
| `iterative-unit-tests` | `<ID>`, `<Priority>`, `<Source file>:Lx-Ly`, `<Function/branch context>`, `<Behavior to cover>`, `<Test file target>`, `<Risk/context>` | Map `<ID>` -> `id`; sequence order -> `order`; `unit_test` -> `item_type`; `<Behavior to cover>` -> `description`; source range -> `source_file`/`source_line_start`/`source_line_end`; `<Function/branch context>` -> `code_context`; `<Test file target>` -> `target_file`; `<Priority>` -> `priority`; `<Risk/context>` -> `risk_context`. |
| `iterative-abstraction-check` | `id`, `status`, `severity`, `mode`, `windowSize`, `fileCount`, `occurrenceCount`, `locations`, `sample` | Map `id` -> `id`; queue order from severity/rank -> `order`; `abstraction_candidate` or `scaffolding_artifact` -> `item_type`; summary from finding/sample -> `description`; first location -> `source_file`/`source_line_start`; `sample` -> `code_context`; `severity` -> `priority`; mode/count details -> `risk_context`; full `locations` and numeric diagnostics -> `metadata`. |
| `iterative-implementation` | `Step`, `Status`, `Objective`, `Context`, `Implementation details`, `Validation`, `User verification checkpoint`, `Next-step prompt` | Map step index or slug -> `id`; step number -> `order`; `implementation_step` -> `item_type`; `Objective` -> `description`; extract first concrete file path to `source_file` when available; use `Context` + `Implementation details` summary for `code_context`; optional target file from details -> `target_file`; dependency risk from context -> `risk_context`; `Validation` and checkpoint/prompt -> `metadata`. |

## Normalization Rules

- If file or line is unknown, use `unknown` instead of leaving fields blank.
- Keep `description` concise and action-oriented.
- Keep large text blobs in `metadata` only when not needed in the canonical fields.
- Never store mutable status in queue items after intake is finalized.
