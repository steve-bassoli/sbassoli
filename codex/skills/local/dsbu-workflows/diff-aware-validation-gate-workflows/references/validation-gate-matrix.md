# Validation Gate Matrix (dsbu-workflows)

Use this matrix after running `scripts/recommend-validation-gate.ps1`.

## Risk Buckets

- `none`: no changed files.
- `low`: isolated module-level source/test/docs/automation updates.
- `medium`: multiple modules, service/model API wiring, shared backend abstractions, or MyBatis/DAO changes.
- `high`: root or module Gradle metadata, DB migration SQL, or broad cross-cutting edits.

## Required Commands by Change Type

- Source changes in one module (`<module>/src/main/**`): `./gradlew.bat :<module>:compileJava`
- Test changes in one module (`<module>/src/test/**`): `./gradlew.bat :<module>:test`
- Integration-test changes in one module (`<module>/src/integrationTest/**`): `./gradlew.bat :<module>:integrationTest`
- MyBatis mapper/resource changes (`dao/src/main/resources/mybatis/**`): `./gradlew.bat :dao:test`
- Root/module build metadata changes (`build.gradle`, `settings.gradle`, `gradle/**`, `<module>/<module>.gradle`):
  - `./gradlew.bat build -x test`
  - `node scripts/generate-bom-confluence.mjs` when root or module Gradle metadata may change dependencies or BOM output
- Docs/agent/codex-only changes: `<none>`

## Escalation Commands

- `medium` risk: run at least one relevant module test suite (for example `./gradlew.bat :service:test` or the touched module's `:test` task).
- `high` risk: `./gradlew.bat test` is required unless blocked by environment/dependencies.

## Skip and Block Rules

- Skip commands only when not applicable to touched files; record the reason.
- If blocked by environment, credentials, or dependency setup, mark as `Blocked`.
- Never report a full pass when required commands fail or are blocked.
