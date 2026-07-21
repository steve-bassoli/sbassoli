---
name: populate-workflows-access-control
description: Populate the local dsbu-access-control-service tenant database with real Workflows application, functionality, permission, and security item type data from C:\work\dsbu-workflows. Use when the local access-control DB was rebuilt, Workflows permissions are missing, users need direct mocked access-control seed data, or Codex should refresh Workflows permission rows without running the Workflows service bootstrap.
---

# Populate Workflows Access Control

## Workflow

Use `scripts/populate-workflows-access-control.ps1` to seed the local access-control database directly.

Default command:

```powershell
& "C:\work\sbassoli\codex\skills\local\dsbu-access-control-service\populate-workflows-access-control\scripts\populate-workflows-access-control.ps1"
```

The script:

- Reads `Application.java`, `Functionality.java`, `Permission.java`, and `SecurityItemType.java` from `C:\work\dsbu-workflows`.
- Converts enum names to lower-spinal-case, matching the shared `EnumUtility.convertNameToLowerSpinalCase` behavior.
- Inserts/reuses the Workflows application in `sd_access_control_service.application`.
- Calls `sd_access_control_service.replace_functionality_v2_fn` with the extracted permission/security item type payload.
- Queries the seeded rows for validation.

## Options

Use parameters only when the local setup differs:

```powershell
& "...\populate-workflows-access-control.ps1" `
  -WorkflowsRepo "C:\work\dsbu-workflows" `
  -ContainerName "access-control-service-database" `
  -Database "local_dev_tenant_alias" `
  -InternalWorkflowsServiceUri "http://localhost:8081"
```

## Notes

- Run this only against local/dev databases. It uses `docker exec` with the local Postgres container and writes table data directly.
- If Docker is not running or the DB was not provisioned, start the access-control local compose stack first.
- If `LOCAL_DEV_PLATFORM_USER_ID` was empty during bootstrap, `user_` can still be empty; this script does not create users or assignments.
