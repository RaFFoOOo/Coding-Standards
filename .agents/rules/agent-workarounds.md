---
name: Agent Workarounds
trigger: always_on
description: Platform-specific terminal workarounds for agent environments
---

# Agent-Specific Workarounds

Platform-specific issues and mitigations that do not belong in the global constitution.

## Known Terminal Issue — Broken stdout pipe in `run_command`

Some agent platforms spawn a shell where stdout is broken: commands that produce output block indefinitely in `command_status`, while commands with no output complete normally.

### Diagnosis
If `echo test` works but `git status` or `ls` hang, this is the issue.

### Workaround
Redirect all output to a temp file and read it via `view_file`:
```bash
nohup bash -c "your-command 2>&1" > /tmp/log.txt &
# Then read with view_file /tmp/log.txt
```

For long-running commands (build, push), poll the log file with a `sleep N && cat /tmp/log.txt` pattern.

**Claude Code note:** Claude Code uses the `Bash` tool for terminal commands, which does not have this stdout pipe issue. This workaround applies to other agent platforms only.

## Known IDE Issue — Ghost File Resurrections during Refactoring

When an Agent performs a destructive mass-deletion of a structural directory via `rm -rf` (e.g., component consolidation), if the user accidentally has any of those targeted files focused natively in an active IDE tab, the IDE's automated persistence loop will instantly resurrect the deleted files immediately back into the system environment causing severe ghost compilation errors.

### Workaround
- **Diagnostics:** If an Angular build fails explicitly citing an import mismatch inside a domain you just deleted, immediately assume IDE Resurrection.
- **Agent Duty:** Warn the user to forcibly close those editor tabs, and re-execute the UNIX `rm -rf` command blindly before re-triggering compilers.

**Claude Code note:** This issue applies identically in VSCode when using Claude Code. The `Bash` tool executes `rm -rf` correctly, but IDE tab resurrection can still occur. Follow the same workaround.

### Variant — stale content on a *modified* (not deleted) file, surviving past the commit

Observed during a sprint close-out: editing a file, then
`git mv`-ing it, then committing, can still commit the file's **pre-edit** content — the edit
landed in the working tree correctly (confirmed by re-reading it), but the commit captured stale
content anyway. Same underlying race as the deletion case above (an open editor tab's own
persistence loop writing its buffered version back to disk right around the `git mv`/commit), just
manifesting as "the commit is wrong" instead of "the file came back after `rm -rf`."

- **Diagnostics:** After any commit that renames/moves a file you just edited, don't trust it —
  `git show HEAD:<path>` and diff it against what you intended. Caught here only because a
  downstream PR merge later failed on an unrelated local-checkout error, which prompted a re-check;
  it would otherwise have shipped silently.
- **Agent Duty:** For any edit-then-`git mv` sequence on a file that might be open in the user's
  editor, verify the **committed** content (`git show HEAD:<path>`), not just the working-tree
  content, before pushing. If it's wrong, fix forward with a new commit (never amend) — do not
  assume a successful `Edit` tool call plus a clean `git status` guarantees the commit itself is
  correct.

## Known Tooling Issue — Playwright MCP shares ONE browser session across concurrently-running
background agents

**Observed once in practice** — three background agents were dispatched in parallel
worktrees, each explicitly told to use Playwright MCP instead of claude-in-chrome *because*
claude-in-chrome drives the user's single real Chrome session (a known collision risk for concurrent
agents), on the assumption Playwright MCP spins up its own isolated browser instance per invocation.
That assumption was wrong in this environment: two of the three agents independently reported landing
on tabs opened by a *different* agent's own `ng serve` instance mid-task, via both `browser_navigate`
and `browser_take_screenshot` defaulting to whatever tab was globally "current" across all callers.

### Diagnosis
A parallel agent's Playwright screenshot/navigation shows the wrong app instance, wrong port, or
content another agent's task clearly wasn't asked to touch. Check `browser_tabs`/tab list — if it
lists tabs your task never opened, you're sharing a session with another concurrently-running agent.

### Workaround
- **Agent Duty (each agent):** Before every single Playwright action in a task known to run alongside
  other browser-driving agents, re-check the tab list and act only on the tab index your own task
  created. Never interact with — or dismiss a dialog on — a tab you didn't open yourself; a stray
  `beforeunload`/confirm dialog on someone else's tab blocks all further automation on that shared
  session (see the general dialog-avoidance guidance for browser automation).
- **Orchestrator duty (when dispatching parallel agents that each need live-browser verification):**
  do not assume "Playwright MCP" alone implies per-agent isolation — that is a property of how the
  MCP server happens to be wired up in the current sandbox, not a guarantee of the tool itself, and it
  was false here. Verify actual isolation with a quick 2-tab smoke check before relying on it across
  several concurrent agents; if it turns out shared (as it did here), either brief every agent with
  the defensive tab-reselection discipline above, or serialize the live-verification step instead of
  running it inside the parallel dispatch.

