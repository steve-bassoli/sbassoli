---
name: guardrail-enforcer-angular
description: "Enforce Angular-only guardrails for component edits in the active repository. Use when editing `.html`, related `.ts`, or Angular feature files to prevent inline styles and template function-call anti-patterns, keep touched code lint-clean, and remediate violations before concluding work."
---

# Angular Guardrail Enforcer

## Workflow

1. Determine whether the task touches Angular app or library files, especially templates (`*.html`) and paired TypeScript files.
2. Review changed templates in full, not only changed hunks, for guardrail violations.
3. Enforce these rules:
   - Never add inline `style="..."` in Angular templates; prefer Bootstrap utility classes over new or changed SCSS/CSS for standard layout, spacing, sizing, alignment, display, and text styling.
   - Never use function calls inside interpolation/property/structural bindings.
   - Event bindings are allowed (`(click)="onAction()"`) but keep expressions simple and delegate logic to component code.
   - Do not leave introduced ESLint violations in touched Angular TypeScript files.
4. When a violation exists, fix it with minimal, pattern-consistent changes:
   - Move template logic to computed component state (property/signal) and bind values.
   - Resolve touched-scope lint violations instead of suppressing them unless suppression already exists and is clearly required.
   - Preserve behavior; avoid unrelated refactors.
5. Run targeted validation for touched files:
   - at minimum, focused ESLint for touched TypeScript files
   - use the repository's established broader lint/test command when the change is cross-cutting or targeted lint is not enough
6. Report what was enforced, what was fixed, and any explicitly deferred exceptions.

## Guardrail Scope

- Apply to newly added or modified template expressions.
- If a pre-existing violation is outside the touched scope, do not expand scope unless the user requests broader remediation.
- If a pre-existing violation is in the touched scope, remediate it as part of the same change.

## Output Expectations

Keep reports concise:
- Violations found (by file/line and rule).
- Fixes applied.
- Validation commands run and result.
