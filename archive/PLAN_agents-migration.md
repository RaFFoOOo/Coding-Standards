# PLAN.md

### 1. Current Sprint Context
- **Goal:** Migrate the global rules to the open `AGENTS.md` standard using the `.agents` workspace folder structure.
- **Status:** Planning

### 2. Feature Specification
#### Feature: AGENTS.md Migration (v1.20.6)
- **User Story:** As a developer running Antigravity v1.20.6, I want to use the open `AGENTS.md` standard instead of proprietary `.gemini` files so that the rules are compliant across all major agent platforms.
- **Acceptance Criteria:**
  - [ ] `.gemini/GEMINI.md` is migrated to the root `AGENTS.md`.
  - [ ] Internal references in workflows, README, and skills are updated.

### 3. Technical Implementation Plan
*Must be approved before code generation starts.*
- **Backend Changes:**
  - [ ] Move `.gemini/GEMINI.md` to `AGENTS.md`.
  - [ ] Delete `.gemini/` folder.
- **Documentation Changes:**
  - [ ] Update paths in `README.md`.
  - [ ] Update paths in `.agents/workflows/feature-cycle.md` & `sync-template.md`.
  - [ ] Update paths in SKILL files (`sprint-manager`, `quality-assurance`, `artifact-manager`).
- **Risks/Notes:** Antigravity v1.20.6 might still have unknown regressions. We will test the UI discovery tab.

### 4. Task Progress
- [x] Pre-flight checks and branch creation.
- [x] Execute codebase replacement.
- [x] Run QA pre-scan.
- [x] Browser test / Customizations Tab verification.
- [x] Commit, push, and create PR.
