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
  - **Preview CI: `push` to `main` (path-filtered) + `workflow_dispatch`, Mock-only by default [cost-reduction + no-preview-backend policy, 2026-07-08 rev.4]:** `<preview-deploy-workflow>` triggers automatically on `push` to `main`, scoped to `paths: ['<spa-app>/**', ...]` so it only fires when Angular-relevant code actually changed — plus `workflow_dispatch` for previewing any other branch on demand. There is no preview backend slot, so the build-config fallback (`inputs.build-config || 'preview'`) defaults every automatic push-triggered preview to the fully-Mocked `preview` config (`environment.preview.ts`) — a stable, backend-independent UX sandbox that a later automatic trigger can't silently flip back to calling the real dev backend. Validating against the real dev backend uses the `development` environment/config instead (local `ng serve`, or an explicit manual `build-config: production` dispatch) — never this shared preview slot. GitHub Actions minutes are a hard, exhaustible cap on this Free private repo, so the `push` trigger stays narrowly scoped to `main` rather than every branch (which is what made the pre-rev.2 `task/**` trigger too expensive); task-branch previews remain opt-in via manual dispatch. *(Revises the 2026-07-06 rev.3 policy, whose fallback defaulted to `production` — see DECISIONS.md 2026-07-08.)*
  - **One job per logical gate, except trivial guards [cost]:** GitHub bills each **job** rounded up to a whole minute. Sub-second checks (the repo-hygiene bash guards in `validate-archive.yml`) MUST share a **single** job with one checkout and sequential steps, not one job each — three trivial jobs cost ~3 billed minutes for ~10 seconds of work. Keep heavyweight, independently-parallelisable work (build vs. test vs. schema-drift) in separate jobs where wall-clock matters.
  - **Branch coverage for preview CI [STRICT]:** A push-triggered preview-deployment workflow MUST include all active branch prefixes: `feature/**`, `chore/**`, `bugfix/**`, `refactor/**`, `sprint/**`, `task/**`. Otherwise preview deployments silently skip branches in the sprint/task hierarchy, and a contributor on an uncovered prefix gets no preview URL.
  - **Preview cost awareness [cost]:** Each preview is a full production build + deploy (typically several billed minutes), and on a Free/private repo Actions minutes are a hard, exhaustible cap. If every branch class already has a validation build elsewhere (e.g. PRs into `main` run the CI build), an auto-preview on push duplicates that coverage and burns minutes — consider making the preview `workflow_dispatch`-only (dispatch on demand) or restricting it to the prefixes that genuinely need a live URL. Record the chosen trade-off in the project's decision log.
- **Branch-prefix filtering** on `pull_request` triggers MUST use a job-level `if` condition, not the `branches:` key:
  ```yaml
  # ✅ Correct — filters by source branch (head_ref)
  if: startsWith(github.head_ref, 'feature/') || startsWith(github.head_ref, 'chore/')

  # ❌ Wrong — branches: filters the TARGET branch, not the source branch
  on:
    pull_request:
      branches: ['feature/**']
  ```

### Trigger Path Scoping [STRICT — action economy]
- A workflow MUST scope its triggers with `on.<event>.paths` to the files it actually consumes — never let it fire on **every** PR/push when only an unrelated subtree changed. An unscoped workflow spins up a billed runner (and shows a red ❌ on failure) for changes it cannot possibly be affected by. *(Concrete failure this prevents: a `.claude/`-only standards-sync PR tripping a repo-hygiene guard that validates root `PLAN_*` artifacts it never touched.)*
- **Scope to inputs — including a global-state guard's inputs.** Even a guard that validates whole-repo state (e.g. "no stray closed `PLAN_*.md` at root") has a finite input set: the artifact patterns it scans + its pointer files (`CLAUDE.md`/`AGENTS.md`) + its script + the workflow file itself. `paths:` is workflow-level, so list the **union** across all jobs. This still catches drift at introduction (the PR that adds the stray file matches the pattern) while no longer blocking unrelated PRs on ambient state.
- **Always include the workflow's own file and its scripts** (`.github/workflows/<name>.yml`, `scripts/ci/**`) in `paths:`, so edits to the guard itself re-run it.
- **Required-check gotcha [STRICT]:** a `paths:`-filtered check MUST NOT be marked a **required** status check as-is. When a PR doesn't match the paths the check never reports its context, so the required check hangs **pending forever** and blocks merge. If it must be required, keep the workflow unfiltered and move scoping to a **job-level `if:`** driven by a `dorny/paths-filter` (or equivalent) result — the job then still reports success when skipped — or add a companion always-runs job that reports the required context.

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

