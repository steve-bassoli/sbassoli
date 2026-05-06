# Entity CRUD Checklist

Use this checklist for entity pages that follow the list/grid + modal + optional detail route pattern.

## 1. Identify analog and scope

- Prefer `groups-v2` when the request includes permission-gated links/actions and detail-route behavior.
- Prefer `roles-v2` when the request is straightforward CRUD with list + modal form workflows.
- Keep scope to one entity slice per request.

## 2. Route touchpoints

- `src/app/app-routing.module.ts`
- Add list route if missing.
- Add detail route if needed.
- Ensure route path matches grid link behavior:
  - For `ColumnType.Link`, the grid appends row id by default.
  - Typical pattern: `/entity-detail/:id`.

## 3. Grid column touchpoints

- `src/app/pages/<entity>/<entity>-grid-column-factory*.ts`
- Name column patterns:
  - Plain text: `ColumnType.String`
  - Link: `ColumnType.Link` + `link.path`
- Action patterns:
  - popover column via `defaultActionPopoverColumn(...)`
  - click wiring via `setOnActionClick(...)` in the component

## 4. Component touchpoints

- `src/app/pages/<entity>/<entity>.component.ts`
- `src/app/pages/<entity>/<entity>.component.html`
- Ensure:
  - data load on init
  - modal open/close flow
  - selected item handling for edit/delete
  - success alert messaging

## 5. Modal/form touchpoints

- Reuse shared form wrappers when available.
- Keep success and error message style consistent:
  - Bad request fallback like `Name already exists.`
  - Internal error fallback like `Failed to <operation> <entity>. Please try again later.`

## 6. Permission touchpoints

- Use `PermissionedDirective` in templates for buttons/actions.
- Reuse shared permission utilities for grid behavior.
- Keep permission enum usage consistent with existing entities.

## 7. Verification checklist

- Run targeted eslint on changed TS files.
- Confirm route navigation from Name column works.
- Confirm create/edit/delete success and error flows.
- Confirm unauthorized users do not see restricted controls.
