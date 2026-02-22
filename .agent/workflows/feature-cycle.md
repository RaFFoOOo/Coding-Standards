---
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. **Open PR Check**: Run `gh pr list`. If there are any open, unmerged PRs, **STOP and warn the user** before starting a new feature.
2. Read the Feature tasks from the project `PLAN.md`.
3. Mark the Feature and its first task as `[/]` in `PLAN.md`.
4. Checkout a new feature branch: `git checkout -b feature/[name]`
5. Read relevant skills: `.agent/skills/sprint-manager/SKILL.md`, `.agent/skills/quality-assurance/SKILL.md` (if exists).
6. Read rules: `.agent/rules/stack-angular.md` and `GEMINI.md` (user global rules).

## Implementation Loop (per task)
// turbo-all

5. **Mockup Gate** (UI tasks only): Use `generate_image` to create a visual mockup. Save as artifact. Skip for backend/service tasks.
6. Implement the code changes following all rules.
7. Mark the task as `[x]` in `PLAN.md`.

## Post-Feature Verification
8. Run build: `npx ng build --configuration development`
9. Check build output for errors and warnings. Fix any issues.
10. If build passes, stage changes: `git add -A` from the project root.
11. Then commit: `git commit -m "feat(feature-name): description"` from the project root.
12. Push branch to remote: `git push -u origin feature/[name]`
13. Create a Pull Request (PR) for the feature.
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
        - If `gh` is unavailable or authentication fails, use the GitHub REST API:
        ```bash
        curl -X POST \
          -H "Authorization: token YOUR_GITHUB_PAT" \
          -H "Accept: application/vnd.github.v3+json" \
          https://api.github.com/repos/RaFFoOOo/Coding-Standards/pulls \
          -d '{
            "title": "feat(scope): your title",
            "body": "Your detailed description following requirements",
            "head": "feature/your-branch-name",
            "base": "main"
          }'
        ```

## Documentation / Recursive Improvement
15. Update `task.md` artifact: mark the Feature as `[x]`.
16. **Recursive Update:** Reflect on the implementations, lessons learned, and hurdles overcome. Update the relevant stack rules, global rules, skills, or workflows to incorporate this new knowledge. This makes our standards evolve recursively.
17. **Documentation Update:** Explicitly check if `README.md` needs to be updated (e.g., due to new files, scope changes, or new parameters/secrets).
18. **Cleanup:** Run a terminal command to delete any temporary files created during the cycle (e.g., `rm -f /tmp/gh_pr_*.txt /tmp/git_*.txt`).

## Deploy (Automated)
19. Inform the user: **"Wait for CI checks to pass on the PR. Upon merging to `main`, the automated CD pipeline will deploy the application."**

## Repeat
20. Move to the next Feature and start from step 1.