### `DISABLE_PIPELINES_FOR_TEMPLATE` — gate app pipelines on a scaffolded repo [STRICT]
- Every app CI/CD workflow (build/test/deploy for the frontend + backend, the SWA preview, and the `Validate Artifacts` hygiene guards) is job-guarded with `if: vars.DISABLE_PIPELINES_FOR_TEMPLATE != 'true'`. **CodeQL is intentionally *not* guarded** — security scanning should run even on an empty repo.
- **When a repo is scaffolded from the standards template but has no app yet** (no webapp/backend directory, no `scripts/ci/*`), set the **repository variable** `DISABLE_PIPELINES_FOR_TEMPLATE=true` (Settings → Secrets and variables → Actions → Variables, or `gh variable set DISABLE_PIPELINES_FOR_TEMPLATE --body true`). Guarded jobs then **skip** (green), instead of failing on missing sources.
- **Unset it (or set `false`) the moment the app lands** — i.e. in the first sprint PR that adds the buildable app — so build, test, deploy, and the hygiene guards activate. Leaving it `true` once there is real code to verify is a silent-coverage bug.
- This flag gates *workflow jobs only*; **Dependabot does not honor it** — keep `dependabot.yml`'s `directory:` targets pointing at paths that actually exist, or its updaters fail independently.

## 4. Reusable Workflows (`workflow_call`)

- Pass `secrets: inherit` from the caller to avoid re-listing every secret.
- The `environment:` input on a reusable workflow maps to a GitHub environment, which controls which secrets/vars are available to the job. For CI/preview builds, use `environment: development` — this avoids environment protection rules and grants access to development-scoped vars without exposing production secrets.
- If the target environment does not exist in the repository, GitHub skips environment protection but still runs the job. This is acceptable for non-production environments.

### A job cannot mix `environment:` with `uses:` [STRICT]
GitHub Actions job schemas are mutually exclusive: a job either **runs steps** (`runs-on` + `steps`,
optionally `environment:`) or **calls a reusable workflow** (`uses:` + `with:`/`secrets:`) — never
both. Adding `environment:` to a `uses:` job doesn't get silently ignored; it breaks the whole
workflow file with a misleading cascade: `Required property is missing: runs-on` on the job, plus
`Unexpected value 'uses'/'with'/'secrets'` on that job's own keys (2026-07-05, `cd-backend-azure-
functions.yml`'s `smoke` job — introduced in a follow-up fix commit, unnoticed until dispatch
failed).

When a `uses:` job needs a value that must resolve inside a specific GitHub environment (e.g. an
environment-scoped `vars.*`), resolve it in a **preceding `runs-on` job that already has
`environment:`**, expose it via that job's `outputs:`, and have the `uses:` job read
`needs.<job>.outputs.<name>` instead of reading `vars.*` directly itself:
```yaml
# ✅ Correct — resolve the env-scoped var where environment: is legal, pass it as an output
deploy-dev:
  runs-on: ubuntu-latest
  environment: development
  outputs:
    api-base-url: ${{ vars.API_BASE_URL }}
  steps: [...]

smoke:                                  # calls a reusable workflow — no environment: here
  needs: deploy-dev
  uses: ./.github/workflows/smoke-dev.yml
  with:
    base-url: ${{ needs.deploy-dev.outputs.api-base-url }}
  secrets: inherit
