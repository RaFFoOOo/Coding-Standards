# Agent Workarounds — portable traps

Every session loads this file. Each entry is a symptom, the check that confirms it and the fix. This
project's own environment (runner, hosts, local walk, egress) is in `project-environment.md`; the
incidents behind each entry are in the project's archive, never here.

## Git and the working tree

- **An open editor tab writes a file back.** A deleted directory reappears, or an edit-then-`git mv`
  commits the pre-edit content while `git status` is clean. After any edit-then-move, read
  `git show HEAD:<path>`; fix forward with a new commit, never amend. After `rm -rf`, ask the user to
  close the tabs and delete again.
- **`.claude/rules` and `.claude/skills` are links into `.agents/`.** On Windows without symlink
  support they check out as one-line text files and nothing loads, silently. Check
  `git config core.symlinks` (true; Windows also needs Developer Mode) and `ls -l .claude/`. Edit the
  `.agents/` path; a tool that writes through a link and replaces it with a directory breaks it.
- **CRLF files without a `.gitattributes`.** With `core.autocrlf=input`, staging an edit to a CRLF
  file converts every line, and a small change reads as hundreds. Compare `git diff --cached -w --stat`
  with the change you meant; stage with `git -c core.autocrlf=false add <paths>`. Never change the
  global config.
- **A release PR carrying the sprint branch's tip merges the draft sprint PR** and, with
  `delete_branch_on_merge`, deletes the branch. Check `git ls-remote origin 'refs/heads/sprint/*'`
  after such a merge; re-cut the branch from `main` and open a new draft PR.
- **A full clone can turn shallow mid-session**, and every path query then answers with the graft
  commit. Re-check `git rev-list --count HEAD` and `ls .git/shallow` immediately before relying on
  history; fix with `git fetch --unshallow` and recompute.
- **Another repository's checkout may be another session's working tree.** Switching its branch, committing in
  it or reinstalling its packages moves the ground under that session (a commit lands on its branch; a checkout
  takes its branch away). Check `git worktree list` and `git branch --show-current` first, and work in your own
  worktree (`git worktree add <dir> -b <branch> origin/main`); serve on a port no one else uses.
- **Stacked task PRs conflict after each squash.** Resolve with the branch's own side
  (`git checkout --ours -- <paths>`, run alone), commit, and confirm `git diff --stat origin/<branch> HEAD`
  is empty before pushing.

## Shell and processes

- **`ps | grep` lies both ways; `pkill -f` / `kill $(pgrep -f …)` kill the calling shell** (exit 144,
  later commands skipped) when the pattern is in its own command line. Use `pgrep -x <name>`, list
  with `ps -eo pid,args`, kill by PID; probe a server by its port.
- **`$?` is the status of the command immediately before.** `bash guard.sh | tail -3` reports `tail`.
  Capture `rc=$?` on the next line, and break one thing on purpose before believing a new harness's
  greens.
- **A broken stdout pipe** (other agent platforms): `echo` works but `git status` hangs. Redirect to a
  file and read it: `nohup bash -c "cmd 2>&1" > /tmp/log.txt &`.
- **A diff-scoped guard does not see an unstaged new file.** Run the guards after `git add`.
- **A file restored by `mv` keeps its old mtime**, so MSBuild skips the rebuild and a mutant stays
  compiled. `touch` it, or restore with `cp`.
- **A self-hosted runner sharing the user's home signs `az` out** after an Azure job. Never run `az`
  while one is active; afterwards ask for `! az login`. A runner in its own VM or home does not.
- **`az monitor app-insights query` reads one hour** unless the CLI gets `--offset <window>` too.
- **`DefaultAzureCredential` under EF hangs 60 s on a network with no metadata endpoint**, then fails
  `TaskCanceledException`. Set `AZURE_TOKEN_CREDENTIALS=AzureCliCredential` for local `dotnet ef`.
- **Skill arguments replace `$0`, `$1`… in the loaded SKILL text**, code blocks included. Run a
  command that uses `$N` from the file on disk, or invoke the skill without arguments.

## Browser automation

- **Concurrent agents share one browser session.** Re-check the tab list before every action, act
  only on your own tab, never dismiss a dialog on another's; serialise if isolation fails a 2-tab check.
- **`resize_window` reports success without reaching the width.** Read `window.innerWidth` after each
  resize and report the width measured, never the one requested.
- **`window.ng` is safe for reads, not writes**: a write can update the DOM without the path a real
  interaction takes. Stage edits through the real UI.
- **`ng serve` keeps serving the last good bundle after a failed rebuild.** Confirm
  `Application bundle generation complete` after your edit before measuring.
- **Playwright:** `locator.isVisible()` does not wait — assert with `expect(…).toBeVisible()`;
  `page.goto` with the default `load` can outlast a test when real images load — use
  `domcontentloaded` plus a readiness assertion; a route stub that answers image requests hides what a
  deployment without credentials shows — render once with them answered `403`.

## AI agents and MCP

- **A chat keeps the tool list it started with.** After a deploy that adds tools, test in a new chat;
  read the server's request log before suspecting the server.

## A macOS development host

| Symptom | Fix |
|---|---|
| `mapfile: command not found`, `globstar: invalid shell option` | `brew install bash` (bash 3.2 ships) |
| `No module named 'yaml'` in a guard | `/usr/bin/python3 -m pip install --user pyyaml` |
| every `dotnet` exits 137 after installing a second SDK | re-sign by copy: `sudo cp dotnet dotnet.new && sudo mv dotnet.new dotnet` |
| the build picks a newer SDK than CI | pin it in `global.json` |
| `func start --csharp` loops on `Permission denied` | omit `--csharp` for the isolated worker |
| `az login` lists no subscription, every tenant asking for MFA | `az login --tenant <tenant>` |
| zsh `no matches found` on a URL | quote every URL (`?` globs) |
| `node --version` disagrees with `nvm alias default` | `nvm use` in each command |
| no `ss`, `free`, `setsid` | `lsof -iTCP:<port> -sTCP:LISTEN`, `vm_stat`, `nohup … &` |
| a test fails only on this host's locale | sweep the culture in the test; never pin `LANG` to make it green |

## Remote sandbox (Claude Code on the web)

- **Never write "not runnable here" before trying.** Install the tool (`apt-cache policy <pkg>`),
  start the service, look for its escape hatch. **A blocked download is not a blocked tool:** try
  every mirror before concluding; diagnose a denial with `curl -sS "$HTTPS_PROXY/__agentproxy/status"`
  and never retry a denied host.
- **.NET from a cold sandbox:** `apt-get install -y dotnet-sdk-10.0` (Ubuntu `noble-updates`; the
  Microsoft CDN is denied); start `dockerd`; `TESTCONTAINERS_RYUK_DISABLED=true` (Docker Hub is
  denied; `mcr.microsoft.com` is not). Read the exception, not the failure count.
- **Node and Playwright:** a too-old Node → prepend a current LTS tarball's `bin/` to `PATH`; with
  `PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`, point `PLAYWRIGHT_CHROMIUM_PATH` at `/opt/pw-browsers/…`
  instead of installing.
