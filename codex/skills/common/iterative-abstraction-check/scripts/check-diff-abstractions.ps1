[CmdletBinding()]
param(
  [string]$RepoRoot = ".",
  [string]$PersistPath = "codex/output/iterative_abstraction_check_run_log.txt",
  [string]$ChecklistPath = "codex/output/iterative_abstraction_check_candidates.txt",
  [string]$QueuePath = "codex/output/iterative_abstraction_check_items.txt",
  [string]$AllowlistPath = "",
  [Alias("BaseRef")]
  [string]$CompareRef = "",
  [int]$ExactWindowSize = 4,
  [int]$StructuralWindowSize = 6,
  [int]$MaxNetAddedLinesForCandidate = 80,
  [int]$MaxFindings = 40,
  [string]$ResolveCandidateId = "",
  [switch]$NoFailOnHighConfidence,
  [switch]$SkipQueueSync
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

  return [System.IO.Path]::GetFullPath((Join-Path $BasePath $Path))
}

function Invoke-Git {
  param(
    [string]$Root,
    [string[]]$GitArgs
  )

  $result = & git -C $Root @GitArgs 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git -C $Root $($GitArgs -join ' ')"
  }

  if ($null -eq $result) {
    return @()
  }

  return @($result)
}

function Join-Lines {
  param(
    [object]$Lines,
    [string]$Separator = [Environment]::NewLine
  )

  if ($null -eq $Lines) {
    return ""
  }

  return [string]::Join($Separator, @($Lines))
}

function Resolve-CompareRefMetadata {
  param(
    [string]$Root,
    [string]$RefName
  )

  if ([string]::IsNullOrWhiteSpace($RefName)) {
    return [pscustomobject]@{
      name        = ""
      commitSha   = ""
      mergeBaseSha = ""
    }
  }

  $candidate = $RefName.Trim()

  try {
    $commitSha = (Invoke-Git -Root $Root -GitArgs @("rev-parse", "--verify", "$candidate^{commit}")) -join ""
  } catch {
    throw "CompareRef '$candidate' is not a valid commit-ish in $Root."
  }

  $mergeBaseSha = (Invoke-Git -Root $Root -GitArgs @("merge-base", $candidate, "HEAD")) -join ""

  return [pscustomobject]@{
    name         = $candidate
    commitSha    = $commitSha
    mergeBaseSha = $mergeBaseSha
  }
}

function Get-ChangedFiles {
  param([string]$Root)

  $staged = Invoke-Git -Root $Root -GitArgs @("diff", "--name-only", "--cached")
  $unstaged = Invoke-Git -Root $Root -GitArgs @("diff", "--name-only")
  $untracked = Invoke-Git -Root $Root -GitArgs @("ls-files", "--others", "--exclude-standard")

  $all = @($staged + $unstaged + $untracked |
      Where-Object { $_ -and $_.Trim() -ne "" } |
      Sort-Object -Unique)

  return [pscustomobject]@{
    staged    = @($staged)
    unstaged  = @($unstaged)
    untracked = @($untracked)
    all       = $all
  }
}

function Get-ChangedFilesFromCompareRef {
  param(
    [string]$Root,
    [string]$RefName
  )

  $tracked = Invoke-Git -Root $Root -GitArgs @("diff", "--name-only", "--no-color", "$RefName...")
  $untracked = Invoke-Git -Root $Root -GitArgs @("ls-files", "--others", "--exclude-standard")

  $all = @($tracked + $untracked |
      Where-Object { $_ -and $_.Trim() -ne "" } |
      Sort-Object -Unique)

  return [pscustomobject]@{
    staged    = @($tracked)
    unstaged  = @()
    untracked = @($untracked)
    all       = $all
  }
}

function Ensure-FileExists {
  param([string]$Path)

  $directory = Split-Path -Parent $Path
  if ($directory -and -not (Test-Path $directory)) {
    [void](New-Item -ItemType Directory -Force -Path $directory)
  }

  if (-not (Test-Path $Path)) {
    [void](New-Item -ItemType File -Force -Path $Path)
  }
}

function Get-SeverityRank {
  param([string]$Severity)

  switch ($Severity) {
    "high" { return 0 }
    "medium" { return 1 }
    default { return 2 }
  }
}

function New-CandidateId {
  param([object]$Finding)

  $canonical = [string]::Join(
    "|",
    @(
      "$($Finding.mode)",
      "$($Finding.windowSize)",
      "$($Finding.fileCount)",
      ([string]::Join(",", @($Finding.files | Sort-Object))),
      ([string]::Join("`n", @($Finding.sample)))
    )
  )

  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
    $hash = $sha.ComputeHash($bytes)
    $hex = ([System.BitConverter]::ToString($hash)).Replace("-", "")
    return "ABS-$($hex.Substring(0, 12))"
  } finally {
    $sha.Dispose()
  }
}

function Read-Checklist {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return [pscustomobject]@{
      pending         = @()
      resolvedHistory = @()
    }
  }

  $raw = Get-Content -Raw -Path $Path
  if ([string]::IsNullOrWhiteSpace($raw)) {
    return [pscustomobject]@{
      pending         = @()
      resolvedHistory = @()
    }
  }

  try {
    $parsed = $raw | ConvertFrom-Json
    return [pscustomobject]@{
      pending         = @($parsed.pending)
      resolvedHistory = @($parsed.resolvedHistory)
    }
  } catch {
    return [pscustomobject]@{
      pending         = @()
      resolvedHistory = @()
    }
  }
}

