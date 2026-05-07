---
name: resolve-pr
description: Workflow to check and resolve all PR comments before proceeding with PR approval
---

# PR Resolution Workflow

> This workflow references `gh` CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

Execute this workflow when a Pull Request has received review comments that need to be addressed before it can be merged.

## 1. Context & Comment Retrieval
1. **Identify the PR**: Ensure you are on the correct feature branch or know the PR number. Determine the **base branch** the PR targets:
   - **Sprint task PR** → base is `sprint/<version>-<slug>` (not `main`)
   - **Sprint final PR** or **standalone PR** → base is `main`
   Keep the base branch in mind — all merges, pushes, and conflict resolution must target it.
2. **Fetch Comments**: Run `gh pr view <branch-name-or-pr-number> --comments` to retrieve all active review comments and threads.
3. **Analyze Feedback**: Read through all the comments carefully to understand the reviewer's requests, raised issues, or suggestions.

## 2. Planning the Resolution
4. **Update Task Plan**: Add a new section in `PLAN.md` (e.g., "PR Review Refinements") specifically for addressing the retrieved comments. Break down each comment into an actionable task.
5. **Acknowledge Trade-offs**: If a comment directly conflicts with `AGENTS.md` (e.g., requests to bypass Clean Surface or 200-Line rules), **STOP** and output a message to the user to discuss the architectural violation before implementing.

## 3. Implementation Loop (per comment)

6. Implement the requested code changes following standard rules.
7. **Quick Pre-QA Scan [MANDATORY]**: Run the `§ 0. Quick Pre-QA Scan` section from `.agents/skills/run-qa/SKILL.md` strictly on the modified files to ensure the new changes adhere to repo standards.
8. **Atomic Commit [MANDATORY]**: Per AGENTS.md §8, commit each comment separately (unless two or more are intimately related).
9. **Comment Resolution [MANDATORY]**: Using the GitHub CLI (`gh pr review` or `gh api`), reply directly to the specific PR comment thread with a concise explanation of the resolution. This enables the reviewer to quickly audit all fixes.
10. Mark the corresponding task as `[x]` in `PLAN.md` once thoroughly addressed.

## 4. Validation & Push
11. **Build Verification**: Run the appropriate build command for the stack (e.g., `npx ng build --configuration development` for Angular) to verify there are no compilation errors.
12. **Merge with base branch [MANDATORY]:** Before pushing, sync with the correct base:
    - Sprint task: `git fetch origin && git merge origin/sprint/<version>-<slug>`
    - Standalone/sprint final: `git fetch origin && git merge origin/main`
13. **Push**: Push the updated branch to remote: `git push origin HEAD`.

## 5. Notification & Approval
14. **Inform the User**: Inform the user that the review comments have been integrated and pushed.
15. **UI Resolution**: Ask the user to officially resolve the conversations in the GitHub UI and re-request review or proceed with the PR approval.
