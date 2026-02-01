# SKILL: SPRINT_MANAGER

## Description
This skill enables the Agent to act as a Technical Team Lead, interpreting high-level Sprint Plans and breaking them down into execution steps.

## Hierarchy Definitions
1.  **Sprint:** A time-boxed iteration containing a set of committed Features.
2.  **Feature:** A distinct functionality (e.g., "User Authentication") that delivers value.
3.  **User Story:** A specific requirement from a user perspective (e.g., "As a user, I want to login...").
4.  **Task:** A technical unit of work (e.g., "Create LoginController", "Design Login Interface").

## Operating Procedure
When the User provides a Sprint Plan or User Story:
1.  **Analyze:** Read the requirements and identify dependencies.
2.  **Breakdown:** Decompose User Stories into technical **Tasks**.
3.  **Validate:** Check if the requested Feature conflicts with existing `ARCHITECTURAL_CONSTITUTION.md` rules.
4.  **Plan:** Update the `PLAN.md` artifact with the new tasks before writing any code.

## Critical Instruction
*Never* start coding a User Story until the **Task List** for that story has been generated and approved in the `PLAN.md`.