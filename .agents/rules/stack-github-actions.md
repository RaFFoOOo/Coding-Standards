---
name: Stack GitHub Actions
trigger: glob
globs: [".github/workflows/**", ".github/actions/**"]
description: CI/CD workflow rules for GitHub Actions pipelines
---

# GITHUB ACTIONS WORKFLOW SPECIFICATIONS

## 1. Trigger Design

### `pull_request` vs `push` for PR-context workflows
- **[STRICT]** Any workflow that needs to post a PR comment, reference a PR number, or react to PR lifecycle (open/close) MUST use `pull_request` as its trigger — not `push`.
  - `push` events carry no PR payload. The PR number would require an extra API call, adding latency and a failure mode.
  - `pull_request` events expose `github.event.number`, `context.issue.number`, and `github.head_ref` natively.
  - **Exception — Azure SWA preview deployments:** When a stable `deployment_environment` URL is required (e.g., for pre-configured auth redirect URIs), use `push` instead. Azure SWA generates PR-numbered URLs for `pull_request`-triggered deployments regardless of the `deployment_environment` parameter. Use `pulls.list({ head })` to resolve the PR number for commenting.
  - **Branch coverage for preview CI [STRICT]:** The `ci-preview-swa.yml` push trigger MUST include all active branch prefixes: `feature/**`, `chore/**`, `bugfix/**`, `refactor/**`, `sprint/**`, `task/**`. This ensures preview deployments fire for the sprint/task hierarchy introduced in Sprint 8.6.
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

### CD Identity Separation [STRICT]
The identity used by the CD pipeline to deploy resources MUST be a dedicated **App Registration
(Service Principal) per environment**, separate from all application runtime identities.

- **Application runtime identities** (e.g., a UAMI used by the Function App to access Azure SQL)
  MUST NOT be granted deployment RBAC roles (e.g., `Website Contributor`). Granting deployment
  rights to a runtime identity allows the running application to redeploy itself — a clear
  least-privilege violation.
- **One CD SPN per GitHub environment** — never share a single SPN across dev and prod. Each SPN
  is granted `Website Contributor` only on its own environment's Function App. An OIDC token
  scoped to `development` cannot be used to deploy to production because the prod SPN has no
  federated credential for the `development` environment.
- **Authentication App Registrations** (SPA login, API JWT audience) are authentication identities
  — never operational identities. Do not reuse them for CI/CD.
- Name CD SPNs following `naming-azure-resources.md`: `<dev-cd-spn>` (dev), `<prod-cd-spn>` (prod).

**Identity taxonomy for this project:**

| Identity | Type | Purpose | Grants |
|---|---|---|---|
| `<runtime-uami>` | User-Assigned Managed Identity | Function App → Azure SQL (runtime) | `db_datareader` + `db_datawriter` on SQL only |
| `<spa-app>` | App Registration | SPA MSAL authentication | — |
| `<api-app>` | App Registration | Backend JWT audience/validation | — |
| `<dev-cd-spn>` | App Registration / SPN | GitHub Actions CD — dev environment | `Reader` on subscription + `Website Contributor` on `<dev-function-app>` |
| `<prod-cd-spn>` | App Registration / SPN | GitHub Actions CD — prod environment (TBD) | `Reader` on subscription + `Website Contributor` on prod Function App |

## 3. Secret & Variable Scope

> The secret naming **schema** and the CI/CD-split principle are defined once in `AGENTS.md §5`. This section covers only the GitHub-specific **placement**.

### CI vs CD secret separation
- When the same Azure resource (e.g., an ASWA deployment token) is required in both a CI workflow (PR/preview) and a CD workflow (production):
  - Register the `CI_AZURE_<RESOURCE>_<NAME>` secret at **repository level** (Settings → Secrets and variables → Actions) — PR workflows cannot access environment-protected secrets.
  - Register the `CD_AZURE_<RESOURCE>_<NAME>` secret scoped to the **production environment** (Settings → Environments → production → Secrets).
  - Never share one secret across both scopes; document the split in `README.md`.

### Variables (feature flags, configuration) — no CI/CD prefix
- Per `AGENTS.md §5`: environment-scoped variables use plain `UPPER_SNAKE_CASE` with no `CI_`/`CD_` prefix (the GitHub environment provides scoping). The `CI_`/`CD_` prefix applies **only** to secrets that need repository-vs-environment isolation.

## 4. Reusable Workflows (`workflow_call`)

- Pass `secrets: inherit` from the caller to avoid re-listing every secret.
- The `environment:` input on a reusable workflow maps to a GitHub environment, which controls which secrets/vars are available to the job. For CI/preview builds, use `environment: development` — this avoids environment protection rules and grants access to development-scoped vars without exposing production secrets.
- If the target environment does not exist in the repository, GitHub skips environment protection but still runs the job. This is acceptable for non-production environments.

### Shared Build Extraction [STRICT]
When two or more workflows share the same build steps (restore → audit → build → optional test/publish), extract those steps into a `shared-build-<stack>.yml` reusable workflow. **Never duplicate steps across CI and CD callers.**

**Extraction rule:** If the same ordered sequence of 3+ steps would appear in both a `ci-*.yml` and a `cd-*.yml`, extract immediately.

**Boolean input pattern:** Use boolean inputs to toggle CI vs. CD behaviour within one shared workflow — do NOT create separate shared workflows for CI and CD variants of the same stack:
```yaml
# shared-build-dotnet.yml inputs
inputs:
  run-tests:
    type: boolean
    default: false    # CI sets true; CD omits (false)
  publish:
    type: boolean
    default: false    # CD sets true; CI omits (false)
  publish-project:
    type: string
    default: '<YourApp>.Functions/<YourApp>.Functions.csproj'
```

