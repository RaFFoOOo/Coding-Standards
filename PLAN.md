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

### 5. PR #20 Review Refinements
Reviewer theme: this is a cross-agent **source of truth** — use generic examples, never direct references to a specific project's implementation (no sprint numbers, no project-only service names/tables, no `DECISIONS.md` hard links).
- [x] `stack-angular.md` §3.7 — replace `IOrderService`/`Order` server-state example with agnostic `IFooService`/`Foo`; genericize the "Why".
- [x] `stack-angular.md` §4 — drop "Sprint 10" reference; state the rule's motivation as plain cause-effect; soften project-specific paths/classes to illustrative examples.
- [x] `stack-dotnet-core.md` §8.1 — rewrite role-based-auth bullet as a generic principle; remove `TenantUserRole`/`ITenantScopeAuthorization`/`FunctionAuthorizationMiddleware` specifics and the `DECISIONS.md` date link.
- [x] `stack-github-actions.md` §1 — drop "Sprint 8.6" and the project-only `ci-preview-swa.yml` filename (line 17); clean the sibling "Sprint 19"/"this repo"/`DECISIONS.md` references in the CodeQL note (line 223).
