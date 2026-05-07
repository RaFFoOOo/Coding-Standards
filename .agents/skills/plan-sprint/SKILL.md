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
0.  **Sprint Branch Creation [MANDATORY for sprint-sized work]:** Before decomposing tasks, determine if this is a sprint (multi-task, >3 files expected) or standalone work:
    - **Sprint:** Create the sprint branch from `main` and immediately open the sprint→main PR:
      ```bash
      git checkout main && git pull origin main
      git checkout -b sprint/<semver>-<kebab-slug>
      git push -u origin sprint/<semver>-<kebab-slug>
      gh pr create --title "feat(sprint/<semver>): <title>" --base main --head sprint/<semver>-<kebab-slug> --body "..."
      ```
      Opening the PR immediately gives the Tech Lead visibility into the cumulative sprint diff at all times. **Do not merge** until all task PRs are squash-merged into the sprint branch and CI is green. Use a **merge commit** (not squash) when merging sprint → `main`.
      All task branches for this sprint will be cut from this sprint branch, not from `main`.
    - **Standalone:** No sprint branch needed — task branches target `main` directly.
1.  **Analyze:** Read the requirements and identify dependencies.
2.  **Breakdown & Estimate:** Decompose User Stories into technical **Tasks**.
    - **Complexity Tags:** Tag each task in `PLAN.md` with an estimation size (`[S]`, `[M]`, `[L]`, `[XL]`).
    - **Priority & Ordering:** Order the tasks in a strict Dependency-First sequence (e.g., Schema -> API -> Service -> UI).
3.  **Visualize (The "Mockup Gate"):**
    - For any UI/Frontend task, you **MUST** create a **text-based wireframe** (markdown layout, component hierarchy, interactions, color tokens). Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`.
    - The wireframe must include specific details about:
        - Layout structure (Grid, Flex, Sidebar, etc.).
        - Color palette defined in the project's Design System.
        - Typography according to project standards.
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
