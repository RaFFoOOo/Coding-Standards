# Project Backlog & Notes (TODO)

This file contains tasks, ideas, and architectural improvements that are **not processable in the current sprint**. It serves as the project's backlog and scratchpad for the team.

---

## 📌 Backlog / To Do
*Items to be evaluated for future sprints. When starting a new `PLAN.md`, the Agent must review this list and move processable items into the active sprint plan.*

- [ ] When migrating to Claude Code: add a `CLAUDE.md` symlink pointing to `AGENTS.md` so Claude natively loads global rules.
- [ ] When migrating to Claude Code: verify that the `.agents/` folder (used for rules/skills/workflows) does not conflict with Claude Code's sub-agent system (`~/.claude/agents/`).

## 📝 Ongoing Notes
*Architectural notes or reminders for the agent/user.*

- Upgraded to Antigravity v1.20.6. Global rules are read from `AGENTS.md` and workspace rules from `.agents/`. The Customizations Tab may be broken due to a known ECONNREFUSED bug with the plural `.agents/` folder — we accept this trade-off for cross-agent compliance.
