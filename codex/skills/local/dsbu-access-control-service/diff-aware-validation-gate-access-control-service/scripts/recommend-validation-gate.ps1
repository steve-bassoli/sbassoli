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

  $result = & git -c core.safecrlf=false -C $Root @GitArgs 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git -C $Root $($GitArgs -join ' ')"
  }

  return @($result)
}

function Get-ChangedFiles {
  param([string]$Root)

  $staged = @(Invoke-Git -Root $Root -GitArgs @("diff", "--name-only", "--cached"))
  $unstaged = @(Invoke-Git -Root $Root -GitArgs @("diff", "--name-only"))
  $untracked = @(Invoke-Git -Root $Root -GitArgs @("ls-files", "--others", "--exclude-standard"))

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

function Get-KnownModules {
  param([string]$Root)

  $settingsPath = Join-Path $Root "settings.gradle"
  if (-not (Test-Path -LiteralPath $settingsPath)) {
    return @()
  }

  $modules = New-Object System.Collections.Generic.List[string]

  foreach ($line in Get-Content -LiteralPath $settingsPath) {
    foreach ($match in [regex]::Matches($line, "'([^']+)'")) {
      Add-Unique -List $modules -Value $match.Groups[1].Value
    }
  }

  return @($modules)
}

function Get-ModuleFromPath {
  param(
    [string]$Path,
    [string[]]$KnownModules
  )

  $normalizedPath = $Path -replace "\\", "/"
  $parts = $normalizedPath.Split("/")

  if ($parts.Count -eq 0) {
    return $null
  }

  if ($KnownModules -contains $parts[0]) {
    return $parts[0]
  }

  return $null
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

$knownModules = @(Get-KnownModules -Root $RepoRoot)

$mainSourceFiles = @($files | Where-Object { $_ -match "^[^/]+/src/main/" })
$testSourceFiles = @($files | Where-Object { $_ -match "^[^/]+/src/test/" })
$integrationTestFiles = @($files | Where-Object { $_ -match "^[^/]+/src/integrationTest/" })
$myBatisFiles = @($files | Where-Object { $_ -match "^dao/src/main/resources/mybatis/" })
$migrationFiles = @($files | Where-Object { $_ -match "^tenancy/src/main/resources/migration/" -or $_ -match "\.sql$" })
$sharedModuleFiles = @($files | Where-Object { $_ -match "^(common|domain|service-model|internal-service-model|client)/" })
$apiSurfaceFiles = @($files | Where-Object { $_ -match "^(service|service-model|internal-service|internal-service-model|client)/src/main/" })

$buildMetadataFiles = @($files | Where-Object {
    $normalized = $_ -replace "\\", "/"
    if ($normalized -in @("build.gradle", "settings.gradle", "gradle.properties", "gradlew", "gradlew.bat")) {
      return $true
    }

    if ($normalized -match "^gradle/" -or $normalized -match "^spotless/" -or $normalized -match "^gradle/libs\.versions\.toml$") {
      return $true
    }

    $module = Get-ModuleFromPath -Path $normalized -KnownModules $knownModules
    if ($null -ne $module -and $normalized -in @("$module/$module.gradle", "$module/build.gradle", "$module/build.gradle.kts")) {
      return $true
    }

    return $false
  })

$changedModules = New-Object System.Collections.Generic.List[string]
$modulesWithMainChanges = New-Object System.Collections.Generic.List[string]
$modulesWithTestChanges = New-Object System.Collections.Generic.List[string]
$modulesWithIntegrationTestChanges = New-Object System.Collections.Generic.List[string]

foreach ($file in $files) {
  $module = Get-ModuleFromPath -Path $file -KnownModules $knownModules
  if ($null -ne $module) {
    Add-Unique -List $changedModules -Value $module
  }
}

foreach ($file in $mainSourceFiles) {
  $module = Get-ModuleFromPath -Path $file -KnownModules $knownModules
  if ($null -ne $module) {
    Add-Unique -List $modulesWithMainChanges -Value $module
  }
}

foreach ($file in $testSourceFiles) {
  $module = Get-ModuleFromPath -Path $file -KnownModules $knownModules
  if ($null -ne $module) {
    Add-Unique -List $modulesWithTestChanges -Value $module
  }
}

foreach ($file in $integrationTestFiles) {
  $module = Get-ModuleFromPath -Path $file -KnownModules $knownModules
  if ($null -ne $module) {
    Add-Unique -List $modulesWithIntegrationTestChanges -Value $module
  }
}

$riskPoints = 0
$riskReasons = New-Object System.Collections.Generic.List[string]

if ($buildMetadataFiles.Count -gt 0) {
  $riskPoints += 3
  Add-Unique -List $riskReasons -Value "build-or-dependency-metadata"
}

if ($sharedModuleFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "shared-modules"
}

if ($migrationFiles.Count -gt 0) {
  $riskPoints += 2
  Add-Unique -List $riskReasons -Value "database-migration"
}

if ($myBatisFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "mybatis"
}

if ($apiSurfaceFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "api-surface"
}

if ($changedModules.Count -gt 1) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "multi-module"
}

if ($mainSourceFiles.Count -gt 0) {
  $riskPoints += 1
  Add-Unique -List $riskReasons -Value "source-main"
}

$riskLevel = "low"
if ($riskPoints -ge 5) {
  $riskLevel = "high"
} elseif ($riskPoints -ge 2) {
  $riskLevel = "medium"
}

$requiredCommands = New-Object System.Collections.Generic.List[string]
$optionalCommands = New-Object System.Collections.Generic.List[string]

foreach ($module in $modulesWithMainChanges) {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat :${module}:compileJava"
}

foreach ($module in $modulesWithTestChanges) {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat :${module}:test"
}

foreach ($module in $modulesWithIntegrationTestChanges) {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat :${module}:integrationTest"
}

if ($myBatisFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat :dao:test"
}

if ($buildMetadataFiles.Count -gt 0) {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat build -x test"
}

if ($riskLevel -eq "high") {
  Add-Unique -List $requiredCommands -Value "./gradlew.bat test"
}

if ($riskLevel -eq "medium") {
  $candidateModules = New-Object System.Collections.Generic.List[string]

  foreach ($module in $modulesWithMainChanges) {
    Add-Unique -List $candidateModules -Value $module
  }

  if ($candidateModules.Count -eq 0) {
    foreach ($module in $changedModules) {
      Add-Unique -List $candidateModules -Value $module
    }
  }

  foreach ($module in $candidateModules) {
    $moduleTestCommand = "./gradlew.bat :${module}:test"
    if (-not $requiredCommands.Contains($moduleTestCommand)) {
      Add-Unique -List $optionalCommands -Value $moduleTestCommand
    }
  }

  if ($optionalCommands.Count -eq 0) {
    Add-Unique -List $optionalCommands -Value "./gradlew.bat test"
  }
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
