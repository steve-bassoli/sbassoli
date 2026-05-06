param(
  [string]$RepoRoot = ".",
  [string]$BaseBranch = "master"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-BaseRef {
  param(
    [string]$Root,
    [string]$Branch
  )

  $candidateRefs = @($Branch, "origin/$Branch")

  foreach ($candidateRef in $candidateRefs) {
    git -C $Root rev-parse --verify --quiet $candidateRef 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
      return $candidateRef
    }
  }

  throw "Unable to resolve base branch '$Branch'. Tried: $($candidateRefs -join ', ')."
}

function Get-ChangedFiles {
  param(
    [string]$Root,
    [string]$Branch
  )

  $baseRef = Resolve-BaseRef -Root $Root -Branch $Branch

  $mergeBase = git -C $Root merge-base HEAD $baseRef 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $mergeBase) {
    throw "Unable to compute merge-base for HEAD and '$baseRef'."
  }

  $diffFromMergeBase = @(git -C $Root diff --name-only $mergeBase 2>$null)
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read git diff against merge-base '$mergeBase'."
  }

  $untrackedFiles = @(git -C $Root ls-files --others --exclude-standard 2>$null)
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to list untracked files."
  }

  $files = @(
    $diffFromMergeBase + $untrackedFiles |
      Where-Object { $_ -and $_.Trim() -ne "" } |
      Sort-Object -Unique
  )

  return [pscustomobject]@{
    BaseRef = $baseRef
    MergeBase = $mergeBase.Trim()
    Files = $files
  }
}

$changeSet = Get-ChangedFiles -Root $RepoRoot -Branch $BaseBranch
$files = @($changeSet.Files)

if ($files.Count -eq 0) {
  Write-Output "No changed files detected against $($changeSet.BaseRef) (merge-base $($changeSet.MergeBase))."
  exit 0
}

$hasHtmlCode = @($files | Where-Object { $_ -match "^html/src/" }).Count -gt 0
$touchedTsFiles = @($files | Where-Object { $_ -match "^html/src/.*\.ts$" })
$hasHtmlTemplates = @($files | Where-Object { $_ -match "^html/src/.*\.(html|scss)$" }).Count -gt 0
$hasHtmlDeps = @($files | Where-Object { $_ -in @("html/package.json", "html/yarn.lock") }).Count -gt 0

Write-Output "Diff baseline: $($changeSet.BaseRef) (merge-base $($changeSet.MergeBase))"
Write-Output "Recommended checks:"

if ($touchedTsFiles.Count -gt 0) {
  $eslintTargets = $touchedTsFiles | ForEach-Object { $_ -replace "^html/", "" }
  Write-Output ("- cd html && yarn eslint {0}" -f ($eslintTargets -join " "))
}

if ($hasHtmlTemplates) {
  Write-Output "- cd html && run template/style formatting or lint checks for touched files"
}

if ($hasHtmlCode) {
  Write-Output "- cd html && run relevant tests (targeted first; expand scope if risk is high)"
}

if ($hasHtmlDeps) {
  Write-Output "- cd html && yarn install"
}

Write-Output ""
Write-Output "Changed files:"
$files | ForEach-Object { Write-Output "- $_" }