```
Reference: `cd-backend-azure-functions.yml`'s `deploy-dev`/`smoke` pair, mirroring the identical
pattern already in `cd-angular-azure-static-web-apps.yml`'s `deploy-dev`/`smoke` pair.

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
strands the folder in the build dir on some SDK versions (others emit it under `--output`
directly — do not assume either way). Add a post-publish step that **merges** the folder rather
than copying the directory itself — `cp -r SRC DST` nests into `DST/.azurefunctions/.azurefunctions`
when `DST` already exists, confirmed in a live CD run's publish.zip listing (2026-07-04):
```yaml
- name: Publish
  run: |
    dotnet publish "<csproj>" --configuration Release --output "$GITHUB_WORKSPACE/publish"
    PROJ_DIR=$(dirname "<csproj>")
    AZFUNC_SRC="$PROJ_DIR/bin/Release/<tfm>/.azurefunctions"
    if [ -d "$AZFUNC_SRC" ]; then
      mkdir -p "$GITHUB_WORKSPACE/publish/.azurefunctions"
      cp -r "$AZFUNC_SRC/." "$GITHUB_WORKSPACE/publish/.azurefunctions/"
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
A CodeQL scan workflow catches a broad class of injection, path-traversal, and data-flow vulnerabilities automatically. **It is free for PUBLIC repositories only.** On a **private** repository, CodeQL *analysis* still runs, but uploading results to the Security tab requires **GitHub Advanced Security** — a paid add-on (Team/Enterprise) **not available on Free/personal plans** (`PATCH …/security_and_analysis` → HTTP 422 "Advanced security has not been purchased"; verified against a Free personal plan). Do **not** state CodeQL is "free at any visibility" — that conflates public-repo-free with all-visibility-free. Running the CodeQL CLI with `upload:false` to dodge GHAS on a private repo is **license-gray** (the CLI is licensed for private use only *in connection with* GitHub code scanning) — not a permitted workaround. For this repo CodeQL ships **dormant** (`workflow_dispatch`-only + `ENABLE_CODEQL` gate); see `DECISIONS.md` 2026-06-02. Free first-party SAST on a private repo means a different tool (semgrep OSS, eslint security plugins, Roslyn analyzers).

## 7. Cost Governance [STRICT]

On a Free private repo, Actions minutes are a hard, exhaustible cap — and when they run out
**every** workflow fails in 2–5 seconds with no logs at all, which reads exactly like a broken
repo. This section exists because that happened on **2026-08-23**, and the diagnosis cost an hour
because a quota block is indistinguishable from a catastrophic config error until you notice that
even a pure-bash guard is failing.

### 7.1 The cost model — three multipliers, and they compound

**GitHub bills each JOB, rounded up to a whole minute.** So the bill is not "how long does CI
take", it is:

```
billed ≈ Σ_jobs ceil(job_minutes) × runs
```

Measured on this repo in the 13–17 Aug 2026 window:

| Workflow | Jobs | Billed / run |
|---|---|---|
| `ci-angular` | Live smoke walk **3** + validate-build **2** | **5 min** |
| `ci-backend` | schema-drift **1** + build-and-test **2** | **3 min** |

98 `ci-angular` runs in five days ⇒ **490 min**, against a 2 000 min/month allowance. Three
multipliers produced that, and **no one of them was reckless on its own**:

1. **Per-run cost.** The live smoke walk (added 2026-08-05) took `ci-angular` from one job at ~2
   billed min to two jobs at 5 — a **2.5×** on every run, one week before the busiest sprint ever.
2. **Run count — the one that surprised everyone.** **52 % of all `ci-angular` runs were on
   `sprint/*` branches, not task branches.** Under `AGENTS.md §8`'s Sprint/Task strategy the
   cumulative sprint→`main` PR stays open for the whole sprint, so **every task merged into the
   sprint branch re-ran that PR's full CI**. ~300 billed minutes re-validating PRs that are drafts
   *precisely because* nobody intends to merge them yet.
3. **Volume.** A 22-task sprint, overlapping the close of one sprint and the start of another.

**The rule: cost a new job before adding it, in billed minutes per *sprint*, not per run.**
`ceil(minutes) × jobs × expected runs`, and expected runs for anything `pull_request`-triggered
must include the sprint-branch re-runs, which roughly **double** the naive per-task estimate.
Record the estimate in the PR that adds the job.

### 7.2 Draft PRs skip the heavy gates

A draft PR is, by definition, not ready to merge — and in this repo the cumulative sprint→`main` PR
is a draft *on purpose*, as the standing STOP gate. Re-running a browser walk on it after every
task merge buys nothing that re-running it once, before merge, does not.

```yaml
- name: Run the live smoke walk
  if: github.event.pull_request.draft != true
  run: npm run smoke:walk
```

Three things about that one line, each of which has a way to go silently wrong:

- **`!= true`, never `== false`.** Outside a `pull_request` event the field is `null`; `null !=
  true` is true, so the gate **fails open** and the work still runs. A correctness gate that
  guesses wrong must over-run, never under-run.
- **You MUST add `ready_for_review` to the trigger's `types:`.** It is *not* in the default set
  (`opened`, `synchronize`, `reopened`), so without it, taking the PR out of draft fires **no run
  at all** and the skipped gate never runs — the gate is not deferred, it is deleted. Listing any
  type replaces the whole default set, so spell all four out.
