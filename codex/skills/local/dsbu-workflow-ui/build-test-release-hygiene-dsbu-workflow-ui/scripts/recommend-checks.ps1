param(
  [string]$RepoRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ChangedFiles {
  param([string]$Root)

  $staged = git -C $Root diff --name-only --cached 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read git staged diff."
  }

  $unstaged = git -C $Root diff --name-only 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to read git unstaged diff."
  }

  return @($staged + $unstaged | Where-Object { $_ -and $_.Trim() -ne "" } | Sort-Object -Unique)
}

$files = @(Get-ChangedFiles -Root $RepoRoot)

if ($files.Count -eq 0) {
  Write-Output "No changed files detected."
  exit 0
}

$hasHtmlCode = $files | Where-Object { $_ -match "^html/src/" }
$hasHtmlTs = $files | Where-Object { $_ -match "^html/src/.*\.ts$" }
$hasHtmlTemplates = $files | Where-Object { $_ -match "^html/src/.*\.(html|scss)$" }
$hasHtmlDeps = $files | Where-Object { $_ -in @("html/package.json", "html/yarn.lock") }
$hasDsV2Deps = $files | Where-Object { $_ -in @("dataservicelib-v2/package.json", "dataservicelib-v2/yarn.lock") }
$hasDsV3Deps = $files | Where-Object { $_ -in @("dataservicelib-v3/package.json", "dataservicelib-v3/yarn.lock") }
$needsBom = $hasHtmlDeps -or $hasDsV2Deps -or $hasDsV3Deps

Write-Output "Recommended checks:"

if ($hasHtmlTs) {
  Write-Output "- cd html && yarn eslint <touched-ts-files>"
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

if ($hasDsV2Deps) {
  Write-Output "- cd dataservicelib-v2 && yarn install"
}

if ($hasDsV3Deps) {
  Write-Output "- cd dataservicelib-v3 && yarn install"
}

if ($needsBom) {
  Write-Output "- node scripts/generate-bom-confluence.mjs"
}

Write-Output ""
Write-Output "Changed files:"
$files | ForEach-Object { Write-Output "- $_" }
