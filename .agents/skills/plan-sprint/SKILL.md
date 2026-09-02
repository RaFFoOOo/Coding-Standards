---
name: plan-sprint
description: Technical team lead skill for sprint decomposition, task estimation, and the Mockup Gate.
---

# SKILL: plan-sprint

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
    - **Shared-Foundation-First [STRICT — complements AGENTS.md §1 "prove-then-extract"]:** When a feature will **recur across surfaces** (e.g. the same inline-edit pattern across catalog / gallery / CMS) **and there are ≥2 concrete cases**, schedule the **shared foundation as task 1** of the generalizing sprint and express the surface tasks as its **dependents**. The base is the serialization point; once it lands the surface tasks are independent (different files → conflict-free) and parallelizable across separate PRs / sessions / sub-agents. This is *foundation-first **after** proof*, **never abstract-first** — the trigger is two real cases, not a guess (one case → build it concretely; extract on the second). Recorded: `DECISIONS.md` 2026-06-13.
    - **Detect mis-ordered / mis-scoped tasks:** If the requested task list violates the dependency order (a surface task before its shared base, or work that belongs to a different sprint), **surface it and propose the corrected order** — never execute a confused sequence literally (AGENTS.md §0/§1). Never silently mutate a *locked in-progress* sprint's scope: amend it on the record (a new task + a `DECISIONS.md` entry) instead.
3.  **Visualize (The "Mockup Gate"):**
    - For any UI/Frontend task, you **MUST** create a **text-based wireframe** in markdown describing the layout, component hierarchy, interactions, and color tokens. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`.
    - **Shared-Surface Inventory [STRICT — run BEFORE drawing, and paste the result into the mockup]:** A wireframe drawn from imagination re-invents primitives the app already ships, and the drawing then *authorises* the re-invention — the gate is where that becomes expensive, because after locking it takes a recorded Tech-Lead decision to undo. So before drawing any surface, **grep for how this app already does each element** and record the answer in the mockup as a table: element → the shared component/class it must use → the command that proves it. See `stack-angular.md §4a` for the mandatory element list and the exact commands.
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
- Carry its **Shared-Surface Inventory** (step 3 above) — a mockup without one is not reviewable,
  because "aligned with the design system" cannot be checked by reading a wireframe.
- Name a shared primitive wherever one exists, rather than drawing the control it renders. Draw
  `<app-action-bar>`, not "a right-aligned Save button": the wireframe describes *what belongs on
  the surface*, and the component decides what it looks like.

### The mockup is subordinate to the shipped standard [STRICT]

**Where a locked wireframe and an existing convention disagree, the convention wins, and the fix is
a `DECISIONS.md` entry — not a faithful implementation of the drawing.** The freeze in `AGENTS.md §1`
protects the sprint from *new ideas* mid-flight; it was never a licence to ship a worse surface than
the app already has.

This is not hypothetical. One sprint's mockup drew an in-card submit button and a half-width mobile field.
Both shipped, both were wrong, and both were defended *from the mockup* until the Tech Lead asked the
question that settles it: **does anything else in the app do this?** The answer took two greps —
9 surfaces use `<app-action-bar>` for a page-level commit (including a customer-facing one), and no
`.form-row` anywhere leaves an unfilled half. Neither fact needed judgement, and neither was
discoverable by re-reading the wireframe. `DECISIONS.md` 2026-08-12.

## Critical Instruction
*Never* start coding a User Story until:
1. The **Visual Mockup** has been presented and **Approved**.
2. The **Task List** for that story has been approved in `PLAN.md`.