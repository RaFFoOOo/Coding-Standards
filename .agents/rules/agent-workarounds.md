# Agent Workarounds — environment and tooling traps

Every session loads this file. Each entry gives the symptom, the check that confirms it and the fix;
where an incident is recorded, a pointer names it.

## Git and the working tree

### An open editor tab can resurrect a deleted file or revert an edit

- **Deleted:** after `rm -rf` of a directory, the build fails on an import inside the domain you
  deleted. Assume an open tab's persistence loop wrote it back to disk. Ask the user to close those tabs,
  run `rm -rf` again, then rebuild.
- **Edited, then `git mv`:** the commit can capture the **pre-edit** content even when the working tree
  is correct and `git status` is clean (Sprint 37 close-out, 2026-07-24). After any edit-then-move,
  check `git show HEAD:<path>` before pushing. If it is wrong, fix forward with a new commit — never
  amend.

### `.claude/rules` and `.claude/skills` are links into `.agents/`

Claude Code reads rules and skills only under `.claude/`; the files live in `.agents/` so other agents
read them too. On Windows a clone without symlink support checks each link out as a one-line text
file holding the target path, and Claude Code then finds no rule and no skill — nothing errors.

```bash
git config core.symlinks        # must print true (Windows also needs Developer Mode)
ls -l .claude/                  # rules -> ../.agents/rules, skills -> ../.agents/skills
```

Fix: enable Developer Mode, `git config core.symlinks true`, then re-checkout the two paths. Edit the
`.agents/` path; a tool that writes through the link and replaces it with a directory breaks the layout.

### `core.autocrlf=input` is set globally; 19 tracked files are committed CRLF

There is no `.gitattributes`. **19 of 1 656** tracked files are CRLF blobs, all under `{webapp}/`
(among them `_variables.scss`, `_shared-sections.scss`, `tsconfig.json`, `index.html`) — measured
2026-09-14 with `git grep -Il $'\r' HEAD`. Staging an edit to one converts every line to LF, so an
18-line edit showed **222** changed lines (Sprint 54 T5).

```bash
git diff --cached -w --stat -- <file>   # -w ignores whitespace: the real size
git show HEAD:<file> | file -           # "with CRLF line terminators"
git -c core.autocrlf=false add <paths>  # the fix — per command, never change the global config
```

Restoring CRLF in the working tree does not help: git converts at `add`. **On every commit, compare
`git diff --cached --stat` with the size of the change you meant.** Any scripted re-serialization (a
whole-file rewrite, a `json.dumps` reflow) produces the same inflated diff. No gate catches it — the
content is correct.

### A clone verified full can become shallow mid-session

`git rev-list --count HEAD` read **1 278, no `.git/shallow`**, and an hour later **4, shallow**, with no
`--depth` in config (`LESSONS_LEARNED.md` Sprint 57). A shallow clone answers every path query with the
graft commit, so nothing errors — dates just become uniform (1 432 of 1 610 files at Sprint 56 T0,
`archive/PLAN_sprint_056.md:54`).

```bash
git rev-list --count HEAD   # small = shallow
ls .git/shallow             # exists = shallow
git log --diff-filter=A --format=%ad --date=short -1 -- <path>   # every file the same recent date?
```

**Re-check immediately before relying on history** — before recording a recovery SHA (`AGENTS.md §2`)
or taking any `git log` measurement. A check at session start does not license a `git rm` later.
Fix: `git fetch --unshallow`, then recompute the conclusion rather than editing it. **The cause is
unknown:** fetching a PR ref was replayed on a full clone and changed nothing — do not repeat it as
the reason.

## Processes and the self-hosted runner

### Broken stdout pipe in a spawned shell

Some agent platforms spawn a shell where stdout is broken: commands that produce output block
indefinitely, while commands with no output complete normally. **If `echo test` works but `git
status` or `ls` hangs, this is it.** Redirect to a file and read that instead:

```bash
nohup bash -c "your-command 2>&1" > /tmp/log.txt &
```

