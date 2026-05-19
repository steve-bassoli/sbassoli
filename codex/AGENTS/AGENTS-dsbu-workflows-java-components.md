---
apply: always
---
## Scope
Repository: `dsbu-workflows-java-components` only.
## Skills
### Custom skill discovery paths
Custom skills are discovered from these path patterns. Do not mirror individual skill names or descriptions here; read the matching `SKILL.md` frontmatter at execution time so additions, removals, and descriptions stay current.
- `C:/work/sbassoli/codex/skills/java/*/SKILL.md`
- `C:/work/sbassoli/codex/skills/common/*/SKILL.md`
### System skills
System skills are provided by the current Codex runtime. Use the session's skill registry and do not hardcode IDE-versioned system skill paths here.
## Skill Rules
- Discover custom skills by reading `SKILL.md` frontmatter from the paths above when task matching is needed.
- Trigger a discovered skill when the user names it (with `$SkillName` or plain text) or when the task clearly matches the skill description.
- If multiple skills match, use the minimal set and state the order.
- Do not carry skills across turns unless re-mentioned.
- Use the iterative implementation skill at `C:/work/sbassoli/codex/skills/common/iterative-implementation/SKILL.md` for multi-step refactors or feature additions.
- For low-risk localized changes, run targeted validation only and summarize what ran.
- If a named skill is missing or unreadable, state it briefly and continue with the best fallback.
## Skill Use Workflow
- Open the selected `SKILL.md` and read only what is needed.
- Resolve skill-referenced relative paths from the skill directory first.
- Load only the necessary referenced files; do not bulk-load assets/references.
- Prefer provided scripts/assets/templates over recreating equivalent content.
## Iterative Implementation Skill Rules (CRITICAL)
- When executing the iterative implementation skill at `C:/work/sbassoli/codex/skills/common/iterative-implementation/SKILL.md`, ALWAYS write the plan to `./codex/output/iterative_implementation_items.txt` and sync the status file BEFORE doing any code work.
- Do NOT execute any step until the plan file exists and the user has confirmed.
- Do NOT create test files as part of an iterative implementation plan step unless the user explicitly requests tests.
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
## Repository Conventions
- **Language:** Java 17+
- **Build:** Gradle (multi-module)
- **Test framework:** TestNG + Mockito
- **Code style:** Spotless (eclipse-format.xml); imports ordered via `spotless/import-order`
- **ID types:** Data-security domain IDs are always `Long` — never `Integer`, never generic `<I>`
- **Projects map 1:1** in workflow tasks and definitions: one `Long` projectId maps to exactly one `UUID` capabilitySecurityItemId
- **No `Function<Set<I>, Map<I, UUID>>` fetcher pattern** — callers build and pass `Map<Long, UUID>` directly
- **License header** required on all new `.java` files:
  `
  /*
   * Copyright (c) 2026 Thermo Fisher Scientific
   * All rights reserved.
   */
  `
## Module Structure
| Module | Purpose |
|---|---|
| `business-logic` | Core processors and access control logic |
| `client` | Access Control and other service clients |
| `common` | Shared types, user context, authorization interfaces |
| `service-model` | Response/request model types |
| `domain` | Domain entity definitions |
| `dao` | Data access objects |
| `service` | Service layer |
| `scheduler` | Scheduled job support |
| `tenant-listener` | Tenant lifecycle event handling |
