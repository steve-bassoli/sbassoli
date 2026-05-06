---
name: central-codex-bootstrap-management
description: Manage centralized Codex repository bootstraps and shared AGENTS source files. Use when asked to replace a repo AGENTS.md with a stable pointer to the matching repo-specific file under C:\work\sbassoli\codex\AGENTS, migrate AGENTS or skill paths between repo-local .\codex and the central Codex store, validate central AGENTS references, or keep the shared Codex skills/scripts/AGENTS layout aligned.
---

# Central Codex Bootstrap Management

## Defaults

- Central store: `C:\work\sbassoli\codex`.
- Repo name: leaf directory name of the repository root.
- Central AGENTS file: `C:\work\sbassoli\codex\AGENTS\AGENTS-<repo-name>.md`.
- Local bootstrap: repository-root `AGENTS.md` with `apply: always` frontmatter and a concrete pointer to the central AGENTS file.
- Repo-local runtime state: `codex/output`.

## Workflow

1. Read the current repository `AGENTS.md` and the central AGENTS target if it exists.
2. If the central AGENTS target is missing, create it from the current repository `AGENTS.md` before replacing the local file.
3. Update the central AGENTS content to reference the central store:
   - Shared skills: `C:/work/sbassoli/codex/skills/<group>/<skill>/SKILL.md`.
   - Repo-local skills: `C:/work/sbassoli/codex/skills/local/<repo-name>/<skill>/SKILL.md`.
   - Shared propagation rules should point to `C:\work\sbassoli\codex`, not stale store paths.
4. Verify each central skill path in the AGENTS file exists. If a repo-local skill was renamed in the central store, use the existing central name only when the mapping is obvious from the folder name and `SKILL.md` frontmatter; otherwise ask the user.
5. Replace the repository `AGENTS.md` with the bootstrap template below.
6. If the user is removing repo-local source copies, keep `codex/output` and remove only the repo-local README, script copies, and skill copies.
7. Run `scripts\Test-CentralCodexBootstrap.ps1` and targeted searches for stale paths.

## Bootstrap Template

Use a concrete central file path when updating one repo:

```markdown
---
apply: always
---

# Repository Instructions

Repository instructions are centralized.

Before doing any work in this repository, read:

`C:\work\sbassoli\codex\AGENTS\AGENTS-<repo-name>.md`

Treat that file as the authoritative AGENTS instructions for this repository.
If it cannot be read, stop and ask the user before making changes.
```

Use a `<repo-name>` placeholder only when the user explicitly wants a generic template across many repos.

## Validation

Run the bundled validation script from the repository root or with an explicit `-RepoRoot`:

```powershell
powershell -File C:\work\sbassoli\codex\skills\common\central-codex-bootstrap-management\scripts\Test-CentralCodexBootstrap.ps1 -RepoRoot C:\work\<repo-name>
```

When repo-local source copies should be gone, add `-RequireNoRepoLocalSources`.

Also search the changed areas for stale store paths without writing the legacy path literally into repository files:

```powershell
$LegacyStore = "C:\work\" + "codex"
rg --fixed-strings $LegacyStore <changed-paths>
```

Validation should confirm:

- The local `AGENTS.md` exists.
- The central AGENTS target exists.
- The local bootstrap points at the expected central target.
- The local and central AGENTS files do not contain the legacy central store path.
- The central AGENTS file does not point at the repo-local absolute `codex` directory for skills.
- If `-RequireNoRepoLocalSources` is used, only `codex/output` remains as the repo-local Codex runtime area.
