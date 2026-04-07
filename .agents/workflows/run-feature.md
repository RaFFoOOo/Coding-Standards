---
name: run-feature
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

> **Claude Code:** This skill references `gh` CLI commands for GitHub operations. In Claude Code environments with MCP GitHub tools, substitute all `gh` commands with the equivalent MCP tools (e.g., `mcp__github__list_pull_requests` for `gh pr list`, `mcp__github__create_pull_request` for `gh pr create`).

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. **Open PR Check**: Run `gh pr list`. If there are any open, unmerged PRs, **STOP and warn the user** before starting a new feature.
2. **Source → PLAN.md Promotion [MANDATORY]:** If the task was picked up from `TODO.md` (not already in `PLAN.md`), you MUST create a `PLAN.md` first — decompose the item into Acceptance Criteria, Technical Implementation steps, and Task Progress — and present it to the user for approval before any execution. Never execute directly from `TODO.md`.
   Read the Feature tasks from the project `PLAN.md`.
3. Mark the Feature and its first task as `[/]` in `PLAN.md`.
4. **Sync main [MANDATORY]:** Before creating the feature branch, ensure you are on the latest `main`: `git checkout main && git pull origin main`
5. Checkout a new feature branch from the updated main: `git checkout -b feature/[name]`
6. Read relevant skills: `.agents/skills/plan-sprint/SKILL.md`, `.agents/skills/run-qa/SKILL.md` (if exists).
   **Skill path integrity check:** If any skill referenced in this file was recently renamed, run `grep -rn "<old-name>" .agents/skills/ AGENTS.md` before proceeding to catch stale references.
7. Read rules: the relevant `.agents/rules/stack-*.md` file for the current tech stack and `AGENTS.md` (user global rules).

## Implementation Loop (per task)

8. **Mockup Gate** (UI tasks only): Use the `/plan-sprint` skill to create a text-based wireframe (markdown layout, component hierarchy, interactions, color tokens). Save as `mockup_[feature].md` artifact. Skip for backend/service tasks.
9. Implement the code changes following all rules.
10. **Quick Pre-QA Scan [MANDATORY]:** Run the `§ 0. Quick Pre-QA Scan` section from `.agents/skills/run-qa/SKILL.md`. If any item fails, fix the issue and re-run the scan until all items pass.
11. **Atomic Commit [MANDATORY]:** Per AGENTS.md §8, commit each task separately (e.g., `git add <files> && git commit -m "feat(scope): complete task part"`).
12. Mark the task as `[x]` in `PLAN.md`.

## Post-Feature Verification
13. Run build: `npx ng build --configuration development`
14. Check build output for errors and warnings. Fix any issues.
15. **Browser Test [OPTIONAL]:** Ask the user if they want to execute structured browser tests. If confirmed, use the `/test-browser` skill. If unavailable, perform manual testing and document results. Fix any failures. If skipped, proceed to the next step.
16. **PLAN.md Full Sync Gate [MANDATORY]:** Verify ALL checkboxes for the Feature are marked `[x]` in EVERY section of `PLAN.md` (Acceptance Criteria, Technical Implementation, Task Progress). Hard gate — do NOT proceed until consistent.
17. **QUALITY_ASSURANCE Strict Gate [MANDATORY]:** Do not stage files or create a PR unless `QA_REPORT.md` exists and contains `STATUS: PASS`. If not, run `.agents/skills/run-qa/SKILL.md` immediately.
18. **Merge with origin/main [MANDATORY]:** `git fetch origin && git merge origin/main`. Resolve conflicts, verify build, then proceed.
19. **PR Review Gate [MANDATORY]:** Output a message to the user asking for review of uncommitted changes. Wait for explicit approval before staging.
20. Push branch to remote: `git push -u origin feature/[name]`
21. Create a Pull Request (PR) for the feature.
    - **Description Requirements**:
        - **Summary**: Brief overview of the implementations and changes.
        - **Lessons Learned**: Any insights or technical hurdles overcome.
        - **Warnings/Pending Actions**: Critical notes for reviewers or future tasks.
    - **Primary Approach (gh CLI) [RECOMMENDED]**:
        - Use the following command:
        ```bash
        gh pr create --title "feat(scope): your title" --body "Your detailed description following requirements"
        ```
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
            "head": "feature/your-branch-name",
            "base": "main"
          }'
        ```

## Documentation / Recursive Improvement
22. Update `PLAN.md` artifact: mark the Feature as `[x]`.
23. **Recursive Update [MANDATORY]:** The final step of the sprint is forced reflection. You MUST generate a `LESSONS_LEARNED.md` artifact detailing exactly 1 new rule, efficiency gain, or workflow refinement discovered during this specific cycle. If absolutely zero structural improvements can be identified, the file must contain exactly "No structural improvements identified." *After* this file is generated, immediately update the relevant template stack rules, global rules, skills, or workflows to incorporate this new knowledge. This forces our standards to evolve recursively without fail.
24. **TODO Audit [MANDATORY — End of Sprint]:** Run the `/todo-manager` skill § 6 audit. Cross-reference every `- [ ]` item in `TODO.md` against the recent git log (`git log --oneline -20`). Mark delivered items `[x]` with a PR reference comment and archive any fully-completed sections. This is not optional — stale TODO entries erode backlog trust.
25. **Documentation Update:** Explicitly check if `README.md` needs to be updated (e.g., due to new files, scope changes, or new parameters/secrets).
26. **Cleanup:** Run a terminal command to delete any temporary files created during the cycle (e.g., `rm -f /tmp/gh_pr_*.txt /tmp/git_*.txt`).

## Dependency Freshness Audit [MANDATORY — End of Sprint]
Execute this section **once per sprint**, after the final Feature's PR has been merged.

27. **Application Dependencies:** Run `npm outdated` (or equivalent) in every project directory. For each outdated package:
    - Check the changelog/release notes for **breaking changes**.
    - If the upgrade is a **major version bump**, flag it as `[BREAKING]` and document the migration steps required.
    - If the upgrade is minor/patch, flag it as `[SAFE]`.
28. **GitHub Actions:** Audit every `.github/workflows/*.yml` file. For each action (e.g., `actions/checkout`, `actions/setup-node`, `Azure/static-web-apps-deploy`):
    - Check the action's GitHub releases page for newer major versions.
    - Verify Node.js runtime compatibility (currently Node.js 24 LTS).
29. **CI/CD Runner Defaults:** Verify the default Node.js version in all workflow files matches the current **LTS** release.
30. **Report & Plan:** If ANY outdated dependencies or actions are found:
    - Generate a `DEPENDENCY_AUDIT.md` artifact listing all findings with their `[SAFE]` / `[BREAKING]` classification.
    - Automatically append upgrade tasks to the **next sprint's** `PLAN.md` (e.g., `Task X.N: Upgrade @angular/core from 21 to 22 [BREAKING]`).
    - If no upgrades are found, log `"All dependencies are current."` in `DEPENDENCY_AUDIT.md`.
31. **Zero-Tolerance Gate:** The sprint CANNOT be formally closed until this audit has been executed and the `DEPENDENCY_AUDIT.md` artifact exists.

## Deploy (Automated)
32. Inform the user: **"Wait for CI checks to pass on the PR. Upon merging to `main`, the automated CD pipeline will deploy the application."**

## Repeat
33. Move to the next Feature and start from step 1.