function Write-Checklist {
  param(
    [string]$Path,
    [string]$RepoRoot,
    [string]$PersistPath,
    [string]$Branch,
    [string]$HeadSha,
    [string]$CompareRef,
    [string]$CompareRefSha,
    [string]$MergeBaseSha,
    [object[]]$Pending,
    [object[]]$ResolvedHistory
  )

  Ensure-FileExists -Path $Path

  $payload = [ordered]@{
    schema                = "iterative-abstraction-checklist-v1"
    generatedAtUtc        = [DateTime]::UtcNow.ToString("o")
    repoRoot              = $RepoRoot
    branch                = $Branch
    headSha               = $HeadSha
    compareRef            = $CompareRef
    compareRefSha         = $CompareRefSha
    mergeBaseSha          = $MergeBaseSha
    sourcePersistLog      = $PersistPath
    pendingCount          = $Pending.Count
    pending               = @($Pending)
    resolvedHistoryCount  = $ResolvedHistory.Count
    resolvedHistory       = @($ResolvedHistory | Select-Object -Last 300)
  }

  $json = $payload | ConvertTo-Json -Depth 8
  Set-Content -Path $Path -Value $json -Encoding utf8
}

function Write-NextCandidatePrompt {
  param(
    [string]$ChecklistPath,
    [object[]]$Pending
  )

  if ($Pending.Count -eq 0) {
    Write-Output "No pending abstraction candidates in $ChecklistPath."
    return
  }

  $next = $Pending[0]
  Write-Output "Next abstraction candidate: $($next.id) (severity=$($next.severity), mode=$($next.mode), files=$($next.fileCount), occurrences=$($next.occurrenceCount))"
  Write-Output "Locations: $([string]::Join(', ', @($next.locations)))"
  foreach ($line in @($next.sample)) {
    Write-Output "Sample: $line"
  }
  Write-Output "After addressing this candidate, run with -ResolveCandidateId $($next.id) to remove it and prompt the next one."
}

function Parse-Location {
  param([string]$Location)

  if ([string]::IsNullOrWhiteSpace($Location)) {
    return [pscustomobject]@{
      file = "unknown"
      line = "unknown"
    }
  }

  $trimmed = $Location.Trim()
  if ($trimmed -match '^(?<file>.+?):(?<line>\d+)$') {
    return [pscustomobject]@{
      file = $Matches.file
      line = [int]$Matches.line
    }
  }

  return [pscustomobject]@{
    file = $trimmed
    line = "unknown"
  }
}

function Build-QueueItemsFromPendingCandidates {
  param(
    [object[]]$PendingCandidates,
    [string]$PersistPath,
    [string]$ChecklistPath
  )

  $items = New-Object System.Collections.Generic.List[object]
  $order = 0

  foreach ($candidate in @($PendingCandidates)) {
    $order++
    $locations = @($candidate.locations)
    $location = if ($locations.Count -gt 0) { [string]$locations[0] } else { "unknown" }
    $parsedLocation = Parse-Location -Location $location
    $sampleLines = @($candidate.sample)
    $codeContext = if ($sampleLines.Count -gt 0) { [string]::Join("`n", $sampleLines) } else { "" }
    $severity = if ([string]::IsNullOrWhiteSpace([string]$candidate.severity)) { "medium" } else { ([string]$candidate.severity).ToLowerInvariant() }
    $riskContext = "mode=$($candidate.mode); occurrences=$($candidate.occurrenceCount); files=$($candidate.fileCount); windowSize=$($candidate.windowSize)"

    $items.Add([ordered]@{
        id                = [string]$candidate.id
        order             = $order
        item_type         = "abstraction_candidate"
        description       = "Address abstraction candidate $($candidate.id) (severity=$severity)."
        source_file       = $parsedLocation.file
        source_line_start = $parsedLocation.line
        source_line_end   = $parsedLocation.line
        code_context      = $codeContext
        target_file       = $parsedLocation.file
        priority          = $severity
        risk_context      = $riskContext
        reference_url     = "n/a"
        metadata          = [ordered]@{
          mode             = $candidate.mode
          severity         = $severity
          file_count       = $candidate.fileCount
          occurrence_count = $candidate.occurrenceCount
          window_size      = $candidate.windowSize
          locations        = $locations
          checklist_path   = $ChecklistPath
          persist_path     = $PersistPath
        }
      })
  }

  return $items.ToArray()
}

function Write-QueueItems {
  param(
    [string]$Path,
    [object[]]$Items
  )

  Ensure-FileExists -Path $Path
  if ($null -eq $Items -or $Items.Count -eq 0) {
    $json = "[]"
  } else {
    $json = ConvertTo-Json -InputObject $Items -Depth 10
  }
  Set-Content -Path $Path -Value $json -Encoding utf8
}

function Sync-QueueState {
  param(
    [string]$QueuePath
  )

  $syncScriptPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\util-iterative-flat-file\scripts\sync-iterative-state.ps1"))
  if (-not (Test-Path -Path $syncScriptPath)) {
    throw "Missing util sync script: $syncScriptPath"
  }

  & $syncScriptPath -InvokingSkillName "iterative-abstraction-check" -QueuePath $QueuePath -Mode preserve
}

