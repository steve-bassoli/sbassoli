# Codex Asset Store

This directory is the central source of truth for reusable Codex project assets.

## Layout

- `AGENTS/AGENTS-<repo-name>.md`: authoritative repo-specific AGENTS instructions.
- `scripts/`: reusable Codex helper scripts.
- `skills/angular`, `skills/common`, `skills/java`: shared skill groups.
- `skills/local/<repo-name>/`: repo-specific skills for one project.

Generated run state belongs in each repository under `codex/output`. Do not copy generated output into this store.

## Repository Bootstrap

Each repository should keep a small root `AGENTS.md` that points to its central instructions:

```markdown
---
apply: always
---

# Repository Instructions

Repository instructions are centralized.

Before doing any work in this repository, read:

`C:\work\sbassoli\codex\AGENTS\AGENTS-<repo-name>.md`

Treat that file as the authoritative AGENTS instructions for this repository.
If it cannot be read, stop and ask the user before making changes.
```

The repo-local `codex` directory should be reserved for `codex/output` runtime artifacts.

## Adding Or Updating Central Assets

Run from PowerShell and set the project root first:

```powershell
$ProjectRoot = "C:\work\my-project"
$StoreRoot = "C:\work\sbassoli\codex"
$RepoName = Split-Path $ProjectRoot -Leaf

New-Item -ItemType Directory -Path "$StoreRoot\AGENTS", "$StoreRoot\skills\local\$RepoName" -Force | Out-Null
Copy-Item -Path "$ProjectRoot\AGENTS.md" -Destination "$StoreRoot\AGENTS\AGENTS-$RepoName.md" -Force
```

Move reusable shared skills into `skills/<group>/<skill-name>` and repo-specific skills into `skills/local/<repo-name>/<skill-name>`.

Project-specific skill folders belong under `skills/local/<repo-name>/`. Prefer the full repo name in new or renamed local skill names when it avoids ambiguity, for example `build-test-release-hygiene-dsbu-workflow-ui`.

## Validation

Validate the central skill store:

```powershell
powershell -File C:\work\sbassoli\codex\scripts\validate-skills.ps1 -RepoRoot C:\work\sbassoli -SkillsRelativePath codex/skills
```

Validate a repository bootstrap:

```powershell
powershell -File C:\work\sbassoli\codex\skills\common\central-codex-bootstrap-management\scripts\Test-CentralCodexBootstrap.ps1 -RepoRoot C:\work\my-project -RequireNoRepoLocalSources
```

Sync central skills to the active Codex home when needed:

```powershell
powershell -File C:\work\sbassoli\codex\scripts\sync-skills.ps1 -RepoRoot C:\work\sbassoli -SkillsRelativePath codex/skills
```

Restart Codex after syncing to load new or updated skills.