**Claude Code note:** Applies to the `mcp__playwright__*` tool family specifically, in this project's
sandbox configuration. Not yet re-tested against claude-in-chrome under the same concurrent-agent
conditions — assume the identical risk there too until proven otherwise, since claude-in-chrome is
already documented (this file, and `feedback_claude_in_chrome_reconnect_fallback` in auto-memory) as
sharing the user's one real browser session.

## Known Environment Issue — `claude-in-chrome`'s `resize_window` cannot reliably reach true mobile widths (375px)

Observed 2026-07-26 (`docs/UX_REVIEW_2026-07-26.md` + its Addendum 1 live-testing pass): repeated
`resize_window` calls requesting 375×812 against a live browser tab were silently capped by the
host window manager — `window.innerWidth` read back anywhere from 500px to 1366px depending on the
tab/window, never the requested 375px, with no error surfaced by the tool call itself (it always
reports "Successfully resized"). One tab in the same session DID reach ~555px after several retries;
another never went below 1366px no matter how many retries.

### Diagnosis
After `resize_window`, verify the ACTUAL width via `javascript_tool` (`window.innerWidth`) before
trusting any "mobile" screenshot — the tool's own success response is not evidence the resize took
effect. If the readback doesn't match the request, this is the known constraint, not a mistake in
how the tool was called.

### Workaround
- Retry `resize_window` 2-3 times on the same tab — it occasionally lands closer on a later attempt
  (555px was reached this way after 2 retries), but do not expect exact pixel control.
- If one tab in a multi-tab session resizes further than another, prefer navigating the more-
  resizable tab to the URL under test rather than fighting the stuck one.
- Treat any width safely under the project's mobile breakpoint (768px, `stack-angular.md §14`) as
  "mobile enough" to exercise the mobile CSS path, but report the ACTUAL measured width achieved in
  any findings doc — do not claim 375px was tested when it wasn't. A true small-phone width
  (360-390px, the most common real device class) may still need a live-device spot-check this
  environment cannot substitute for.

## Known Testing Pitfall — Angular debug API (`window.ng`) is read-only safe, not write-safe

`ng.getComponent(el)` (and the wider `window.ng.*` debug API) is a reliable way to *read* a live
component's signal values or a service's current state during a claude-in-chrome/Playwright QA
session — e.g. reading `someService.entries()` directly to check whether a resubscription
happened, without needing a specific UI surface to display it. It is **not** a safe substitute for
*simulating a write* (calling `comp.updateSomeField(value)`, setting a signal directly) when the
behavior under test is itself change-detection-dependent — dirty tracking, form validity gates,
resubscription triggers. A debug-API-driven "edit" can visibly update signal-bound DOM while
never flowing through the same event path a real keystroke/click would, so a dependent mechanism
(e.g. a dirty-vs-committed comparison gating a "Save all" button) can silently never see it.

### Diagnosis
A live QA click-through of a reactivity fix (e.g. "does X refetch after a write") produces no
observable effect, and the interactive control that should react to the change (a Save button, a
dirty-state indicator) stays in its unchanged/disabled state — even though a fix is independently
known-correct (code review, or its own `TestBed` unit test) and other, real UI interactions on the
same page work normally.

### Workaround
- Use `window.ng`/`ng.getComponent()` for **read-only** introspection only (checking a signal's
  current value, confirming which service instance a component holds).
- For anything that must register as a genuine "the user changed this" event (staging an edit,
  marking a form dirty, triggering a save-enablement gate), drive the real UI: a `computer` click,
  a typed keystroke sequence, or the `find`/`form_input` tools — not a direct method/signal call.
- If a component's own real interaction pattern is unclear (e.g. a custom inline-edit control that
  isn't a plain `<input>`), read its template/component source first to find the correct activation
  gesture, rather than reaching for the debug API as a shortcut.
- Found during a live QA gate: an inline-edit controller's dirty check never registered a
  debug-API-driven title edit, so its "Save all" button stayed disabled. Record incidents of this
  shape in `LESSONS_LEARNED.md`.

## Known Environment Constraint — the remote sandbox IS backend-capable; two hosts are egress-denied

**Recorded 2026-08-03 after a QA gate wrongly reported the backend as unverifiable.** The Claude
Code on the web sandbox image ships Node, Java/Maven/Gradle, Ruby, Python and Playwright browsers —
but **no .NET SDK and no running Docker daemon**. That is an image-composition gap, *not* a
verification boundary: both are recoverable in-session.

### Recipe — full green backend suite from a cold sandbox