function Append-Section {
  param(
    [string]$Path,
    [string]$SectionName,
    [string]$Content
  )

  Add-Content -Path $Path -Value "===== $SectionName =====" -Encoding utf8
  if ([string]::IsNullOrWhiteSpace($Content)) {
    Add-Content -Path $Path -Value "<none>" -Encoding utf8
  } else {
    Add-Content -Path $Path -Value $Content -Encoding utf8
  }
  Add-Content -Path $Path -Value "" -Encoding utf8
}

function Test-CodeFile {
  param([string]$Path)
  return $Path -match '\.(ts|tsx|js|jsx|html|scss|css)$'
}

function Test-TestFile {
  param([string]$Path)
  return $Path -match '\.(spec|test)\.(ts|tsx|js|jsx)$' -or $Path -match '(^|[\\/])__tests__([\\/]|$)'
}

function Normalize-Whitespace {
  param([string]$Text)
  $value = if ($null -eq $Text) { "" } else { $Text }
  return ([regex]::Replace($value, '\s+', ' ')).Trim()
}

function Normalize-StructuralLine {
  param(
    [string]$Text,
    [System.Collections.Generic.HashSet[string]]$Keywords
  )

  $value = Normalize-Whitespace -Text $Text
  if (-not $value) {
    return ""
  }

  $singleQuotedStringPattern = '''[^''\\]*(?:\\.[^''\\]*)*'''
  $doubleQuotedStringPattern = '"[^"\\]*(?:\\.[^"\\]*)*"'
  $templateStringPattern = '`[^`]*`'
  $stringPattern = "$singleQuotedStringPattern|$doubleQuotedStringPattern|$templateStringPattern"
  $value = [regex]::Replace($value, $stringPattern, '__STR__')
  $value = [regex]::Replace($value, '\b\d+(?:\.\d+)?\b', '__NUM__')
  $value = [regex]::Replace(
    $value,
    '\b[A-Za-z_][A-Za-z0-9_]*\b',
    [System.Text.RegularExpressions.MatchEvaluator]{
      param($match)
      $token = $match.Value
      if ($Keywords.Contains($token)) {
        return $token
      }
      return '__ID__'
    }
  )
  return $value
}

function Test-LowSignalBlock {
  param([string[]]$Lines)

  if ($Lines.Count -eq 0) {
    return $true
  }

  $emptyOrPunctuation = 0
  $importLike = 0
  $alphaCount = 0

  foreach ($line in $Lines) {
    $normalized = Normalize-Whitespace -Text $line
    if (-not $normalized -or $normalized -match '^[{}();,\[\]]+$' -or $normalized -match '^(//|/\*|\*|\*/|<!--)') {
      $emptyOrPunctuation++
    }

    if ($normalized -match '^(import|export)\s') {
      $importLike++
    }

    $alphaCount += (([regex]::Replace($normalized, '[^A-Za-z]', '')).Length)
  }

  if ($emptyOrPunctuation -ge [int][Math]::Ceiling($Lines.Count / 2.0)) {
    return $true
  }

  if ($importLike -ge [int][Math]::Ceiling($Lines.Count / 2.0)) {
    return $true
  }

  if ($alphaCount -lt 18) {
    return $true
  }

  return $false
}

function Test-LowSignalHtmlAttributeBlock {
  param([string[]]$Lines)

  if ($Lines.Count -eq 0) {
    return $true
  }

  $simpleCount = 0
  foreach ($line in $Lines) {
    $normalized = Normalize-Whitespace -Text $line
    if (-not $normalized) {
      continue
    }

    if ($normalized -match '^\[[^]]+\]="[^"]*"$' -or
        $normalized -match '^\([^)]*\)="[^"]*"$' -or
        $normalized -match '^[A-Za-z][A-Za-z0-9-]*="[^"]*"$' -or
        $normalized -match '^</?[A-Za-z][^>]*>$' -or
        $normalized -match '^<[A-Za-z][^>]*$' -or
        $normalized -match '^></[A-Za-z][^>]*>$') {
      $simpleCount++
      continue
    }

    if ($normalized -match '\{\{|\}\}|=>|;|^\*ng|^\#|^\@') {
      return $false
    }
  }

  return $simpleCount -ge [int][Math]::Ceiling($Lines.Count * 0.85)
}

