# SKILL: SPRINT_MANAGER

## Description
This skill enables the Agent to act as a Technical Team Lead, interpreting high-level Sprint Plans and breaking them down into execution steps.

## Hierarchy Definitions
1.  **Sprint:** A time-boxed iteration containing a set of committed Features.
2.  **Feature:** A distinct functionality delivering value.
3.  **User Story:** A requirement from a user perspective.
4.  **Task:** A technical unit of work.

## Operating Procedure
When the User provides a Sprint Plan or User Story:
1.  **Analyze:** Read requirements and dependencies.
2.  **Breakdown:** Decompose User Stories into technical **Tasks**.
3.  **Validate:** Check against the **Global Constitution** (in `GEMINI.md`) and **Project Rules** (e.g., `stack-angular.md`).
4.  **Plan:** Update `PLAN.md` with new tasks before writing code.

## Critical Instruction
*Never* start coding a User Story until the **Task List** is approved in `PLAN.md`.