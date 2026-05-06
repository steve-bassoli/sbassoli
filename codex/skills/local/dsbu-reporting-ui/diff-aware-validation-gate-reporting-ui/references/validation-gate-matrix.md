# Validation Gate Matrix

Use this matrix after running `scripts/recommend-validation-gate.ps1`.

## Risk Buckets

- `none`: no changed files.
- `low`: isolated page-level updates, docs-only edits, or narrow TS changes.
- `medium`: multiple feature files, API/page wiring, or cross-area feature changes.
- `high`: shared components, routing, permission logic, dependency metadata, or cross-package changes.

## Required Commands by Change Type

- TypeScript in Angular packages:
  - `yarn eslint <touched-ts-files>`
- Dependency metadata:
  - `yarn install` when root or workspace dependency metadata changed
- Shared library source changes:
  - `yarn test:shared-angular` when `libs/shared/angular/src/**` changed
  - `yarn test:viewer` when `libs/viewer/src/**` changed
  - `yarn workspace shared-utility run test:prod` when `libs/shared/utility/src/**` changed
  - `yarn workspace dataservicelib run test` when `libs/dataservicelib/**` changed

## Escalation Commands

- `medium` risk: run one relevant behavior check (usually `yarn workspace designer run test:prod`) when flow-level behavior changed.
- `high` risk: `yarn workspace designer run test:prod` is required when `apps/designer/src/**` is touched, unless blocked by environment or dependency setup.

## Skip and Block Rules

- Skip commands only when not applicable to touched files; record the reason.
- If blocked by environment, licensing, or missing dependencies, mark the command as `Blocked`.
- Never report a full pass when required commands fail or are blocked.
