# Codex Asset Store

This directory is the central backup and transfer point for Codex project assets.

## Layout

- `AGENTS/AGENTS-<repo-name>.md`: backed-up project `AGENTS.md` files.
- `scripts/`: reusable Codex helper scripts.
- `skills/angular`, `skills/common`, `skills/java`: project-agnostic shared skill groups.
- `skills/local/<repo-name>/`: repo-specific skills for one project.

Do not export generated run state such as `codex/output`; keep this store limited to reusable source, scripts, references, and `AGENTS.md` backups.

## Export From A Project

Run from PowerShell and set the project root first:

```powershell
$ProjectRoot = "C:\work\dsbu-reporting-ui"
$StoreRoot = "C:\work\sbassoli\codex"
$RepoName = Split-Path $ProjectRoot -Leaf

New-Item -ItemType Directory -Path "$StoreRoot\AGENTS", "$StoreRoot\scripts", "$StoreRoot\skills\local\$RepoName" -Force | Out-Null
Copy-Item -Path "$ProjectRoot\AGENTS.md" -Destination "$StoreRoot\AGENTS\AGENTS-$RepoName.md" -Force
Copy-Item -Path "$ProjectRoot\codex\scripts\*" -Destination "$StoreRoot\scripts" -Recurse -Force

foreach ($Group in @("angular", "common", "java")) {
  $Source = "$ProjectRoot\codex\skills\$Group"
  if (Test-Path -LiteralPath $Source) {
    New-Item -ItemType Directory -Path "$StoreRoot\skills\$Group" -Force | Out-Null
    Copy-Item -Path "$Source\*" -Destination "$StoreRoot\skills\$Group" -Recurse -Force
  }
}

$LocalSource = "$ProjectRoot\codex\skills\local"
if (Test-Path -LiteralPath $LocalSource) {
  Copy-Item -Path "$LocalSource\*" -Destination "$StoreRoot\skills\local\$RepoName" -Recurse -Force
}
```

Project-specific skill folders belong under `skills/local/<repo-name>/`. Prefer the full repo name in new or renamed local skill names when it avoids ambiguity, for example `build-test-release-hygiene-dsbu-workflow-ui`.

## Import Into A Project

Run from PowerShell and set the target project root first:

```powershell
$ProjectRoot = "C:\work\my-project"
$StoreRoot = "C:\work\sbassoli\codex"
$RepoName = Split-Path $ProjectRoot -Leaf

New-Item -ItemType Directory -Path "$ProjectRoot\codex\scripts", "$ProjectRoot\codex\skills", "$ProjectRoot\codex\skills\local" -Force | Out-Null

$AgentsBackup = "$StoreRoot\AGENTS\AGENTS-$RepoName.md"
if (Test-Path -LiteralPath $AgentsBackup) {
  Copy-Item -Path $AgentsBackup -Destination "$ProjectRoot\AGENTS.md" -Force
}

Copy-Item -Path "$StoreRoot\scripts\*" -Destination "$ProjectRoot\codex\scripts" -Recurse -Force

foreach ($Group in @("angular", "common", "java")) {
  $Source = "$StoreRoot\skills\$Group"
  if (Test-Path -LiteralPath $Source) {
    Copy-Item -Path $Source -Destination "$ProjectRoot\codex\skills" -Recurse -Force
  }
}

$LocalSource = "$StoreRoot\skills\local\$RepoName"
if (Test-Path -LiteralPath $LocalSource) {
  Copy-Item -Path "$LocalSource\*" -Destination "$ProjectRoot\codex\skills\local" -Recurse -Force
}
```

After importing, review `AGENTS.md` paths and skill names if you intentionally renamed local skills during export.

## Validation And Sync

Validate the central store:

```powershell
powershell -File C:\work\sbassoli\codex\scripts\validate-skills.ps1 -RepoRoot C:\work -SkillsRelativePath codex/skills
```

Validate an imported project:

```powershell
powershell -File C:\work\my-project\codex\scripts\validate-skills.ps1 -RepoRoot C:\work\my-project
```

Sync central skills to the active Codex home:

```powershell
powershell -File C:\work\sbassoli\codex\scripts\sync-skills.ps1 -RepoRoot C:\work -SkillsRelativePath codex/skills
```

Restart Codex after syncing to load new or updated skills.
