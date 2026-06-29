---
name: plan-sprint
description: Technical team lead skill for sprint decomposition, task estimation, and the Mockup Gate.
---

# SKILL: SPRINT_MANAGER

## Description
This skill enables the Agent to act as a Technical Team Lead, interpreting high-level Sprint Plans and breaking them down into execution steps. It enforces a "Design First" workflow to minimize UI rework.

## Hierarchy Definitions
1.  **Sprint:** A time-boxed iteration containing a set of committed Features.
2.  **Feature:** A distinct functionality (e.g., "User Authentication") that delivers value.
3.  **User Story:** A specific requirement from a user perspective (e.g., "As a user, I want to login...").
4.  **Task:** A technical unit of work (e.g., "Create LoginController", "Design Login Interface").

## Operating Procedure
When the User provides a Sprint Plan or User Story:
0.  **Sprint Branch Creation [MANDATORY for sprint-sized work]:** Determine if this is a sprint (multi-task, >3 files expected) or standalone work (task branch off `main` directly). For a sprint, create the branch and **immediately** open the sprint→main PR so the Tech Lead sees the cumulative diff throughout:
      ```bash
      git checkout main && git pull origin main
      git checkout -b sprint/<semver>-<kebab-slug>
      git push -u origin sprint/<semver>-<kebab-slug>
      gh pr create --title "feat(sprint/<semver>): <title>" --base main --head sprint/<semver>-<kebab-slug> --body "..."
      ```
    All task branches are cut from this sprint branch. Branch naming and merge types (squash task→sprint; merge-commit sprint→main; **don't merge** until all task PRs are in and CI is green) follow **AGENTS.md §8**.
1.  **Analyze:** Read the requirements and identify dependencies.
2.  **Breakdown & Estimate:** Decompose User Stories into technical **Tasks**.
    - **Complexity Tags:** Tag each task in `PLAN.md` with an estimation size (`[S]`, `[M]`, `[L]`, `[XL]`).
    - **Priority & Ordering:** Order the tasks in a strict Dependency-First sequence (e.g., Schema -> API -> Service -> UI).
    - **Shared-Foundation-First [STRICT — complements AGENTS.md §1 "prove-then-extract"]:** When a feature will **recur across surfaces** (e.g. the same inline-edit pattern across several pages) **and there are ≥2 concrete cases**, schedule the **shared foundation as task 1** of the generalizing sprint and express the surface tasks as its **dependents**. The base is the serialization point; once it lands the surface tasks are independent (different files → conflict-free) and parallelizable across separate PRs / sessions / sub-agents. This is *foundation-first **after** proof*, **never abstract-first** — the trigger is two real cases, not a guess (one case → build it concretely; extract on the second).
    - **Detect mis-ordered / mis-scoped tasks:** If the requested task list violates the dependency order (a surface task before its shared base, or work that belongs to a different sprint), **surface it and propose the corrected order** — never execute a confused sequence literally (AGENTS.md §0/§1). Never silently mutate a *locked in-progress* sprint's scope: amend it on the record (a new task + a decision-log entry) instead.
3.  **Visualize (The "Mockup Gate"):**
    - For any UI/Frontend task, you **MUST** create a **text-based wireframe** in markdown describing the layout, component hierarchy, interactions, and color tokens. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`.
    - The prompt for the image verification must include specific details about:
        - Layout structure (Grid, Flex, Sidebar, etc.).
        - Color palette defined in the project's Design System.
        - Typography according to project standards.
    - Save the generated image as an artifact and embed it in `implementation_plan.md`.
4.  **Validate:** Check dependencies against the **Global Constitution** (in `AGENTS.md`) and **Project Rules** (e.g., `stack-angular.md`).
5.  **Plan:** Update the `PLAN.md` artifact with the new tasks only *after* the Visual Mockup is approved.

## Visualization Standards
A valid Mockup must:
- clearly show the **Component Hierarchy** (e.g. clearly distinguishing sections).
- Demonstrate **Responsiveness** logic (e.g. "Mobile View" vs "Desktop View" if critical).
- Be aesthetically aligned with the project's design system.

## Critical Instruction
*Never* start coding a User Story until:
1. The **Visual Mockup** has been presented and **Approved**.
2. The **Task List** for that story has been approved in `PLAN.md`.