**Deploy job stays in the caller — never in the shared workflow.** The deploy job requires `environment: production` to access environment-scoped secrets. Moving it into the shared workflow would force all callers (including CI) to request production secrets — a security misconfiguration.

```yaml
# ✅ Correct split — cd-backend-azure-functions.yml
jobs:
  build:
    uses: ./.github/workflows/shared-build-dotnet.yml
    with:
      publish: true
    secrets: inherit

  deploy:                          # ← stays in the CD caller
    needs: build
    environment: production        # ← production secrets scoped here only
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with: { name: dotnet-publish-output, path: publish }
      - uses: azure/functions-action@<sha>  # pinned per A08
        with:
          app-name: ${{ vars.FUNCTION_APP_NAME }}
          package: publish
          publish-profile: ${{ secrets.CD_AZURE_FUNC_DEPLOYMENT_TOKEN }}
```

**Artifact handoff:** The shared workflow uploads a publish artifact (e.g., `dotnet-publish-output`); the deploy job downloads it. Use `retention-days: 1` — artifacts are ephemeral build products, not long-lived assets.

**Node.js note:** The shared .NET workflow does not install Node.js — do not mix runtimes in a single shared workflow. Keep `shared-build-angular.yml` and `shared-build-dotnet.yml` strictly separate.

### Azure Functions isolated worker — `.azurefunctions/` folder [STRICT]

Azure Functions host **v4.1000+** requires a `.azurefunctions/` folder at the root of the
deployed package. The folder is generated by `Microsoft.Azure.Functions.Worker.Sdk` during
build (in the project's `bin/<config>/<tfm>/.azurefunctions/`) and contains the worker
extension binaries. Without it, the host loads **0 functions** and every HTTP route returns
404 — silently, with no startup error visible from outside the Log Stream.

Two pitfalls were hit on the same pipeline within hours:

**Pitfall 1 — `dotnet publish --output <custom-path>` does not copy `.azurefunctions/`:**
The SDK target writes to `$(OutputPath)`, not `$(PublishDir)`, so a custom `--output` flag
strands the folder in the build dir. Add a post-publish copy step:
```yaml
- name: Publish
  run: |
    dotnet publish "<csproj>" --configuration Release --output "$GITHUB_WORKSPACE/publish"
    PROJ_DIR=$(dirname "<csproj>")
    AZFUNC_SRC="$PROJ_DIR/bin/Release/<tfm>/.azurefunctions"
    if [ -d "$AZFUNC_SRC" ]; then
      cp -r "$AZFUNC_SRC" "$GITHUB_WORKSPACE/publish/.azurefunctions"
    fi
```

**Pitfall 2 — `actions/upload-artifact@v4+` excludes hidden paths by default:**
`include-hidden-files` defaults to `false` in v4+, so `.azurefunctions/` (dot-prefixed) is
silently filtered out of the artifact even though it exists in the source path. Any artifact
that legitimately needs a dot-prefixed file or directory MUST set `include-hidden-files: true`:
```yaml
- uses: actions/upload-artifact@v7
  with:
    name: dotnet-publish-output
    path: ${{ github.workspace }}/publish
    include-hidden-files: true   # required for .azurefunctions/
```

**Verification:** after deploy, a fresh `GET https://<scmsite>/api/vfs/site/wwwroot/` should
list the `.azurefunctions/` directory. If absent, the Functions Log Stream will show
`Could not find the .azurefunctions folder in the deployed artifacts of a .NET isolated
function app` and `0 functions found (Custom)`.

## 5. Node.js Runtime

- JavaScript actions (`actions/checkout`, `actions/upload-artifact`, `actions/github-script`, etc.) must target **Node.js 24** natively. Pin to a major version that ships with Node 24 support (check the action's release notes).
- Do not rely on `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` as a permanent solution — use it only as a temporary bridge while waiting for a new major version of the action to be published.
- When the `shared-build-angular.yml` reusable workflow upgrades Node.js, audit all workflow files for action version consistency.

## 6. Security Gates

### A06 — CVE Checks [STRICT]
Every Node-based workflow MUST run `npm audit` as a non-skippable step. Every .NET workflow (when introduced) MUST run `dotnet list package --vulnerable` and fail on any HIGH or CRITICAL finding. These steps MUST NOT use `continue-on-error: true`.

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
A CodeQL scan workflow catches a broad class of injection, path-traversal, and data-flow vulnerabilities automatically. **It is free for PUBLIC repositories only.** On a **private** repository, CodeQL *analysis* still runs, but uploading results to the Security tab requires **GitHub Advanced Security** — a paid add-on (Team/Enterprise) **not available on Free/personal plans** (`PATCH …/security_and_analysis` → HTTP 422 "Advanced security has not been purchased"; verified 2026-06-02, Sprint 19). Do **not** state CodeQL is "free at any visibility" — that conflates public-repo-free with all-visibility-free. Running the CodeQL CLI with `upload:false` to dodge GHAS on a private repo is **license-gray** (the CLI is licensed for private use only *in connection with* GitHub code scanning) — not a permitted workaround. For this repo CodeQL ships **dormant** (`workflow_dispatch`-only + `ENABLE_CODEQL` gate); see `DECISIONS.md` 2026-06-02. Free first-party SAST on a private repo means a different tool (semgrep OSS, eslint security plugins, Roslyn analyzers).