For a long-running command, poll the log rather than the process. Claude Code's `Bash` tool does not
have this issue; the workaround is for other platforms, and it is why this entry survives here.

### `ps | grep` lies in both directions — use `pgrep -x`

`ps` truncates its argument column, so a running process reads as stopped; `grep` matches its own
shell, so a stopped one reads as running. A truncated reading once started a **second**
`Runner.Listener` against one registration, failing CI on two branches in a way that read as code
failures (`archive/LESSONS_LEARNED_ARCHIVE.md`, 2026-08-17 §8).

```bash
pgrep -x Runner.Listener      # exact process name, no self-match
pgrep -af 'Runner.Listener'   # the full command line, read deliberately
ss -ltnp 'sport = :4300'      # a server: probe the port, the only proof it serves
```

**`pkill -f <pattern>` kills the shell running it** whenever the pattern also appears in that shell's own
command line — the Bash call dies with **exit 144** and every later command in it is skipped. Measured
twice on 2026-09-14/15; the second time it skipped a `git checkout` restoring `local.settings.json`. Kill
by the port's PID (`ss -ltnp 'sport = :4300'`) or by exact name (`pgrep -x func`), then check each
step's result. **`kill $(pgrep -f <pattern>)` is the same trap:** `pgrep -f` matches the calling shell
too, and on 2026-09-17 stopping the runner that way ended the call with exit 144. **So is a loop over
`/proc/*/cmdline` that kills on a pattern** (twice on 2026-10-09): the loop's own shell carries the
pattern. List candidates with `ps -eo pid,args`, read them, then `kill <pid>` by number.

### The self-hosted runner has 7.7 GB of RAM

The SQL Server Testcontainer exits below 2 GB. **Signature:** many failures, each
`ContainerNotRunningException` on the **same container id**, and zero assertion failures (PR #841:
109 of 517). That is memory, not code — re-run once; it passed with 3.7 GB free against 2.4 GB during
the smoke walk. Jobs serialize on the one runner, so *queued* is not *stuck*. Locally, run **one** dev
server and check `free -m` before starting a second (`verify/SKILL.md §7` Step 3).

**When memory runs out, the system kills the runner itself** — measured 2026-09-14, twice in an hour:
Chrome at 3.2 GB (19 processes) plus a local walk stack, or Chrome alone plus the backend job. The job
then stays `in_progress` on a dead runner, the next queued job never starts, and the restarted runner
logs `A session for this runner already exists … Conflict` until GitHub drops the old session.

- **Never run the local walk stack while a self-hosted CI job is active**, and check `free -m` against
  Chrome's share before pushing.
- **Recover:** `gh api -X POST repos/<owner>/<repo>/actions/runs/<id>/force-cancel` — a plain
  `gh run cancel` waits forever for the dead runner — then `gh run rerun <id>`.
- **Start the runner detached, never as a session background task.** Claude Code stops its own
  background tasks under memory pressure: on 2026-09-15 a `run.sh` started that way was stopped
  mid-job, together with a `gh run watch`; `free -m` read 4.8 GB available minutes afterwards. Use
  `setsid nohup ./run.sh > <log> 2>&1 < /dev/null &`, and stop it yourself when done — or use
  `scripts/deploy/with-self-hosted-runner.sh`, which does both.
- **Before stopping it, check that no run is queued or in progress** — including the one a merge just
  started on its target branch. Stopping mid-job cancels that run and it reads as a failure: on
  2026-09-16 merging #1006 started a guards run on the sprint branch, the stop cancelled it, and it had
  to be re-run. `gh run list --status in_progress` and `--status queued` both empty, then stop.
- **A listener can stay connected and stop taking jobs.** On 2026-09-17, after a job was cancelled,
  runs sat `queued` for 10+ minutes with nothing in the runner log; `kill -INT` left the listener alive
  40 s later, and starting a second `run.sh` logged `A session for this runner already exists`. Fix:
  `kill -TERM` every `Runner.Listener` / `run-helper.sh` / `run.sh` PID, confirm `pgrep -x
  Runner.Listener` is empty, then start one detached runner — it took the queued jobs within seconds.

