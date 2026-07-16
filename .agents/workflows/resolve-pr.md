---
name: resolve-pr
description: Workflow to check and resolve all PR comments before proceeding with PR approval
---

# PR Resolution Workflow

> This workflow references gh CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

Execute this workflow when a Pull Request has received review comments that need to be addressed before it can be merged.

## 1. Context & Comment Retrieval
1. **Identify the PR**: Ensure you are on the correct feature branch or know the PR number. Determine the **base branch** the PR targets:
   - **Sprint task PR** → base is `sprint/<version>-<slug>` (not `main`)
   - **Sprint final PR** or **standalone PR** → base is `main`
   Keep the base branch in mind — all merges, pushes, and conflict resolution must target it.
2. **Fetch Comments [BOTH KINDS — MANDATORY]**: `gh pr view <branch-name-or-pr-number> --comments` only returns **issue-level** comments (the PR's own conversation tab) — it silently returns nothing for **inline review comments** (attached to a specific file/line as part of a review), even when they exist. Always fetch both:
   - Issue-level: `gh pr view <pr> --comments`
   - Inline review comments: `gh api repos/<owner>/<repo>/pulls/<pr>/comments`
   - Reviews (for review-level summary bodies, may be empty even when inline comments exist): `gh api repos/<owner>/<repo>/pulls/<pr>/reviews`
   An empty result from the first command is **not** evidence that no comments exist — a real review comment can be sitting in the second/third and be missed entirely if only `--comments` is checked. If the Tech Lead references a comment you can't find, re-check the inline endpoint before concluding it doesn't exist.
3. **Analyze Feedback**: Read through all the comments carefully to understand the reviewer's requests, raised issues, or suggestions.

## 2. Planning the Resolution
4. **Update Task Plan**: Add a new section in `PLAN.md` (e.g., "PR Review Refinements") specifically for addressing the retrieved comments. Break down each comment into an actionable task.
5. **Acknowledge Trade-offs**: If a comment directly conflicts with `AGENTS.md` (e.g., requests to bypass Clean Surface or 200-Line rules), **STOP** and output a message to the user to discuss the architectural violation before implementing.

## 3. Implementation Loop (per comment)

6. Implement the requested code changes following standard rules.
7. **Quick Pre-QA Scan [MANDATORY]**: Run the `§ 0. Quick Pre-QA Scan` section from `.agents/skills/run-qa/SKILL.md` strictly on the modified files to ensure the new changes adhere to repo standards.
8. **Atomic Commit [MANDATORY]**: Per AGENTS.md §8, commit each comment separately (unless two or more are intimately related).
9. **Comment Resolution [MANDATORY]**: Reply directly to the specific PR comment thread with a concise explanation of the resolution — this enables the reviewer to quickly audit all fixes.
   - **Inline review comment** (has an `id` from the fetch above): reply in the same thread via
     `gh api repos/<owner>/<repo>/pulls/<pr>/comments -f body="<resolution>" -F in_reply_to=<comment_id>`
     (do not pass `commit_id`/`path` — they're inherited from the parent comment and a stale/foreign SHA will 422).
   - **Issue-level comment / no pre-existing thread** (feedback given verbally or in chat, not as a GitHub comment): post a new summary comment via `gh pr comment <pr> --body "..."` instead — there is no thread to reply into.
10. Mark the corresponding task as `[x]` in `PLAN.md` once thoroughly addressed.

## 4. Validation & Push
9. **Build Verification**: Run `npx ng build --configuration development` (or the equivalent build command for the stack) to verify there are no compilation errors.
10. **Merge with base branch [MANDATORY]:** Before pushing, sync with the correct base:
    - Sprint task: `git fetch origin && git merge origin/sprint/<version>-<slug>`
    - Standalone/sprint final: `git fetch origin && git merge origin/main`
11. **Push**: Push the updated branch to remote: `git push origin HEAD`.

## 5. Notification & Approval
12. **Inform the User**: Inform the user that the review comments have been integrated and pushed.
13. **UI Resolution**: Ask the user to officially resolve the conversations in the GitHub UI and re-request review or proceed with the PR approval.
