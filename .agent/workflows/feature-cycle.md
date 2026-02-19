---
description: Standard workflow for implementing a feature from PLAN.md
---

# Feature Implementation Cycle

Execute each step sequentially for every Feature in the sprint.

## Pre-Flight
1. Read the Feature tasks from `lc-webapp/PLAN.md`.
2. Mark the Feature and its first task as `[/]` in `PLAN.md`.
3. Read relevant skills: `.agent/skills/sprint-manager/SKILL.md`, `.agent/skills/quality_assurance/SKILL.md` (if exists).
4. Read rules: `.agent/rules/stack-angular.md` and `GEMINI.md` (user global rules).

## Implementation Loop (per task)
// turbo-all

5. **Mockup Gate** (UI tasks only): Use `generate_image` to create a visual mockup. Save as artifact. Skip for backend/service tasks.
6. Implement the code changes following all rules.
7. Mark the task as `[x]` in `PLAN.md`.

## Post-Feature Verification
8. Run build: `npx ng build --configuration development` from `lc-webapp/`.
9. Check build output for errors and warnings. Fix any issues.
10. If build passes, stage changes: `git add -A` from the project root.
11. Then commit: `git commit -m "feat(feature-letter): description"` from the project root.

## Documentation
11. Update `task.md` artifact: mark the Feature as `[x]`.
12. If new patterns or best practices were discovered, update `.agent/rules/stack-angular.md` or create new rules/skills.

## Deploy (optional)
13. Ask the user: **"Would you like to deploy to Azure?"**
    - If yes, execute the `/deploy-azure` workflow.
    - If no, skip and continue.

## Repeat
14. Move to the next Feature and start from step 1.
