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

$htmlTsFiles = @($files | Where-Object { $_ -match "^html/src/.*\.ts$" })
$htmlScssFiles = @($files | Where-Object { $_ -match "^html/src/.*\.scss$" })
$htmlTemplateFiles = @($files | Where-Object { $_ -match "^html/src/.*\.html$" })
$htmlCodeFiles = @($files | Where-Object { $_ -match "^html/src/" })
$sharedFiles = @($files | Where-Object { $_ -match "^html/src/app/shared/" -or $_ -match "^html/src/app/controls/" })
$routingFiles = @($files | Where-Object { $_ -match "^html/src/app/.*routing.*\.ts$" })
$permissionFiles = @($files | Where-Object { $_ -match "^html/src/app/.*permission.*\.ts$" })
$apiFiles = @($files | Where-Object { $_ -match "^html/src/app/services/.+service\.ts$" })

$htmlDepsChanged = @($files | Where-Object { $_ -in @("html/package.json", "html/yarn.lock") })
$depsChanged = $htmlDepsChanged.Count -gt 0

$riskPoints = 0
$riskReasons = New-Object System.Collections.Generic.List[string]

if ($depsChanged) {
  $riskPoints += 3
  Add-Unique -List $riskReasons -Value "dependency-metadata"
}

if ($sharedFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "shared-components"
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

if ($htmlTsFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "typescript"
}

if ($htmlScssFiles.Count -gt 0 -or $htmlTemplateFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "template-style"
}

$riskLevel = "low"
if ($riskPoints -ge 5) {
  $riskLevel = "high"
} elseif ($riskPoints -ge 2) {
  $riskLevel = "medium"
}

$requiredCommands = New-Object System.Collections.Generic.List[string]
$optionalCommands = New-Object System.Collections.Generic.List[string]

if ($htmlTsFiles.Count -gt 0) {
  $tsFiles = $htmlTsFiles | ForEach-Object { $_ -replace "^html/", "" }
  Add-Unique -List $requiredCommands -Value ("cd html && yarn eslint " + ($tsFiles -join " "))
}

if ($htmlScssFiles.Count -gt 0) {
  $scssFiles = $htmlScssFiles | ForEach-Object { $_ -replace "^html/", "" }
  Add-Unique -List $optionalCommands -Value ("cd html && yarn stylelint " + ($scssFiles -join " "))
}

if ($htmlDepsChanged.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "cd html && yarn install"
}

if ($riskLevel -eq "high" -and $htmlCodeFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "cd html && yarn test:prod"
}

if ($riskLevel -eq "medium" -and $htmlCodeFiles.Count -gt 0) {
  Add-Unique -List $optionalCommands -Value "cd html && yarn test:prod"
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
