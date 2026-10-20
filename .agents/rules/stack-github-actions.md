---
paths:
  - ".github/workflows/**"
  - ".github/actions/**"
  - "scripts/deploy/**"
---

# GitHub Actions — workflow rules

Section numbers are stable: workflows, scripts and `DECISIONS.md` cite them. Incident history lives
behind the pointer in each section.

## 1. Trigger Design

### `pull_request` vs `push`
- **[STRICT] A workflow that comments on a PR, reads its number or reacts to its lifecycle uses
  `pull_request`**, which carries `github.event.number` and `github.head_ref`; `push` carries no PR
  payload.
  - **Exception — an SWA preview that needs a stable URL** (auth redirect URIs): `pull_request` gets a
    PR-numbered URL whatever `deployment_environment` says, so trigger it another way and resolve the
    PR number with `pulls.list({ head })`.
- **Filter a `pull_request` by source branch with a job-level `if:`** — `branches:` filters the
  *target*:
  ```yaml
  # ✅
  if: startsWith(github.head_ref, 'feature/') || startsWith(github.head_ref, 'chore/')
  # ❌ matches PRs INTO feature/**, not from it
  on: { pull_request: { branches: ['feature/**'] } }
  ```

### Previews
- **`ci-preview-swa.yml` is `workflow_dispatch`-only**: a preview is always an explicit act for the
  branch you want to see. The `push` trigger on `main` was removed 2026-09-01 — it duplicated the dev
  deploy and raced PR dispatches for the one shared slot (`ci-preview-swa.yml:13`).
- **Its build-config fallback is the all-Mock `preview`** (`inputs.build-config || 'preview'`), so a
  preview never calls the real dev backend (🔒 `DECISIONS.md` 2026-07-08 rev.2). Validate against dev
  with a local `ng serve` or a `build-config: production` dispatch.
- **If a preview is ever push-triggered again**, it covers every branch prefix (`feature/**`,
  `chore/**`, `bugfix/**`, `refactor/**`, `sprint/**`, `task/**`) — and cost it first (§7.1): each run
  is a full build and deploy.

### Trigger path scoping [STRICT]
- **Scope every trigger with `on.<event>.paths` to the files the workflow reads**, including a
  whole-repo guard's inputs (the artifact patterns, its pointer files, its script) and **always the
  workflow file itself**. `paths:` is workflow-level, so list the union across jobs.
