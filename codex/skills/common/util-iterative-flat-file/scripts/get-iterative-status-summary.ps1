[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$InvokingSkillName,
  [string]$StateUse = "items_status",
  [string]$StatePath = "",
  [switch]$AsJson
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

function Read-StateRows {
  param([string]$Path)

  if (-not (Test-Path -Path $Path)) {
    throw "State file not found: $Path"
  }

  $lines = @(Get-Content -Path $Path)
  if ($lines.Count -eq 0) {
    return @()
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
    if ($parts.Count -lt 2) {
      continue
    }

    $id = $parts[0].Trim()
    if ([string]::IsNullOrWhiteSpace($id)) {
      continue
    }

    $status = $parts[1].Trim().ToLowerInvariant()
    if ($status -notin @("open", "done", "skipped", "blocked")) {
      $status = "open"
    }

    $notes = if ($parts.Count -ge 3) { $parts[2].Trim() } else { "" }
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
$rows = Read-StateRows -Path $resolvedStatePath

$openRows = @($rows | Where-Object { $_.status -eq "open" })
$doneRows = @($rows | Where-Object { $_.status -eq "done" })
$skippedRows = @($rows | Where-Object { $_.status -eq "skipped" })
$blockedRows = @($rows | Where-Object { $_.status -eq "blocked" })

$payload = [ordered]@{
  state_path         = $resolvedStatePath
  total              = $rows.Count
  open               = $openRows.Count
  done               = $doneRows.Count
  skipped            = $skippedRows.Count
  blocked            = $blockedRows.Count
  total_processed    = $doneRows.Count + $skippedRows.Count
  remaining_open     = $openRows.Count
  open_ids           = @($openRows | Select-Object -ExpandProperty id)
  blocked_ids        = @($blockedRows | Select-Object -ExpandProperty id)
}

if ($AsJson.IsPresent) {
  $payload | ConvertTo-Json -Depth 4
  exit 0
}

Write-Output "State path: $($payload.state_path)"
Write-Output "Total items: $($payload.total)"
Write-Output "Total processed: $($payload.total_processed)"
Write-Output "Done: $($payload.done)"
Write-Output "Skipped: $($payload.skipped)"
Write-Output "Blocked: $($payload.blocked)"
Write-Output "Remaining open: $($payload.remaining_open)"
Write-Output "Invoking skill: $(Normalize-NameToken -Value $InvokingSkillName -FieldName 'InvokingSkillName')"

if ($payload.open_ids.Count -gt 0) {
  Write-Output "Open ids: $([string]::Join(', ', $payload.open_ids))"
}

if ($payload.blocked_ids.Count -gt 0) {
  Write-Output "Blocked ids: $([string]::Join(', ', $payload.blocked_ids))"
}
