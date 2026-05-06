# Scaffolding Artifact Patterns

Use these searches as fast signal generation. Always review matches in code context before fixing.
Record suspicious findings in `/codex/output/iterative_abstraction_check_scaffolding.txt` with file, line, and context.

## Scope First

Start with changed files unless the user asks for a full-repo scan.

```powershell
$changed = @(
  git diff --name-only HEAD
  git ls-files --others --exclude-standard
) | Sort-Object -Unique | Where-Object { $_ -match '\.(ts|tsx|js|jsx)$' }
```

## 1) Top-Of-Method Immediate Return Guards

Find methods and inspect the first executable statement for immediate-return guards.

```powershell
rg -n -P "^\s*(public|private|protected)?\s*(async\s+)?[A-Za-z0-9_]+\s*\([^)]*\)\s*:\s*[^{]+\{\s*$" $changed
```

Suspicious examples:

- `if (...) { return; }`
- `if (...) { return value; }`
- `if (!this.someService) { return ...; }`

Risk increases when the guard references an optional constructor dependency.

## 2) Optional Constructor Dependencies

```powershell
rg -n "constructor\s*\([^)]*\?\s*:" $changed
rg -n "private\s+readonly\s+[A-Za-z0-9_]+\?\s*:" $changed
```

## 3) Constructor Overload / Multiple Constructor Scaffolding

```powershell
rg -n "^\s*constructor\s*\(" $changed
```

Review files with multiple constructor declarations/signatures. Some overloads are legitimate; flag only likely temporary scaffolding.

## 4) Nullable DI/Service Calls Masking Required Dependencies

```powershell
rg -n "this\.[A-Za-z0-9_]+\?\." $changed
rg -n "if\s*\(\s*!this\.[A-Za-z0-9_]+\s*\)\s*\{\s*return" $changed
```

## 5) Temporary / Cleanup Markers

```powershell
rg -n "TODO|temporary|temp|workaround|cleanup|follow[- ]?up|codex" $changed
```

Only flag when marker clearly corresponds to implementation scaffolding to be removed.

## Context Capture Helper

```powershell
$path = "src/example.ts"
$line = 120
Get-Content $path | Select-Object -Skip ([Math]::Max(0, $line - 3)) -First 7
```

## Checklist Entry Template

```text
[
  {
    "id": "ABS-SCF-1",
    "order": 1,
    "item_type": "scaffolding_artifact",
    "description": "<single sentence describing suspicious scaffolding>",
    "source_file": "<repo-relative-path>",
    "source_line_start": "<line number or unknown>",
    "source_line_end": "<line number or unknown>",
    "code_context": "<short code context or symbol/method summary>",
    "target_file": "<repo-relative-path>",
    "priority": "<high|medium|low>",
    "risk_context": "<why suspicious + proposed fix summary>",
    "reference_url": "n/a",
    "metadata": {
      "pattern": "<top-return-guard|optional-constructor-dependency|constructor-overload|nullable-di-call|other>"
    }
  }
]
```

If no suspicious items are found, still write:

```text
[]
```
