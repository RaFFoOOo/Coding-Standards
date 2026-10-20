---
name: ops
description: Deploy through the self-hosted runner, fix a red workflow run until it is green, and resolve PR review comments thread by thread.
---

# ops

Three procedures. `gh` commands assume a local session; in Claude Code use the GitHub MCP tools
(`actions_list`, `get_job_logs`, `actions_run_trigger`, `pull_request_read`,
`add_reply_to_pull_request_comment`, `resolve_review_thread`).

## A. Deploy

**Local session** — the self-hosted runner, zero billed minutes:
```bash
./scripts/deploy/with-self-hosted-runner.sh cd-backend-azure-functions.yml <ref>
./scripts/deploy/with-self-hosted-runner.sh cd-angular-azure-static-web-apps.yml <ref>
./scripts/deploy/ci-runner.sh status | self-hosted | github      # the GLOBAL default for every workflow
```
The first script starts the runner, dispatches with `runner=self-hosted`, waits, and always stops
the runner it started. `self-hosted` as the global mode strands any PR opened while the runner is
offline — say so when asked to flip it. Check no run is queued or in progress before stopping a
runner; never run the local walk stack while a self-hosted job is active (7.7 GB machine).

**Remote session** (Claude Code on the web): none of this is possible — the runner, `az`, `func`,
`swa` and `gh` are absent and Azure is egress-denied. A remote session can dispatch a workflow with
`actions_run_trigger` and read its result; it cannot start the runner, set `CI_RUNNER`, or deploy.

**Preview:** `ci-preview-swa.yml` deploys the branch to the shared `preview` slot; take the URL
from the *Post Preview URL as PR Comment* step, never the bare hostname (a different, stale build).
The slot is shared — redeploy from the branch under test right before walking it, and assert one
string only that build has.

**Production:** `promote-prod.yml`, dispatched from `main` by the Tech Lead with a release tag;
`dry-run` is the default and the only kind an agent runs. Never deploy production from a script. `cd-angular-azure-storage.yml` is legacy, manual only.

## B. A red workflow run

Use for failures whose cause is code, config or a script in the repo. Not for a missing secret, an
RBAC grant or a portal step (pause and list the manual actions), a workflow without
`workflow_dispatch` (it cannot be re-triggered on a new head), or a production deploy.

1. Resolve the run (id given, or the latest on the current branch); if its conclusion is
   `success`, stop. Cache branch, workflow path, run id. Checkout must match the run's branch.
2. Pull the failed job log; find the **first** real error (`##[error]`, an exception name, a
   named step's exit code) — not the trailing "Process completed with exit code N".
3. Diagnose from the workflow YAML or composite action, adjacent steps, referenced repo files.
   **Rule out a failure that is not this branch's**: the same error on the base branch, or a
   service the diff does not touch failing identically on one re-run.
4. If the cause is outside the repo: stop, print the exact error, the manual steps, and
   *"re-run once done"*. Never push a speculative fix.
5. Apply the minimal fix; one conventional commit (`fix(ci): …`); push.
6. Dispatch a fresh run on the branch head; confirm the new run's `headSha` is `git rev-parse HEAD`;
   watch it to a terminal state.
7. Green: report iterations, fixes with SHAs, the run URL. Red: if the failing step and first error
   are identical to the previous iteration, stop (*no progress*); else iterate, at most 5 times.
8. Never push to `main`, never `--no-verify`, never `--force`, never disable or skip a test or a
   guard to get green; a fix touching more than 5 files pauses for the Tech Lead.

## C. PR review comments

1. Identify the PR and its base (sprint branch for a task PR; `main` otherwise).
2. Fetch **both kinds**: issue-level comments *and* inline review threads, plus reviews. An empty
   conversation tab is not evidence there are no comments.
3. A request that conflicts with `AGENTS.md` stops here — put the trade-off to the Tech Lead.
4. Per comment: the change; `verify §1` on the touched files; one atomic commit; a reply **in that
   thread** saying what changed (or why not); resolve the thread. A bot's optional finding gets a
   one-line reply and is resolved; a red-circle finding is never optional.
5. Merge the base into the branch; compile both stacks and `ng lint`; push.
6. Tell the Tech Lead what was integrated; re-request their review after a changes-requested
   review.
