---
apply: always
---

## Scope

Repository: `dsbu-reporting-service` only.

## Skills

### Available skills (custom)

- `best-practices-java`: audit changed Java and Spring Boot files for high-value best-practice gaps and remediate iteratively.  
  File: `C:/work/dsbu-reporting-service/codex/skills/java/best-practices-java/SKILL.md`
- `guardrail-enforcer-java`: enforce Java/backend repo guardrails for `.java`, Gradle, and MyBatis changes, including Spotless/Xlint/SonarQube-sensitive hygiene in touched scope.  
  File: `C:/work/dsbu-reporting-service/codex/skills/java/guardrail-enforcer-java/SKILL.md`
- `diff-aware-validation-gate-workflows`: conditional post-edit validation for medium/high-risk or PR-ready backend work.  
  File: `C:/work/dsbu-reporting-service/codex/skills/local/diff-aware-validation-gate-workflows/SKILL.md`
- `iterative-unit-tests`: iterative unit test backlog/execution with approval between items.  
  File: `C:/work/dsbu-reporting-service/codex/skills/common/iterative-unit-tests/SKILL.md`
- `iterative-abstraction-check`: duplicate/repeated-logic and scaffolding-artifact iterative gate.  
  File: `C:/work/dsbu-reporting-service/codex/skills/common/iterative-abstraction-check/SKILL.md`
- `iterative-github-comments`: process unresolved PR comments iteratively with status tracking.  
  File: `C:/work/dsbu-reporting-service/codex/skills/common/iterative-github-comments/SKILL.md`
- `iterative-implementation`: write step plan to `./agent/implementation-steps.txt` and execute iteratively.  
  File: `C:/work/dsbu-reporting-service/codex/skills/common/iterative-implementation/SKILL.md`

### Available skills (system)

- `skill-creator`  
  File: `C:/Users/steve.bassoli/AppData/Local/JetBrains/IntelliJIdea2025.3/aia/codex/skills/.system/skill-creator/SKILL.md`
- `skill-installer`  
  File: `C:/Users/steve.bassoli/AppData/Local/JetBrains/IntelliJIdea2025.3/aia/codex/skills/.system/skill-installer/SKILL.md`

## Skill Rules

- Trigger a skill when the user names it (with `$SkillName` or plain text) or when the task clearly matches the skill description.
- If multiple skills match, use the minimal set and state the order.
- Do not carry skills across turns unless re-mentioned.
- `diff-aware-validation-gate-workflows` is conditional, not mandatory every turn.
- Use `diff-aware-validation-gate-workflows` for medium/high-risk changes or PR-ready validation.
- For low-risk localized changes, run targeted validation only and summarize what ran.
- If a named skill is missing or unreadable, state it briefly and continue with the best fallback.

## Skill Use Workflow

- Open the selected `SKILL.md` and read only what is needed.
- Resolve skill-referenced relative paths from the skill directory first.
- Load only the necessary referenced files; do not bulk-load assets/references.
- Prefer provided scripts/assets/templates over recreating equivalent content.

## Skill Execution Metrics

- If one or more custom (non-system) skills were used, include `Skill Execution Metrics` in the final response.
- Include: `Skills used` and `Skill-trigger reason`.
- Omit this section if no custom skill was executed.

## Repository Guardrails

1. Read relevant code before edits.
2. Keep changes minimal unless a selected skill requires broader implementation.
3. Follow existing precedent and abstract reusable code.
4. Scope new code strictly to the request.
5. No unrelated refactors.
6. Do not update unit tests unless explicitly asked.
7. Run appropriate post-edit validation after edits.
8. For implementation plans, output only implementation steps for developer verification.
9. Do not proactively block or disable user actions to prevent expected backend/API failures unless explicitly requested.
10. At task close, include `Skill recommendation` with proposed name/trigger/scope if a reusable pattern is likely for 2+ future requests; otherwise include `Skill recommendation: None` with a one-line reason.
11. Start each task with a task contract using exactly: `Goal`, `Out of scope`, `Acceptance criteria`, `Validation command(s)`, `Constraints`.
12. Allow quick mode only for tiny, low-risk requests; quick mode still requires acceptance criteria and validation command(s).
13. Do not add low-value unit tests unless explicitly requested.
