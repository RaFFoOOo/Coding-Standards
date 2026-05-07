---
trigger: glob
glob: ".github/workflows/**"
---

# GITHUB ACTIONS WORKFLOW SPECIFICATIONS

## 1. Trigger Design

### `pull_request` vs `push` for PR-context workflows
- **[STRICT]** Any workflow that needs to post a PR comment, reference a PR number, or react to PR lifecycle (open/close) MUST use `pull_request` as its trigger — not `push`.
  - `push` events carry no PR payload. The PR number would require an extra API call, adding latency and a failure mode.
  - `pull_request` events expose `github.event.number`, `context.issue.number`, and `github.head_ref` natively.
  - **Exception — preview deployments requiring a stable URL:** When a stable environment URL is required (e.g., for pre-configured auth redirect URIs), use `push` instead. Some providers (e.g., Azure SWA) generate PR-numbered URLs for `pull_request`-triggered deployments regardless of the `deployment_environment` parameter. Use `pulls.list({ head })` to resolve the PR number for commenting.
  - **Branch coverage for preview CI [STRICT]:** The preview CI push trigger MUST include all active branch prefixes: `feature/**`, `chore/**`, `bugfix/**`, `refactor/**`, `sprint/**`, `task/**`. This ensures preview deployments fire for the sprint/task hierarchy.
- **Branch-prefix filtering** on `pull_request` triggers MUST use a job-level `if` condition, not the `branches:` key:
  ```yaml
  # ✅ Correct — filters by source branch (head_ref)
  if: startsWith(github.head_ref, 'feature/') || startsWith(github.head_ref, 'chore/')

  # ❌ Wrong — branches: filters the TARGET branch, not the source branch
  on:
    pull_request:
      branches: ['feature/**']
  ```

## 2. Permissions

### Workflow-level `permissions` for reusable workflow calls
- **[STRICT]** Any `pull_request`-triggered workflow that calls a reusable workflow (`uses:`) containing a `actions/checkout` step MUST declare `permissions: contents: read` at the **workflow level** — not the job level.
  - GitHub generates the `GITHUB_TOKEN` for reusable workflow jobs using the caller's workflow-level permissions. Per-job `permissions` blocks do not propagate into `uses:` calls.
  - Without `contents: read`, private repos return "Repository not found" (not "Permission denied") on checkout — a misleading error.
- When PR comment posting is also required, add `pull-requests: write` to the same block and remove any redundant per-job `permissions`:
  ```yaml
  permissions:
    contents: read
    pull-requests: write
  ```

### Principle of Least Privilege
- Declare only the permissions the workflow actually needs. Never omit permissions entirely and rely on repository defaults — defaults are environment-dependent and can differ between repositories.

## 3. Secret & Variable Scope

### CI vs CD secret separation
- When the same cloud resource is required in both a CI workflow (PR/preview) and a CD workflow (production):
  - Register a `CI_<CLOUD>_<RESOURCE>_<NAME>` secret at **repository level** (Settings → Secrets and variables → Actions). Required because PR workflows cannot access environment-protected secrets.
  - Register a `CD_<CLOUD>_<RESOURCE>_<NAME>` secret scoped to the **production environment** (Settings → Environments → production → Secrets).
  - Never share one secret across both scopes; document the split in `README.md` under two clearly labelled subsections.

### Variables (feature flags, configuration) — no CI/CD prefix
- Environment-scoped variables use plain `UPPER_SNAKE_CASE` — no `CI_`/`CD_` prefix. The GitHub environment already provides scoping; different environments hold different values for the same variable name.
- The `CI_`/`CD_` prefix convention applies exclusively to **secrets** where repository-level vs. environment-level isolation is critical.

## 4. Reusable Workflows (`workflow_call`)

- Pass `secrets: inherit` from the caller to avoid re-listing every secret.
- The `environment:` input on a reusable workflow maps to a GitHub environment, which controls which secrets/vars are available to the job. For CI/preview builds, use `environment: development` — this avoids environment protection rules and grants access to development-scoped vars without exposing production secrets.
- If the target environment does not exist in the repository, GitHub skips environment protection but still runs the job. This is acceptable for non-production environments.

## 5. Node.js Runtime

- JavaScript actions (`actions/checkout`, `actions/upload-artifact`, `actions/github-script`, etc.) must target **Node.js 24** natively. Pin to a major version that ships with Node 24 support (check the action's release notes).
- Do not rely on `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` as a permanent solution — use it only as a temporary bridge while waiting for a new major version of the action to be published.
- When a reusable workflow upgrades Node.js, audit all workflow files for action version consistency.

## 6. Security Gates

### A06 — CVE Checks [STRICT]
Every Node-based workflow MUST run `npm audit` as a non-skippable step. Every .NET workflow MUST run `dotnet list package --vulnerable` and fail on any HIGH or CRITICAL finding. These steps MUST NOT use `continue-on-error: true`.

**Node.js (copy-paste ready):**
```yaml
- name: Audit npm dependencies
  run: npm audit --audit-level=moderate
  # continue-on-error is intentionally absent — any moderate+ finding fails the workflow
```

**.NET (copy-paste ready — add after `dotnet restore`):**
```yaml
- name: Audit .NET dependencies
  run: |
    dotnet list package --vulnerable --include-transitive 2>&1 | tee /tmp/vuln.txt
    if grep -qiE "(High|Critical)" /tmp/vuln.txt; then
      echo "::error::HIGH or CRITICAL vulnerability detected in .NET packages"
      exit 1
    fi
```

### A08 — Supply-Chain Action Pinning [STRICT]
Third-party GitHub Actions (anything **not** under `actions/` or `github/` orgs) MUST be pinned to a full 40-character commit SHA, not a floating major-version tag. First-party actions (`actions/checkout`, `actions/setup-node`, etc.) MAY use major version tags — GitHub's own integrity guarantees cover them.

Rationale: tag mutation on third-party repos is a known supply-chain attack vector (e.g., `tj-actions/changed-files` incident, 2025).

```yaml
# ❌ Floating tag — vulnerable to tag mutation
uses: third-party/some-action@v2

# ✅ SHA-pinned + human-readable comment
uses: third-party/some-action@a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2  # v2.1.0 — pinned per A08
```

### A06 — CodeQL Scanning [RECOMMENDED]
A CodeQL scan workflow is recommended for every repository; it is free for any visibility level and catches a broad class of injection, path-traversal, and data-flow vulnerabilities automatically. Add to the project backlog when feasible.