function Get-AllowlistPatterns {
  param([string]$Path)

  $patterns = New-Object System.Collections.Generic.List[System.Text.RegularExpressions.Regex]
  if (-not (Test-Path $Path)) {
    return $patterns
  }

  foreach ($rawLine in Get-Content -Path $Path) {
    $line = $rawLine.Trim()
    if (-not $line -or $line.StartsWith("#")) {
      continue
    }

    if ($line.StartsWith("-")) {
      $line = $line.Substring(1).Trim()
    }

    if ($line -match '^regex:\s*(.+)$') {
      $pattern = $Matches[1].Trim()
      if ($pattern) {
        $patterns.Add([regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
      }
      continue
    }

    if ($line -match '^literal:\s*(.+)$') {
      $literal = $Matches[1].Trim()
      if ($literal) {
        $patterns.Add([regex]::new([regex]::Escape($literal), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))
      }
      continue
    }
  }

  return $patterns
}

function Test-Allowlisted {
  param(
    [string]$Text,
    [System.Collections.Generic.List[System.Text.RegularExpressions.Regex]]$Patterns
  )

  foreach ($pattern in $Patterns) {
    if ($pattern.IsMatch($Text)) {
      return $true
    }
  }

  return $false
}

function Parse-HunkStartLine {
  param([string]$HunkHeader)
  if ($HunkHeader -match '^@@\s+-\d+(?:,\d+)?\s+\+(\d+)(?:,\d+)?\s+@@') {
    return [int]$Matches[1]
  }
  return 0
}

function Get-AddedLinesFromDiff {
  param([string[]]$DiffLines)

  $items = New-Object System.Collections.Generic.List[object]
  $currentFile = ""
  $currentLine = 0

  foreach ($line in $DiffLines) {
    if ($line -match '^\+\+\+\s+b/(.+)$') {
      $currentFile = $Matches[1]
      $currentLine = 0
      continue
    }

    if ($line -like "@@*@@*") {
      $currentLine = Parse-HunkStartLine -HunkHeader $line
      continue
    }

    if (-not $currentFile) {
      continue
    }

    if ($line.StartsWith("+") -and -not $line.StartsWith("+++")) {
      $items.Add([pscustomobject]@{
          file = $currentFile
          line = $currentLine
          text = $line.Substring(1)
        })
      $currentLine++
      continue
    }

    if ($line.StartsWith("-") -and -not $line.StartsWith("---")) {
      continue
    }

    if ($line -eq '\ No newline at end of file') {
      continue
    }

    if ($currentLine -gt 0) {
      $currentLine++
    }
  }

  return $items
}

function Get-NetAddedByFileFromDiff {
  param([string[]]$DiffLines)

  $netByFile = @{}
  $currentFile = ""

  foreach ($line in $DiffLines) {
    if ($line -match '^\+\+\+\s+b/(.+)$') {
      $currentFile = $Matches[1]
      if (-not $netByFile.ContainsKey($currentFile)) {
        $netByFile[$currentFile] = 0
      }
      continue
    }

    if (-not $currentFile) {
      continue
    }

    if ($line.StartsWith('+') -and -not $line.StartsWith('+++')) {
      $netByFile[$currentFile] += 1
      continue
    }

    if ($line.StartsWith('-') -and -not $line.StartsWith('---')) {
      $netByFile[$currentFile] -= 1
      continue
    }
  }

  return $netByFile
}

function Get-AddedLinesFromUntrackedFiles {
  param(
    [string]$Root,
    [string[]]$Files
  )

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($file in $Files) {
    if (-not (Test-CodeFile -Path $file)) {
      continue
    }

    $absoluteFile = Join-Path $Root $file
    if (-not (Test-Path $absoluteFile)) {
      continue
    }

    $lineNumber = 1
    foreach ($line in Get-Content -Path $absoluteFile) {
      $items.Add([pscustomobject]@{
          file = $file
          line = $lineNumber
          text = $line
        })
      $lineNumber++
    }
  }

  return $items
}

function Get-DuplicateFindings {
  param(
    [object[]]$AddedLines,
    [string]$Mode,
    [int]$WindowSize,
    [System.Collections.Generic.HashSet[string]]$Keywords,
    [System.Collections.Generic.List[System.Text.RegularExpressions.Regex]]$AllowlistPatterns,
    [hashtable]$NetAddedByFile,
    [int]$NetAddedThreshold
  )

  $byKey = @{}
  $fileGroups = $AddedLines | Group-Object file

  foreach ($fileGroup in $fileGroups) {
    $ordered = @($fileGroup.Group | Sort-Object line)
    $normalizedEntries = New-Object System.Collections.Generic.List[object]

    foreach ($entry in $ordered) {
      $normalized = if ($Mode -eq "exact") {
        Normalize-Whitespace -Text $entry.text
      } else {
        Normalize-StructuralLine -Text $entry.text -Keywords $Keywords
      }

      if (-not $normalized) {
        continue
      }

      $normalizedEntries.Add([pscustomobject]@{
          file       = $entry.file
          line       = [int]$entry.line
          normalized = $normalized
          original   = Normalize-Whitespace -Text $entry.text
        })
    }

    for ($i = 0; $i -le $normalizedEntries.Count - $WindowSize; $i++) {
      $slice = @($normalizedEntries[$i..($i + $WindowSize - 1)])
      $normalizedSlice = @($slice | ForEach-Object { $_.normalized })
      if (Test-LowSignalBlock -Lines $normalizedSlice) {
        continue
      }

      if ($Mode -eq "structural" -and $fileGroup.Name -match '\.html$') {
        $originalSlice = @($slice | ForEach-Object { $_.original })
        if (Test-LowSignalHtmlAttributeBlock -Lines $originalSlice) {
          continue
        }
      }

      $key = [string]::Join("`n", $normalizedSlice)
      if (-not $byKey.ContainsKey($key)) {
        $byKey[$key] = New-Object System.Collections.Generic.List[object]
      }

      $byKey[$key].Add([pscustomobject]@{
          file      = $fileGroup.Name
          startLine = [int]$slice[0].line
          endLine   = [int]$slice[$slice.Count - 1].line
          sample    = @($slice | ForEach-Object { $_.original })
        })
    }
  }

  $findings = New-Object System.Collections.Generic.List[object]

  foreach ($entry in $byKey.GetEnumerator()) {
    $occurrences = $entry.Value.ToArray()
    $files = @($occurrences | Select-Object -ExpandProperty file -Unique)
    if ($files.Count -lt 2) {
      continue
    }

    $netAddedAcrossFiles = 0
    foreach ($file in $files) {
      if ($NetAddedByFile.ContainsKey($file)) {
        $netAddedAcrossFiles += [int]$NetAddedByFile[$file]
      }
    }
    if ($NetAddedThreshold -gt 0 -and $netAddedAcrossFiles -gt $NetAddedThreshold) {
      continue
    }

    $sampleLines = @($occurrences[0].sample)
    $sampleText = [string]::Join("`n", $sampleLines)
    if (Test-Allowlisted -Text $sampleText -Patterns $AllowlistPatterns) {
      continue
    }

    $locations = @($occurrences | Select-Object -First 8 | ForEach-Object { "$($_.file):$($_.startLine)" })
    $findings.Add([pscustomobject]@{
        mode            = $Mode
        windowSize      = $WindowSize
        fileCount       = $files.Count
        occurrenceCount = $occurrences.Count
        netAddedAcrossFiles = $netAddedAcrossFiles
        files           = $files
        locations       = $locations
        sample          = $sampleLines
      })
  }

  return $findings.ToArray()
}

function Get-FindingSeverity {
  param([object]$Finding)

  if (-not $Finding -or $Finding.PSObject.Properties.Match('files').Count -eq 0) {
    return "low"
  }

  $productionFiles = @($Finding.files | Where-Object { -not (Test-TestFile -Path $_) })
  $productionFileCount = $productionFiles.Count

  if ($productionFileCount -ge 2) {
    if ($Finding.mode -eq "exact" -and $Finding.windowSize -ge 4) {
      return "high"
    }
    if ($Finding.mode -eq "structural" -and $Finding.windowSize -ge 6) {
      return "high"
    }
    return "medium"
  }

  if ($Finding.fileCount -ge 2) {
    return "low"
  }

  return "low"
}

function Format-FindingsForLog {
  param([object[]]$Findings)

  if ($Findings.Count -eq 0) {
    return "no_findings: true"
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $index = 1
  foreach ($finding in $Findings) {
    $candidateId = if ($finding.PSObject.Properties.Match("candidateId").Count -gt 0) { $finding.candidateId } else { "<none>" }
    $lines.Add("[$index] candidate_id=$candidateId; severity=$($finding.severity); mode=$($finding.mode); files=$($finding.fileCount); occurrences=$($finding.occurrenceCount); net_added=$($finding.netAddedAcrossFiles)")
    $lines.Add("locations: $([string]::Join(', ', $finding.locations))")
    foreach ($sampleLine in $finding.sample) {
      $lines.Add("sample: $sampleLine")
    }
    $lines.Add("")
    $index++
  }

  return [string]::Join([Environment]::NewLine, $lines)
}

function Get-LatestRunMetadata {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return $null
  }

  $raw = Get-Content -Raw -Path $Path
  if (-not $raw) {
    return $null
  }

  $startToken = "===== RUN_START ====="
  $endToken = "===== RUN_END ====="
  $startIndex = $raw.LastIndexOf($startToken, [System.StringComparison]::Ordinal)
  if ($startIndex -lt 0) {
    return $null
  }

  $endIndex = $raw.IndexOf($endToken, $startIndex, [System.StringComparison]::Ordinal)
  if ($endIndex -lt 0) {
    $endIndex = $raw.Length
  } else {
    $endIndex += $endToken.Length
  }

  $block = $raw.Substring($startIndex, $endIndex - $startIndex)
  $timestampMatch = [regex]::Match($block, "timestamp_utc:\s*(.+)")
  $resultMatch = [regex]::Match($block, "result:\s*(.+)")

  return [pscustomobject]@{
    timestamp = if ($timestampMatch.Success) { $timestampMatch.Groups[1].Value.Trim() } else { "" }
    result    = if ($resultMatch.Success) { $resultMatch.Groups[1].Value.Trim() } else { "" }
  }
}

$keywords = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@(
  "if", "else", "switch", "case", "default", "break", "continue",
  "for", "while", "do", "in", "of", "return", "try", "catch", "finally", "throw",
  "const", "let", "var", "function", "class", "new", "this", "super",
  "import", "from", "export", "type", "interface", "extends", "implements", "readonly",
  "public", "private", "protected", "static", "async", "await", "yield",
  "true", "false", "null", "undefined", "void", "typeof", "instanceof", "as"
) | ForEach-Object { [void]$keywords.Add($_) }

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
$resolvedPersistPath = Resolve-AbsolutePath -Path $PersistPath -BasePath $resolvedRepoRoot
$resolvedChecklistPath = Resolve-AbsolutePath -Path $ChecklistPath -BasePath $resolvedRepoRoot
$resolvedQueuePath = Resolve-AbsolutePath -Path $QueuePath -BasePath $resolvedRepoRoot
$resolvedAllowlistPath = if ([string]::IsNullOrWhiteSpace($AllowlistPath)) {
  Resolve-AbsolutePath -Path "..\references\abstraction-allowlist.md" -BasePath $PSScriptRoot
} else {
  Resolve-AbsolutePath -Path $AllowlistPath -BasePath $resolvedRepoRoot
}

Ensure-FileExists -Path $resolvedPersistPath
Ensure-FileExists -Path $resolvedChecklistPath
Ensure-FileExists -Path $resolvedQueuePath

$failOnHighConfidence = -not $NoFailOnHighConfidence.IsPresent

$runStarted = $false
$runEnded = $false
$highCount = 0
$mediumCount = 0
$lowCount = 0
$result = "error"

try {
  $timestampUtc = [DateTime]::UtcNow.ToString("o")
  $branch = (Invoke-Git -Root $resolvedRepoRoot -GitArgs @("rev-parse", "--abbrev-ref", "HEAD")) -join ""
  $headSha = (Invoke-Git -Root $resolvedRepoRoot -GitArgs @("rev-parse", "HEAD")) -join ""
  $compareRefMetadata = Resolve-CompareRefMetadata -Root $resolvedRepoRoot -RefName $CompareRef
  $resolvedCompareRef = $compareRefMetadata.name
  $compareRefSha = $compareRefMetadata.commitSha
  $mergeBaseSha = $compareRefMetadata.mergeBaseSha

  $changes = $null
  $stagedDiffLines = @()
  $unstagedDiffLines = @()
  $combinedTrackedDiffLines = @()
  $diffScope = "uncommitted_only"
  $changedFilesSource = "staged + unstaged + untracked"

  if ($resolvedCompareRef) {
    $changes = Get-ChangedFilesFromCompareRef -Root $resolvedRepoRoot -RefName $resolvedCompareRef
    $stagedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--no-color", "$resolvedCompareRef...HEAD")
    $unstagedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--no-color", "HEAD")
    $combinedTrackedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--no-color", "$resolvedCompareRef...")
    $diffScope = "compare_ref_merge_base_to_worktree"
    $changedFilesSource = "git diff --name-only $resolvedCompareRef... + untracked"
  } else {
    $changes = Get-ChangedFiles -Root $resolvedRepoRoot
    $stagedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--cached", "--no-color")
    $unstagedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--no-color")
    $combinedTrackedDiffLines = Invoke-Git -Root $resolvedRepoRoot -GitArgs @("diff", "--no-color", "HEAD")
  }

  $previousRun = Get-LatestRunMetadata -Path $resolvedPersistPath

  $stagedDiffText = Join-Lines -Lines $stagedDiffLines
  $unstagedDiffText = Join-Lines -Lines $unstagedDiffLines
  $compareRefLabel = if ($resolvedCompareRef) { $resolvedCompareRef } else { "<none>" }
  $compareRefShaLabel = if ($compareRefSha) { $compareRefSha } else { "<none>" }
  $mergeBaseShaLabel = if ($mergeBaseSha) { $mergeBaseSha } else { "<none>" }

  $runStartLines = New-Object System.Collections.Generic.List[string]
  $runStartLines.Add("timestamp_utc: $timestampUtc")
  $runStartLines.Add("repo_root: $resolvedRepoRoot")
  $runStartLines.Add("branch: $branch")
  $runStartLines.Add("head_sha: $headSha")
  $runStartLines.Add("diff_scope: $diffScope")
  $runStartLines.Add("compare_ref: $compareRefLabel")
  $runStartLines.Add("compare_ref_sha: $compareRefShaLabel")
  $runStartLines.Add("merge_base_sha: $mergeBaseShaLabel")
  $runStartLines.Add("changed_files_source: $changedFilesSource")
  $runStartLines.Add("persist_path: $resolvedPersistPath")
  $runStartLines.Add("checklist_path: $resolvedChecklistPath")
  $runStartLines.Add("queue_path: $resolvedQueuePath")
  $runStartLines.Add("allowlist_path: $resolvedAllowlistPath")
  $runStartLines.Add("exact_window_size: $ExactWindowSize")
  $runStartLines.Add("structural_window_size: $StructuralWindowSize")
  $runStartLines.Add("max_net_added_lines_for_candidate: $MaxNetAddedLinesForCandidate")
  $runStartLines.Add("changed_files_count: $($changes.all.Count)")
  if ($previousRun) {
    $runStartLines.Add("previous_run_timestamp_utc: $($previousRun.timestamp)")
    $runStartLines.Add("previous_run_result: $($previousRun.result)")
  } else {
    $runStartLines.Add("previous_run_timestamp_utc: <none>")
    $runStartLines.Add("previous_run_result: <none>")
  }
  $runStartLines.Add("changed_files:")
  if ($changes.all.Count -eq 0) {
    $runStartLines.Add("- <none>")
  } else {
    foreach ($file in $changes.all) {
      $runStartLines.Add("- $file")
    }
  }

  Append-Section -Path $resolvedPersistPath -SectionName "RUN_START" -Content ([string]::Join([Environment]::NewLine, $runStartLines))
  $runStarted = $true

  Append-Section -Path $resolvedPersistPath -SectionName "RAW_DIFF_STAGED" -Content $stagedDiffText
  Append-Section -Path $resolvedPersistPath -SectionName "RAW_DIFF_UNSTAGED" -Content $unstagedDiffText

  $allowlistPatterns = Get-AllowlistPatterns -Path $resolvedAllowlistPath

  $addedFromTrackedChanges = Get-AddedLinesFromDiff -DiffLines $combinedTrackedDiffLines
  $addedFromUntracked = Get-AddedLinesFromUntrackedFiles -Root $resolvedRepoRoot -Files $changes.untracked
  $netAddedByFile = Get-NetAddedByFileFromDiff -DiffLines $combinedTrackedDiffLines
  foreach ($group in @($addedFromUntracked | Group-Object file)) {
    $untrackedFile = $group.Name
    $lineCount = @($group.Group).Count
    if (-not $netAddedByFile.ContainsKey($untrackedFile)) {
      $netAddedByFile[$untrackedFile] = 0
    }
    $netAddedByFile[$untrackedFile] += $lineCount
  }

  $allAddedLines = @(
    @($addedFromTrackedChanges) + @($addedFromUntracked) |
      Where-Object {
        $item = $_
        $item -and $item.PSObject.Properties.Match('file').Count -gt 0 -and (Test-CodeFile -Path $item.file)
      }
  )

  $uniqueAddedLines = @(
    $allAddedLines |
      Group-Object { "$($_.file)|$($_.line)|$($_.text)" } |
      ForEach-Object { $_.Group[0] } |
      Sort-Object file, line
  )

  $exactFindings = @()
  $structuralFindings = @()
  if ($uniqueAddedLines.Count -ge $ExactWindowSize) {
    $exactFindings = Get-DuplicateFindings `
      -AddedLines $uniqueAddedLines `
      -Mode "exact" `
      -WindowSize $ExactWindowSize `
      -Keywords $keywords `
      -AllowlistPatterns $allowlistPatterns `
      -NetAddedByFile $netAddedByFile `
      -NetAddedThreshold $MaxNetAddedLinesForCandidate
  }
  if ($uniqueAddedLines.Count -ge $StructuralWindowSize) {
    $structuralFindings = Get-DuplicateFindings `
      -AddedLines $uniqueAddedLines `
      -Mode "structural" `
      -WindowSize $StructuralWindowSize `
      -Keywords $keywords `
      -AllowlistPatterns $allowlistPatterns `
      -NetAddedByFile $netAddedByFile `
      -NetAddedThreshold $MaxNetAddedLinesForCandidate
  }

  $allFindings = New-Object System.Collections.Generic.List[object]
  foreach ($finding in @(@($exactFindings) + @($structuralFindings))) {
    if (-not $finding -or $finding.PSObject.Properties.Match('files').Count -eq 0) {
      continue
    }
    $finding | Add-Member -NotePropertyName severity -NotePropertyValue (Get-FindingSeverity -Finding $finding)
    $finding | Add-Member -NotePropertyName candidateId -NotePropertyValue (New-CandidateId -Finding $finding)
    $allFindings.Add($finding)
  }

  $rankedFindings = @(
    $allFindings |
      Sort-Object `
        @{ Expression = { Get-SeverityRank -Severity $_.severity } }, `
        @{ Expression = { -1 * $_.fileCount } }, `
        @{ Expression = { -1 * $_.occurrenceCount } }, `
        @{ Expression = { $_.candidateId } } |
      Select-Object -First $MaxFindings
  )

  $highCount = @($rankedFindings | Where-Object { $_.severity -eq "high" }).Count
  $mediumCount = @($rankedFindings | Where-Object { $_.severity -eq "medium" }).Count
  $lowCount = @($rankedFindings | Where-Object { $_.severity -eq "low" }).Count

  if ($highCount -gt 0) {
    $result = "fail"
  } elseif ($mediumCount -gt 0) {
    $result = "warn"
  } else {
    $result = "pass"
  }

  $findingsContent = Format-FindingsForLog -Findings $rankedFindings
  Append-Section -Path $resolvedPersistPath -SectionName "FINDINGS" -Content $findingsContent

  $checklistData = Read-Checklist -Path $resolvedChecklistPath
  $resolvedHistory = @($checklistData.resolvedHistory)

  $candidateMap = @{}
  foreach ($finding in $rankedFindings) {
    if (-not $candidateMap.ContainsKey($finding.candidateId)) {
      $candidateMap[$finding.candidateId] = [pscustomobject]@{
        id              = $finding.candidateId
        status          = "pending"
        severity        = $finding.severity
        mode            = $finding.mode
        windowSize      = $finding.windowSize
        fileCount       = $finding.fileCount
        occurrenceCount = $finding.occurrenceCount
        locations       = @($finding.locations)
        sample          = @($finding.sample)
      }
    }
  }

  $pendingCandidates = @($candidateMap.Values |
      Sort-Object `
        @{ Expression = { Get-SeverityRank -Severity $_.severity } }, `
        @{ Expression = { -1 * $_.fileCount } }, `
        @{ Expression = { -1 * $_.occurrenceCount } }, `
        @{ Expression = { $_.id } })

  $resolvedMessage = ""
  $resolvedCandidateId = $ResolveCandidateId.Trim()
  if ($resolvedCandidateId) {
    $resolvedCandidate = $pendingCandidates | Where-Object { $_.id -eq $resolvedCandidateId } | Select-Object -First 1
    if ($resolvedCandidate) {
      $pendingCandidates = @($pendingCandidates | Where-Object { $_.id -ne $resolvedCandidateId })
      $resolvedHistory += [pscustomobject]@{
        id             = $resolvedCandidateId
        resolvedAtUtc  = [DateTime]::UtcNow.ToString("o")
        severity       = $resolvedCandidate.severity
        mode           = $resolvedCandidate.mode
        resolutionNote = "Removed by ResolveCandidateId flag."
      }
      $resolvedMessage = "Resolved candidate removed: $resolvedCandidateId"
    } else {
      $resolvedMessage = "ResolveCandidateId not found in current pending candidates: $resolvedCandidateId"
    }
  }

  Write-Checklist `
    -Path $resolvedChecklistPath `
    -RepoRoot $resolvedRepoRoot `
    -PersistPath $resolvedPersistPath `
    -Branch $branch `
    -HeadSha $headSha `
    -CompareRef $resolvedCompareRef `
    -CompareRefSha $compareRefSha `
    -MergeBaseSha $mergeBaseSha `
    -Pending $pendingCandidates `
    -ResolvedHistory $resolvedHistory

  $queueItems = @(
    Build-QueueItemsFromPendingCandidates `
      -PendingCandidates $pendingCandidates `
      -PersistPath $resolvedPersistPath `
      -ChecklistPath $resolvedChecklistPath
  )

  Write-QueueItems -Path $resolvedQueuePath -Items $queueItems

  $queueSyncMessage = "Queue state sync skipped by request."
  if (-not $SkipQueueSync.IsPresent) {
    Sync-QueueState -QueuePath $resolvedQueuePath
    $queueSyncMessage = "Queue state synced via util-iterative-flat-file."
  }

  $decisionLines = @(
    "result: $result",
    "high: $highCount",
    "medium: $mediumCount",
    "low: $lowCount",
    "total: $($rankedFindings.Count)",
    "checklist_path: $resolvedChecklistPath",
    "pending_candidates: $($pendingCandidates.Count)",
    "resolve_candidate_id: $resolvedCandidateId",
    "resolve_message: $resolvedMessage",
    "queue_path: $resolvedQueuePath",
    "queue_items: $($queueItems.Count)",
    "queue_sync: $queueSyncMessage",
    "compare_ref: $compareRefLabel",
    "compare_ref_sha: $compareRefShaLabel",
    "merge_base_sha: $mergeBaseShaLabel",
    "diff_scope: $diffScope",
    "max_net_added_lines_for_candidate: $MaxNetAddedLinesForCandidate",
    "fail_on_high_confidence: $failOnHighConfidence"
  )
  Append-Section -Path $resolvedPersistPath -SectionName "DECISION" -Content ([string]::Join([Environment]::NewLine, $decisionLines))
  Append-Section -Path $resolvedPersistPath -SectionName "RUN_END" -Content "timestamp_utc: $([DateTime]::UtcNow.ToString('o'))"
  $runEnded = $true

  Write-Output "Abstraction check result: $result"
  Write-Output "Findings: high=$highCount medium=$mediumCount low=$lowCount total=$($rankedFindings.Count)"
  if ($resolvedCompareRef) {
    Write-Output "Compared against ref: $resolvedCompareRef (merge-base $mergeBaseSha)"
  } else {
    Write-Output "Compared against: uncommitted changes only"
  }
  Write-Output "Persisted run log: $resolvedPersistPath"
  Write-Output "Pending checklist: $resolvedChecklistPath (count=$($pendingCandidates.Count))"
  Write-Output "Queue file: $resolvedQueuePath (count=$($queueItems.Count))"
  Write-Output $queueSyncMessage
  if ($resolvedMessage) {
    Write-Output $resolvedMessage
  }
  Write-NextCandidatePrompt -ChecklistPath $resolvedChecklistPath -Pending $pendingCandidates

  if ($result -eq "fail" -and $failOnHighConfidence) {
    exit 2
  }

  exit 0
} catch {
  $errorMessage = $_.Exception.Message
  $errorDetail = $_ | Out-String

  if (-not $runStarted) {
    Append-Section -Path $resolvedPersistPath -SectionName "RUN_START" -Content ("timestamp_utc: " + [DateTime]::UtcNow.ToString("o"))
    $runStarted = $true
  }

  Append-Section -Path $resolvedPersistPath -SectionName "ERROR" -Content ("message: $errorMessage" + [Environment]::NewLine + $errorDetail.Trim())

  if (-not $runEnded) {
    Append-Section -Path $resolvedPersistPath -SectionName "DECISION" -Content ("result: error" + [Environment]::NewLine + "high: $highCount" + [Environment]::NewLine + "medium: $mediumCount" + [Environment]::NewLine + "low: $lowCount")
    Append-Section -Path $resolvedPersistPath -SectionName "RUN_END" -Content "timestamp_utc: $([DateTime]::UtcNow.ToString('o'))"
  }

  Write-Error "Abstraction check failed: $errorMessage"
  exit 1
}
