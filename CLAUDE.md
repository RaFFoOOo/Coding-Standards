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

### Available Skills
Invoke via slash commands (shims in `.claude/skills/`) or by reading the source file:

| Command | Source File | Purpose |
|---|---|---|
| `/quality-assurance` | `.agents/skills/quality-assurance/SKILL.md` | Pre-merge QA verification (mandatory gate) |
| `/sprint-manager` | `.agents/skills/sprint-manager/SKILL.md` | Break sprint into estimated tasks + mockup gate |
| `/artifact-manager` | `.agents/skills/artifact-manager/SKILL.md` | Manage PLAN.md structure and artifact lifecycle |
| `/feature-cycle` | `.agents/workflows/feature-cycle.md` | Execute a full feature from PLAN.md to merged PR |
| `/pr-resolution` | `.agents/workflows/pr-resolution.md` | Resolve PR review comments |
| `/sync-template` | `.agents/workflows/sync-template.md` | Sync standards to/from a target project repo |
| `/browser-test` | `.agents/workflows/browser-test.md` | Plan and execute browser tests |
| `/deploy-azure` | `.agents/workflows/deploy-azure.md` | Build for production and deploy to Azure |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve
the plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Remote Execution
All instructions are version-controlled. Remote/scheduled agents load from this repo.
Never rely on machine-local `~/.claude/` files for project-critical rules.

### Agent-Specific Deployment
When deploying standards to a real project, use `/sync-template`.
It will ask which agent the target project uses and transform paths, entry points,
and tool references accordingly (Claude Code → `.claude/` + `CLAUDE.md`; Gemini → `.agents/` as-is).

### Stack Rules Reference
- Angular/TypeScript projects: `.agents/rules/stack-angular.md`
- ASP.NET Core/C# projects: `.agents/rules/stack-dotnet-core.md`
