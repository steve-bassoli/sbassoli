[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$PrUrl,
  [string]$OutputPath = "codex/output/iterative_github_comments_items.txt",
  [ValidateSet("preserve", "reset")]
  [string]$StateSyncMode = "preserve",
  [switch]$SkipStateSync,
  [switch]$IncludeResolved
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RepoFromRemoteUrl {
  param([string]$RemoteUrl)

  if (-not $RemoteUrl) {
    return $null
  }

  if ($RemoteUrl -match "github\.com[:/](?<owner>[^/]+)/(?<repo>[^/]+?)(?:\.git)?$") {
    return "$($Matches.owner)/$($Matches.repo)"
  }

  return $null
}

function Truncate-Lines {
  param(
    [string]$Text,
    [int]$MaxLines = 40
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $normalized = ($Text -replace "`r", "").Trim()
  $allLines = $normalized.Split("`n")

  if ($allLines.Count -le $MaxLines) {
    return $normalized
  }

  $keptLines = $allLines[0..($MaxLines - 1)]
  $remaining = $allLines.Count - $MaxLines
  return (($keptLines -join "`n") + "`n... [truncated $remaining additional lines]")
}

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

function Resolve-LineValue {
  param([object]$LineValue)

  $line = if ($null -eq $LineValue) { "" } else { [string]$LineValue }
  if ($line -match "^\d+$") {
    return [int]$line
  }

  return "unknown"
}

if ($PrUrl -notmatch "^https://github\.com/(?<owner>[^/]+)/(?<repo>[^/]+)/pull/(?<number>\d+)(?:[/?#].*)?$") {
  throw "Unsupported PR URL: '$PrUrl'. Expected format: https://github.com/<owner>/<repo>/pull/<number>"
}

$prOwner = $Matches.owner
$prRepo = $Matches.repo
$prNumber = [int]$Matches.number
$prRepoSlug = "$prOwner/$prRepo"

$originUrl = (git config --get remote.origin.url).Trim()
$localRepoSlug = Get-RepoFromRemoteUrl -RemoteUrl $originUrl

if (-not $localRepoSlug) {
  throw "Unable to derive local GitHub repo from remote.origin.url: '$originUrl'"
}

if ($localRepoSlug.ToLowerInvariant() -ne $prRepoSlug.ToLowerInvariant()) {
  throw "Repository mismatch. Local repo is '$localRepoSlug' but PR URL targets '$prRepoSlug'."
}

$currentBranch = (git rev-parse --abbrev-ref HEAD).Trim()
if (-not $currentBranch) {
  throw "Unable to determine current branch."
}

$prMetadata = gh api "repos/$prOwner/$prRepo/pulls/$prNumber" | ConvertFrom-Json
$prHeadBranch = $prMetadata.head.ref

if ($currentBranch -ne $prHeadBranch) {
  throw "Branch mismatch. Local branch is '$currentBranch' but PR head branch is '$prHeadBranch'."
}

$query = @'
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      title
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          path
          comments(first: 20) {
            nodes {
              author { login }
              body
              url
              line
              originalLine
              startLine
              originalStartLine
              diffHunk
              createdAt
            }
          }
        }
      }
    }
  }
}
'@

$threadResponse = gh api graphql -f query=$query -f owner=$prOwner -f repo=$prRepo -F number=$prNumber | ConvertFrom-Json
$pullRequest = $threadResponse.data.repository.pullRequest

if (-not $pullRequest) {
  throw "Unable to load PR data for '$prRepoSlug#$prNumber'."
}

$threads = @($pullRequest.reviewThreads.nodes | Where-Object { ($IncludeResolved.IsPresent -or -not $_.isResolved) -and -not $_.isOutdated })
$records = New-Object System.Collections.Generic.List[object]

