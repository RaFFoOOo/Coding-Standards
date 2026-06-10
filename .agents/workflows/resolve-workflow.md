---
name: resolve-workflow
description: Diagnose and fix a failing GitHub Actions workflow run, then re-trigger until it passes
---

# Workflow Resolution Loop

> This workflow references gh CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

Execute this workflow when a GitHub Actions run has failed and you want to systematically diagnose, fix, push, and re-trigger until the run completes successfully.

## When to use vs. when NOT to use

**Use it for:** transient CD/CI failures caused by code, config, or scripts in the repo. Each iteration applies a code change, pushes it, and triggers a fresh run.

**Do NOT use it for:**
- Failures the agent cannot fix without the human (missing GitHub secret, Azure RBAC grant, Entra portal step). The skill must pause and request human input — never loop on it.
- Workflows without a `workflow_dispatch` trigger. The skill needs to start a fresh run on the current branch HEAD; `gh run rerun` re-runs the original commit and skips new pushes.
- Production deploy workflows. Re-trigger loops on prod are risky — fix once, push, then let the normal PR/merge flow validate.

## Inputs

- `runId` (optional, positional) — the specific failed run to start from.
- `--max-iterations N` (optional, default `5`) — hard cap on the resolve loop.

If `runId` is omitted, the skill resolves the latest run on the **current branch** for the workflow that was last triggered. If there are multiple workflows on the branch, surface them and ask the user which one to fix.

## § 1. Context Retrieval

1. **Resolve the run.**
   - If `runId` given: `gh run view <runId> --repo <owner/repo> --json databaseId,headBranch,conclusion,status,workflowName,workflowDatabaseId,event,jobs`
   - Otherwise: detect the current branch (`git rev-parse --abbrev-ref HEAD`), then
     `gh run list --branch <branch> --repo <owner/repo> --limit 5 --json databaseId,workflowName,status,conclusion,createdAt,event`
     Pick the most recent run. If conclusion is `success`, exit with "nothing to fix".

2. **Resolve the workflow file path.** Needed to re-trigger with `gh workflow run`.
   `gh api repos/<owner/repo>/actions/runs/<runId> --jq '.path'` → e.g. `.github/workflows/cd-backend-azure-functions.yml`.
   Cache the **branch**, **workflow path**, and **workflow database ID** for use throughout the loop.

3. **Confirm `workflow_dispatch`.** Open the workflow YAML and verify it has `on: workflow_dispatch:`. If not, abort with a clear message — this skill cannot re-trigger that workflow.

4. **Verify branch checkout.** `git branch --show-current` must match the run's `headBranch`. If not, checkout the branch first (warn the user before doing so).

## § 2. Iteration Loop

For each iteration `i` from 1 to `--max-iterations`:

### § 2.1 Extract the failure

5. `gh run view <runId> --repo <owner/repo> --log-failed > /tmp/run-<runId>.log`
   If the file is empty (no failed step), the run is still in progress — `gh run watch <runId>` until terminal.

6. Parse the log for the **first** real error line. Skip the trailing "Process completed with exit code N" and look for:
   - `##[error]` markers
   - SDK exception names (`System.IO.FileNotFoundException`, `ERROR: ...`)
   - Shell exit codes from named steps

7. Identify the **step name** and **command** that failed. Use the step name as the unit of progress (see § 2.5).

### § 2.2 Diagnose

8. Read the failing step from the workflow YAML or composite action. Map the error to a concrete root cause. If the cause is unclear from logs alone:
   - Inspect adjacent steps in the run for missing artifacts/env vars.
   - Inspect repo files referenced by the failing step.
   - Use `gh api repos/<owner/repo>/environments/<env>/variables` to verify GitHub variables are present and non-empty when the failure involves config injection.

### § 2.3 Pause-for-human gate [MANDATORY]

9. If the root cause is **NOT a code/config change in the repo** — e.g. a missing GitHub variable, missing Azure RBAC grant, missing Entra app registration step, expired token — **stop the loop** and output:
   - The exact error and the step that failed
   - A bulleted list of the manual actions the human must take (commands, portal paths)
   - A literal "Re-run this skill once the manual steps are complete: `/resolve-workflow <runId>`"
   Do **not** push speculative fixes. Do not loop.

### § 2.4 Fix and push

10. Apply the minimal code change that addresses the diagnosed root cause. Follow `AGENTS.md §8 — Atomic Commits`: one commit per logical fix.
11. Conventional commit message naming the failing component, e.g. `fix(cd): <one-line summary of the fix>`.
12. Push to the same branch: `git push origin <branch>`.

### § 2.5 Re-trigger and wait

13. Trigger a fresh run on the branch HEAD:
    `gh workflow run <workflow-path> --ref <branch> --repo <owner/repo>`
14. Sleep 5s, then resolve the new run ID:
    `gh run list --branch <branch> --workflow <workflow-path> --repo <owner/repo> --limit 1 --json databaseId,headSha`
    Verify `headSha` matches `git rev-parse HEAD` — guard against picking up an older run.
15. Stream progress: `gh run watch <new-runId> --repo <owner/repo> --exit-status` (exits non-zero on failure).

### § 2.6 Outcome

16. **Success** → exit the loop. Report total iterations, list of fixes applied, link to the green run.
17. **Failure**:
    - Set `runId = <new-runId>` and continue to the next iteration.
    - **No-progress guard:** if the new failing step name + first error line are **identical** to the previous iteration, abort with a "no progress — same error twice in a row" message. The current fix approach is wrong; the human must intervene.
18. **Max iterations reached** → abort with a summary of all attempted fixes and the latest error.

## § 3. Output Format

On termination (success, manual gate, or abort), emit:

- One-line status: `✅ Workflow green after N iterations` / `⏸ Paused — human action required` / `❌ Aborted after N iterations`
- A bulleted list of the fixes applied with commit SHAs
- The final run URL
- If aborted/paused: the exact next action the human must take

## § 4. Safety Rails

- Never push to `main` or any protected branch directly — the skill only operates on feature/task branches that are already checked out.
- Never bypass `git` hooks (`--no-verify`).
- Never use `--force` push (would discard concurrent work).
- Never disable a failing test or guard to "make it green" — that is not a fix, it is sabotage. Diagnose root cause only.
- If a fix would touch >5 files in one iteration, pause and ask the user first — the diagnosis is likely too broad.

## § 5. Examples

**Direct ID:** `/resolve-workflow 26000441649`
**Latest on current branch:** `/resolve-workflow`
**Wider iteration cap:** `/resolve-workflow --max-iterations 10`
