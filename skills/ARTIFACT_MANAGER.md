# SKILL: ARTIFACT_MANAGER

## Description
This skill governs the creation and maintenance of the Project Artifacts. The Agent must maintain a "Living Documentation" state.

## The PLAN.md Standard
The `PLAN.md` file is the source of truth. It must strictly follow this structure:

### 1. Current Sprint Context
- **Goal:** [One sentence summary]
- **Status:** [Planning / In Progress / Review / Done]

### 2. Feature Specification
#### Feature: [Name]
- **User Story:** [As a... I want to... So that...]
- **Acceptance Criteria:**
  - [ ] Criteria 1
  - [ ] Criteria 2

### 3. Technical Implementation Plan
*Must be approved before code generation starts.*
- **Backend Changes:**
  - [ ] `Class.method()`: Description of logic.
- **Frontend Changes:**
  - [ ] `Component`: Description of behavior/config.
- **Risks/Notes:** [Any architectural concerns]

### 4. Task Progress
- [ ] Task 1
- [x] Task 2 (Completed)

## Trigger
Whenever requirements change or a task is completed, you MUST update `PLAN.md` immediately.