### A self-hosted Azure job signs the user's `az` out

The runner runs as the user and shares `~/.azure`, so `azure/login` replaces the session and the
job's cleanup clears it: after every self-hosted backend deploy, `az account show` says *Please run
'az login'* (three times on 2026-10-13). Never run `az` while such a job is active; afterwards ask the
user for `! az login`.

### `dotnet ef` against Azure SQL hangs 60 s, then "Failed to authenticate … TaskCanceledException"

`DefaultAzureCredential` tries managed identity before the CLI, and since MSAL 4.84 (in the graph from
`Azure.Storage.Blobs` 12.30.1) that probe calls `169.254.169.254` without a short timeout. On a network
where nothing answers that address — this laptop, the self-hosted runner — it waits until SQL's
connect timeout cancels the whole chain, and `az login` is never consulted. Measured 2026-10-13: a
plain `SqlConnection` got its token in 7 s, the same credential under EF hung 60 s; the Azure SDK log
(`AzureEventSourceListener.CreateConsoleLogger()`) shows the pending `getplatformmetadata` request.

```bash
AZURE_TOKEN_CREDENTIALS=AzureCliCredential dotnet ef migrations list \
  --project {Backend}.DataAccess --startup-project {Backend}.Functions   # reads the DB
```

The deploy action's EF step sets the same variable.

### `$?` is only the exit code of the command immediately before it

`echo "$(basename "$s") exit=$?"` prints `basename`'s status, and `bash guard.sh | tail -3` reports
`tail`'s: a loop over eight guards once printed `exit=0` for all of them while one was failing
(`archive/LESSONS_LEARNED_ARCHIVE.md`, Sprint 46 T17). Capture it on the next line, and prove a new
batch harness by breaking one thing on purpose before believing its greens:

```bash
bash "$s" > "$log" 2>&1
rc=$?
echo "$(basename "$s") exit=$rc"
```

## Browser automation

### Concurrent agents share one browser session

`mcp__playwright__*` in this sandbox shares **one** session across concurrent agents — two of three
parallel agents landed on another agent's tab (Sprint 38, `archive/LESSONS_LEARNED_ARCHIVE.md`).
`claude-in-chrome` drives the user's single real Chrome; assume the same risk.

- **Each agent:** re-check the tab list before every action; act only on a tab you opened; never
  dismiss a dialog on someone else's tab — it blocks the whole session.
- **Orchestrator:** verify isolation with a 2-tab check before parallel live verification; if it is
  shared, brief every agent with the rule above or serialize that step.

### `resize_window` reports success without reaching the width

Requests for 375×812 read back anywhere from **500 to 1 366 px**, and the tool still says
"Successfully resized" (`docs/UX_REVIEW_2026-07-26.md`).

- Read `window.innerWidth` with `javascript_tool` after every resize.
- Retrying 2–3 times sometimes gets closer (one tab reached 555 px); navigate the tab that resized
  furthest.
- Any width under the 768 px breakpoint (`stack-shared-ui.md §14`) exercises the mobile CSS. **Report
  the width you measured** — never claim 375 px. A real 360–390 px phone may still need a device check.

### `window.ng` is safe for reads, not for writes

`ng.getComponent(el)` reliably reads a signal or a service's state. Calling a method or setting a
signal through it can update the DOM without taking the path a real interaction takes, so a gate that
depends on change detection — a dirty check, a Save button — never fires (Sprint 41,
`archive/LESSONS_LEARNED_ARCHIVE.md`). To stage an edit, click or type through the real UI; read the
component's template first if its activation gesture is unclear.

### The SWA preview slot is not the bare hostname

`ci-preview-swa.yml:105` deploys to the named environment `preview`:

```
https://{swa-host}-preview.{region}.{n}.azurestaticapps.net   ← the preview build
https://{swa-host}.{n}.azurestaticapps.net                   ← a different, older build
```

The bare host answers 200 with a working, stale site — nothing on the page says so.

