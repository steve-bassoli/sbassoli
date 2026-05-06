---
name: best-practices-java
description: Audit changed Java and Spring Boot files in the active repository for high-value best-practice gaps. Write a human-readable findings report to `/codex/output/best-practices-java.txt`, maintain iterative queue/status using util-iterative-flat-file artifacts at `/codex/output/best_practices_java_items.txt` and `/codex/output/best_practices_java_items_status.txt`, and remediate one issue at a time. Use when a user asks for a Java best-practices review, a Spring Boot quality scan, or iterative remediation of changed backend files with tracked findings.
---

# Java Best Practices

## Workflow

1. Determine the comparison base branch (use the repository default branch unless the user specifies one) and compute changed files with `git diff --name-only <base-branch>...HEAD`.
2. Restrict scope to changed backend files that materially affect Java/Spring behavior:
   - `*/src/main/java/**`
   - `*/src/test/java/**`
   - `*/src/integrationTest/java/**`
   - Spring-relevant config files such as `application*.yml`, `application*.yaml`, or `application*.properties` when changed with the Java work
3. Read [references/java-spring-review-rules.md](references/java-spring-review-rules.md).
4. Review each changed file in full, not only changed hunks.
5. Perform a deprecated-API scan for touched Java files and include actionable replacements in findings:
   - Prefer non-deprecated APIs when low-risk replacements exist in touched scope.
   - For Commons Lang `3.18+`, treat `StringUtils.*` deprecated delegators as actionable (for example `equals`, `compare*`, `contains*`, `startsWith*`, `endsWith*`) and migrate to `org.apache.commons.lang3.Strings` variants or equivalent repository-standard alternatives.
6. Write findings to:
   - Human-readable report: `/codex/output/best-practices-java.txt`
   - Immutable queue intake: `/codex/output/best_practices_java_items.txt`
7. Sync mutable status state with util-iterative-flat-file:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "best-practices-java"`
8. Fix one `open` violation at a time using `/codex/output/best_practices_java_items_status.txt`.
9. After each fix, stop and ask the user whether to continue to the next fix.

## Canonical Files

- Human-readable report:
  - `/codex/output/best-practices-java.txt`
- Queue intake (immutable):
  - `/codex/output/best_practices_java_items.txt`
- Mutable progress state:
  - `/codex/output/best_practices_java_items_status.txt`
- Utility scripts:
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1`
  - `C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\get-iterative-status-summary.ps1`

## Java and Spring Review Rules

1. Prefer constructor injection for new Spring dependencies; avoid introducing new field injection. If a class already uses constructor injection, extend that pattern instead of mixing styles.
2. Keep controllers thin: HTTP mapping, status codes, and request/response translation belong in controllers; orchestration belongs in processors/services; SQL and mapper details belong in DAOs/MyBatis.
3. Keep Spring beans cohesive. Avoid constructor side effects, hidden global state, and oversized methods that combine validation, authorization, persistence, and response building.
4. Prefer immutable or clearly bounded data carriers for DTO/domain transport types. Use records where appropriate and aligned with existing repo patterns; avoid unnecessary mutable state.
5. Avoid returning `null` from new code when `Optional`, empty collections, or explicit exception handling communicate intent better.
6. Catch exceptions only when adding context, translating boundaries, or preserving behavior. Prefer specific exception handling over broad `catch (Exception)`.
7. Preserve repository conventions for shared exception types, `ResponseEntity` usage, permission annotations, and `UserRequestInformation` flow rather than inventing alternate patterns.
8. Favor type-safe APIs. Avoid raw types, unnecessary `Object` plumbing, and unchecked casts unless guarded and justified.
9. Keep transactional and side-effect boundaries explicit. Do not bury remote calls, writes, or permission decisions inside low-level helpers without a clear ownership boundary.
10. Focus on maintainability, correctness, and framework usage. Do not emit low-signal stylistic nits.
11. Treat newly introduced or newly surfaced deprecation warnings in touched scope as actionable when a safe, local replacement exists.

## Findings File Contract

Write one block per issue to `/codex/output/best-practices-java.txt`:

```text
Issue: <incrementing number>
Status: <Open|Done|Skipped|Blocked>
File: <relative/path/to/file>
Line: <line number>
Context: <concise code excerpt or summary of the relevant line/block>
What to fix: <actionable correction aligned to repo conventions>
```

Include only findings that are meaningfully actionable for the current repository.

Also write queue items to `/codex/output/best_practices_java_items.txt` as a JSON array using util-iterative-flat-file schema:

- Required:
  - `id` (example: `BPJ-1`)
  - `order`
  - `item_type` (`java_best_practice`)
  - `description`
- Recommended:
  - `source_file`
  - `source_line_start`
  - `source_line_end`
  - `code_context`
  - `target_file`
  - `priority`
  - `risk_context`
  - `metadata` (include `what_to_fix` and related context)

After writing/refreshing the queue file, always run:

`powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\sync-iterative-state.ps1 -InvokingSkillName "best-practices-java"`

## Remediation Loop

1. Apply one fix.
2. Run targeted validation for the modified file(s), typically `./gradlew.bat :<module>:compileJava` or a focused module test when behavior changed.
3. Update mutable status with util script:
   - `powershell -File C:\work\sbassoli\codex\skills\common\util-iterative-flat-file\scripts\set-iterative-item-status.ps1 -InvokingSkillName "best-practices-java" -ItemId "<id>" -Status done|skipped|blocked -Notes "<short disposition>"`
4. Reflect the same status in `/codex/output/best-practices-java.txt`.
5. Report the change briefly.
6. Prompt user: `Issue <n> fixed. Continue to issue <n+1>?`
7. Continue only after user confirmation.

## Constraints

1. Keep scope limited to changed backend files for the scan.
2. Assess the entire changed files, not just line-level diff hunks.
3. Respect established repo patterns even when a more general Java style-guide preference exists.
4. Use `guardrail-enforcer-java` for touched-scope hygiene/compliance and the repository's diff-aware validation gate when review fixes increase risk.
5. Use util-iterative-flat-file queue/state files for iterative status tracking; do not create alternate mutable status artifacts.
