[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InvokingSkillName,
  [string]$StateUse = "items_status",
  [string]$StatePath = "",
  [Parameter(Mandatory = $true)]
  [string]$ItemId,
  [Parameter(Mandatory = $true)]
  [ValidateSet("open", "done", "skipped", "blocked")]
  [string]$Status,
  [string]$Notes,
  [switch]$AppendNotes
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

function Normalize-Notes {
  param([string]$Text)

  if ($null -eq $Text) {
    return ""
  }

  return (($Text -replace "`t", " ") -replace "(\r?\n)+", " ").Trim()
}

function Parse-StateRows {
  param([string]$Path)

  if (-not (Test-Path -Path $Path)) {
    throw "State file not found: $Path"
  }

  $lines = @(Get-Content -Path $Path)
  if ($lines.Count -eq 0) {
    throw "State file is empty: $Path"
  }

  $startIndex = 0
  if ($lines[0].Trim().ToLowerInvariant() -eq "id`tstatus`tnotes`tupdated_at_utc") {
    $startIndex = 1
  }

  $rows = New-Object System.Collections.Generic.List[object]
  for ($i = $startIndex; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    if ([string]::IsNullOrWhiteSpace($line)) {
      continue
    }

    $parts = $line -split "`t", 4
    $id = if ($parts.Count -ge 1) { $parts[0].Trim() } else { "" }
    if ([string]::IsNullOrWhiteSpace($id)) {
      continue
    }

    $status = if ($parts.Count -ge 2) { $parts[1].Trim().ToLowerInvariant() } else { "open" }
    if ($status -notin @("open", "done", "skipped", "blocked")) {
      $status = "open"
    }

    $notes = if ($parts.Count -ge 3) { Normalize-Notes -Text $parts[2] } else { "" }
    $updated = if ($parts.Count -ge 4) { $parts[3].Trim() } else { "" }

    $rows.Add([pscustomobject]@{
        id            = $id
        status        = $status
        notes         = $notes
        updated_at_utc = $updated
      })
  }

  return $rows
}

$repoRoot = (Get-Location).Path
$canonicalStatePath = Get-CanonicalSkillFilePath -RepoRoot $repoRoot -InvokingSkillName $InvokingSkillName -UseForSkill $StateUse
$resolvedStatePath = Resolve-CanonicalPath -ProvidedPath $StatePath -CanonicalPath $canonicalStatePath -BasePath $repoRoot -Label "StatePath"
$rows = Parse-StateRows -Path $resolvedStatePath

$hasNotesArgument = $PSBoundParameters.ContainsKey("Notes")
$normalizedNotes = if ($hasNotesArgument) { Normalize-Notes -Text $Notes } else { "" }
$normalizedItemId = $ItemId.Trim()
if ([string]::IsNullOrWhiteSpace($normalizedItemId)) {
  throw "ItemId cannot be blank."
}

$found = $false
$updatedRow = $null
$updatedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

foreach ($row in $rows) {
  if ($row.id.Equals($normalizedItemId, [System.StringComparison]::OrdinalIgnoreCase)) {
    $found = $true
    $row.status = $Status

    if ($hasNotesArgument) {
      if ($AppendNotes.IsPresent -and -not [string]::IsNullOrWhiteSpace($row.notes) -and -not [string]::IsNullOrWhiteSpace($normalizedNotes)) {
        $row.notes = Normalize-Notes -Text "$($row.notes) | $normalizedNotes"
      } else {
        $row.notes = $normalizedNotes
      }
    }

    $row.updated_at_utc = $updatedAt
    $updatedRow = $row
    break
  }
}

if (-not $found) {
  throw "Item id '$normalizedItemId' was not found in state file: $resolvedStatePath"
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("id`tstatus`tnotes`tupdated_at_utc")
foreach ($row in $rows) {
  $lines.Add("$($row.id)`t$($row.status)`t$($row.notes)`t$($row.updated_at_utc)")
}

Set-Content -Path $resolvedStatePath -Value $lines -Encoding utf8

Write-Output "Updated item: $normalizedItemId"
Write-Output "Invoking skill: $(Normalize-NameToken -Value $InvokingSkillName -FieldName 'InvokingSkillName')"
Write-Output "State path: $resolvedStatePath"
Write-Output "Status: $Status"
if ($hasNotesArgument) {
  Write-Output "Notes: $($updatedRow.notes)"
}
