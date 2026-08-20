---
apply: always
---

## Scope

Repository: `dsbu-access-control-service` only.

## Skills

### Custom skill discovery paths

Custom skills are discovered from these path patterns. Do not mirror individual skill names or descriptions here; read the matching `SKILL.md` frontmatter at execution time so additions, removals, and descriptions stay current.

- `C:/work/sbassoli/codex/skills/local/dsbu-access-control-service/*/SKILL.md`
- `C:/work/sbassoli/codex/skills/java/*/SKILL.md`
- `C:/work/sbassoli/codex/skills/common/*/SKILL.md`
- `C:/work/sbassoli/codex/skills/other/*/SKILL.md`

### System skills

System skills are provided by the current Codex runtime. Use the session's skill registry and do not hardcode IDE-versioned system skill paths here.

## Skill Rules

- Discover custom skills by reading `SKILL.md` frontmatter from the paths above when task matching is needed.
- Trigger a discovered skill when the user names it (with `$SkillName` or plain text) or when the task clearly matches the skill description.
- If multiple skills match, use the minimal set and state the order.
- Do not carry skills across turns unless re-mentioned.
- Use the iterative implementation skill at `C:/work/sbassoli/codex/skills/common/iterative-implementation/SKILL.md` for multi-step refactors or feature additions.
- A discovered repo-local validation-gate skill is conditional, not mandatory every turn.
- Use the matching repo-local validation-gate skill for medium/high-risk changes or PR-ready validation.
- For low-risk localized changes, run targeted validation only and summarize what ran.
- If a named skill is missing or unreadable, state it briefly and continue with the best fallback.

## Skill Use Workflow

- Open the selected `SKILL.md` and read only what is needed.
- Resolve skill-referenced relative paths from the skill directory first.
- Load only the necessary referenced files; do not bulk-load assets/references.
- Prefer provided scripts/assets/templates over recreating equivalent content.

## Iterative Implementation Skill Rules (CRITICAL)

- When executing the iterative implementation skill at `C:/work/sbassoli/codex/skills/common/iterative-implementation/SKILL.md`, always write the plan to `./codex/output/iterative_implementation_items.txt` and sync the status file before doing code work.
- Do not execute any step until the plan file exists and the user has confirmed.
- Do not create test files as part of an iterative implementation plan step unless the user explicitly requests tests.
- Each step must produce file output (edits or creates). Prose-only responses for an execute command are not acceptable.
- After completing a step, confirm the file paths written and wait for user verification before proceeding.

## Non-Negotiable GitHub Write Ban

- Never create, reply to, update, delete, submit, resolve, or react to GitHub PR/issue/review comments.
- Treat requests like `address comments`, `process comments`, `next`, iterative GitHub-comment processing, `review PR`, or a PR URL as permission to read GitHub comments and make local code/status-file changes only.
- If asked to post/reply/comment/review/react/resolve on GitHub, provide the exact text or action as a local draft in chat and state that GitHub/CR writes are disabled.
- Prohibited always: `_add_comment_to_issue`, `_reply_to_review_comment`, `_add_review_to_pr`, `_update_issue_comment`, `_update_review_comment`, reaction tools, and any equivalent GitHub write tool.

## Skill Execution Metrics

- If one or more custom (non-system) skills were used, include `Skill Execution Metrics` in the final response.
- Include: `Skills used` and `Skill-trigger reason`.
- Use `N/A` when a metric cannot be measured reliably.
- Omit this section if no custom skill was executed.

## Repository Guardrails

1. Read relevant code before edits.
2. Keep changes minimal unless a selected skill requires broader implementation.
3. Follow existing precedent and abstract reusable code only when the precedent is clear.
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
14. Prefer happy-path implementation that follows local precedent. Do not add defensive null/empty checks unless existing nearby code requires them.

## Repository Conventions

- **Language/framework:** Java/Spring Boot multi-module Gradle service.
- **Test framework:** TestNG + Mockito.
- **Persistence:** MyBatis mappers call PostgreSQL functions managed through Liquibase migration files.
- **Code style:** Spotless with repository import ordering and license headers.
- **Request/response models:** Prefer records and immutable copied collections where existing service-model requests do so.
- **Layering:** Keep controllers thin; processors orchestrate behavior; DAOs handle MyBatis/database calls.
- **Assignment APIs:** Prefer one DAO/mapper/database call for combined assignment operations rather than controller or processor fan-out.

## Module Structure

| Module | Purpose |
|---|---|
| `business-logic` | Core processors and orchestration |
| `client` | Service clients |
| `common` | Shared service utilities and user types |
| `dao` | MyBatis DAOs and mapper interfaces |
| `domain` | Domain entities and constants |
| `internal-service` | Internal Spring service endpoints |
| `internal-service-model` | Internal request/response model types |
| `scheduler` | Scheduled job support |
| `service` | Public Spring service endpoints |
| `service-model` | Public request/response model types |
| `tenancy` | Tenant database migrations and tenancy service |
