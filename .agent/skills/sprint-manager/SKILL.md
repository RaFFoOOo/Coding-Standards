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
1.  **Analyze:** Read the requirements and identify dependencies.
2.  **Breakdown:** Decompose User Stories into technical **Tasks**.
3.  **Visualize (The "Mockup Gate"):**
    - For any UI/Frontend task, you **MUST** use the `generate_image` tool to create a high-fidelity visual representation of the expected output.
    - The prompt for the image verification must include specific details about:
        - Layout structure (Grid, Flex, Sidebar, etc.).
        - "Cementine" color palette (`#79C1B0`, etc.).
        - Typography (`Montserrat`, Script fonts).
    - Save the generated image as an artifact and embed it in `implementation_plan.md`.
4.  **Validate:** Check dependencies against the **Global Constitution** (in `GEMINI.md`) and **Project Rules** (e.g., `stack-angular.md`).
5.  **Plan:** Update the `PLAN.md` artifact with the new tasks only *after* the Visual Mockup is approved.

## Visualization Standards
A valid Mockup must:
- Be a **PNG/JPG image** generated via `generate_image`.
- clearly show the **Component Hierarchy** (e.g. clearly distinguishing sections).
- Demonstrate **Responsiveness** logic (e.g. "Mobile View" vs "Desktop View" if critical).
- Be aesthetically aligned with the project's design system.

## Critical Instruction
*Never* start coding a User Story until:
1. The **Visual Mockup** has been presented and **Approved**.
2. The **Task List** for that story has been approved in `PLAN.md`.