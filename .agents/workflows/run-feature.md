---
name: run-feature
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

> This workflow references `gh` CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. **Open PR Check**: Run `gh pr list`. If there are any open, unmerged PRs targeting the same base branch, **STOP and warn the user** before starting a new task.
2. **Stale Branch Hygiene [MANDATORY — user confirmation always required]:**
   Run `git fetch --prune origin` then `git branch -vv | grep ": gone]" | awk '{print $1}'` to identify local branches whose upstream has been deleted (the canonical signal that a squash-merged PR's remote branch was auto-removed by GitHub).
   - If the list is empty, log "no stale branches" and continue.
   - If 1+ branches are returned, **STOP and ask the user** before deleting: present the count + the list (truncate to first 20 if longer), then explicitly request confirmation. Never `git branch -d`/`-D` without affirmative user approval, even though the branches are already merged remotely.
   - On approval, batch-delete with `xargs -n 20 git branch -D` (force-delete is safe for the gone-upstream subset because GitHub only deletes the remote after a successful merge; squash-merge changes the commit SHA so plain `-d` would refuse). Branches WITHOUT a `gone` upstream are NEVER touched by this step.
   - **Rationale:** branches accumulate per-task as merged PRs leave stranded locals. Pruning per-task (at run-feature pre-flight, not at sprint-close) keeps the local count under control without a 80+-item sweep at sprint end. Single batch confirmation per task = low friction.
3. **Source → PLAN.md Promotion [MANDATORY]:** If the task was picked up from `TODO.md` (not already in `PLAN.md`), you MUST create a `PLAN.md` first — decompose the item into Acceptance Criteria, Technical Implementation steps, and Task Progress — and present it to the user for approval before any execution. Never execute directly from `TODO.md`.
   Read the Feature tasks from the project `PLAN.md`.
4. Mark the Feature and its first task as `[/]` in `PLAN.md`.
5. **Determine work scope [MANDATORY]:** Inspect the task size before branching:
   - **Sprint task** (part of a multi-task sprint with >3 files expected): use the Sprint/Task hierarchy (see `AGENTS.md §8`). The sprint branch (`sprint/<version>-<slug>`) must already exist; create a task branch from it: `git checkout sprint/<version>-<slug> && git pull && git checkout -b task/sprint-<version>/<id>-<brief>`
   - **Small/standalone work** (hotfix, chore, single-file, doc): sync `main` and branch directly: `git checkout main && git pull origin main && git checkout -b <bugfix|chore|refactor|docs>/<slug>`
6. Read relevant skills: `.agents/skills/plan-sprint/SKILL.md`, `.agents/skills/run-qa/SKILL.md` (if exists).
   **Skill path integrity check:** If any skill referenced in this file was recently renamed, run `grep -rn "<old-name>" .claude/skills/ CLAUDE.md` before proceeding to catch stale references.
7. Read rules: the relevant `.agents/rules/stack-*.md` file for the current tech stack and `AGENTS.md` (user global rules).

## Implementation Loop (per task)

8. **Mockup Gate** (UI tasks only): Use the `/plan-sprint` skill to create a text-based wireframe (markdown layout, component hierarchy, interactions, color tokens). Save as `mockup_[feature].md` artifact. Skip for backend/service tasks.
9. Implement the code changes following all rules.
10. **Quick Pre-QA Scan [MANDATORY]:** Run the `§ 0. Quick Pre-QA Scan` section from `.agents/skills/run-qa/SKILL.md`. If any item fails, fix the issue and re-run the scan until all items pass.
11. **Atomic Commit [MANDATORY]:** Per AGENTS.md §8, commit each task separately (e.g., `git add <files> && git commit -m "feat(scope): complete task part"`).
12. **PLAN.md Live Sync [MANDATORY — do not defer]:** Immediately after the commit in step 11:
    - Mark the task `[x]` in **both** the Acceptance Criteria section and the Task Progress section of `PLAN.md`.
    - Commit the PLAN.md update in the same push (can be a separate commit: `docs(plan): mark task X.Y done`).
    - **Never** leave a completed task as `[ ]` to "batch later" — stale checkboxes erode plan trust.

## Post-Feature Verification
13. Run build: `npx ng build --configuration development`
14. Check build output for errors and warnings. Fix any issues.
15. **Browser Test [OPTIONAL]:** Ask the user if they want to execute structured browser tests. If confirmed, use the `/test-browser` skill (requires Playwright MCP server in `.mcp.json`). If unavailable, perform manual testing and document results. Fix any failures. If skipped, proceed to the next step.
16. **PLAN.md Full Sync Gate [MANDATORY]:** Verify ALL checkboxes for the Feature are marked `[x]` in EVERY section of `PLAN.md` (Acceptance Criteria, Technical Implementation, Task Progress). Hard gate — do NOT proceed until consistent.
17. **QUALITY_ASSURANCE Strict Gate [MANDATORY]:** Do not stage files or create a PR unless `QA_REPORT.md` exists and contains `STATUS: PASS`. If not, run `.agents/skills/run-qa/SKILL.md` immediately.
18. **Merge with base branch [MANDATORY]:** Determine the correct base branch:
    - **Sprint task:** `git fetch origin && git merge origin/sprint/<version>-<slug>`
    - **Small/standalone work:** `git fetch origin && git merge origin/main`
    Resolve conflicts, verify build, then proceed.
19. **PR Review Gate [MANDATORY]:** Output a message to the user asking for review of uncommitted changes. Wait for explicit approval before staging.
20. Push branch to remote: `git push -u origin <branch-name>`
21. Create a Pull Request (PR) targeting the correct base branch:
    - **Sprint task PR** → targets `sprint/<version>-<slug>` (NOT `main`). Use **squash merge** when merging.
    - **Sprint branch final PR** → targets `main` (opened after all tasks are merged). Use **merge commit** when merging. Include links to all task PRs in the description.
    - **Small/standalone work PR** → targets `main` as usual.
    - **Description Requirements**:
        - **Summary**: Brief overview of the implementations and changes.
        - **Lessons Learned**: Any insights or technical hurdles overcome.
        - **Warnings/Pending Actions**: Critical notes for reviewers or future tasks.
        - *(Sprint final PRs only)* **Task PRs**: List all constituent task PR links.
    - **Primary Approach (gh CLI) [RECOMMENDED]**:
        - Sprint task: `gh pr create --title "feat(scope): your title" --base sprint/<version>-<slug> --body "..."`
        - Sprint final / standalone: `gh pr create --title "feat(scope): your title" --base main --body "..."`
    - **Fallback Approach (curl)**:
        - If `gh` is unavailable or authentication fails, use the GitHub REST API (extract the owner/repo dynamically):
        ```bash
        REPO_URL=$(git config --get remote.origin.url)
        OWNER_REPO=$(echo "$REPO_URL" | sed -E 's/.*github\.com[/:](.*)\.git/\1/')
        curl -X POST \
          -H "Authorization: token YOUR_GITHUB_PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/$OWNER_REPO/pulls \
          -d '{
            "title": "feat(scope): your title",
            "body": "Your detailed description following requirements",
            "head": "task/sprint-X.Y/N-slug",
            "base": "sprint/X.Y-slug"
          }'
        ```

## Documentation / Recursive Improvement
22. **PLAN.md Feature Close [MANDATORY]:** Mark the Feature `[x]` in PLAN.md. Then run the **Sprint Archive Check**:
    - List all features in the active sprint PLAN file.
    - If **all** features are `[x]` or `[-]` (superseded/deferred): add `> **STATUS: CLOSED**` to the plan header, move the file to `archive/`, and remove any associated QA reports and mockup files from the root.
    - If any features remain open: leave the file in the root and continue.
    - **Never** leave a closed sprint plan at the project root — it pollutes the active artifact space.
23. **Recursive Update [MANDATORY]:** The final step of the sprint is forced reflection. You MUST generate a `LESSONS_LEARNED.md` artifact detailing exactly 1 new rule, efficiency gain, or workflow refinement discovered during this specific cycle. If absolutely zero structural improvements can be identified, the file must contain exactly "No structural improvements identified." *After* this file is generated, immediately update the relevant template stack rules, global rules, skills, or workflows to incorporate this new knowledge. This forces our standards to evolve recursively without fail.
24. **TODO Audit [MANDATORY — End of Sprint]:** Run the `/todo-manager` skill § 6 audit. Cross-reference every `- [ ]` item in `TODO.md` against the recent git log (`git log --oneline -20`). Mark delivered items `[x]` with a PR reference comment and archive any fully-completed sections. This is not optional — stale TODO entries erode backlog trust.
25. **Documentation Update:** Explicitly check if `README.md` needs to be updated (e.g., due to new files, scope changes, or new parameters/secrets).
26. **Cleanup:** Run a terminal command to delete any temporary files created during the cycle (e.g., `rm -f /tmp/gh_pr_*.txt /tmp/git_*.txt`).

## Dependency Freshness Audit [MANDATORY — End of Sprint]
Execute this section **once per sprint**, after the final Feature's PR has been merged.

26. **Application Dependencies:** Run `npm outdated` (or equivalent) in every project directory. For each outdated package:
    - Check the changelog/release notes for **breaking changes**.
    - If the upgrade is a **major version bump**, flag it as `[BREAKING]` and document the migration steps required.
    - If the upgrade is minor/patch, flag it as `[SAFE]`.
27. **GitHub Actions:** Audit every `.github/workflows/*.yml` file **AND** every `.github/actions/**/*.yml` composite action file. For each action (e.g., `actions/checkout`, `actions/setup-node`, `Azure/static-web-apps-deploy`):
    - Check the action's GitHub releases page for newer major versions.
    - Verify Node.js runtime compatibility (currently Node.js 24 LTS).
    - **[Sprint 12 lesson]** Composite actions in `.github/actions/` are frequently missed — they must be included in the A08 SHA-pinning audit alongside top-level workflow files.
28. **CI/CD Runner Defaults:** Verify the default Node.js version in all workflow files matches the current **LTS** release.
29. **Report & Plan:** If ANY outdated dependencies or actions are found:
    - Generate a `DEPENDENCY_AUDIT.md` artifact listing all findings with their `[SAFE]` / `[BREAKING]` classification.
    - Automatically append upgrade tasks to the **next sprint's** `PLAN.md` (e.g., `Task X.N: Upgrade @angular/core from 21 to 22 [BREAKING]`).
    - If no upgrades are found, log `"All dependencies are current."` in `DEPENDENCY_AUDIT.md`.
30. **Zero-Tolerance Gate:** The sprint CANNOT be formally closed until this audit has been executed and the `DEPENDENCY_AUDIT.md` artifact exists.

## Deploy (Automated)
31. Inform the user: **"Wait for CI checks to pass on the PR. Upon merging to `main`, the automated CD pipeline will deploy the application."**

## Repeat
32. Move to the next Feature and start from step 1.

