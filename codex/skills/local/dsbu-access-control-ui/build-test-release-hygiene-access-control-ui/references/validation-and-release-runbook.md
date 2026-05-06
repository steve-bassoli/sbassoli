# Validation Runbook

Use this runbook to choose the smallest reliable command set.

## Baseline Selection

- Compute changed files from `master` merge-base with:
  - `scripts/recommend-checks.ps1 -RepoRoot <repo-root> -BaseBranch master`
- Use the script output as the source of truth for touched files.
- If no files are changed against baseline, skip lint/test unless explicitly requested.

## Decision Matrix

### Case 1: TypeScript logic changes in `html/src`

- Run targeted eslint for touched TS files.
- If behavior changes are meaningful, run relevant tests.
- Escalate to wider tests only when confidence is low.

### Case 2: HTML/SCSS changes

- Run formatting/lint checks for touched templates/styles.
- Add targeted component tests if behavior changed.

### Case 3: Dependency metadata changes

Trigger files:

- `html/package.json`
- `html/yarn.lock`

Actions:

1. Install dependencies in `html`.
2. Re-run targeted lint/test checks for touched areas.

## Canonical Commands

Run from `html`:

- `yarn eslint <touched-ts-files>`
- `yarn test:prod`
- `yarn test:coverage`

## Operational Constraints

- Run Yarn commands inside `html`.
- Avoid `yarn --cwd` for this repo.
- If Kendo license activation is required, ensure environment is configured first.

## Reporting Format

- Baseline:
  - base ref + merge-base SHA
- Executed:
  - command
  - pass/fail
- Skipped:
  - command
  - reason
- Blocked:
  - command
  - blocker
