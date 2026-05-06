---
name: build-test-release-hygiene-reporting-ui
description: Select and run the minimum required lint, test, and dependency checks for dsbu-reporting-ui changes. Use when preparing a PR, validating local edits, or touching dependency metadata.
---

# Reporting Build Test Release Hygiene

## Quick Start

1. Read [references/validation-and-release-runbook.md](references/validation-and-release-runbook.md).
2. Run `scripts/recommend-checks.ps1` to classify changed files.
3. Execute only the recommended commands.
4. Report exactly what was run and what was skipped.

## Workflow

1. Classify changes by area:
   - `apps/designer/src` code changes
   - shared library changes (`libs/shared/angular`, `libs/viewer`, `libs/shared/utility`, `libs/dataservicelib`)
   - dependency metadata changes (`package.json` / `yarn.lock`, root or workspace)
2. Pick the smallest command set that gives confidence.
3. Run commands from repo root using workspace-aware Yarn commands.
4. If dependency metadata changed, run `yarn install` before lint/test.
5. Summarize validation outcomes with command-level granularity.

## Command Rules

- Prefer `yarn workspace <name> run <script>` for package-specific tests.
- Prefer targeted lint/test when scope is narrow.
- Respect `prestart` requirements for designer tests that activate Kendo licensing.

## Output Requirements

- List executed commands.
- List skipped commands and rationale.
- Call out blockers (missing env vars, license issues, missing dependencies).

## Resources

- Read [references/validation-and-release-runbook.md](references/validation-and-release-runbook.md).
- Use [scripts/recommend-checks.ps1](scripts/recommend-checks.ps1) to generate a starting command set.
