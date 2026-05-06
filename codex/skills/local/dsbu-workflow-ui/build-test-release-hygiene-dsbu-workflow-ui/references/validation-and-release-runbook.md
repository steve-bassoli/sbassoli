# Validation and Release Runbook

Use this runbook to choose the smallest reliable command set.

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
- `dataservicelib-v2/package.json`
- `dataservicelib-v2/yarn.lock`
- `dataservicelib-v3/package.json`
- `dataservicelib-v3/yarn.lock`

Actions:

1. Install dependencies in affected project directories.
2. Regenerate BOM with `node scripts/generate-bom-confluence.mjs`.
3. Verify BOM output.

## Canonical Commands

Run from `html`:

- `yarn eslint <files>`
- `yarn test:prod`
- `yarn test:coverage`

Run from repo root:

- `node scripts/generate-bom-confluence.mjs`

## Operational Constraints

- Run Yarn commands inside each project directory.
- Avoid `yarn --cwd` for this repo.
- If Kendo license activation is required, ensure environment is configured first.

## Reporting Format

- Executed:
  - command
  - pass/fail
- Skipped:
  - command
  - reason
- Blocked:
  - command
  - blocker
