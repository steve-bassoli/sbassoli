[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InvokingSkillName,
  [string]$QueueUse = "items",
  [string]$StateUse = "items_status",
  [string]$QueuePath = "",
  [string]$StatePath = "",
  [ValidateSet("preserve", "reset")]
  [string]$Mode = "preserve"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-AbsolutePath {
  param(
    [string]$Path,
    [string]$BasePath
  )

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path -Path $BasePath -ChildPath $Path))
}

function Normalize-NameToken {
  param(
    [string]$Value,
    [string]$FieldName
  )

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "$FieldName cannot be blank."
  }

  $normalized = $Value.Trim().ToLowerInvariant()
  $normalized = [regex]::Replace($normalized, "[^a-z0-9]+", "_")
  $normalized = [regex]::Replace($normalized, "_{2,}", "_")
  $normalized = $normalized.Trim("_")

  if ([string]::IsNullOrWhiteSpace($normalized)) {
    throw "$FieldName has no usable letters or digits after normalization."
  }

  return $normalized
}

function Get-CanonicalSkillFilePath {
  param(
    [string]$RepoRoot,
    [string]$InvokingSkillName,
    [string]$UseForSkill
  )

  $skillToken = Normalize-NameToken -Value $InvokingSkillName -FieldName "InvokingSkillName"
  $useToken = Normalize-NameToken -Value $UseForSkill -FieldName "UseForSkill"
  return [System.IO.Path]::GetFullPath((Join-Path -Path $RepoRoot -ChildPath "codex/output/$skillToken`_$useToken.txt"))
}

function Resolve-CanonicalPath {
  param(
    [string]$ProvidedPath,
    [string]$CanonicalPath,
    [string]$BasePath,
    [string]$Label
  )

  if ([string]::IsNullOrWhiteSpace($ProvidedPath)) {
    return $CanonicalPath
  }

  $resolvedProvidedPath = Resolve-AbsolutePath -Path $ProvidedPath -BasePath $BasePath
  if (-not [string]::Equals($resolvedProvidedPath, $CanonicalPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "$Label must follow /codex/output/<name_of_invoking_skill>_<use_for_skill>.txt. Expected path: $CanonicalPath"
  }

  return $resolvedProvidedPath
}

function Normalize-Status {
  param([string]$Status)

  $value = if ($null -eq $Status) { "" } else { $Status.Trim().ToLowerInvariant() }
  switch ($value) {
    "open" { return "open" }
    "done" { return "done" }
    "skipped" { return "skipped" }
    "blocked" { return "blocked" }
    default { return "open" }
  }
}

function Normalize-Notes {
  param([string]$Text)

  if ($null -eq $Text) {
    return ""
  }

  return (($Text -replace "`t", " ") -replace "(\r?\n)+", " ").Trim()
}

function Get-QueueItems {
  param([string]$Path)

  if (-not (Test-Path -Path $Path)) {
    throw "Queue file not found: $Path"
  }

  $raw = Get-Content -Raw -Path $Path
  if ([string]::IsNullOrWhiteSpace($raw)) {
    throw "Queue file is empty: $Path"
  }

  $parsed = $raw | ConvertFrom-Json
  $items = @()

  if ($parsed -is [System.Array]) {
    $items = @($parsed)
  } elseif ($null -ne $parsed -and $parsed.PSObject.Properties.Name -contains "items") {
    $items = @($parsed.items)
  } else {
    throw "Queue file must be a JSON array or an object with an items array."
  }

  $seenIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  $normalized = New-Object System.Collections.Generic.List[object]
  $index = 0

  foreach ($item in $items) {
    $index++
    $id = if ($null -eq $item.id) { "" } else { [string]$item.id }
    if ([string]::IsNullOrWhiteSpace($id)) {
      throw "Queue item #$index is missing id."
    }

    if (-not $seenIds.Add($id)) {
      throw "Queue contains duplicate id: $id"
    }

    $order = $index
    if ($null -ne $item.order -and ([string]$item.order) -match "^-?\d+$") {
      $order = [int]$item.order
    }

    $normalized.Add([pscustomobject]@{
        id    = $id
        order = $order
        index = $index
      })
  }

  return @(
    $normalized |
      Sort-Object @{ Expression = { $_.order } }, @{ Expression = { $_.index } }
  )
}

function Read-StateMap {
  param([string]$Path)

  $map = @{}
  if (-not (Test-Path -Path $Path)) {
    return $map
  }

  $lines = @(Get-Content -Path $Path)
  if ($lines.Count -eq 0) {
    return $map
  }

  $startIndex = 0
  if ($lines[0].Trim().ToLowerInvariant() -eq "id`tstatus`tnotes`tupdated_at_utc") {
    $startIndex = 1
  }

  for ($i = $startIndex; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $parts = $line -split "`t", 4
    if ($parts.Count -lt 2) {
      continue
    }

    $id = $parts[0].Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
      continue
    }

    if ($map.ContainsKey($id)) {
      continue
    }

    $status = Normalize-Status -Status $parts[1]
    $notes = if ($parts.Count -ge 3) { Normalize-Notes -Text $parts[2] } else { "" }
    $updated = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }

    $map[$id] = [pscustomobject]@{
      status        = $status
      notes         = $notes
      updated_at_utc = $updated
    }
  }

  return $map
}