foreach ($thread in $threads) {
  $comments = @($thread.comments.nodes)
  if ($comments.Count -eq 0) {
    continue
  }

  $comment = $comments[0]
  $line = $comment.line
  if (-not $line) { $line = $comment.originalLine }
  if (-not $line) { $line = $comment.startLine }
  if (-not $line) { $line = $comment.originalStartLine }

  $author = if ($null -ne $comment.author -and $null -ne $comment.author.login) { [string]$comment.author.login } else { "unknown" }
  $commentBody = if ($null -ne $comment.body) { [string]$comment.body } else { "" }
  $diffHunk = if ($null -ne $comment.diffHunk) { [string]$comment.diffHunk } else { "" }
  $path = if ([string]::IsNullOrWhiteSpace($thread.path)) { "unknown" } else { [string]$thread.path }
  $url = if ([string]::IsNullOrWhiteSpace($comment.url)) { "n/a" } else { [string]$comment.url }

  $records.Add([PSCustomObject]@{
      File      = $path
      Line      = $line
      Url       = $url
      Author    = $author
      CreatedAt = $comment.createdAt
      Comment   = (Truncate-Lines -Text $commentBody -MaxLines 16)
      Context   = (Truncate-Lines -Text $diffHunk -MaxLines 40)
    })
}

$orderedRecords = @(
  $records | Sort-Object File, @{
    Expression = {
      $lineValue = [string]$_.Line
      if ($lineValue -match "^\d+$") { return [int]$lineValue }
      return [int]::MaxValue
    }
  }
)

$queueItems = New-Object System.Collections.Generic.List[object]
$index = 0

foreach ($record in $orderedRecords) {
  $index++
  $lineValue = Resolve-LineValue -LineValue $record.Line
  $description = if ([string]::IsNullOrWhiteSpace($record.Comment)) { "[empty github comment]" } else { $record.Comment }
  $sourceFile = if ([string]::IsNullOrWhiteSpace($record.File)) { "unknown" } else { $record.File }
  $codeContext = if ([string]::IsNullOrWhiteSpace($record.Context)) { "" } else { $record.Context }
  $referenceUrl = if ([string]::IsNullOrWhiteSpace($record.Url)) { "n/a" } else { $record.Url }

  $queueItems.Add([ordered]@{
      id                = "IGC-$index"
      order             = $index
      item_type         = "github_comment"
      description       = $description
      source_file       = $sourceFile
      source_line_start = $lineValue
      source_line_end   = $lineValue
      code_context      = $codeContext
      target_file       = $sourceFile
      priority          = "high"
      risk_context      = "Unresolved PR feedback item"
      reference_url     = $referenceUrl
      metadata          = [ordered]@{
        author        = $record.Author
        created_at    = $record.CreatedAt
        pr_url        = $PrUrl
        repo          = $prRepoSlug
        branch        = $currentBranch
        ingest_source = "github_review_threads"
        change_summary = ""
        over_optimization_likelihood = ""
        overly_cautious_null_empty_checking_likelihood = ""
        assessment_note = ""
      }
    })
}

$repoRoot = (Get-Location).Path
$resolvedOutputPath = Resolve-AbsolutePath -Path $OutputPath -BasePath $repoRoot
$outputDirectory = Split-Path -Path $resolvedOutputPath -Parent
if ($outputDirectory -and -not (Test-Path -Path $outputDirectory)) {
  New-Item -Path $outputDirectory -ItemType Directory -Force | Out-Null
}

$queueJson = ConvertTo-Json -InputObject $queueItems.ToArray() -Depth 8
Set-Content -Path $resolvedOutputPath -Value $queueJson -Encoding utf8
Write-Output "Wrote unresolved comment queue: $resolvedOutputPath (count=$($queueItems.Count))"

if (-not $SkipStateSync.IsPresent) {
  $syncScriptPath = [System.IO.Path]::GetFullPath((Join-Path -Path $PSScriptRoot -ChildPath "..\..\util-iterative-flat-file\scripts\sync-iterative-state.ps1"))
  if (-not (Test-Path -Path $syncScriptPath)) {
    throw "Missing util sync script: $syncScriptPath"
  }

  & $syncScriptPath -InvokingSkillName "iterative-github-comments" -QueuePath $resolvedOutputPath -Mode $StateSyncMode
  Write-Output "Synced queue state via util-iterative-flat-file."
} else {
  Write-Output "Skipped state sync by request."
}
