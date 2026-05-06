---
name: build-test-release-hygiene-access-control-ui
description: Select and run the minimum required lint and test checks for dsbu-access-control-ui changes. Use when preparing a PR, validating local edits, or touching dependency metadata.
---

# Access Control Build Test Hygiene

## Quick Start

1. Read [references/validation-and-release-runbook.md](references/validation-and-release-runbook.md).
2. Run `scripts/recommend-checks.ps1 -RepoRoot <repo-root> -BaseBranch master` to classify changed files against `master` merge-base.
3. Execute only the recommended commands.
4. Report exactly what was run and what was skipped.

## Workflow

1. Classify changes against `master` merge-base by area:
   - `html/src` code changes
   - dependency metadata changes (`html/package.json` / `html/yarn.lock`)
2. Pick the smallest command set that gives confidence.
3. Run commands from the correct project directory.
4. If dependency metadata changed, run dependency install before lint/test.
5. Skip repo-wide lint/test unless explicitly requested; prefer touched-file commands from the recommender.
6. Summarize validation outcomes with command-level granularity.

## Command Rules

- Run Yarn commands inside `html`.
- Do not use `yarn --cwd` from repo root for this repo.
- Respect `prestart` needs for commands that require Kendo license activation.
- Prefer targeted lint/test when scope is narrow.

## Output Requirements

- List executed commands.
- List skipped commands and rationale.
- Call out blockers (missing env vars, license issues, missing dependencies).

## Resources

- Read [references/validation-and-release-runbook.md](references/validation-and-release-runbook.md).
- Use [scripts/recommend-checks.ps1](scripts/recommend-checks.ps1) to generate a starting command set.
