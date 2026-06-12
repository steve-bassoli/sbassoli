---
name: localdev-authenticated-curl
description: Authenticate local HTTP proof-of-concept requests against developer services by discovering required identity headers, generating or extracting local test tokens, and issuing PowerShell-safe curl requests. Use when Codex needs to test a live localhost or port-forwarded endpoint that rejects anonymous requests, especially when repo docs or code mention custom auth headers, browser-copied tokens, local JWT helper scripts, proxy header injection, or tenant/user routing.
---

# Localdev Authenticated Curl

## Quick Start

1. Identify the endpoint, method, request body, and expected caller identity.
2. Read repo docs and code for request identity requirements before sending requests.
3. Prefer repo-local token generation or proxy helpers over browser-copy workflows.
4. Write JSON bodies to a temp file and use `curl.exe --data-binary "@file"` to avoid PowerShell quoting errors.
5. Reuse the same token across contrast requests so auth stays constant while filters change.
6. If the response is unexpected, contrast nearby endpoints or inspect service logs before assuming a data leak.

## Workflow

### 1. Discover the Auth Contract

Search for the exact request-context contract in code and docs:

- `README`
- header constants
- exception handlers for missing user info
- Swagger/OpenAPI header declarations
- local proxy, nginx, docker-compose, or entrypoint scripts
- `curl`, `jwt`, `token`, `tenant`, `platformUserId`, `userRequestInformation`

Capture:

- required auth headers
- tenant alias or user-routing headers
- whether the service expects a JWT or plain header values
- whether auth and data-security scoping are separate checks

### 2. Find the Best Token Source

Use this order:

1. Repo-local generator or payload template
2. Local proxy or container script that already injects the header
3. Browser-captured token from the intended dev tenant

Prefer mirroring an existing helper script over inventing token structure.

### 3. Generate or Adapt a Local Token

If the repo includes a base JWT payload template:

- patch only the fields the service actually keys on
- commonly update user id, subject, tenant alias, `iat`, and `exp`
- keep token generation local and ephemeral
- do not persist tokens in repo files

If subject encoding or claim shape is repo-specific, copy the existing local helper exactly enough to reproduce the expected token.

### 4. Send the Request Safely from PowerShell

Use `curl.exe`, not PowerShell's `curl` alias.

For JSON requests:

```powershell
$bodyPath = Join-Path $env:TEMP 'request.json'
Set-Content -Path $bodyPath -Value '{"top":10}' -NoNewline

curl.exe -i -s -X POST "http://localhost:8080/path" `
  -H "Content-Type: application/json" `
  -H "custom-auth-header: $token" `
  --data-binary "@$bodyPath"
```

Guidelines:

- prefer `localhost` when the service is bound locally
- use the explicit host only when the local proxy requires it
- use temp files for JSON bodies instead of inline quoting
- reuse a shared header array when issuing multiple contrast calls in one session

### 5. Interpret the Response Correctly

Treat common outcomes as follows:

- `400` with JSON parse errors: body quoting issue, not auth
- `400` mentioning missing user info header: auth header missing or malformed
- `401` or `403`: auth accepted, permission or policy denied
- `500`: inspect service logs before concluding the endpoint leaked data
- `200` with unexpected data: compare against a sibling endpoint or direct DB facts if available

### 6. Use Contrast Requests to Confirm Leaks

Keep auth fixed and change only the filter or endpoint:

- compare `/filter` versus `/statistics/filter`
- compare with and without project filters
- compare `currentUser=true` versus `false` when supported
- compare expected-visible versus expected-hidden project ids

Use the same token for all contrast calls in the sequence.

## Guardrails

1. Do not print or commit full tokens.
2. Do not assume a token from one tenant is valid for another tenant alias.
3. Do not treat generic `500` responses as proof of business-logic failure without log confirmation.
4. Prefer repo-defined auth conventions over ad hoc JWT claim choices.
5. Use DB access only to interpret endpoint results, not as a substitute for the live HTTP proof.

## Output Contract

Report:

- endpoint and method tested
- auth source used, without exposing the token
- request body
- response status
- response summary
- whether the observed behavior indicates auth failure, permission denial, or a likely data leak
