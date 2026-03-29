# PLAN.md

### 1. Current Sprint Context
- **Goal:** Migrate the primary coding agent from Antigravity to Claude Code, making the repository natively usable by Claude Code while keeping `.agents/` as the cross-agent canonical source of truth. Enhance `sync-template` to deploy agent-specific structures to target projects.
- **Status:** Done

### 2. Feature Specification
#### Feature: Claude Code Migration
- **User Story:** As a Tech Lead migrating from Antigravity to Claude Code, I want the Coding-Standards template to be natively loaded by Claude Code (CLAUDE.md, .claude/skills/ shims) and the sync-template workflow to be agent-aware, so that I can use Claude Code as my primary agent while the template remains cross-agent compatible.
- **Acceptance Criteria:**
  - [x] `CLAUDE.md` exists at project root, imports `AGENTS.md`, and lists all available skills/workflows.
  - [x] `.claude/skills/` shims exist for all 8 skills/workflows, enabling `/slash-command` invocation.
  - [x] `sync-template` workflow prompts for target agent and performs path/tool transformation for Claude Code targets.
  - [x] `agent-workarounds.md` has no Antigravity-specific content; includes Claude Code notes.
  - [x] `TODO.md` reflects migration complete.
  - [x] `README.md` updated to reflect Claude Code as primary agent and the new agent-agnostic deployment model.

### 3. Technical Implementation Plan
*Approved.*
- **New Files:**
  - [x] `CLAUDE.md` — Claude Code entry point (imports AGENTS.md + CC-specific guidance)
  - [x] `.claude/skills/*/SKILL.md` (×8) — Thin shims delegating to `.agents/`
- **Modified Files:**
  - [x] `.agents/sync-state.json` — Add `.claude/` to skipList
  - [x] `.agents/workflows/sync-template.md` — Agent detection + transformation logic
  - [x] `.agents/rules/agent-workarounds.md` — Remove Antigravity section, add Claude Code notes
  - [x] `TODO.md` — Mark migration items complete
  - [x] `README.md` — Agent references and repo map updates
- **Risks/Notes:** `.claude/skills/` shims must NOT be synced to target projects (controlled via sync-state.json skipList). Verify shim delegation works correctly in Claude Code session.

### 4. Task Progress
- [x] Archive old PLAN.md → `archive/PLAN_agents-migration.md`
- [x] Create `CLAUDE.md`
- [x] Create `.claude/skills/` shims (×8)
- [x] Update `.agents/sync-state.json` (add `.claude/` skipList)
- [x] Enhance `sync-template.md` with agent-aware deployment logic
- [x] Update `agent-workarounds.md`
- [x] Update `TODO.md`
- [x] Update `README.md`
