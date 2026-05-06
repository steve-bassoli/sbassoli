---
name: entity-crud-slice-dsbu-workflow-ui
description: Implement or update Angular entity CRUD slices in dsbu-workflow-ui. Use for requests to add a new entity management page, wire create/edit/delete modals, make a grid Name column link to a detail page, or mirror Projects/Memberships patterns with routing and permissions.
---

# DSBU Workflow UI Entity CRUD Slice

## Quick Start

1. Read [references/entity-crud-checklist.md](references/entity-crud-checklist.md).
2. Confirm the entity shape:
   - list route path
   - detail route path format (`/path/:id` or fixed page)
   - API client/service methods
   - required permissions
3. Pick the closest analog in the repo:
   - `projects` for richer permissions and tabs
   - `memberships` for simpler list + modal CRUD
4. Implement end-to-end in one pass:
   - route
   - grid column factory
   - component wiring
   - modal/form integration
   - targeted verification

## Workflow

1. Map touchpoints before editing.
2. Add or update route entries in `app-routing.module.ts`.
3. Update the grid column factory:
   - set Name column to `ColumnType.Link` when needed
   - set `link.path` to the detail route base
4. Wire action handling and modal IDs in the page component.
5. Wire API operations and success/error messaging in the modal/form component.
6. Apply permission checks consistently:
   - use `PermissionedDirective` in templates
   - use shared grid permission service for conditional links/actions when required
7. Verify with focused commands in the active project directory.

## Output Requirements

- Keep changes localized to the smallest feature slice.
- Preserve existing naming/style conventions in adjacent files.
- Prefer reusing shared components and utilities over introducing new abstractions.
- Include a short verification summary in the final response.

## Verification

Use the minimum commands that prove the change:

- `yarn eslint <touched-ts-files>`
- If templates/styles changed, include formatting/lint checks as needed.
- If behavior changed substantially, run relevant tests.

## References

- Read [references/entity-crud-checklist.md](references/entity-crud-checklist.md) before editing.
