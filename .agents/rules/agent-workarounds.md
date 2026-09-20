---
name: Agent Workarounds
trigger: always_on
description: Environment and tooling traps — the symptom, the check that confirms it, and the fix
---

# Agent Workarounds — environment and tooling traps

Every session loads this file. Each entry gives the symptom, the check that confirms it and the fix.
Where an incident is recorded, keep the account in the lessons log, not here.

## Git and the working tree

### An open editor tab can resurrect a deleted file or revert an edit

- **Deleted:** after `rm -rf` of a directory, the build fails on an import inside the domain you
  deleted. Assume an open tab's persistence loop wrote it back to disk. Ask the user to close those
  tabs, run `rm -rf` again, then rebuild.
- **Edited, then `git mv`:** the commit can capture the **pre-edit** content even when the working
  tree is correct and `git status` is clean. After any edit-then-move, check `git show HEAD:<path>`
  before pushing. If it is wrong, fix forward with a new commit — never amend.

### `core.autocrlf=input` with CRLF blobs already committed

With no `.gitattributes`, a repo can carry a handful of CRLF-committed files. Staging an edit to one
converts every line to LF, so an 18-line edit shows as hundreds of changed lines.

```bash
git grep -Il $'\r' HEAD                 # which tracked files are CRLF
git diff --cached -w --stat -- <file>   # -w ignores whitespace: the real size
git show HEAD:<file> | file -           # "with CRLF line terminators"
git -c core.autocrlf=false add <paths>  # the fix — per command, never change the global config
```

Restoring CRLF in the working tree does not help: git converts at `add`. **On every commit, compare
`git diff --cached --stat` against the size of the change you meant.** Any scripted whole-file
rewrite produces the same inflated diff, and no gate catches it — the content is correct.

### A clone verified full can become shallow mid-session

A clone measured full has later read shallow in the same session with no `--depth` in config. A
shallow clone answers every path query with the graft commit, so nothing errors — dates just become
uniform.

```bash
git rev-list --count HEAD   # small = shallow
ls .git/shallow             # exists = shallow
git log --diff-filter=A --format=%ad --date=short -1 -- <path>   # every file the same recent date?
```

**Re-check immediately before relying on history** — before recording a recovery commit (`AGENTS.md
§2`) or taking any `git log` measurement. A check at session start does not license a `git rm` later.
Fix: `git fetch --unshallow`, then recompute the conclusion rather than editing it.

## Processes and shells

### Broken stdout pipe in a spawned shell

Some agent platforms spawn a shell where stdout is broken: commands that produce output block
indefinitely, while commands with no output complete normally. **If `echo test` works but `git
status` or `ls` hangs, this is it.** Redirect to a file and read that instead:

```bash
nohup bash -c "your-command 2>&1" > /tmp/log.txt &
```

For a long-running command, poll the log rather than the process. Claude Code's `Bash` tool does not
have this issue; the workaround is for other platforms.

### `ps | grep` lies in both directions — use `pgrep -x`

`ps` truncates its argument column, so a running process reads as stopped; `grep` matches its own
shell, so a stopped one reads as running. A truncated reading has started a **second** listener
against one registration, failing CI in a way that read as a code failure.

```bash
pgrep -x <exact-process-name>   # no self-match
pgrep -af '<pattern>'           # the full command line, read deliberately
ss -ltnp 'sport = :<port>'      # a server: probe the port, the only proof it serves
```

**`pkill -f <pattern>` kills the shell running it** whenever the pattern also appears in that shell's
own command line — the call dies with **exit 144** and every later command in it is skipped, silently
dropping cleanup steps. `kill $(pgrep -f <pattern>)` is the same trap. Kill by the port's PID or by
exact name, then check each step's result.

### `$?` is only the exit code of the command immediately before it

`echo "$(basename "$s") exit=$?"` prints `basename`'s status, and `cmd | tail -3` reports `tail`'s. A
loop over eight guards once printed `exit=0` for all of them while one was failing. Capture it on the
next line, and prove a new batch harness by breaking one thing on purpose before believing its greens:

```bash
bash "$s" > "$log" 2>&1
rc=$?
echo "$(basename "$s") exit=$rc"
```

### A self-hosted runner is a developer machine with finite RAM

A database test container exits below its memory floor. **Signature:** many failures, each a
container-not-running error on the **same container id**, and **zero assertion failures**. That is
memory, not code — re-run once with the machine idle. Jobs serialize on one runner, so *queued* is
not *stuck*.

When memory runs out the system kills the runner itself: the job stays `in_progress` on a dead
runner, the next queued job never starts, and a restarted runner logs a session conflict until the
service drops the old one.

- **Never run a local dev stack while a self-hosted CI job is active.** Check free memory first.
- **Recover:** force-cancel the run through the API — a plain cancel waits forever for the dead
  runner — then re-run it.
