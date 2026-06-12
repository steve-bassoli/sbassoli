---
name: iterative-smells
description: Run iterative code-smell scans that track findings one item at a time in flat files. Use when Codex needs to search a codebase for design smells, overlap between modules, boundary leaks, N+1 lookups, authorization drift, or duplicated domain rules, and write the findings to durable queue/status artifacts for follow-up work.
---

# Iterative Smells

## Quick Start

1. Define the review scope before searching. Capture the focal files, the adjacent modules, and the smell themes to test.
2. Search the codebase for the focal symbols and neighboring concepts.
3. Read the relevant files in full before declaring a smell.
4. Write the human-readable findings report to `codex/output/iterative-smells.txt`.
5. Write immutable queue intake to `codex/output/iterative_smells_items.txt` using the util-iterative-flat-file schema.
6. Sync mutable state:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "iterative-smells"`
7. Process one `open` smell at a time and update only the state file:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "iterative-smells" -ItemId "<id>" -Status done -Notes "<short disposition>"`

## Review Workflow

1. Start from the user-named file or subsystem.
2. Expand outward with targeted search for callers, collaborators, duplicated rules, and alternate resolution paths.
3. Prefer smells that are concrete and actionable:
   - responsibility overlap across processors/services
   - authorization derived multiple ways for the same entity
   - collection helpers that silently pick the first element
   - DAO or client lookups inside per-item loops
   - one subsystem bypassing another subsystem's invariants
   - full-tenant enumeration hidden inside common helpers
4. Anchor every finding with exact file paths and line numbers.
5. Reject low-signal style nits. A smell must imply maintenance risk, correctness risk, or performance risk.

## Findings File Contract

Write one block per smell to `codex/output/iterative-smells.txt`:

```text
Issue: <incrementing number>
Status: <Open|Done|Skipped|Blocked>
File: <relative/path/to/file>
Line: <line number>
Context: <concise code excerpt or summary>
What to fix: <specific remediation direction>
```

Write the immutable queue to `codex/output/iterative_smells_items.txt` as a JSON array.

Required fields:
- `id`
- `order`
- `item_type`
- `description`

Recommended fields:
- `source_file`
- `source_line_start`
- `source_line_end`
- `code_context`
- `target_file`
- `priority`
- `risk_context`
- `metadata`

Use `code_smell` for `item_type` unless a more specific subtype is necessary.

## Knowledge From This Pass

Read `references/smell-patterns.md` when the request is about overlap between business processors, task flows, access-control helpers, or memberships. It captures the concrete smell patterns found in `dsbu-workflows` and generalizes them into reusable checks.

## Constraints

1. Keep queue intake immutable after generation unless new intake data arrives.
2. Keep mutable progress only in `codex/output/iterative_smells_items_status.txt`.
3. Use only `open`, `done`, `skipped`, or `blocked` in the status file.
4. Do not call something a smell unless you can name the risk and the likely boundary that should own the fix.
5. Prefer cross-file findings over isolated local style comments.
