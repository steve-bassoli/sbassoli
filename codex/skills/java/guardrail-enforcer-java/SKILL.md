---
name: guardrail-enforcer-java
description: Enforce Java/backend repository guardrails in the active repository. Use when editing `.java`, Gradle, or MyBatis files to keep changes aligned with the repository's Spotless, Xlint, and SonarQube expectations, clean up introduced Java-hygiene issues in touched scope, and choose focused validation before concluding work.
---

# Java Guardrail Enforcer

## Workflow

1. Use this skill when the task changes backend files such as:
   - `*/src/main/**`, `*/src/test/**`, or `*/src/integrationTest/**`
   - `dao/src/main/resources/mybatis/**`
   - `build.gradle`, `settings.gradle`, `gradle/**`, or `<module>/<module>.gradle`
2. Read [references/java-repo-guardrails.md](references/java-repo-guardrails.md).
3. Review touched files in full, not just changed hunks, and enforce these guardrails:
   - Keep formatting, import order, and license-header-sensitive edits compatible with Spotless.
   - Do not leave introduced unused imports, obviously dead code, or compiler-lint-sensitive issues in touched scope.
   - Keep control flow and null-handling SonarQube-friendly; avoid needless nesting, duplicated branches, and commented-out code.
   - Preserve existing repository patterns for Java, Gradle, and MyBatis changes; avoid opportunistic refactors.
4. Fix violations with minimal, pattern-consistent edits in the touched scope.
5. Run focused validation:
   - localized Java source change: `./gradlew.bat :<module>:compileJava`
   - test-only change: `./gradlew.bat :<module>:test`
   - integration-test change: `./gradlew.bat :<module>:integrationTest`
   - shared, multi-module, or build-risk change: use the repository's diff-aware validation gate when one is available
6. Report guardrails enforced, fixes applied, and validation commands run.

## Scope Rules

- Apply to newly added or modified code in the files you touch.
- If a pre-existing issue is outside touched scope, do not widen scope unless the user asks.
- If a nearby pre-existing issue in the touched file would clearly break compile/format/compliance confidence, fix it as part of the same change.

## Output Expectations

- Guardrails enforced.
- Violations fixed.
- Validation commands run and result.
- Deferred issues or blockers.