$repoRoot = (Get-Location).Path
$canonicalQueuePath = Get-CanonicalSkillFilePath -RepoRoot $repoRoot -InvokingSkillName $InvokingSkillName -UseForSkill $QueueUse
$canonicalStatePath = Get-CanonicalSkillFilePath -RepoRoot $repoRoot -InvokingSkillName $InvokingSkillName -UseForSkill $StateUse
$resolvedQueuePath = Resolve-CanonicalPath -ProvidedPath $QueuePath -CanonicalPath $canonicalQueuePath -BasePath $repoRoot -Label "QueuePath"
$resolvedStatePath = Resolve-CanonicalPath -ProvidedPath $StatePath -CanonicalPath $canonicalStatePath -BasePath $repoRoot -Label "StatePath"

$stateDirectory = Split-Path -Path $resolvedStatePath -Parent
if ($stateDirectory -and -not (Test-Path -Path $stateDirectory)) {
  New-Item -Path $stateDirectory -ItemType Directory -Force | Out-Null
}

$queueItems = Get-QueueItems -Path $resolvedQueuePath
$stateMap = if ($Mode -eq "preserve") { Read-StateMap -Path $resolvedStatePath } else { @{} }
$now = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("id`tstatus`tnotes`tupdated_at_utc")

$newCount = 0
$preservedCount = 0

foreach ($item in $queueItems) {
  $status = "open"
  $notes = ""
  $updated = $now

  if ($Mode -eq "preserve" -and $stateMap.ContainsKey($item.id)) {
    $existing = $stateMap[$item.id]
    $status = Normalize-Status -Status $existing.status
    $notes = Normalize-Notes -Text $existing.notes
    $updated = if ([string]::IsNullOrWhiteSpace($existing.updated_at_utc)) { $now } else { $existing.updated_at_utc }
    $preservedCount++
  } else {
    $newCount++
  }

  $lines.Add("$($item.id)`t$status`t$notes`t$updated")
}

Set-Content -Path $resolvedStatePath -Value $lines -Encoding utf8

Write-Output "Invoking skill: $(Normalize-NameToken -Value $InvokingSkillName -FieldName 'InvokingSkillName')"
Write-Output "Queue file: $resolvedQueuePath"
Write-Output "State file synced: $resolvedStatePath"
Write-Output "Queue items: $(@($queueItems).Count)"
Write-Output "Preserved rows: $preservedCount"
Write-Output "New rows: $newCount"
Write-Output "Mode: $Mode"
