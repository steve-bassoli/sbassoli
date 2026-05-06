# Unified Iterative Item Attributes

Use this attribute set when building iterative work queues intended to be processed one item at a time.

## Naming Rule

Always follow:

`/codex/output/<name_of_invoking_skill>_<use_for_skill>.txt`

Normalization:

- Convert `<name_of_invoking_skill>` to lowercase snake_case.
- Use lowercase snake_case for `<use_for_skill>`.
- Default use suffixes:
  - `items` for queue intake
  - `items_status` for mutable progress

## Queue File

- Path pattern: `/codex/output/<invoking_skill>_items.txt`
- Format: JSON array serialized in `.txt`
- Rule: treat this file as immutable intake data; do not mutate progress status here.

### Required Queue Attributes

| Attribute | Type | Description |
| --- | --- | --- |
| `id` | string | Stable unique identifier for durable status tracking. |
| `order` | number | Processing order (lowest first). |
| `item_type` | string | Domain label such as `github_comment`, `unit_test`, `abstraction_candidate`, `implementation_step`. |
| `description` | string | What should be done for this item. |

### Recommended Queue Attributes

| Attribute | Type | Description |
| --- | --- | --- |
| `source_file` | string | Primary file path related to the item, or `unknown`. |
| `source_line_start` | number/string | Start line, `unknown`, or `new`. |
| `source_line_end` | number/string | End line, `unknown`, or `new`. |
| `code_context` | string | Best-effort code hunk, branch context, or execution context. |
| `target_file` | string | Intended file to update (often same as `source_file`) or `n/a`. |
| `priority` | string | Importance label such as `essential`, `high`, `medium`, `low`. |
| `risk_context` | string | Why this item matters or likely failure mode if skipped. |
| `reference_url` | string | Optional permalink to PR comment, issue, or design artifact. |
| `metadata` | object | Skill-specific structured extras that should not change queue shape. |

## State File

- Path pattern: `/codex/output/<invoking_skill>_items_status.txt`
- Format: tab-separated file with a fixed header
- Rule: update this file only when marking progress.

### State Columns

| Column | Description |
| --- | --- |
| `id` | Queue item id (join key). |
| `status` | One of `open`, `done`, `skipped`, `blocked`. |
| `notes` | Short disposition, skip reason, or unblock hint. |
| `updated_at_utc` | Timestamp of the latest state update. |

## Minimal Example

Queue path:
`/codex/output/iterative_github_comments_items.txt`

```json
[
  {
    "id": "IGC-1",
    "order": 1,
    "item_type": "github_comment",
    "description": "Replace fragile null fallback with explicit validation.",
    "source_file": "src/app/member/member.service.ts",
    "source_line_start": 118,
    "source_line_end": 139,
    "code_context": "if (!membership) { return; }",
    "target_file": "src/app/member/member.service.ts",
    "priority": "high",
    "risk_context": "Silent early return hides data-contract problems.",
    "reference_url": "https://github.com/org/repo/pull/123#discussion_r1",
    "metadata": {
      "author": "reviewer-handle"
    }
  }
]
```

State path:
`/codex/output/iterative_github_comments_items_status.txt`

```tsv
id	status	notes	updated_at_utc
IGC-1	open		2026-04-16T20:00:00Z
```
