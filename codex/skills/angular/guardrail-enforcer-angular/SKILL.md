---
name: guardrail-enforcer-angular
description: "Enforce Angular-only guardrails for component edits in the active repository. Use when editing `.html`, related `.ts`, or Angular feature files to prevent inline styles, template function-call anti-patterns, UI hacks around missing server properties, and touched-scope lint violations before concluding work."
---

# Angular Guardrail Enforcer

## Workflow

1. Determine whether the task touches Angular app or library files, especially templates (`*.html`) and paired TypeScript files.
2. Review changed templates in full, not only changed hunks, for guardrail violations. Also review the paired component TypeScript for every template-bound identifier.
3. Enforce these rules:
   - Never add inline `style="..."` in Angular templates; prefer Bootstrap utility classes over new or changed SCSS/CSS for standard layout, spacing, sizing, alignment, display, and text styling.
   - Never use arbitrary component method calls inside interpolation/property/structural bindings. Angular signal reads such as `value()` are allowed only when the paired TypeScript declares `value` as a signal, computed, input, or model signal; verify this instead of assuming.
   - Treat component TypeScript getters (`get value(): ...`) used by templates as function calls. Do not bind templates to getters, even when the template syntax looks like a property read (`{{ value }}`, `[disabled]="value"`, `*ngIf="value"`).
   - When reviewing a template identifier, search the paired component for `get <identifier>()`. If found, replace the getter with stored component state, a readonly field, or verified signal/computed state that is not exposed to the template as a getter-backed property.
   - Event bindings are allowed (`(click)="onAction()"`) but keep expressions simple and delegate logic to component code.
   - Block UI work when a feature depends on an obvious server/API property that is missing from the response. Do not add client-side lookup fallbacks, name/version correlation, derived opaque IDs, extra API calls, or other UI hacks to reconstruct the missing property. Tell the user the request is blocked until the server/API returns the required property.
     - Example: if `taskDetail()?.workflowDefinitionId` is `undefined`, `app-diagram-view-modal` can open and the BPMN viewer shell/zoom controls can render, but no XML request is made and no diagram appears. Do not resolve this in the UI by looking up a workflow definition from `workflowDefinitionName` and `workflowDefinitionVersion`; block the request until the task-detail endpoint includes `workflowDefinitionId`.
   - Do not leave introduced ESLint violations in touched Angular TypeScript files.
4. When a violation exists, fix it with minimal, pattern-consistent changes:
   - Move template logic to computed component state and bind values without invoking component methods/getters from the template.
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
- Blocked API contract gaps, including the missing server property and why the UI must not infer it.
- Validation commands run and result.
