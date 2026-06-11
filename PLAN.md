# PLAN.md

### 1. Current Context
- **Work:** `chore/claude-target-scaffold` (standalone — 2 small tasks editing `sync-templates.md`; not sprint-sized, no sprint hierarchy).
- **Goal:** Round out the Claude Code target scaffold that `sync-templates` Step 5b emits. Today it generates `.claude/skills/` + `CLAUDE.md` but leaves `.mcp.json` and `.claude/settings.json` as **manual** post-sync checklist items. Promote them to auto-emission.
- **Status:** Planning (awaiting approval to implement).

### 2. Decisions (Tech-Lead approved)
- **#11 hooks:** emit a **commented opt-in template** — `settings.json` with permission defaults + an **inactive** `hooks` block plus a documented PostToolUse-lint example (JSON has no comments, so the live file ships `"hooks": {}` and the example lives in the Step 7 checklist / a `_hooksExample` note). Projects enable what fits their stack; no stack assumption baked in.
- **#12 Copilot transform path:** **deferred** — its agent-file conventions aren't stable enough to build against. Stays in `TODO.md` as written.

### 3. Tasks
- [ ] **T1 `[S]` — Emit `.mcp.json` (Playwright MCP) in Step 5b.** Add `.mcp.json` to Step 5b's "Generate in target" section (same as `CLAUDE.md` is generated), using the existing Step 7 snippet (`mcpServers.playwright` → `npx -y @playwright/mcp@latest`). Downgrade the manual Step 7 `[OPTIONAL] Create .mcp.json` item to a note that it's now auto-emitted (verify/customize only). *(file: `sync-templates.md`)*
- [ ] **T2 `[M]` — Emit `.claude/settings.json` (permissions + opt-in hooks) in Step 5b.** Add `settings.json` generation: sensible permission defaults + inactive `"hooks": {}`, with a documented PostToolUse-lint example in Step 7 so projects can opt in per stack. *(file: `sync-templates.md`; Step 7 checklist)*

### 4. Acceptance Criteria
- [ ] Step 5b lists `.mcp.json` and `.claude/settings.json` among the files it generates for a Claude Code target, with concrete content blocks.
- [ ] Step 7's manual `.mcp.json` item reflects that it's now auto-emitted (no duplicate manual step).
- [ ] `settings.json` template makes no stack assumption; the lint-hook example is clearly opt-in.
- [ ] No existing tagged rule altered; changes confined to `sync-templates.md`.

### 5. Out of scope
- Adding `.mcp.json` to **this** repo (Coding-Standards has no app to browser-test — #10 is about the *emitted target scaffold*, not local).
- #12 Copilot path (deferred to backlog).
