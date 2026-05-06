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

function Add-Unique {
  param(
    [System.Collections.Generic.List[string]]$List,
    [string]$Value
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    return
  }

  if (-not $List.Contains($Value)) {
    [void]$List.Add($Value)
  }
}

$files = @(Get-ChangedFiles -Root $RepoRoot)

if ($files.Count -eq 0) {
  Write-Output "Risk level: none"
  Write-Output "Risk reasons: no changed files"
  Write-Output "Required commands:"
  Write-Output "- <none>"
  Write-Output "Optional commands:"
  Write-Output "- <none>"
  Write-Output "Changed files:"
  Write-Output "- <none>"
  exit 0
}

$designerTsFiles = @($files | Where-Object { $_ -match "^apps/designer/src/.*\.ts$" })
$designerScssFiles = @($files | Where-Object { $_ -match "^apps/designer/src/.*\.scss$" })
$designerTemplateFiles = @($files | Where-Object { $_ -match "^apps/designer/src/.*\.html$" })
$designerCodeFiles = @($files | Where-Object { $_ -match "^apps/designer/src/" })

$sharedAngularCodeFiles = @($files | Where-Object { $_ -match "^libs/shared/angular/src/" })
$viewerCodeFiles = @($files | Where-Object { $_ -match "^libs/viewer/src/" })
$sharedUtilityCodeFiles = @($files | Where-Object { $_ -match "^libs/shared/utility/src/" })
$dataServiceCodeFiles = @($files | Where-Object { $_ -match "^libs/dataservicelib/" })

$routingFiles = @($files | Where-Object { $_ -match "^apps/designer/src/app/.*(routes|routing).*\.ts$" })
$permissionFiles = @($files | Where-Object { $_ -match "^apps/designer/src/.*permission.*\.(ts|html)$" })
$apiFiles = @($files | Where-Object { $_ -match "^apps/designer/src/services/clients/" })

$dependencyFiles = @(
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
$depsChanged = $dependencyFiles.Count -gt 0

$touchedAreas = New-Object System.Collections.Generic.List[string]
if ($designerCodeFiles.Count -gt 0) { Add-Unique -List $touchedAreas -Value "designer" }
if ($sharedAngularCodeFiles.Count -gt 0) { Add-Unique -List $touchedAreas -Value "shared-angular" }
if ($viewerCodeFiles.Count -gt 0) { Add-Unique -List $touchedAreas -Value "viewer" }
if ($sharedUtilityCodeFiles.Count -gt 0) { Add-Unique -List $touchedAreas -Value "shared-utility" }
if ($dataServiceCodeFiles.Count -gt 0) { Add-Unique -List $touchedAreas -Value "dataservicelib" }

$riskPoints = 0
$riskReasons = New-Object System.Collections.Generic.List[string]

if ($depsChanged) {
  $riskPoints += 3
  Add-Unique -List $riskReasons -Value "dependency-metadata"
}

if ($sharedAngularCodeFiles.Count -gt 0 -or $viewerCodeFiles.Count -gt 0 -or $sharedUtilityCodeFiles.Count -gt 0 -or $dataServiceCodeFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "shared-libraries"
}

if ($routingFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "routing"
}

if ($permissionFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "permissions"
}

if ($apiFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "api-client"
}

if ($designerTsFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "typescript"
}

if ($designerScssFiles.Count -gt 0 -or $designerTemplateFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "template-style"
}

if ($touchedAreas.Count -ge 2) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "multi-package"
}

$riskLevel = "low"
if ($riskPoints -ge 6) {
  $riskLevel = "high"
} elseif ($riskPoints -ge 3) {
  $riskLevel = "medium"
}

$requiredCommands = New-Object System.Collections.Generic.List[string]
$optionalCommands = New-Object System.Collections.Generic.List[string]

if ($depsChanged) {
  Add-Unique -List $requiredCommands -Value "yarn install"
}

$allTsFiles = @($files | Where-Object { $_ -match "^(apps/designer/src|libs/shared/angular/src|libs/shared/utility/src|libs/viewer/src)/.*\.ts$" })
if ($allTsFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value ("yarn eslint " + ($allTsFiles -join " "))
}

if ($designerScssFiles.Count -gt 0) {
  Add-Unique -List $optionalCommands -Value ("yarn stylelint " + ($designerScssFiles -join " "))
}

if ($sharedAngularCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "yarn test:shared-angular"
}

if ($viewerCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "yarn test:viewer"
}

if ($sharedUtilityCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "yarn workspace shared-utility run test:prod"
}

if ($dataServiceCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "yarn workspace dataservicelib run test"
}

if ($riskLevel -eq "high" -and $designerCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "yarn workspace designer run test:prod"
}

if ($riskLevel -eq "medium" -and $designerCodeFiles.Count -gt 0) {
  Add-Unique -List $optionalCommands -Value "yarn workspace designer run test:prod"
}

if ($requiredCommands.Count -eq 0) {
  Add-Unique -List $requiredCommands -Value "<none>"
}

if ($optionalCommands.Count -eq 0) {
  Add-Unique -List $optionalCommands -Value "<none>"
}

if ($riskReasons.Count -eq 0) {
  Add-Unique -List $riskReasons -Value "narrow-change-scope"
}

Write-Output "Risk level: $riskLevel"
Write-Output ("Risk reasons: " + ($riskReasons -join ", "))

Write-Output "Required commands:"
$requiredCommands | ForEach-Object { Write-Output "- $_" }

Write-Output "Optional commands:"
$optionalCommands | ForEach-Object { Write-Output "- $_" }

Write-Output "Changed files:"
$files | ForEach-Object { Write-Output "- $_" }
