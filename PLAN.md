# PLAN.md

### 1. Current Sprint Context
- **Goal:** Review the project files and fix any discrepancies with the `README.md` mission and internal rules to improve standards recursively.
- **Status:** Planning

### 2. Feature Specification
#### Feature: Repository Maintenance
- **User Story:** As the Technical Lead, I want the agent to review and align all project configuration files, CI/CD pipelines, and internal rules, so that the Coding Standards template remains consistent, up-to-date, and correct.
- **Acceptance Criteria:**
  - [x] `README.md` correctly maps all Secrets and Variables used in the CI/CD pipeline.
  - [x] `.agent/workflows/feature-cycle.md` has sequential numbering.
  - [x] `.agent/workflows/feature-cycle.md` correctly references `PLAN.md` instead of the internal `task.md`.

### 3. Technical Implementation Plan
- **Backend Changes:**
  - [ ] None
- **Frontend Changes:**
  - [ ] None
- **Documentation Changes:**
  - [x] `README.md`: Update "Secrets and Variables Map" table.
  - [x] `.agent/workflows/feature-cycle.md`: Re-number list and fix artifact reference.
- **Risks/Notes:** Ensures templates generated from this repo will have correct secrets context.

### 4. Task Progress
- [x] Task 1: Update `README.md` environment mapping.
- [x] Task 2: Update `.agent/workflows/feature-cycle.md` numbering and references.