- **A `paths:` filter cannot scope individual pushes** — §7.2b.
- **Never make a `paths:`-filtered check a required status check.** When a PR matches no path the
  context never reports, and the check blocks merge forever. If it must be required, leave the
  workflow unfiltered and skip with a job-level `if:` (a skipped job reports success), or add an
  always-running job that reports the context. This repo protects `main` with no required checks
  (GitHub Pro since 2026-10-16: a PR is required, force-push and deletion are blocked, no approval
  count — the only reviewer is the PR's own author).

### One job per logical gate, except trivial guards [cost]
GitHub bills each **job** rounded up to a whole minute. Sub-second guards share **one** job with one
checkout — `validate-archive.yml`'s *Repo-hygiene guards* runs every pure-bash guard in sequence. Keep
heavy, parallelisable work (build, test, schema drift, the walk) in separate jobs.

## 2. Permissions

- **[STRICT] A `pull_request` workflow that calls a reusable workflow with a checkout declares
  `permissions: contents: read` at the WORKFLOW level.** A job-level block does not reach a `uses:`
  call, and a private repo then fails checkout with *"Repository not found"*. Add
  `pull-requests: write` to the same block when the workflow comments.
- **Declare only what the workflow needs** — never rely on repository defaults.

### CD Identity Separation [STRICT]
- **The CD pipeline deploys with a dedicated App Registration (SPN) per GitHub environment.** Never
  share one across dev and prod; the prod SPN has no federated credential for `development`, so a dev
  OIDC token cannot deploy to prod.
- **A runtime identity never gets a deployment role** (`Website Contributor`) — the running app could
  redeploy itself.
- **Authentication app registrations are never CD identities.**
- Names and the scheme: `naming-azure-resources.md`.

| Identity | Type | Purpose | Grants |
|---|---|---|---|
| `eudw{prefix}umi01` | User-Assigned Managed Identity | Function App runtime → storage + SQL | Storage Blob Delegator + Blob/Queue/Table/File data roles, `db_datareader` + `db_datawriter` (`scripts/azure-setup/assign-roles.sh:81`–`:117`) |
| `{app}-spa` | App Registration | SPA MSAL authentication | — |
| `{services}-api` | App Registration | Backend JWT audience | — |
| `eudw{prefix}spn01` | App Registration / SPN | CD — development | `Reader` on the subscription + `Website Contributor` on `eudw{prefix}azf01` (`provision-cd-identity.sh:131`) |
| `euwp{prefix}spn01` | App Registration / SPN | CD — production (pending) | same, on the prod Function App |

## 3. Secret & Variable Scope

The naming schema and the CI/CD split are `AGENTS.md §5`; this is only where they live in GitHub.

- **A secret both CI and CD need is registered twice:** `CI_AZURE_<RESOURCE>_<NAME>` at repository
  level (a PR workflow cannot read environment secrets) and `CD_AZURE_<RESOURCE>_<NAME>` on the
  environment. Document the split in `README.md`.
- **Variables carry no `CI_`/`CD_` prefix** — the environment scopes them.

### `DISABLE_PIPELINES_FOR_TEMPLATE` [STRICT]
- **Every app workflow's jobs are guarded with `if: vars.DISABLE_PIPELINES_FOR_TEMPLATE != 'true'`**
  (7 workflows today). CodeQL is not — scanning runs even on an empty repo.
- **Set it to `true` on a repo scaffolded from the template with no app yet**, so jobs skip green
  instead of failing on missing sources; **unset it in the first PR that adds the app** — left on,
  nothing is verified.
- It gates workflow jobs only; Dependabot ignores it, so keep `dependabot.yml`'s `directory:` targets
  real.

## 4. Reusable Workflows (`workflow_call`)

- **Pass `secrets: inherit`** rather than re-listing secrets.
- **A CI or preview job that needs environment-scoped values binds `environment: development`** — no
  protection rules, no production secrets. A missing environment is skipped, not an error. (Distinct
  from `shared-build-angular.yml`'s `environment` **input**, which is the Angular build configuration.)

### A job cannot mix `environment:` with `uses:` [STRICT]
A job either runs steps (`runs-on` + `steps`, optionally `environment:`) or calls a reusable workflow
(`uses:` + `with:` / `secrets:`). Adding `environment:` to a `uses:` job breaks the whole file with a
misleading cascade — `Required property is missing: runs-on`, then `Unexpected value 'uses'`. Resolve
the environment-scoped value in a preceding step job and pass it as an output:

```yaml
deploy-dev:
  runs-on: ubuntu-latest
  environment: development
  outputs:
    api-base-url: ${{ vars.API_BASE_URL }}
  steps: [...]

smoke:                                # ✅ no environment: here
  needs: deploy-dev
  uses: ./.github/workflows/smoke-dev.yml
  with:
    base-url: ${{ needs.deploy-dev.outputs.api-base-url }}
  secrets: inherit
```

Reference: the `deploy-dev` / `smoke` pairs in `cd-backend-azure-functions.yml:54`/`:110` and
`cd-angular-azure-static-web-apps.yml`.

### Shared build extraction [STRICT]
- **The same ordered 3+ steps in a `ci-*.yml` and a `cd-*.yml` become a `shared-build-<stack>.yml`,
  immediately.** CI and CD differ by boolean inputs, never by a second shared workflow:
  `shared-build-dotnet.yml` takes `run-tests` (CI) and `publish` (CD).
- **The deploy job stays in the caller**, bound to its environment, with login and deploy as steps
  (`cd-backend-azure-functions.yml:86` — `azure/login` over OIDC, then `.github/actions/deploy-functions`).
  In the shared workflow it would hand production secrets to every caller, CI included.
- **Artifact handoff:** the shared workflow uploads, the deploy job downloads; `retention-days: 1`.
  What must outlive the run goes to a release instead: after the dev smoke, the CD `release` job
  attaches the artifact to `build-<sha7>` (`.github/actions/publish-release-asset`), which does not
  expire and does not count against Actions storage.
- **One runtime per shared workflow** — `shared-build-dotnet.yml` installs no Node.

### Current host — Azure Functions: the `.azurefunctions/` folder [STRICT]
*Deleted when the backend moves to an ASP.NET Core host.*

Functions host v4.1000+ loads **0 functions** — every route 404s, with no startup error visible from
outside — unless the package root holds `.azurefunctions/`. Two steps can lose it:

- **`dotnet publish --output <path>` may leave it in `bin/<config>/<tfm>/`.** Merge its contents
  (`cp -r SRC/. DST/`); `cp -r SRC DST` nests it as `DST/.azurefunctions/.azurefunctions` when `DST`
  exists (`shared-build-dotnet.yml:135`).
- **`actions/upload-artifact@v4+` skips hidden paths** — set `include-hidden-files: true`
  (`shared-build-dotnet.yml:157`).

**Check after deploy:** `GET https://<scmsite>/api/vfs/site/wwwroot/` lists `.azurefunctions/`. If it
does not, Log Stream shows `Could not find the .azurefunctions folder…` and `0 functions found`.

## 5. Node.js Runtime

- **JavaScript actions run on Node.js 24 natively** — pin a major that ships it. Use
  `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24=true` only as a bridge until that major exists (0 uses today).
- **When `shared-build-angular.yml` moves Node, audit every workflow's action versions.**

## 6. Security Gates

### A06 — CVE checks [STRICT]
- **Every Node workflow runs `npm audit --audit-level=moderate`; every .NET workflow runs
  `dotnet list package --vulnerable --include-transitive` and fails on High or Critical.** Never
  `continue-on-error: true`.
- **Run `npm audit` last — after lint, tests and build, before the artifact upload.** It is a network
  call; placed after `npm ci`, a 12-hour npm registry outage failed **six** PRs with no signal from the
  suite or the build (`shared-build-angular.yml:142`).
- **Say when the failure is the registry, not a CVE — and still fail.** A refused connection and an
  HTTP 503 both exit 1 with `audit endpoint returned an error`, which reads like a finding; one
  2026-09-04 outage took three re-runs to tell apart.

```yaml
- name: Audit npm dependencies
  run: |
    status=0
    npm audit --audit-level=moderate > "$RUNNER_TEMP/npm-audit.log" 2>&1 || status=$?
    cat "$RUNNER_TEMP/npm-audit.log"
    if [ "$status" -ne 0 ] && grep -q 'audit endpoint returned an error' "$RUNNER_TEMP/npm-audit.log"; then
      echo "::error::npm registry unreachable — this is not a CVE finding. Re-run the job."
    fi
    exit "$status"
```
```yaml
- name: Audit .NET dependencies        # after dotnet restore — shared-build-dotnet.yml:71
  run: |
    dotnet list package --vulnerable --include-transitive 2>&1 | tee /tmp/vuln.txt
    if grep -qiE "(High|Critical)" /tmp/vuln.txt; then
      echo "::error::HIGH or CRITICAL vulnerability detected in .NET packages"
      exit 1
    fi
```

### A08 — supply-chain action pinning [STRICT]
A third-party action — outside the `actions/` and `github/` orgs — is pinned to a full 40-character
SHA with a version comment; first-party actions may use a major tag. Tags on third-party repos can be
moved (`tj-actions/changed-files`, 2025).

```yaml
uses: third-party/some-action@v2                                          # ❌
uses: azure/login@7ddb5af1ef8758cf1353cf3b42f940aee27ba21c  # v3.0.2 — pinned per A08   # ✅
```

### CodeQL
**Free for public repositories only.** On a private repo, uploading results needs GitHub Advanced
Security, which neither Free nor Pro can buy (`HTTP 422 "Advanced security has not been purchased"`), and
running the CLI with `upload:false` to avoid it is licence-gray. So `codeql.yml` ships dormant —
dispatch-only and gated on `ENABLE_CODEQL` (🔒 `DECISIONS.md` 2026-06-02). Free SAST on a private repo
means another tool: semgrep OSS, eslint security plugins, Roslyn analyzers.

## 7. Cost Governance [STRICT]

On a private repo Actions minutes are a monthly allowance — 3 000 on Pro since 2026-10-16 (2 000 on
Free ran out on 2026-10-16) — and past it, with a $0 spending limit, every workflow fails in seconds
with no logs, which reads like a broken repo (`DECISIONS.md` 2026-08-23).

### 7.1 Cost a job in billed minutes per sprint

```
billed ≈ Σ_jobs ceil(job_minutes) × runs
```

- **Cost a new job before adding it:** `ceil(minutes) × jobs × expected runs`, and record the
  estimate in its PR.
- **Expected runs include the sprint-branch re-runs.** The cumulative sprint→`main` PR re-ran full CI
  on every task merge — **52 %** of `ci-angular` runs in the measured week, roughly doubling a naive
  per-task estimate.
- **A saving that does not cross a whole-minute boundary is worth nothing** (`AGENTS.md §0`).

### 7.2 Draft PRs skip the heavy steps

```yaml
on:
  pull_request:
    types: [opened, synchronize, reopened, ready_for_review]
...
- name: Run the live smoke walk
  if: github.event.pull_request.draft != true
```

- **`!= true`, never `== false`.** Outside `pull_request` the field is `null`, so the gate fails
  open — it must over-run, never under-run.
- **Add `ready_for_review` to `types:`**, and spell out all four: listing any type replaces the default
  set, and without it taking a PR out of draft fires no run — the gate is deleted, not deferred.
- **List every step in the job before choosing where the gate goes.** Gate the job only when no step
  in it must run on a draft; otherwise move that step to a job that already runs, rather than keep a
  job alive for it. The e2e type-check lives in `validate-build` (`run-e2e-typecheck`), so the
  smoke-walk job and its scope run only where the walk does. `build-and-test` and `validate-build` are gated whole
  (2026-09-16): on a draft they defer build, tests, lint, schema drift and both CVE audits. The
  draft that matters is the sprint PR, and its task PRs already ran all of them — **a sprint +
  `main` failure is found at `ready_for_review`, not at merge**.
- **The walk also skips every PR that does not target the default branch** (2026-09-17, `DECISIONS.md`):
  a task PR into `sprint/*` runs build, tests, lint and the e2e type-check, never the walk. The
  condition sits on the `walk-scope` job, and the walk job needs it, so both are skipped — not run to
  say "skipped" — and bill nothing.
- **A job is billed a whole minute however short it is** (measured 2026-10-16: two scope jobs of 8 s
  and 5 s, a 29 s type-check job and a 51 s build billed 4 minutes for one task-PR push). Before adding
  a job, ask which running job could host the step; on a draft, skip the scope jobs too, since
  everything they gate skips there.

Enforced by `scripts/ci/generic/check-workflow-cost-guards.sh` (rules 1–5).

### 7.2b `paths:` does not filter a pull_request's individual pushes [STRICT]

**`paths:` is evaluated against the cumulative PR diff**, so once a PR holds one matching file every
later push re-runs the workflow. On #970, **21 of 33 commits were docs-only and each billed 10
minutes** (`LESSONS_LEARNED.md` Sprint 58).

**The fix is `shared-push-scope.yml`**, which compares this push against the **last tested head** —
the newest run on the branch whose `tested-job` passed — and gates the expensive jobs on its
`touched` output: 1 billed minute to save 4–9 on a push that touches nothing they read. **Never
diff from `github.event.before`:** a run cancelled before its build leaves `before` unbuilt, and a
docs-only push after it would skip the build and read green on code nobody compiled.

**The prefixes are an input, never hardcoded**, defaulted from a repository variable so a sibling
repo reuses the file unchanged:

```yaml
push-scope:
  uses: ./.github/workflows/shared-push-scope.yml
  with:
    prefixes: >-
      ${{ vars.ANGULAR_SCOPE_PREFIXES || '{webapp}/ package.json package-lock.json' }}
    tested-job: validate-build
  permissions:          # the lookup reads earlier runs; a called workflow cannot exceed this
    contents: read
    actions: read

validate-build:
  needs: push-scope
  if: needs.push-scope.outputs.touched != 'false'
```

- **Keep the caller's literal `paths:` and its `prefixes` in step** — `on:` resolves before any
  expression can, so `paths:` cannot read a variable. Both lists include the workflow file and
  `shared-push-scope.yml`.
- **A prefix ending in `/` matches its subtree; anything else matches the whole path. Anchor with `^`
  and escape metacharacters** — otherwise `docs/{webapp}-notes.md` matches `{webapp}/`, and an
  unescaped dot lets `package-lock.json` match `package-lockXjson`.
- **[STRICT] One scope per gated job, holding THAT job's inputs** — its `tested-job` names the job
  it answers for, and `tested-step` the step that proves the expensive part ran when the job can
  pass without it. A job gated on another job's scope inherits its prefixes: the walk shared the
  build's, which include `docs/uat/`, and walked the app for a docs-only PR. Guard rule 5.
- **It fails open, in all four places:**

| | Why |
|---|---|
| `opened` / `reopened` / `ready_for_review` ⇒ the whole PR | no earlier push to compare; until 2026-09-27 this answered "run everything", so every new PR ran every job |
| no tested run ⇒ the whole PR; Actions API unreadable ⇒ `before` | nothing on the branch was built; without the API it is no worse than before the lookup |
| a tested head that is not an ancestor, or `\|\| files=""` ⇒ `true` | a force-push leaves the base unresolvable |
| consumers test `!= 'false'`, never `== 'true'` | an unset output must still run the job |

- **Scope can gate any job; draft gates a job only when none of its steps must run on a draft**
  (§7.2). Unchanged inputs mean nothing the job asserts can newly fail; a draft's code *can* have
  changed.
- **Skipping a whole job is safe only with no required checks** — §1.
- **Say which skip happened** with a `::notice::`, so a green check never reads as "the app was
  walked" (`ci-angular.yml:222`).
- **Never cancel a superseded run whose push touched code when the newer push did not.** Scope is
  per push, so the code push's run is the only one that tests the code. On 2026-09-17 PR #1010's code
  push (`4264ffff`) was cancelled to free the self-hosted runner, its docs-only follow-up went green
  with `build-and-test` and `validate-build` both **skipped**, and nothing had been tested. Re-run the
  cancelled run (`gh run rerun <id>`) — it keeps its own `before…after`.

### 7.3 Every `pull_request` runner job cancels superseded runs

```yaml
concurrency:
  group: <job>-${{ github.ref }}
  cancel-in-progress: true
```

Three pushes in a minute otherwise bill three minutes for one answer. A `uses:` job inherits the
caller's block. Guard rule 2.

### 7.4 When the allowance is gone, recognise it fast

| Symptom | Reading |
|---|---|
| **every** workflow fails, pure-bash guards included | not your code |
| jobs finish in **2–5 s**, or show no runner and 0 steps | the runner never started |
| every job's log download returns **HTTP 404** | no step ran |
| a workflow with a long green history fails unchanged | not the workflow |

Do not debug the diff. Re-run once to confirm; a second re-run is waste. Then check Settings → Billing
and githubstatus.com — or switch runners (§8).

## 8. Self-Hosted Runner — Opt-In Only [STRICT]

A self-hosted runner uses none of the GitHub-hosted minutes allowance and, measured on October
2026's usage export, bills nothing: 1 012 self-hosted minutes at $0 (GitHub has announced a
$0.002/min platform charge; re-check the export if it appears). This repo uses one only when a person
asks for it.

### 8.1 The contract

```
github.event.inputs.runner   per-run override — manual dispatch only
   ↓ null on push / pull_request
vars.CI_RUNNER               repository variable — the global default
   ↓ unset
ubuntu-latest                hard fallback, never removed
```

- **The variable is the primary control.** `vars.*` is readable in `runs-on`, so `pull_request` and
  `push` workflows follow it with no `workflow_dispatch` of their own. Switch it with
  `./scripts/deploy/ci-runner.sh status | self-hosted | github`; for one deploy,
  `./scripts/deploy/with-self-hosted-runner.sh <workflow> <ref> key=value` starts the runner,
  dispatches and stops it.
- **While `CI_RUNNER=self-hosted` is set, a PR opened with the runner offline queues and its check
  never reports.** It is a global mode switch: set it for an outage, unset it after. For one run, the
  dispatch input is the safer instrument.
- **Not every job follows it:** `cd-angular-azure-storage.yml:59`, `:114` and `codeql.yml:32` hardcode
  `ubuntu-latest`.

Callers compute the chain; reusable workflows accept it:

```yaml
# caller — the only place the chain is written
own-job:
  runs-on: ${{ github.event.inputs.runner == 'self-hosted' && 'self-hosted' || vars.CI_RUNNER || 'ubuntu-latest' }}
called-job:
  uses: ./.github/workflows/shared-build-dotnet.yml
  with:
    runner: ${{ github.event.inputs.runner == 'self-hosted' && 'self-hosted' || vars.CI_RUNNER || 'ubuntu-latest' }}
```
```yaml
# reusable — accepts, never decides
on:
  workflow_call:
    inputs:
      runner: { type: string, required: false, default: 'ubuntu-latest' }
jobs:
  build:
    runs-on: ${{ inputs.runner || vars.CI_RUNNER || 'ubuntu-latest' }}
```

- **`github.event.inputs.runner` is null on every non-dispatch event**, so the chain falls through
  to the variable, then to GitHub-hosted — by construction.
- **`A && B || C` needs a truthy `B`.** `'self-hosted'` is; anything falsy collapses to `C`.
- **Every `runs-on:` expression names `ubuntu-latest` last.** `${{ inputs.runner }}` alone is empty on
  an event with no input, and an empty `runs-on` is a hard error. Guard rule 3.
- **Forward the runner to every `uses:` call.** Miss one and a dispatch half-works: the build keeps
  running, and billing, on GitHub-hosted. Guard rule 4.

### 8.2 What the runner host provides

**The workflows assume Linux with bash**, measured 2026-09-14 across `.github/`: 5 × `sed -i` (GNU
semantics), 3 × `set -euo pipefail`, 7 × `[[ ]]`, `jq` in `deploy-swa` and `shared-push-scope`. Only
the 8 composite-action `run:` blocks pin `shell: bash`; the 11 in workflows rely on the Linux default,
and would run under `pwsh` on Windows.

**Linux is not Debian.** Name the actual need — a package manager, a libc, systemd. `playwright install
--with-deps` died on this non-apt runner with `apt-get: command not found` (exit 127) before any test
ran (PR #802).

**Needed on the host:** the `az` CLI (`deploy-functions` runs `az functionapp deploy`), `jq`, `gh`
and `zip` (`publish-release-asset` creates the release and zips the artifact), and Chromium's system
libraries. Node and the .NET SDK come from `setup-node` / `setup-dotnet`. If a host lacks the libraries,
`playwright install-deps --dry-run` names them — never assert they are missing without a launch
failure that says so.

**[STRICT] A workflow provisions the WORKSPACE; it never mutates the HOST.** `--with-deps` runs
`apt-get` as root on the runner, and on a self-hosted runner that is someone's machine: any PR editing
a workflow could run root commands on it. So it is removed, and system libraries are a precondition of
registering a runner.

| Thing | Home | Why |
|---|---|---|
| System libraries, root-owned packages | host precondition | host-wide, persistent, needs root |
| Chromium binary (`playwright install`, no flag) | project dependency | locked to `@playwright/test`'s version |
| Node / .NET SDK (`setup-*`) | workspace | the tool cache, not system paths — hence `DOTNET_INSTALL_DIR: ${{ runner.temp }}/dotnet` (`shared-build-dotnet.yml:67`) |

The cost: host setup is state the repo cannot show, so a rebuilt machine fails cryptically. Keep the
list above accurate. And this buys no minutes — the walk job measures 161 s, 3 billed minutes, with or
without the browser step (§7.1).

### 8.3 Security

A self-hosted runner executes repository code with that machine's credentials. The fork-PR attack
does not apply to this private repo — **never enable one on a public repo without an approval gate**.
Keep it non-privileged, and stop it when it is not in use.
