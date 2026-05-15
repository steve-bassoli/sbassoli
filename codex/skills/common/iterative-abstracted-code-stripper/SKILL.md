---
name: iterative-abstracted-code-stripper
description: Quickly apply an existing or emerging shared abstraction to one target codebase to see how much duplicated code can be stripped and what remains unaccounted for. Use when a user asks for iterative-minimal-implementation, quick-and-dirty abstraction consumption, code cleanup exploration, facade replacement, service-to-components migration, or a scan/strip/gap report where compilation may be optional.
---

# Iterative Abstracted Code Stripper

## Workflow

1. Confirm the target abstraction and target service.
   - Treat the shared abstraction API as the center of the experiment.
   - Keep existing public service method names stable unless the user explicitly asks for renames.
   - Prefer full domain words over abbreviations when creating or renaming shared abstractions.

2. Snapshot and scan before editing.
   - Run `git status --short` in every touched repo.
   - Use `rg` for duplicate concepts: facade method names, access-level constants, assignment fetches, mapping helpers, entity enrichment, filtering, and local utility classes.
   - Read the smallest set of source files needed to map the current flow end to end.

3. Build a mapping table in your head before patching.
   - Source facade methods -> shared abstraction methods.
   - Service constants/context -> shared context object.
   - Domain ID -> capability security item ID resolver.
   - Service null-ID policy -> explicit context or clearly noted gap.
   - Local helper responsibilities -> shared processor responsibilities.

4. Strip one minimal slice at a time.
   - Keep the service facade class if call sites or Spring expressions depend on it.
   - Replace internals with delegation to the shared abstraction.
   - Leave the domain-specific resolver local unless the resolver itself is already abstracted.
   - Delete now-duplicated private helpers in the target file.
   - Avoid broad refactors, test rewrites, and unrelated formatting.

5. Record iterative-minimal-implementation notes.
   - Add or update `codex/output/<topic>/iterative_minimal_implementation_items*.txt`.
   - For each slice, record target files, shared replacements, removed local code, retained domain-specific code, validation, and gaps.
   - Mark compilation intentionally skipped when the user asks for quick-and-dirty or non-compiling exploration.

6. Validate to the level requested.
   - If compilation is expected, run the narrowest compile/test command.
   - If compilation is optional, run static checks such as `rg`, `git diff --stat`, and targeted file reads.
   - Report stale tests and likely compile blockers as gaps, not as completed work.

## Patterns

- A good first strip target is a domain access facade that already exposes stable methods such as `hasReadAccess`, `hasWriteAccess`, `fetchReadable...Ids`, or `fetch...AccessLevels`.
- Shared access processors usually absorb assignment request construction, null response handling, platform-user filtering, access-level defaulting, and highest-access selection.
- The target service usually still owns context constants, security item type, null-ID policy, and ID-to-capability-ID lookup.
- If a target entity maps to many lower-level data-security IDs, delegate through the lower-level IDs first, keep the parent aggregation local, and record the missing parent-to-child abstraction as a gap.
- Entity enrichment/filtering is a separate abstraction from access-level resolution. If local code still maps entities to `WithAccessLevel` records and filters on readable levels, capture that as a candidate for a later abstraction.
- Utility classes often shrink to normalization only after access-level constants move to shared code. Note whether normalization should become shared and public.
