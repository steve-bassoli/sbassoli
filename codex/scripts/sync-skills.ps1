[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [string]$SkillsRelativePath = "codex/skills",
  [string]$CodexHome = $env:CODEX_HOME
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-CodexHomePath {
  param([string]$ConfiguredCodexHome)

  if (-not [string]::IsNullOrWhiteSpace($ConfiguredCodexHome)) {
    return $ConfiguredCodexHome
  }

  return (Join-Path $env:USERPROFILE ".codex")
}

$skillsSourcePath = Join-Path $RepoRoot $SkillsRelativePath
if (-not (Test-Path -LiteralPath $skillsSourcePath)) {
  throw "Skills source path does not exist: $skillsSourcePath"
}

$resolvedCodexHome = Resolve-CodexHomePath -ConfiguredCodexHome $CodexHome
$skillsDestinationRoot = Join-Path $resolvedCodexHome "skills"

New-Item -ItemType Directory -Path $skillsDestinationRoot -Force | Out-Null

$sourceEntries = @(Get-ChildItem -LiteralPath $skillsSourcePath -Force)
if ($sourceEntries.Count -eq 0) {
  Write-Output "No skills found at $skillsSourcePath"
  Write-Output "Nothing to sync."
  exit 0
}

foreach ($entry in $sourceEntries) {
  Copy-Item -LiteralPath $entry.FullName -Destination $skillsDestinationRoot -Recurse -Force
}

Write-Output "Synced skills from:"
Write-Output "  $skillsSourcePath"
Write-Output "to:"
Write-Output "  $skillsDestinationRoot"
Write-Output "Restart Codex to pick up new or updated skills."
