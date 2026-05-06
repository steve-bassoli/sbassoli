param(
  [string]$RepoRoot = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
  param(
    [string]$Root,
    [string[]]$GitArgs
  )

  $result = git -C $Root @GitArgs 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git -C $Root $($GitArgs -join ' ')"
  }

  return @($result)
}

function Get-ChangedFiles {
  param([string]$Root)

  $staged = Invoke-Git -Root $Root -GitArgs @("diff", "--name-only", "--cached")
  $unstaged = Invoke-Git -Root $Root -GitArgs @("diff", "--name-only")
  $untracked = Invoke-Git -Root $Root -GitArgs @("ls-files", "--others", "--exclude-standard")

  return @($staged + $unstaged + $untracked |
      Where-Object { $_ -and $_.Trim() -ne "" } |
      Sort-Object -Unique)
}

$files = @(Get-ChangedFiles -Root $RepoRoot)

if ($files.Count -eq 0) {
  Write-Output "No changed files detected."
  exit 0
}

$touchedTsFiles = @($files | Where-Object { $_ -match "^(apps/designer/src|libs/shared/angular/src|libs/shared/utility/src|libs/viewer/src)/.*\.ts$" })
$touchedScssFiles = @($files | Where-Object { $_ -match "^(apps/designer/src|libs/shared/angular/src|libs/viewer/src)/.*\.scss$" })
$touchedTemplateFiles = @($files | Where-Object { $_ -match "^(apps/designer/src|libs/shared/angular/src|libs/viewer/src)/.*\.html$" })

$hasDesignerCode = @($files | Where-Object { $_ -match "^apps/designer/src/" }).Count -gt 0
$hasSharedAngularCode = @($files | Where-Object { $_ -match "^libs/shared/angular/src/" }).Count -gt 0
$hasViewerCode = @($files | Where-Object { $_ -match "^libs/viewer/src/" }).Count -gt 0
$hasSharedUtilityCode = @($files | Where-Object { $_ -match "^libs/shared/utility/src/" }).Count -gt 0
$hasDataServiceCode = @($files | Where-Object { $_ -match "^libs/dataservicelib/" }).Count -gt 0

$dependencyChanges = @(
  $files |
    Where-Object {
      $_ -in @(
        "package.json",
        "yarn.lock",
        "apps/designer/package.json",
        "libs/shared/angular/package.json",
        "libs/shared/utility/package.json",
        "libs/viewer/package.json",
        "libs/dataservicelib/package.json"
      ) -or $_ -match "^(apps/designer|libs/shared/angular|libs/shared/utility|libs/viewer|libs/dataservicelib)/yarn\.lock$"
    }
)
$depsChanged = $dependencyChanges.Count -gt 0

Write-Output "Recommended checks:"

if ($depsChanged) {
  Write-Output "- yarn install"
}

if ($touchedTsFiles.Count -gt 0) {
  Write-Output ("- yarn eslint " + ($touchedTsFiles -join " "))
}

if ($touchedScssFiles.Count -gt 0 -or $touchedTemplateFiles.Count -gt 0) {
  Write-Output "- run template/style formatting or lint checks for touched files"
}

if ($hasDesignerCode) {
  Write-Output "- yarn workspace designer run test:prod (or narrower targeted tests first)"
}

if ($hasSharedAngularCode) {
  Write-Output "- yarn test:shared-angular"
}

if ($hasViewerCode) {
  Write-Output "- yarn test:viewer"
}

if ($hasSharedUtilityCode) {
  Write-Output "- yarn workspace shared-utility run test:prod"
}

if ($hasDataServiceCode) {
  Write-Output "- yarn workspace dataservicelib run test"
}

Write-Output ""
Write-Output "Changed files:"
$files | ForEach-Object { Write-Output "- $_" }
