[CmdletBinding()]
param(
  [string]$RepoRoot = "",
  [string]$SkillsRelativePath = "codex/skills",
  [string]$CodexHome = $env:CODEX_HOME,
  [string]$ValidatorPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  $scriptBase = if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) { (Get-Location).Path } else { $PSScriptRoot }
  $RepoRoot = (Resolve-Path (Join-Path $scriptBase "..\..")).Path
}

function Resolve-CodexHomePath {
  param([string]$ConfiguredCodexHome)

  if (-not [string]::IsNullOrWhiteSpace($ConfiguredCodexHome)) {
    return $ConfiguredCodexHome
  }

  return (Join-Path $env:USERPROFILE ".codex")
}

function Resolve-ValidatorPath {
  param(
    [string]$ExplicitValidatorPath,
    [string]$ResolvedCodexHome
  )

  if (-not [string]::IsNullOrWhiteSpace($ExplicitValidatorPath)) {
    if (-not (Test-Path -LiteralPath $ExplicitValidatorPath)) {
      throw "Provided validator path does not exist: $ExplicitValidatorPath"
    }

    return $ExplicitValidatorPath
  }

  $candidates = @(
    (Join-Path $ResolvedCodexHome "skills\.system\skill-creator\scripts\quick_validate.py"),
    (Join-Path (Join-Path $env:USERPROFILE ".codex") "skills\.system\skill-creator\scripts\quick_validate.py")
  )

  foreach ($candidate in $candidates) {
    if (Test-Path -LiteralPath $candidate) {
      return $candidate
    }
  }

  throw "Unable to find quick_validate.py. Install system skills or provide -ValidatorPath."
}

$skillsRootPath = Join-Path $RepoRoot $SkillsRelativePath
if (-not (Test-Path -LiteralPath $skillsRootPath)) {
  throw "Skills path does not exist: $skillsRootPath"
}

$skillDirectories = New-Object System.Collections.Generic.List[string]

if (Test-Path -LiteralPath (Join-Path $skillsRootPath "SKILL.md")) {
  $skillDirectories.Add($skillsRootPath)
}

Get-ChildItem -LiteralPath $skillsRootPath -Recurse -Directory |
  Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") } |
  Sort-Object -Property FullName -Unique |
  ForEach-Object { $skillDirectories.Add($_.FullName) }

if ($skillDirectories.Count -eq 0) {
  throw "No skill directories found under $skillsRootPath"
}

$resolvedCodexHome = Resolve-CodexHomePath -ConfiguredCodexHome $CodexHome
$resolvedValidatorPath = Resolve-ValidatorPath -ExplicitValidatorPath $ValidatorPath -ResolvedCodexHome $resolvedCodexHome

$failed = New-Object System.Collections.Generic.List[string]

foreach ($skillDir in $skillDirectories) {
  Write-Output "Validating: $skillDir"
  python $resolvedValidatorPath $skillDir
  if ($LASTEXITCODE -ne 0) {
    $failed.Add($skillDir)
  }
}

if ($failed.Count -gt 0) {
  Write-Output ""
  Write-Output "Validation failed for:"
  $failed | ForEach-Object { Write-Output "- $_" }
  exit 1
}

Write-Output ""
Write-Output "All skills are valid ($($skillDirectories.Count) total)."
