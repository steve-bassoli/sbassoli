# Abstraction Rules

## Scope

- Preferred scan scope: compare against a baseline ref (typically `master`) using `-CompareRef`.
  - tracked diff: merge-base(`CompareRef`, `HEAD`) to current worktree
  - include untracked files
- Fallback scan scope (when `-CompareRef` is omitted): uncommitted-only
  - staged diff
  - unstaged diff
  - untracked files
- Analyze added code only for duplication candidates.

## Detection Passes

1. Exact pass:
   - Normalize whitespace.
   - Default window size: `4` meaningful lines.
2. Structural pass:
   - Normalize whitespace.
   - Replace literals and identifiers to detect copy-with-rename patterns.
   - Default window size: `6` meaningful lines.

## Noise Controls

- Ignore mostly-import windows.
- Ignore punctuation-only windows.
- Ignore empty/comment-only windows.
- De-prioritize spec/test files.
- Skip candidates whose affected files exceed the net-added-lines threshold (`MaxNetAddedLinesForCandidate`, default `80`).

## Severity Policy

- `high`:
  - production-code duplicates across `2+` files from exact pass, or
  - production-code structural duplicates across `2+` files with window size `>= 6`.
- `medium`:
  - duplicates across `2+` files with at least one production file.
- `low`:
  - duplicates found only in tests/specs or low-confidence patterns.

## Gate Policy

- `fail` when `high > 0`.
- `warn` when `high = 0` and `medium > 0`.
- `pass` when `high = 0` and `medium = 0`.

## Persistence Contract

Always append to `/codex/output/iterative_abstraction_check_run_log.txt` with sections:

1. `RUN_START`
2. `RAW_DIFF_STAGED`
3. `RAW_DIFF_UNSTAGED`
4. `FINDINGS`
5. `DECISION`
6. `RUN_END`

When `-CompareRef` is set, include `compare_ref`, `compare_ref_sha`, and `merge_base_sha` metadata in `RUN_START` and `DECISION`.

On any exception, write:

- `ERROR` (before `RUN_END`)

Maintain pending candidates in `/codex/output/iterative_abstraction_check_candidates.txt` as a mutable queue:

- Add/sync candidates from current findings by stable candidate ID.
- Remove candidate when resolved (`-ResolveCandidateId`).
- Always prompt next pending candidate (highest severity first).