- **Start the runner detached**, not as an agent background task: agents stop their own background
  tasks under memory pressure, which kills the runner mid-job. Use `setsid nohup … &`, and stop it
  yourself when done.
- **Before stopping it, check that no run is queued or in progress** — including the one a merge just
  started. Stopping mid-job cancels that run and it reads as a failure.
- **A listener can stay connected and stop taking jobs.** Runs sit queued with nothing in the log and
  an interrupt leaves the listener alive. Terminate every listener and helper PID, confirm `pgrep -x`
  is empty, then start one detached runner.

## Browser automation

### Concurrent agents share one browser session

A shared MCP browser session puts concurrent agents on each other's tabs. An extension driver drives
the user's single real browser; assume the same risk.

- **Each agent:** re-check the tab list before every action; act only on a tab you opened; never
  dismiss a dialog on someone else's tab — it blocks the whole session.
- **Orchestrator:** verify isolation with a two-tab check before parallel live verification; if it is
  shared, brief every agent or serialize that step.

### `resize_window` reports success without reaching the width

Requests for a phone width read back anywhere from 500 to 1366 px, and the tool still reports success.

- Read `window.innerWidth` after every resize.
- Retrying 2–3 times sometimes gets closer; navigate the tab that resized furthest.
- Any width under the mobile breakpoint exercises the mobile CSS. **Report the width you measured** —
  never claim the width you asked for. A real phone may still need a device check.

### A framework debug API is safe for reads, not for writes

Reading a signal or a service's state through the debug handle is reliable. Calling a method or
setting a signal through it can update the DOM without taking the path a real interaction takes, so a
gate that depends on change detection — a dirty check, a Save button — never fires. To stage an edit,
click or type through the real UI; read the component's template first if its activation gesture is
unclear.

### A preview deployment slot is not the bare hostname

A named preview environment and the production hostname are different URLs, and **the bare host
answers 200 with a working, stale site — nothing on the page says so.**

- **Take the URL from the deploy step's own output**, or construct the slot URL explicitly.
- **The slot is shared** — the latest push from any branch overwrites it. Re-deploy from the branch
  under test right before walking it.
- **Before reporting any live measurement, assert one string that only the build under test has.**

### Run the test suite the way CI runs it

Calling a test runner directly instead of through the framework's build plugin skips the builder, so
specs compile differently and a stable tree fails for reasons unrelated to it. One measured case: the
direct runner reported 21 failures across 7 files — binding errors, an unexpected route — while the
same tree on the same machine passed in full under the project's own test command. The failures
survive a cache clear and reproduce across runtime versions, so neither of those familiar
explanations fits: it is the wrong command, not a broken environment. The same holds for a subset.

### Browser end-to-end tests

- **`page.goto` with the default `waitUntil: 'load'` can outlast a test** when the page resolves real
  remote asset URLs even in Mock mode. Use `domcontentloaded` plus a readiness assertion.
- **A bare landmark selector can match several elements** — scope to an explicit role.
- **A responsive header often renders each menu twice**, once for desktop and once inside a mobile
  sheet. Scope menu selectors to the banner, or strict mode finds two.
- **After a failed rebuild, a dev server keeps serving the last good bundle**, so a test can pass
  against stale code. Confirm the rebuild completed in the serve log after your edit.

## Remote sandbox

**Never write "not runnable in this environment" before trying:** install the tool, check whether a
service only needs starting, and look for the tool's own escape hatch. A limitation section makes an
unattempted check read as an impossible one.

### The backend suite runs from a cold sandbox

The image may have no SDK and no running container daemon; both are recoverable.

```bash
apt-get update && apt-get install -y <sdk-package>   # match the project's target framework
dockerd > /tmp/dockerd.log 2>&1 &                    # the binary ships; the daemon does not start
<restore> && TESTCONTAINERS_RYUK_DISABLED=true <test-command>
```

| Signature | Missing step |
|---|---|
| `command not found` | the SDK install |
| DB tests fail on the container socket | the daemon |
| DB tests fail on a missing reaper image | `TESTCONTAINERS_RYUK_DISABLED=true` |

The two container cases fail the **same number** of tests — read the exception, not the count.

### Egress denials, and the route around each

Diagnose any denial through the proxy's own status endpoint, which names the blocked host. Do not
retry a denied host.

| Host class | Symptom | Route |
|---|---|---|
| A vendor's SDK download host | `CONNECT tunnel failed, response 403` | the distro's own package repository usually ships it |
| A public container registry | pull returns `Forbidden` | disable the reaper; an allowed registry still serves the database image |
| The project's own deployed hosts | `curl` 000, connection rejected | run locally against a preview build; never claim a deployed check from here |

### Running a browser walk in the sandbox

| Symptom | Fix |
|---|---|
| the CLI demands a newer runtime than the image ships | download the current LTS tarball and prepend its `bin/` to `PATH` |
| the browser binary is missing and downloads are disabled | do not install; point the runner at the preinstalled browser path the config already reads |
