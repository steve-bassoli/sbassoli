# Validation and Release Runbook

Use this runbook to choose the smallest reliable command set.

## Decision Matrix

### Case 1: TypeScript logic changes in `apps/designer/src` or shared libs

- Run targeted eslint for touched TS files.
- If behavior changes are meaningful, run the relevant package test command.
- Escalate to broader tests only when confidence is low.

### Case 2: HTML/SCSS changes in Angular packages

- Run formatting/lint checks for touched templates/styles.
- Add targeted package tests if behavior changed.

### Case 3: Dependency metadata changes

Trigger files:

- `package.json`
- `yarn.lock`
- `apps/designer/package.json`
- `libs/shared/angular/package.json`
- `libs/shared/utility/package.json`
- `libs/viewer/package.json`
- `libs/dataservicelib/package.json`

Actions:

1. Run `yarn install` at repo root.
2. Run impacted lint/test commands from this runbook.

## Canonical Commands

Run from repo root:

- `yarn eslint <files>`
- `yarn workspace designer run test:prod`
- `yarn test:shared-angular`
- `yarn test:viewer`
- `yarn workspace shared-utility run test:prod`
- `yarn workspace dataservicelib run test`

## Operational Constraints

- Use workspace-aware commands from repo root.
- Prefer targeted file/package checks before broader suites.
- For designer tests, ensure Kendo licensing prerequisites are available.

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
