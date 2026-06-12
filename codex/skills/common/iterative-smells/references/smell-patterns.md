# Smell Patterns

Use these heuristics when a request asks for overlap, code smells, or architectural drift across tasks, access helpers, and memberships.

## First-Item Authorization

Flag helpers that accept a collection but authorize only the first element.

Why it matters:
- multi-project or multi-entity access becomes order-dependent
- callers think they are asking for aggregate access semantics when they are not
- UI access decoration can disagree with backend enforcement

Look for:
- methods named `first*`, `iterator().next()`, or collection overloads that delegate to singular overloads
- callers passing a set of project ids, memberships, or assignments into those helpers

## Resolution Drift

Flag entities whose authorization or lookup context is derived multiple ways in the same flow.

Why it matters:
- preauthorize checks, response decoration, and secondary fetches can disagree
- bug fixes become local patches instead of boundary fixes

Look for:
- one method using `task -> workflow instance -> project`
- another method using `workflow definition -> project`
- response code recomputing access after an authorization guard already ran

## Hidden Full-Scan Helpers

Flag shared helpers that enumerate all rows in a tenant before applying a narrower filter.

Why it matters:
- list endpoints accidentally inherit full-table behavior
- access-control code becomes a latency hot spot

Look for:
- `fetchAll*` helpers reused by task or workflow filters
- DAO calls with empty filter builders inside access processors

## Per-Item Resolver Loops

Flag loops that call DAOs or remote clients once per item when a batched lookup is feasible.

Why it matters:
- common paths degrade linearly with result size
- performance problems hide behind innocuous helper methods

Look for:
- `for` loops around `fetch*ById`, `resolve*`, or client lookups
- task/workflow list enrichment that starts from a set of ids

## Domain Invariant Bypass

Flag one subsystem reaching directly into another subsystem's storage rules instead of reusing the domain boundary.

Why it matters:
- archived/not-found/lifecycle rules drift across modules
- the same business concept gets validated differently depending on entry point

Look for:
- task code querying membership state directly
- assignment updates accepting foreign ids without using the owning processor/service
- duplicate not-found or archived checks across modules
