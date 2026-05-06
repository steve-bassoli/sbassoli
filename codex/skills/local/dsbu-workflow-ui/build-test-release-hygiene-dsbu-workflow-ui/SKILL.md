---
name: build-test-release-hygiene-dsbu-workflow-ui
description: Select and run the minimum required lint, test, and release checks for dsbu-workflow-ui changes. Use when preparing a PR, validating local edits, touching dependency metadata, or deciding when BOM regeneration is required.
---

# DSBU Workflow UI Build Test Release Hygiene

## Quick Start

1. Read [references/validation-and-release-runbook.md](references/validation-and-release-runbook.md).
2. Run `scripts/recommend-checks.ps1` to classify changed files.
3. Execute only the recommended commands.
4. Report exactly what was run and what was skipped.

## Workflow

1. Classify changes by area:
   - `html/src` code changes
   - dependency metadata changes (`package.json` / `yarn.lock`)
   - dataservicelib-v2/v3 changes
2. Pick the smallest command set that gives confidence.
3. Run commands from the correct project directory.
4. If dependency metadata changed, regenerate BOM.
5. Summarize validation outcomes with command-level granularity.

## Command Rules

- Run Yarn commands inside each project directory.
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
