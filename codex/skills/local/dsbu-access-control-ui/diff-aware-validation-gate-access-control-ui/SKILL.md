---
name: diff-aware-validation-gate-access-control-ui
description: Run a conditional post-edit validation gate in dsbu-access-control-ui by classifying git diff changes, selecting the minimum reliable checks, executing required commands, and reporting pass/fail for higher-risk or PR-ready work.
---

# Diff Aware Validation Gate

## Quick Start

1. Read [references/validation-gate-matrix.md](references/validation-gate-matrix.md).
2. Run `scripts/recommend-validation-gate.ps1` from repo root.
3. Execute all listed `Required commands` first.
4. Execute `Optional commands` when risk is medium/high, behavior changed, or confidence is low.
5. Report executed, skipped, and blocked commands with pass/fail.

## When Required

Use this skill when one or more of the following is true:

- Changes touch shared components, routing, permissions, API clients, or dependency metadata.
- The user asks for PR-ready/full validation confidence.
- Risk is medium/high and targeted file-scoped checks are not enough.

For small low-risk localized edits, skip this skill and run focused targeted validation only.

## Workflow

1. Collect changed files (staged, unstaged, untracked).
2. Classify touched areas and compute risk (`none`, `low`, `medium`, `high`).
3. Select the smallest command set that still gives confidence.
4. Run required commands from the correct working directory.
5. If a required command fails, either:
   - fix and rerun, or
   - report blocker and avoid claiming full validation.
6. Include gate summary in the final response:
   - risk level
   - required command results
   - optional commands run/skipped and why
   - validation pass rate (`passed/total`)

## Command Rules

- Run Yarn commands inside `html`.
- Avoid `yarn --cwd` from repo root for this repo.
- Prefer file-scoped checks when risk is low.
- Escalate to broader tests only for medium/high-risk changes or when targeted checks are insufficient.
- If no files changed, explicitly report `No validation commands required`.

## Output Requirements

- `Risk level`: `none`, `low`, `medium`, or `high`.
- `Executed`: command plus pass/fail.
- `Skipped`: command plus reason.
- `Blocked`: command plus blocker.
- `Gate result`: pass/fail with confidence note when any required command is skipped.

## Resources

- Use [scripts/recommend-validation-gate.ps1](scripts/recommend-validation-gate.ps1) to generate baseline recommendations.
- Use [references/validation-gate-matrix.md](references/validation-gate-matrix.md) for escalation decisions.
