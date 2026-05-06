---
name: iterative-github-comments
description: Review unresolved feedback iteratively from either a GitHub pull request URL or user-pasted review comments. Build `/codex/output/iterative_github_comments_items.txt` as an immutable queue and `/codex/output/iterative_github_comments_items_status.txt` as mutable status using the util-iterative-flat-file pattern, process one open item at a time with explicit user approval between items, and end with a full done/skipped/open/blocked status summary so remaining items are always visible. Use when a user asks to process code review comments iteratively.
---

# Iterative GitHub Comments

## Quick Start

1. Select intake mode:
   - **PR URL mode:** Run `scripts/build-unresolved-pr-comments.ps1 -PrUrl "<github-pr-url>"`.
   - **Manual mode:** Build `/codex/output/iterative_github_comments_items.txt` directly from user-pasted comments when no PR URL is provided.
2. For manual mode, sync status file with util script:
   - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1 -InvokingSkillName "iterative-github-comments"`
3. For PR URL mode, stop if the script reports repo mismatch or branch mismatch.
4. Reconcile queue completeness and ensure each item has `id`, `order`, `item_type`, and `description` with best-effort source/context metadata.
5. Ask: `Would you like me to start addressing unresolved comments one by one?`
6. Process one `open` item at a time using `/codex/output/iterative_github_comments_items_status.txt`.
7. After each item, ask: `Please review this change. Should I process the next unresolved comment?`
8. Keep both files after processing and present a full status summary that includes any remaining open/blocked items.

## Canonical Files

- Queue intake (immutable):
  - `/codex/output/iterative_github_comments_items.txt`
- Mutable progress state:
  - `/codex/output/iterative_github_comments_items_status.txt`
- Utility scripts:
  - `codex/skills/common/util-iterative-flat-file/scripts/sync-iterative-state.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1`
  - `codex/skills/common/util-iterative-flat-file/scripts/get-iterative-status-summary.ps1`

## Workflow

1. Validate intake inputs:
   - **PR URL mode:** Confirm URL format is `https://github.com/<owner>/<repo>/pull/<number>`, confirm local git `origin` repo matches the URL repo, and confirm local branch matches PR head branch.
   - **Manual mode:** Confirm the user provided a finite list of comments to process; if file/line is missing, keep `source_file=unknown` or line fields as `unknown` and continue.
2. Build `/codex/output/iterative_github_comments_items.txt`:
   - **PR URL mode:** Use `scripts/build-unresolved-pr-comments.ps1` (this script also syncs status using util-iterative-flat-file by default).
   - **Manual mode:** Append one queue item per pasted comment with required queue fields and best-effort source metadata, then run util sync script.
3. Reconcile queue completeness before starting fixes:
   - **PR URL mode:** Compare queue items against current open PR review comments from GitHub and append missing queue items.
   - **Manual mode:** Echo parsed queue summary to user and confirm no comment was dropped.
   - Re-run `sync-iterative-state.ps1 -InvokingSkillName "iterative-github-comments"` after queue changes.
4. Wait for explicit user approval before starting fixes.
5. For each unresolved comment:
   - Read the next `open` id from `/codex/output/iterative_github_comments_items_status.txt`.
   - Resolve the matching queue item in `/codex/output/iterative_github_comments_items.txt`.
   - Apply minimal code changes for that single item, or mark it as `skipped` with a concise reason.
   - Run targeted validation for the touched files.
   - Ask the user to review before continuing.
   - Update state with util script:
     - `powershell -File codex/skills/common/util-iterative-flat-file/scripts/set-iterative-item-status.ps1 -InvokingSkillName "iterative-github-comments" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
6. Repeat until no `open` items remain. Do not declare completion while any item is still `open` unless the user explicitly asks to stop.
7. If the user explicitly stops early, keep queue + status files and state that processing is incomplete with remaining `open` items.
8. Keep both files as persistent audit records.
9. End with `Comments Status Summary` in the user response:
   - `Total comments`: `<done + skipped + blocked + open>`
   - `Total processed`: `<done + skipped + blocked>`
   - `Done`: count
   - `Skipped`: count
   - `Blocked`: count
   - `Remaining open`: count
   - One line per done item: `[index] done - file:line - short disposition`
   - One line per skipped item: `[index] skipped - file:line - short disposition`
   - One line per blocked item: `[index] blocked - file:line - short disposition`
   - One line per open item: `[index] open - file:line - short disposition`

## Queue File Format

Treat `/codex/output/iterative_github_comments_items.txt` as intake source-of-truth.

Each item includes:
- Required:
  - `id`
  - `order`
  - `item_type` (`github_comment`)
  - `description`
- Recommended:
  - `source_file`
  - `source_line_start`
  - `source_line_end`
  - `code_context`
  - `target_file`
  - `priority`
  - `risk_context`
  - `reference_url`
  - `metadata`

Treat `/codex/output/iterative_github_comments_items_status.txt` as mutable progress source-of-truth.

Status file columns:
- `id`
- `status` (`open`, `done`, `skipped`, `blocked`)
- `notes`
- `updated_at_utc`

Manual mode entry template:
```text
[
  {
    "id": "IGC-1",
    "order": 1,
    "item_type": "github_comment",
    "description": "<raw review comment>",
    "source_file": "<path or unknown>",
    "source_line_start": "<line number or unknown>",
    "source_line_end": "<line number or unknown>",
    "code_context": "<best-effort code context>",
    "target_file": "<path or unknown>",
    "priority": "high",
    "risk_context": "Unresolved PR feedback item",
    "reference_url": "<comment/permalink or n/a>",
    "metadata": {}
  }
]
```

## Script

For PR URL mode, use `scripts/build-unresolved-pr-comments.ps1` to generate the queue file.

The script:
- Parses and validates the PR URL.
- Verifies local repo/branch alignment with the PR.
- Queries unresolved review threads from GitHub.
- Writes a util-compatible JSON queue at `/codex/output/iterative_github_comments_items.txt`.
- Syncs `/codex/output/iterative_github_comments_items_status.txt` via util-iterative-flat-file by default.

For manual mode, create or update `/codex/output/iterative_github_comments_items.txt` directly from user-provided comments using the queue format above, then run the util sync script.
