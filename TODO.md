# Project Backlog & Notes (TODO)

This file contains tasks, ideas, and architectural improvements that are **not processable in the current sprint**. It serves as the project's backlog and scratchpad for the team.

---

## 📌 Backlog / To Do
*Items to be evaluated for future sprints. When starting a new `PLAN.md`, the Agent must review this list and move processable items into the active sprint plan.*

- [ ] Configure Playwright MCP server (`.mcp.json`) to enable native browser testing via the `/browser-test` skill in Claude Code projects.
- [ ] Evaluate adding a `hooks` section to `.claude/settings.json` in the sync-template output for Claude Code targets (e.g., PostToolUse linting hook on Write/Edit).
- [ ] Consider adding a `Copilot` (GitHub Copilot) transformation path to `sync-template` once its agent file conventions stabilize.
- [ ] **Root-cause the sync re-leak (high value):** Back-port the `templateSanitization` pattern into the *source* project's `.claude/sync-state.json` so reverse-transform syncs strip project-specific identifiers (sprint numbers, project-only service/table names like `IOrderService`/`TenantUserRole`, dated `DECISIONS.md` links) automatically. PR #20 had to clean these by hand — without the source-side pattern, every future sync re-introduces them.
- [ ] **Repo-wide agnostic sweep:** Audit the remaining synced files (`.agents/workflows/**`, `.agents/skills/**`, `.agents/sync-state.json`) for the same direct-project-reference pattern the PR #20 reviewer flagged in the stack rules, and genericize.

## 📝 Ongoing Notes
*Architectural notes or reminders for the agent/user.*

- Running on Claude Code. `CLAUDE.md` + `.claude/skills/` shims provide native Claude Code integration. `.agents/` remains the cross-agent source of truth and is never modified for agent-specific concerns.
- When syncing standards to a new project, use `/sync-template` and select the target agent. Claude Code targets receive a full `.claude/` structure with `CLAUDE.md`, path-transformed skills, and Antigravity tool substitutions applied automatically.
