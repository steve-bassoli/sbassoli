[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$RepoRoot,

  [string]$CentralStore = "C:\work\sbassoli\codex",

  [switch]$RequireNoRepoLocalSources
)

$ErrorActionPreference = "Stop"
$failed = $false

function Add-Failure {
  param([string]$Message)
  Write-Error $Message -ErrorAction Continue
  $script:failed = $true
}

$resolvedRepo = Resolve-Path -LiteralPath $RepoRoot
$resolvedCentral = Resolve-Path -LiteralPath $CentralStore

$repoRootPath = $resolvedRepo.Path
$centralStorePath = $resolvedCentral.Path
$repoName = Split-Path -Leaf $repoRootPath
$localAgents = Join-Path $repoRootPath "AGENTS.md"
$centralAgents = Join-Path (Join-Path $centralStorePath "AGENTS") "AGENTS-$repoName.md"

if (-not (Test-Path -LiteralPath $localAgents)) {
  Add-Failure "Missing local AGENTS.md: $localAgents"
}

if (-not (Test-Path -LiteralPath $centralAgents)) {
  Add-Failure "Missing central AGENTS file: $centralAgents"
}

if ($failed) {
  exit 1
}

$localContent = Get-Content -LiteralPath $localAgents -Raw
$centralContent = Get-Content -LiteralPath $centralAgents -Raw

if (-not $localContent.Contains($centralAgents)) {
  Add-Failure "Local AGENTS.md does not point at expected central file: $centralAgents"
}

$staleStore = "C:\work\" + "codex"
if ($localContent.Contains($staleStore)) {
  Add-Failure "Local AGENTS.md contains stale store path: $staleStore"
}

if ($centralContent.Contains($staleStore)) {
  Add-Failure "Central AGENTS file contains stale store path: $staleStore"
}

$repoCodexBackslash = Join-Path $repoRootPath "codex"
$repoCodexSlash = $repoCodexBackslash -replace "\\", "/"
if ($centralContent.Contains($repoCodexBackslash) -or $centralContent.Contains($repoCodexSlash)) {
  Add-Failure "Central AGENTS file still points at the repo-local absolute codex directory: $repoCodexBackslash"
}

if ($RequireNoRepoLocalSources) {
  $repoCodexRoot = Join-Path $repoRootPath "codex"
  $repoLocalSourcePaths = @(
    (Join-Path $repoCodexRoot "README.md"),
    (Join-Path $repoCodexRoot "scripts"),
    (Join-Path $repoCodexRoot "skills")
  )

  foreach ($sourcePath in $repoLocalSourcePaths) {
    if (Test-Path -LiteralPath $sourcePath) {
      Add-Failure "Repo-local Codex source copy should be removed: $sourcePath"
    }
  }

  $repoOutputPath = Join-Path $repoCodexRoot "output"
  if (-not (Test-Path -LiteralPath $repoOutputPath)) {
    Add-Failure "Missing repo-local Codex output directory: $repoOutputPath"
  }
}

if ($failed) {
  exit 1
}

Write-Host "Central Codex bootstrap validated for $repoName"
Write-Host "Local AGENTS: $localAgents"
Write-Host "Central AGENTS: $centralAgents"
