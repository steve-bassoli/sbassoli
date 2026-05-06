# Java and Spring Review Rules

Use this reference when applying `best-practices-java`.

## Repository Context

- Controllers live primarily under `service` and `internal-service`.
- Business orchestration typically lives in `business-logic` processors/components.
- Persistence and SQL concerns live in `dao` and MyBatis resources.
- The repo already uses Java records for immutable data carriers in `domain`, `common`, and elsewhere.
- Some legacy classes use `@Autowired`; prefer constructor injection for new work, but do not churn stable code only to remove existing annotations.

## High-Value Review Focus

- Dependency injection and bean boundaries:
  - prefer constructor injection for new dependencies
  - avoid adding field injection or hidden mutable bean state
- Layering:
  - controllers should not absorb business logic
  - DAOs/MyBatis should not absorb HTTP or permission concerns
- Exceptions:
  - favor shared application/resource exception patterns already used in the repo
  - catch broadly only when translating a boundary and preserving intended behavior
- API/data modeling:
  - prefer typed request/response and domain structures over loose `Object`-based plumbing
  - use records or immutable carriers where behavior is not required
- Deprecated API hygiene:
  - treat deprecations in touched scope as high-signal when low-risk replacements exist
  - for Commons Lang 3.18+, avoid deprecated `StringUtils` delegator methods (for example `equals`, `compare*`, `contains*`, `startsWith*`, `endsWith*`) and use `org.apache.commons.lang3.Strings` or equivalent repository-standard replacements
- Maintainability:
  - keep methods cohesive
  - extract helpers when a method mixes too many concerns
  - avoid dead branches and commented-out code in touched scope

## Validation Pairing

- For review fixes in one module, prefer `./gradlew.bat :<module>:compileJava`.
- If behavior or tests changed, run the smallest relevant `:test` or `:integrationTest`.
- If the diff is cross-cutting, shared-module, DAO/MyBatis, or build-related, pair the review with the repository's diff-aware validation gate when one is available.