- **Gate the STEP, never the JOB — this is the trap.** Cheap guards routinely share an expensive
  job (§1's "one job per logical gate, except trivial guards"), so a job-level `if:` silently
  disables them too. In this repo `check-file-length.sh`, `check-mock-order-items.sh`,
  `check-validation-anchors.sh` and the e2e type-check all live inside the `smoke-walk` job — and
  `check-mock-order-items.sh` caught a real defect on exactly the integration PR a job-level gate
  would have skipped. **Before gating anything, list every step in the job and confirm each one is
  genuinely deferrable.**

Both halves are enforced by `scripts/ci/check-workflow-cost-guards.sh`, because a rule you verify
by grepping cannot be re-argued and a rule you verify by memory will be.

### 7.3 Every `pull_request` runner job cancels superseded runs

```yaml
concurrency:
  group: <job>-${{ github.ref }}
  cancel-in-progress: true
```

Without it, three pushes in a minute bill three whole minutes to answer the same question three
times. `uses:` jobs inherit the caller's block and need none of their own. Same guard, rule 2.

### 7.4 When the allowance is gone, recognise it fast

Do not debug the diff. The signature is unmistakable once you know it:

| Symptom | Reading |
|---|---|
| **Every** workflow fails, including pure-bash guards that pass locally | not your code |
| Jobs complete in **2–5 s** | the runner never started |
| Log download returns **HTTP 404** for every job | no step ever executed, so there is nothing to log |
| A workflow with 150+ prior green runs fails unchanged | not the workflow |

One re-run is sanctioned to confirm (a job that dies before any step is "runner loss" per this
file's re-run rule); a second is waste. Then check Settings → Billing → Plans and usage, and
githubstatus.com.

## 8. Self-Hosted Runner — Opt-In Only [STRICT]

Added 2026-08-23, while the GitHub-hosted allowance was exhausted (§7). A self-hosted runner costs
**no Actions minutes**. This repo can use one, but only when a person asks for it by name.

### 8.1 The contract

The choice resolves through a **three-step chain**, most specific first:

```
github.event.inputs.runner   per-run override, manual dispatch only
   ↓ (null on push / pull_request)
vars.CI_RUNNER               repository variable — the global default
   ↓ (unset)
ubuntu-latest                hard fallback, always GitHub-hosted
```

**The repository variable is the primary control**, and it is the reason this works without adding
`workflow_dispatch` to every workflow: `vars.*` is readable in `runs-on`, so a `pull_request`- or
`push`-only workflow follows it too. Set `CI_RUNNER=self-hosted` and *everything* moves; delete the
variable and everything reverts, with no code change and no redeploy.

**The tradeoff, stated plainly: while `CI_RUNNER=self-hosted` is set, a PR opened when the runner
is offline queues with no runner to take it, and the check never reports.** That is a global mode
switch, so treat it as one — set it for the duration of a quota outage, unset it after. The
dispatch input remains the safer instrument for a one-off: it moves a single run without changing
the default for everyone.

The hard fallback is never removed, so a repo with no variable and no dispatch behaves exactly as
it did before this section existed.

Callers compute the chain; reusable workflows accept it as an input:

```yaml
# caller — resolves the chain, and is the only place it is written
jobs:
  own-job:
    runs-on: ${{ github.event.inputs.runner == 'self-hosted' && 'self-hosted' || vars.CI_RUNNER || 'ubuntu-latest' }}
  called-job:
    uses: ./.github/workflows/shared-build-dotnet.yml
    with:
      runner: ${{ github.event.inputs.runner == 'self-hosted' && 'self-hosted' || vars.CI_RUNNER || 'ubuntu-latest' }}
```
```yaml
# reusable — accepts, never decides; still consults the variable when a caller does not opt in
on:
  workflow_call:
    inputs:
      runner: { type: string, required: false, default: 'ubuntu-latest' }
jobs:
  build:
    runs-on: ${{ inputs.runner || vars.CI_RUNNER || 'ubuntu-latest' }}
```

A workflow with no `workflow_dispatch` needs no changes beyond the `runs-on` expression — the
variable reaches it anyway. The dispatch input is added only where a per-run override is useful.

Four things about that shape, each with a way to go wrong silently:

- **`github.event.inputs.runner` is null on every non-dispatch event**, so `null == 'self-hosted'`
  is false and the chain falls through to `vars.CI_RUNNER`, then to `ubuntu-latest`. With no
  variable set, the automatic path is GitHub-hosted **by construction**, not by remembering to set
  a default.
- **The `A && B || C` ternary needs a truthy B.** `'self-hosted'` is a non-empty string, so it is
  safe. Substitute anything falsy and the expression silently collapses to `C`.
- **Every `runs-on:` expression must name `ubuntu-latest` as its fallback.** `runs-on: ${{
  inputs.runner }}` alone resolves to an empty string on any event that supplies no input, and an
  empty `runs-on` is a hard workflow error. Guard rule 3.
- **Half the jobs are `uses:` calls, and the forward is easy to forget.** Miss it and the dispatch
  *appears* to work while the build half quietly stays on GitHub-hosted and keeps billing. Guard
  rule 4. This is the failure mode this whole section is shaped around: it does not fail, it
  half-works.

### 8.2 What the runner host must provide

The workflows assume **Linux**. Verified assumptions, not guesses: 5 × `sed -i` (GNU semantics —
BSD/macOS `sed` needs an empty-string argument), 3 × `set -euo pipefail`, 3 × `[[ ]]`, and 2 × `jq`.
Only 8 of 17 multi-line `run:` blocks pin `shell: bash`, so on a Windows runner the other 9 would
execute under `pwsh` and fail.

**"Linux" is not "Debian".** An earlier version of this line said `playwright install --with-deps`
was "`apt` and therefore Linux-only", which quietly equated the two — and the Tech Lead's runner is
Linux and not apt-based. The step died with `apt-get: command not found` (exit 127) before a single
test ran, so `Live smoke walk` reported a failure that had nothing to do with the diff under test
Never write a host assumption as "Linux" when what the command needs is a
package manager, a specific libc, or systemd.

Needed on the host: the `az` CLI (the backend deploy shells out to `az functionapp deploy`), the
.NET SDK or `actions/setup-dotnet`, Node, and `jq`.

**Chromium's system libraries are NOT on that list, and the reason is worth recording**, because
the first version of this section put them there on no evidence. The failure log proved only that
`apt-get` was absent — it said nothing about a missing library, and the Tech Lead had been running
Playwright on that machine for months, so they were plainly already present. `--with-deps` was
installing what was already installed, with a tool the distro does not have. **Dropping the flag
was the whole fix.** If a host ever genuinely lacks them, `playwright install-deps --dry-run`
names them for that distro — but do not assert they are missing without a launch failure that says
so.

**A workflow provisions the WORKSPACE; it never mutates the HOST [STRICT].**

That is the line, and `--with-deps` is the only step in this repo that crossed it. The flag runs
`apt-get` **as root on the runner machine** — disposable on a GitHub-hosted VM, but on a
self-hosted runner that machine is someone's laptop, so any PR that edits a workflow could execute
arbitrary root commands on it. That is a supply-chain hole, and it decides the question on its own;
the tidiness argument is not needed. `--with-deps` is therefore removed, and the system libraries
above are a **pre-condition of registering a runner**, not a step.

The rule is not "never install during a workflow" — that would ban `setup-node` and
`setup-dotnet` too, and the toolchain version belongs in the workflow where it is explicit rather
than in host state nobody can see. Three categories, three homes:

| Thing | Where | Why |
|---|---|---|
| System libraries, root-owned packages | **host pre-condition** | host-wide, persistent, needs root |
| Chromium binary (`playwright install`, no flag) | project dependency | version-locked to `@playwright/test`; pinning it to the host drifts on every bump — `agent-workarounds.md` records that exact failure |
| Node / .NET SDK (`setup-*`) | workspace | installs into the tool cache, not system paths (hence `DOTNET_INSTALL_DIR`, §8.1) |

**The cost of the pre-condition model, stated rather than glossed:** host setup becomes state no
one can read from the repo. Rebuild the machine or add a second runner and CI fails with a cryptic
error instead of a useful one. The mitigation is the list above being kept accurate — which is why
it names packages instead of saying "the usual dependencies".

**This buys no CI minutes**, and should not be sold as if it did: the smoke-walk job measures 161 s
→ 3 billed minutes, and deleting the browser step entirely still bills 3 (§7.1's whole-minute
boundary). Self-hosted bills nothing at all. The change is about blast radius and determinism.

### 8.3 Security

A self-hosted runner executes repository code on that machine with that machine's credentials. This
repo is private, so the fork-PR attack that makes self-hosted runners dangerous on public repos does
not apply — **never enable one on a public repo without an approval gate**. Keep the runner
non-privileged, and stop it when it is not in use rather than leaving it registered and idle.
