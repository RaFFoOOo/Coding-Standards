@AGENTS.md

---

## Claude Code — Working in this Repository

This is the master Coding Standards template. Work here is meta: you are editing the
rules, skills, and workflows that get deployed to real projects via `/sync-template`.

### Rules & Skills Location (this repo)
All rules, skills, and workflows live in `.agents/` (the cross-agent standard):
- Rules: `.agents/rules/`
- Skills: `.agents/skills/`
- Workflows: `.agents/workflows/`

When executing any skill or workflow, read its `SKILL.md` / workflow `.md` directly.

`.agents/` is the **cross-agent source of truth and is never modified for agent-specific
concerns** — `CLAUDE.md` and the `.claude/skills/` shims carry everything Claude Code needs, so a
second agent's conventions never leak into the canonical set.

The backlog is [`backlog/`](backlog/), indexed by [`backlog/README.md`](backlog/README.md);
its lifecycle is the `todo-manager` skill.

### Available Skills
Invoke via slash commands (shims in `.claude/skills/`) or by reading the source file:

| Command | Source File | Purpose |
|---|---|---|
| `/run-qa` | `.agents/skills/run-qa/SKILL.md` | Pre-merge QA verification (mandatory gate) |
| `/plan-sprint` | `.agents/skills/plan-sprint/SKILL.md` | Break sprint into estimated tasks + mockup gate |
| `/manage-artifacts` | `.agents/skills/manage-artifacts/SKILL.md` | Manage PLAN.md structure and artifact lifecycle |
| `/run-feature` | `.agents/workflows/run-feature.md` | Execute a full feature from PLAN.md to merged PR |
| `/resolve-pr` | `.agents/workflows/resolve-pr.md` | Resolve PR review comments |
| `/sync-templates` | `.agents/workflows/sync-templates.md` | Sync standards to/from a target project repo |
| `/test-browser` | `.agents/workflows/test-browser.md` | Plan and execute browser tests |
| `/deploy-azure` | `.agents/workflows/deploy-azure.md` | Build for production and deploy to Azure |
| `/todo-manager` | `.agents/skills/todo-manager/SKILL.md` | Manage the `backlog/` lifecycle (append, mark done, archive, promote to PLAN.md) |
| `/recursive-review` | `.agents/workflows/recursive-review.md` | Periodic honest audit of rules, skills, code, pipeline, and direction |
| `/ux-review` | `.agents/workflows/ux-review.md` | Full-site heuristic UX review, per user role |
| `/run-sprint-unattended` | `.agents/workflows/run-sprint-unattended.md` | Execute already-planned sprint tasks under a scoped merge authorisation |
| `/resolve-workflow` | `.agents/workflows/resolve-workflow.md` | Diagnose and fix a failing GitHub Actions run until it passes |
| `/pause-session` | `.agents/workflows/pause-session.md` | End-of-session checkpoint; writes `__resume_prompt.txt` + persists lessons |
| `/resume-session` | `.agents/workflows/resume-session.md` | Session-start bootstrap; replays the saved resume protocol |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve
the plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Remote Execution
All instructions are version-controlled. Remote/scheduled agents load from this repo.
Never rely on machine-local `~/.claude/` files for project-critical rules.

### Agent-Specific Deployment
When deploying standards to a real project, use `/sync-templates`.
It will ask which agent the target project uses and transform paths, entry points,
and tool references accordingly (Claude Code → `.claude/` + `CLAUDE.md`; Gemini → `.agents/` as-is).

### Stack Rules Reference
Each rule is path-scoped, so only the ones matching the files you touch load.

| Angular / TypeScript | ASP.NET Core / C# | Any stack |
|---|---|---|
| `stack-angular.md` — architecture, state, DI, structure | `stack-dotnet-core.md` — syntax, architecture, testing, async, nullability | `stack-github-actions.md` |
| `stack-shared-ui.md` — shared primitives, controls, form grid | `stack-dotnet-api.md` — endpoints, validation, security | |
| `stack-navigation.md` — routing and placement | `stack-dotnet-data.md` — persistence, resilience, DB auth | |
| `stack-i18n.md` — assets and translation | | |
| `stack-angular-testing.md` — frontend test strategy | | |

All live in `.agents/rules/`.
