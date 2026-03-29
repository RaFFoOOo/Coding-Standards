---
name: Feature Cycle
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. **Open PR Check**: Run `gh pr list`. If there are any open, unmerged PRs, **STOP and warn the user** before starting a new feature.
2. Read the Feature tasks from the project `PLAN.md`.
3. Mark the Feature and its first task as `[/]` in `PLAN.md`.
4. **Sync main [MANDATORY]:** Before creating the feature branch, ensure you are on the latest `main`: `git checkout main && git pull origin main`
5. Checkout a new feature branch from the updated main: `git checkout -b feature/[name]`
6. Read relevant skills: `.agents/skills/sprint-manager/SKILL.md`, `.agents/skills/quality-assurance/SKILL.md` (if exists).
7. Read rules: the relevant `.agents/rules/stack-*.md` file for the current tech stack and `AGENTS.md` (user global rules).

## Implementation Loop (per task)
// turbo-all

8. **Mockup Gate** (UI tasks only): Use `generate_image` to create a visual mockup. Save as artifact. Skip for backend/service tasks.
9. Implement the code changes following all rules.
10. **Quick Pre-QA Scan [MANDATORY]:** Run the `§ 0. Quick Pre-QA Scan` section from `.agents/skills/quality-assurance/SKILL.md`. If any item fails, fix the issue and re-run the scan until all items pass.
11. **Atomic Commit [MANDATORY]:** Stage and commit the specific changes related strictly to this task. **You must separate commits for each task** (e.g., `git add <files> && git commit -m "feat(scope): complete task part"`). This creates clean revert options if required.
12. Mark the task as `[x]` in `PLAN.md`.

## Post-Feature Verification
12. Run build: `npx ng build --configuration development`
13. Run build: `npx ng build --configuration development`
14. Check build output for errors and warnings. Fix any issues.
15. **Browser Test [OPTIONAL]:** Ask the user if they want to execute structured browser tests. If confirmed, run the `/browser-test` workflow. Write a test plan based on the feature's Acceptance Criteria, execute it in the browser using the `browser_subagent`, and fix any failures. If skipped, proceed to the next step.
16. **PLAN.md Full Sync Gate [MANDATORY]:** Before staging, verify that ALL checkboxes related to the completed Feature are marked `[x]` in EVERY section of `PLAN.md` (Acceptance Criteria in Section 2, Technical Implementation in Section 3, AND Task Progress in Section 4). This is a hard gate — do NOT proceed to staging until all sections are consistent.
17. **QUALITY_ASSURANCE Strict Gate [MANDATORY]:** You are absolutely forbidden from staging files or creating a Pull Request unless the `QA_REPORT.md` artifact physically exists in your environment and explicitly contains the exact string `STATUS: PASS`. If it does not, run the `.agents/skills/quality-assurance/SKILL.md` immediately.
18. **Merge with origin/main [MANDATORY]:** Before staging, always pull and merge the latest `origin/main` into your feature branch: `git fetch origin && git merge origin/main`. Resolve any conflicts, verify the build still compiles cleanly, and only then proceed. This prevents merge conflicts from surfacing in the PR.
19. **PR Review Gate [MANDATORY]:** Before staging any changes, call `notify_user` asking the user if they want to review the uncommitted code changes in the current branch. DO NOT proceed to staging and committing until the user explicitly approves.
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
24. **Documentation Update:** Explicitly check if `README.md` needs to be updated (e.g., due to new files, scope changes, or new parameters/secrets).
25. **Cleanup:** Run a terminal command to delete any temporary files created during the cycle (e.g., `rm -f /tmp/gh_pr_*.txt /tmp/git_*.txt`).

## Dependency Freshness Audit [MANDATORY — End of Sprint]
Execute this section **once per sprint**, after the final Feature's PR has been merged.

26. **Application Dependencies:** Run `npm outdated` (or equivalent) in every project directory. For each outdated package:
    - Check the changelog/release notes for **breaking changes**.
    - If the upgrade is a **major version bump**, flag it as `[BREAKING]` and document the migration steps required.
    - If the upgrade is minor/patch, flag it as `[SAFE]`.
27. **GitHub Actions:** Audit every `.github/workflows/*.yml` file. For each action (e.g., `actions/checkout`, `actions/setup-node`, `Azure/static-web-apps-deploy`):
    - Check the action's GitHub releases page for newer major versions.
    - Verify Node.js runtime compatibility (currently Node.js 24 LTS).
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

