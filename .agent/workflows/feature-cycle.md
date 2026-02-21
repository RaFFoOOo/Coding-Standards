---
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. Read the Feature tasks from the project `PLAN.md`.
2. Mark the Feature and its first task as `[/]` in `PLAN.md`.
3. Checkout a new feature branch: `git checkout -b feature/[name]`
4. Read relevant skills: `.agent/skills/sprint-manager/SKILL.md`, `.agent/skills/quality-assurance/SKILL.md` (if exists).
5. Read rules: `.agent/rules/stack-angular.md` and `GEMINI.md` (user global rules).

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
14. Update `task.md` artifact: mark the Feature as `[x]`.
15. **Recursive Update:** Reflect on the implementations, lessons learned, and hurdles overcome. Update the relevant stack rules, global rules, skills, or workflows to incorporate this new knowledge. This makes our standards evolve recursively.

## Deploy (optional)
16. Ask the user: **"Would you like to deploy to Azure?"**
    - If yes, execute the `/deploy-azure` workflow.
    - If no, skip and continue.

## Repeat
17. Move to the next Feature and start from step 1.