```bash
apt-get update && apt-get install -y dotnet-sdk-10.0   # 10.0.110, matches the net10.0 target
dockerd > /tmp/dockerd.log 2>&1 &                       # binary ships; daemon does not auto-start
cd <backend-dir> && dotnet restore
TESTCONTAINERS_RYUK_DISABLED=true dotnet test           # 355/355
dotnet list package --vulnerable --include-transitive   # 0 vulnerabilities
```

### The two genuine egress denials, and why neither blocks verification

| Host | Symptom | Route around it |
|---|---|---|
| `builds.dotnet.microsoft.com:443` | `curl: (56) CONNECT tunnel failed, response 403` | Ubuntu `noble-updates/universe` ships `dotnet-sdk-10.0` and is reachable. **Do not retry the denied host** — the proxy README forbids it. |
| Docker Hub (`production.cloudfront.docker.com`) | `docker pull testcontainers/ryuk` → `Forbidden` | `TESTCONTAINERS_RYUK_DISABLED=true`. Ryuk only reaps containers post-run; the sandbox is ephemeral, so there is nothing to reap. `mcr.microsoft.com` is **allowed**, so the mssql image itself pulls fine. |

Diagnose any egress denial with `curl -sS "$HTTPS_PROXY/__agentproxy/status"` — `recentRelayFailures`
names the exact host and reason.

### Failure signatures, in the order they appear if you skip a step

- `dotnet: command not found` → SDK not installed (step 1).
- 90/355 failing with `DockerUnavailableException: unix:///var/run/docker.sock` → daemon not
  started (step 2).
- 90/355 failing with `DockerImageNotFoundException: testcontainers/ryuk` → ryuk not disabled
  (step 3). **Note the count is identical in both Docker cases** — do not assume a rerun that still
  says "90 failed" made no progress; read the actual exception.

### Agent duty

Never write "not runnable in this environment" for a missing toolchain without first attempting an
install (`apt-cache policy <pkg>` is one cheap, definitive command), checking whether a service
merely needs starting, and looking for the tool's own constrained-environment escape hatch. A
well-written limitation section makes an unattempted check look like an impossible one and survives
review because the caveat itself reads as diligence. Full incident: `LESSONS_LEARNED.md` Sprints
42+43, finding 5.

## Known Environment Constraint — running the live smoke walk in this sandbox

Recorded 2026-08-05, building `<spa-app>/e2e/smoke-walk.spec.ts`. Three obstacles, all recoverable
in-session; none of them is a reason to write "not runnable here" (see the .NET entry above).

| Obstacle | Symptom | Fix |
|---|---|---|
| Node one patch below Angular's floor | `The Angular CLI requires a minimum Node.js version of v22.22.3…` (sandbox ships v22.22.2) | `nodejs.org` **is** reachable — download the current v24 tarball and prepend its `bin/` to `PATH`. Ubuntu's `nodejs` package is v18 and useless here. |
| Playwright browser build mismatch | `Executable doesn't exist at /opt/pw-browsers/chromium_headless_shell-1234/…` | The image pre-bakes a *different* build (chromium-1194). `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1` is set, so do **not** run `playwright install` — set `PLAYWRIGHT_CHROMIUM_PATH=/opt/pw-browsers/chromium-<n>/chrome-linux/chrome`, which `playwright.config.ts` reads into `launchOptions.executablePath`. |
| The deployed dev SWA and Function App are egress-denied | `curl` returns 000; `$HTTPS_PROXY/__agentproxy/status` shows `connect_rejected … 403` for `*.azurestaticapps.net` and `<dev-function-app>.azurewebsites.net` | Not fixable, and not needed: the walk targets a local `ng serve --configuration preview`, which is fully Mocked. Do not claim a deployed-environment check was performed from this sandbox. |

**Two page-level pitfalls the walk had to design around, both likely to recur in any Playwright work
against this app:**
- `page.goto` defaults to `waitUntil: 'load'`, which can exceed a whole test budget here — Mock mode
  still resolves real Blob Storage photo URLs and those hang under the egress policy. Use
  `domcontentloaded` plus an explicit readiness assertion.
- A bare `header` selector matches **four** elements on Home (content sections render their own
  `<header class="page-header">`). Scope to `getByRole('banner')`. Likewise, the mobile bottom-nav
  renders its own `AccountMenuComponent`/`LanguageMenuComponent` instances, so any `.account-menu__item`
  or `.language-menu__item` selector must be scoped to the shell or it fails strict mode with two matches.

**And one that will silently mislead you:** after editing a source file, `ng serve` may fail the
rebuild and keep serving the previous bundle. The test then exercises stale code and passes. Confirm
`Application bundle generation complete` appeared in the serve log after your edit before believing
any result. Full incident: `LESSONS_LEARNED.md` "Chore: Live Smoke Walk (2026-08-05)", finding 3.
