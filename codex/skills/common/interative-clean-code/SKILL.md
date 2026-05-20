---
name: interative-clean-code
description: Build and optionally execute an iterative clean-code queue for exactly one source file, focused on overly cautious null checks, empty checks, defensive defaults, redundant sanitization, and similar guard code. Use when the user asks to clean up defensive checks, introduce non-null contracts, apply Clean Code-style simplification, or audit one Processor, Controller, DAO, mapper/mapping, validator, client, configuration, or similar class against precedent from related files.
---

# Interative Clean Code

## Quick Start

1. Require exactly one target file path. If the request names zero or multiple files, ask the user to choose one.
2. Read the target file in full.
3. Classify the target role from name/package, such as `Processor`, `Controller`, `Dao`, `Mapper`, `Mapping`, `Validator`, `Client`, `Configuration`, `Service`, `Utility`, or `Model`.
4. Build precedent from related code before judging a check as overly cautious.
5. Write queue items to `/codex/output/interative_clean_code_items.txt`.
6. Sync mutable state:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "interative-clean-code"`
7. If the user asked only for options/audit, stop after reporting the queue summary.
8. If the user asked to execute/fix, process one `open` item at a time, validate, update status, and ask before continuing.

## Canonical Files

- Queue intake:
  - `/codex/output/interative_clean_code_items.txt`
- Mutable progress state:
  - `/codex/output/interative_clean_code_items_status.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Precedent Search

Use `rg` first.

1. Search the target file for defensive-check candidates:
   - `== null || .*\.isEmpty\(\)`
   - `== null \? Collections\.empty`
   - `Objects::nonNull`
   - `filter\(Objects::nonNull\)`
   - `Optional\.ofNullable`
   - `StringUtils\.isBlank|StringUtils\.isEmpty`
   - helper names like `sanitize`, `normalize`, `safe`, `default`, `emptyIfNull`
2. Search direct collaborators:
   - callers and callees of candidate methods
   - tests covering the candidate behavior
   - request/response/model classes passed through candidate methods
3. Search same-package and same-domain files.
4. If the target role is clear, perform an exhaustive same-role precedent pass across the solution:
   - `*Processor.java` for a Processor
   - `*Controller.java` for a Controller
   - `*Dao.java` and DAO interfaces/resources for a DAO
   - `*Mapper.java`, `*Mapping*.java`, generated mapper-adjacent code for mapping
   - `*Validator.java` for a Validator
   - `*Client.java` for a Client
   - `*Configuration.java` for Configuration
5. Exhaustive means every same-role file is included in the search set. Use `rg` and targeted section reads when the set is large, but report how many same-role files were searched and which patterns were checked.

## Candidate Rules

Create a queue item only when there is evidence the defensive code is likely unnecessary or misplaced.

Good candidates:

- Internal method accepts `null` but callers and same-role precedent imply non-null inputs.
- A null check converts a caller bug into an empty result.
- A helper only wraps a one-line null/empty/default pattern and has one or two local uses.
- A collection is sanitized after being built locally from non-null-filtered data.
- A branch returns `Collections.emptyMap`, `emptySet`, or `emptyList` where fail-fast or a non-null contract is clearer.
- A check duplicates validation already done by the caller, request validator, framework, or DAO contract.

Do not queue:

- Boundary checks for controllers, deserialization, external clients, external API responses, user input, legacy data, database rows, or nullable request fields.
- Checks where related code consistently accepts `null` as a documented value.
- Checks needed to preserve existing API compatibility.
- Checks on collection elements when no element-level non-null contract exists.
- Checks whose removal would require broad contract migration outside the one target file.

## Queue Item Requirements

Use the util-iterative-flat-file unified fields.

Required:

- `id`
- `order`
- `item_type` (`clean_code_candidate`)
- `description`

Recommended:

- `source_file`
- `source_line_start`
- `source_line_end`
- `code_context`
- `target_file`
- `priority` (`high`, `medium`, `low`)
- `risk_context`
- `metadata`

Each `metadata` block should include:

- `candidate_type`
- `current_behavior`
- `why_overly_cautious`
- `same_role_precedent`
- `direct_collaborator_precedent`
- `recommended_change`
- `validation`
- `non_goals`

Use stable IDs like `clean-code-001`.

## Intake Workflow

1. Read the target file and gather candidate line numbers.
2. Run the precedent search before writing any queue item.
3. For each candidate, decide:
   - `queue`: evidence supports cleanup
   - `skip`: defensive check is justified
   - `blocked`: contract cannot be inferred without user/domain input
4. Write only queued candidates to `/codex/output/interative_clean_code_items.txt`.
5. Keep skipped/blocker rationale in the chat summary unless the user asks for an exhaustive report.
6. Sync the status file with the util script.
7. Summarize:
   - target file
   - target role
   - same-role files searched
   - candidate count by priority
   - top 3 candidates
   - blockers or assumptions

## Execution Workflow

1. Read `/codex/output/interative_clean_code_items_status.txt`.
2. Pick the earliest `open` item.
3. Re-read the target code and immediate collaborators for that item.
4. Make the smallest behavior-preserving edit:
   - prefer removing local guard/helper code
   - use `Objects.requireNonNull` only when a fail-fast contract is useful and locally consistent
   - use `@Nullable` only where null is genuinely accepted
   - use package-level non-null defaults only when the user explicitly authorizes contract rollout
5. Validate with the smallest relevant command:
   - source-only Java change: module compile or focused test already covering the area
   - test-only change: focused test
   - no code change: no validation command required
6. Update status:
   `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "interative-clean-code" -ItemId "<id>" -Status done|blocked|skipped -Notes "<short disposition>"`
7. Report the item outcome and ask whether to continue to the next open item.

## Cleanup Judgment

Prefer clarity over dogma. Do not remove defensive checks simply because they look cautious. Remove or rewrite them when the surrounding code establishes a stronger contract and the cleanup makes incorrect calls fail earlier or makes normal control flow simpler.

When evidence is mixed, queue the item as lower priority or block for user confirmation rather than making a speculative edit.
