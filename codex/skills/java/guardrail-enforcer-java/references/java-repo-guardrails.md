# Java Repo Guardrails

Use this reference when applying `guardrail-enforcer-java`.

## Build Hooks

- `gradle/base.gradle` applies Spotless and makes `compileJava` depend on `spotlessApply`.
- `gradle/analysis.gradle` applies SonarQube configuration and enables `-Xlint` on `JavaCompile` when `codeAnalysisEnabled` is true.

## What That Means For Edits

- Keep Java formatting, license headers, and import ordering compatible with Spotless.
- Expect compile-time lint warnings to matter; avoid introduced unused imports and other obvious compiler-lint-sensitive issues.
- Keep changed code SonarQube-friendly:
  - no commented-out code
  - no needless nested conditionals when a simpler branch is clearer
  - no obviously duplicated branches or dead local code in touched scope
- In unit tests, avoid consecutive field-by-field `assertEquals(...)` chains; build an expected object and use a single `assertEquals(expected, actual)`.
- Preserve existing repo patterns for MyBatis XML, Gradle module files, and service/DAO wiring.

## Validation Guidance

- Prefer focused module validation first.
- If `compileJava` is run, Spotless may rewrite files; re-check the diff after validation.
- Use the repository's diff-aware validation gate when changes are multi-module, shared-module, DAO/MyBatis, or build-metadata related.
