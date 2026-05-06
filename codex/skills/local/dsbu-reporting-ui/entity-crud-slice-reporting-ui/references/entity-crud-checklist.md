# Entity CRUD Checklist

Use this checklist for reporting entity pages that follow list/grid + modal + optional detail route patterns.

## 1. Identify analog and scope

- Prefer `security-groups` when the request includes permission-gated links/actions.
- Prefer `reports` when the request is list + detail route centric.
- Keep scope to one entity slice per request.

## 2. Route touchpoints

- `apps/designer/src/app/app.routes.ts`
- Optional route-provider alignment:
  - `apps/designer/src/services/providers/application-routing/application-routing-provider.ts`
- Add list route if missing.
- Add detail route if needed.
- Ensure route path matches grid link behavior:
  - For `ColumnType.Link`, grid links should resolve to the entity detail route.
  - Typical pattern: `/entity/:id`.

## 3. Grid column touchpoints

- `apps/designer/src/components/controls/<entity>-grid/<entity>-grid-column-factory.ts`
- Name column patterns:
  - Plain text: `ColumnType.String`
  - Link: `ColumnType.Link` + `link.path`
- Action patterns:
  - popover column via `defaultActionPopoverColumn(...)`
  - click wiring via `setOnActionClick(...)` in the component
  - permission-conditioned links/actions via `GridPermissionProvider` where applicable

## 4. Component touchpoints

- `apps/designer/src/components/pages/<entity>-page/<entity>-page.ts`
- `apps/designer/src/components/pages/<entity>-page/<entity>-page.html`
- related controls/modals under `apps/designer/src/components/controls/**`
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

- Use `sharedReportingAuthorization` in templates for buttons/actions where applicable.
- Reuse `PERMISSION_CLIENT` and existing permission enums/utilities.
- Keep permission checks consistent with existing reporting entities.

## 7. Verification checklist

- Run targeted eslint on changed TS files.
- Confirm route navigation from Name column works.
- Confirm create/edit/delete success and error flows.
- Confirm unauthorized users do not see restricted controls.
