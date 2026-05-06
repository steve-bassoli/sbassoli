# Validation Gate Matrix

Use this matrix after running `scripts/recommend-validation-gate.ps1`.

## Risk Buckets

- `none`: no changed files.
- `low`: isolated page-level updates, docs-only edits, or narrow TS changes.
- `medium`: multiple feature files, API/page wiring, or cross-area feature changes.
- `high`: shared components, routing, permission logic, dependency metadata, or cross-package changes.

## Required Commands by Change Type

- TypeScript in `html/src`: `cd html && yarn eslint <touched-ts-files>`
- Dependency metadata:
  - `cd html && yarn install` when `html/package.json` or `html/yarn.lock` changed
  - `cd dataservicelib-v2 && yarn install` when `dataservicelib-v2/package.json` or `dataservicelib-v2/yarn.lock` changed
  - `cd dataservicelib-v3 && yarn install` when `dataservicelib-v3/package.json` or `dataservicelib-v3/yarn.lock` changed
  - `node scripts/generate-bom-confluence.mjs` when any dependency metadata changed
- Dataservice library source changes:
  - `cd dataservicelib-v2 && yarn test`
  - `cd dataservicelib-v3 && yarn test`

## Escalation Commands

- `medium` risk: run one relevant behavior check (usually `cd html && yarn test:prod`) when flow-level behavior changed.
- `high` risk: `cd html && yarn test:prod` is required unless blocked by environment or dependency setup.

## Skip and Block Rules

- Skip commands only when not applicable to touched files; record the reason.
- If blocked by environment, licensing, or missing dependencies, mark the command as `Blocked`.
- Never report a full pass when required commands fail or are blocked.