- **Take the URL from the `Post Preview URL as PR Comment` step** (`:107`), which posts only when the
  branch has an open PR; otherwise it logs `No open PR found … skipping comment`. Without a PR,
  construct `<prefix>-preview.<region>.<n>.azurestaticapps.net`.
- **The slot is shared** — the latest push from any branch overwrites it. Re-deploy from the branch
  under test right before walking it.
- **Before reporting any live measurement, assert one string that only the build under test has.**

### `npx vitest run` is not the frontend suite — `npm test` is

Run the suite the way CI does: `npm test` (`ng test`, the Angular Vitest builder). Calling the runner
directly skips the builder, so specs compile **JIT** and a stable tree fails for reasons that have
nothing to do with it. Measured 2026-09-17 at the S59 gate: `npx vitest run` reported **21 failures
across 7 files** — `NG0303: Can't bind to 'pending'`, an unexpected `UrlTree` — and the same tree,
same machine, under `npm test`, passed **1 049/1 049 in 31 s**. The failures survive a cache clear
(`node_modules/.vite`, `node_modules/.vitest`) and reproduce under Node 24 as well as 26, so neither
of those familiar explanations fits: it is the wrong command, not a broken environment.

The same holds for a subset: `npm test -- --include '<glob>' --watch=false`, never
`npx vitest run <path>`. A bare path is not a subset — `ng test` reads it as the project name and
exits 1 (`Argument: project, Given: "src/app/…spec.ts", Choices: "{webapp}"`, 2026-10-05).

### Playwright against this app

- **`page.goto` with the default `waitUntil: 'load'` can outlast a test** — Mock mode still resolves
  real Blob photo URLs. Use `domcontentloaded` plus a readiness assertion
  (`e2e/smoke-walk.helpers.ts:175`).
- **A bare `header` selector matches 4 elements on Home** — the banner plus 3
  `<header class="page-header">`. Scope to `getByRole('banner')`.
- **The header renders each menu twice** — a desktop dropdown inside `<header>` and a mobile
  `<app-bottom-sheet>` outside it (`layout/header/header.html:111`/`:172`, `:136`/`:165`). Scope
  `app-language-menu` / `app-account-menu` selectors to the banner, or strict mode finds two.
- **After a failed rebuild, `ng serve` keeps serving the last good bundle**, and a test can pass against
  stale code. Confirm `Application bundle generation complete` in the serve log after your edit
  (`archive/LESSONS_LEARNED_ARCHIVE.md`, Chore: Live Smoke Walk, finding 3).
- **A route stub that answers blob requests hides what the preview shows.** Fulfilling
  `*.blob.core.windows.net` with stand-in images made the logo wall render in every Sprint 72 T3
  check, while the deployed preview, which has no SAS, drew a broken image for every logo (fixed in
  #1209). Render once with blob requests answered `403` before calling an image surface done.
- **`locator.isVisible()` does not wait** — its `timeout` option is ignored, so it answers for the
  instant it is called. A dialog opened by the preceding click read as absent on 2026-09-27 and nearly
  reported a working confirm as broken. Assert with `await expect(locator).toBeVisible()`, which
  retries, or `locator.waitFor()`.

## Skills

### Skill arguments are substituted into `$0`, `$1`, `$2`… in the SKILL text

Invoking a skill with `args` replaces positional tokens in the loaded `SKILL.md` — code blocks
included. `run-qa` invoked with *"Sprint 62 app gate …"* rendered its awk task-table check as
`t && app ~ /T[0-9]/` and `(s ? $s : Sprint)` (2026-09-26); the file on disk was intact. **Run a
command from the file, not from the loaded skill text,** whenever it uses `$N` — or invoke the skill
without `args`.

## Remote sandbox (Claude Code on the web)

**Never write "not runnable in this environment" before trying:** install the tool
(`apt-cache policy <pkg>` is one command), check whether a service only needs starting, and look for
the tool's own escape hatch. A limitation section makes an unattempted check read as an impossible one
(`archive/LESSONS_LEARNED_ARCHIVE.md`, Sprints 42 + 43 §5).

**A blocked download is not a blocked tool.** Before saying a tool or a walk cannot run here, try every
mirror below; one 403 or `000` from a vendor CDN proves nothing about the package. On 2026-10-06 the
agent told the Tech Lead the Http + `devauth` walk could not run from the sandbox after two CDN
probes; `packages.microsoft.com` had `func` all along, and the walk ran the next morning
(`LESSONS_LEARNED.md` Sprint 67).

| Source | Reachable (2026-10-07) | Gives you |
|---|---|---|
| `packages.microsoft.com` (apt) | ✅ | `azure-functions-core-tools-4` (`func`), Microsoft packages |
| Ubuntu `noble-updates` (apt) | ✅ | `dotnet-sdk-10.0` |
| `api.nuget.org` | ✅ | `dotnet restore`, `dotnet tool restore` (`dotnet-ef` is a repo-local tool) |
| `registry.npmjs.org` | ✅ | `npx azurite`, npm packages |
| `mcr.microsoft.com` | ✅ | SQL Server image |
| `cdn.functions.azure.com`, `functionscdn.azureedge.net`, GitHub release downloads, Docker Hub, `ghcr.io` image layers (`pkg-containers.githubusercontent.com`, so the ZAP image does not pull — 2026-10-12), `builds.dotnet.microsoft.com` | ❌ | — use the rows above |
| `*.database.windows.net`, `*.azurewebsites.net`, `*.azurestaticapps.net` | ❌ | no Azure resource is reachable — dev SQL, dev Functions, the SWA preview |

### What each environment can prove — never offer a check the build cannot run

| Environment | Auth | Data | Proves | Cannot prove |
|---|---|---|---|---|
| `preview` build (local `npm run start:preview` or the deployed SWA slot) | Mock | frontend Mock JSON | rendering, copy, client logic | anything about the backend or a real sign-in — **its `auth` is `Mock`**, so "sign in for real on the preview" is not a check |
| Local Http + `devauth`, backend `DATA_ACCESS_MODE=Mock` (runs **in this sandbox**, below) | devauth stub | backend in-memory repositories (what prod runs) | real handlers, validation, owner authorization, `/v1/me` roles, real POSTs | EF/SQL queries, MSAL |
| Local Http + `devauth`, `DATA_ACCESS_MODE=Database` (`{short}-dev up`, the Tech Lead's machine) | devauth stub | dev Azure SQL | the above plus real queries | MSAL |
| Deployed dev | real MSAL | dev Azure SQL | the redirect itself | — needs the Tech Lead's interactive sign-in |

### The Http + `devauth` walk in the sandbox

Measured 2026-10-07 (Sprint 67 T2). About 5 minutes from a cold sandbox.

```bash
curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" \
  > /etc/apt/sources.list.d/microsoft-prod.list
apt-get update && apt-get install -y azure-functions-core-tools-4 dotnet-sdk-10.0
cd {services} && dotnet restore
# local.settings.json, for the walk only — restore it with `git checkout` afterwards:
#   "DATA_ACCESS_MODE": "Mock",
#   "DEV_FAKE_AUTH_USERS": "owner=<owner OID>,customer=<customer OID>"   (the OIDs: bullet below)
setsid nohup npx -y azurite --silent --location <scratch>/azurite > <log> 2>&1 < /dev/null &
cd {Backend}.Functions && setsid nohup func start --port 7071 > <log> 2>&1 < /dev/null &
cd {webapp} && setsid nohup npx ng serve --configuration devauth --port 4200 > <log> 2>&1 < /dev/null &
curl -s "localhost:7071/api/v1/me?tenantId=<tid>" -H 'X-Dev-User: owner'   # must say "role":"owner"
```

- **Never `git add -A {services}` while the walk's `local.settings.json` edits are in place** — the
  file is tracked, so the Mock mode and fake users get committed (it happened on 2026-10-10, fixed
  forward). Stage named paths, or `git checkout` the file first.
- The two OIDs are the keys of `MockDataSeed.OidRoleOverrides` (owner / customer on every tenant), not the dev-DB
  identities in `docs/uat/README.md` — those exist only in the Database mode.
- The fake users start **not onboarded**: `PUT /v1/me?tenantId=<tid>` with `X-Dev-User` and
  `{"name":…,"phone":…}` before the browser walk, or every page diverts to `/onboarding`.
- In the browser: cookies `tenant=<name>`, `{short}_mock_auth=1`, `{short}_dev_identity=owner|customer`.
- **Why not a local SQL Server container:** `AzureSqlAuthInterceptor` puts an Azure AD token on every
  connection, so SQL Server refuses it (`Login failed for user ''`, *configured for Integrated
  authentication only*). Bypassing the interceptor weakens authentication; the session's safety check
  refuses it, and so should you. EF/SQL behaviour stays with `dotnet test` (Testcontainers) and the
  Tech Lead's `{short}-dev up`.

### The backend suite runs from a cold sandbox

Observed 2026-08-03: the image has no .NET SDK and no running Docker daemon; both are recoverable.

```bash
apt-get update && apt-get install -y dotnet-sdk-10.0   # matches the net10.0 target
dockerd > /tmp/dockerd.log 2>&1 &                       # the binary ships; the daemon does not start
cd {services} && dotnet restore
TESTCONTAINERS_RYUK_DISABLED=true dotnet test
dotnet list package --vulnerable --include-transitive
```

| Signature | Missing step |
|---|---|
| `dotnet: command not found` | the SDK install |
| DB tests fail with `DockerUnavailableException: unix:///var/run/docker.sock` | `dockerd` |
| DB tests fail with `DockerImageNotFoundException: testcontainers/ryuk` | `TESTCONTAINERS_RYUK_DISABLED=true` |

The two Docker cases fail the **same number** of tests — read the exception, not the count.

**The database tests do not run in every sandbox.** On 2026-10-09 (kernel 6.18) the pinned
`mssql/server:2025-latest` died at start-up (`fatal error … Reason: 0x00000004`, a core dump) while
`2022-latest` started fine, and 2022 cannot host the schema: it has no native `json` column type.
Every `[Collection("Database")]` test then fails with `ContainerNotRunningException`. That is the
environment, not the change: run the rest locally with `--filter`, and let CI's `build-and-test` job
(`shared-build-dotnet.yml`) run the database tests.

### Egress denials, and the route around each

Diagnose any denial with `curl -sS "$HTTPS_PROXY/__agentproxy/status"` (`recentRelayFailures` names
the host). Do not retry a denied host.

| Host | Symptom | Route |
|---|---|---|
| `builds.dotnet.microsoft.com` | `CONNECT tunnel failed, response 403` | Ubuntu `noble-updates/universe` ships `dotnet-sdk-10.0` |
| Docker Hub | `docker pull testcontainers/ryuk` → `Forbidden` | disable Ryuk (above) — it only reaps containers after the run, and the sandbox is ephemeral; `mcr.microsoft.com` is allowed, so the mssql image pulls |
| `*.azurestaticapps.net`, `eudw{prefix}azf01.azurewebsites.net` | `curl` 000; `connect_rejected … 403` | walk a local `ng serve --configuration preview` for the visual half, the sandbox Http + `devauth` walk (above) for the backend half; never claim a deployed check from here |

### The smoke walk in the sandbox

Observed 2026-08-05.

| Symptom | Fix |
|---|---|
| `The Angular CLI requires a minimum Node.js version of v22.22.3…` (the image had v22.22.2) | download the current v24 tarball from `nodejs.org` and prepend its `bin/` to `PATH`; Ubuntu's `nodejs` is v18 |
| `Executable doesn't exist at /opt/pw-browsers/chromium_headless_shell-…` | `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` is set, so do not `playwright install`; set `PLAYWRIGHT_CHROMIUM_PATH=/opt/pw-browsers/chromium-<n>/chrome-linux/chrome` (read by `playwright.config.ts:65`) |
