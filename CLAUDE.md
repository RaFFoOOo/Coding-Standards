@AGENTS.md

---

## Claude Code — Agent Configuration

This repository is the **standards hub**: the shared `AGENTS.md`, rules and skills that projects merge
with `scripts/standards/sync.sh`. A project made from this template keeps this file and fills in
the two project sections below.

### Layout
- **Rules:** `.agents/rules/*.md`. A `paths:` list loads a rule only when a matching file is read;
  a rule without one loads in every session.
- **Skills:** `.agents/skills/<name>/SKILL.md`. The frontmatter `name` is the slash command.
- `.claude/rules` and `.claude/skills` are folder links to them, the only places Claude Code looks.
  Edit the `.agents/` path.
- **Shared standards:** `.agents/standards-manifest.txt` lists what `sync-templates` merges.

### Skills Available
| Command | Purpose |
|---|---|
| `/plan` | Open a sprint: branch and draft PR, sized tasks, change-cost pass, Mockup Gate, approval |
| `/build` | Implement one approved task: task branch, atomic commits, PLAN row marked, PR |
| `/verify` | Prove a change: quick scan, console, viewports, a11y, backend, performance, the walk |
| `/close` | Close a sprint: gate, backlog sweep, pointer, archive, merge commit |
| `/review` | Monthly: recursive review, UX pass, dependency audit, lessons, scans |
| `/ops` | Deploy, fix a red workflow run, resolve PR comments |
| `/sync-templates` | Merge the shared standards with the hub, three ways |

### Placeholders in the shared rules and skills
The shared files name a project only by placeholder. Read each as its value in this repository, and
substitute it before running a command from a skill. **A project fills in the right-hand column**;
in the hub the values stay empty.

| Placeholder | Here |
|---|---|
| `{webapp}` | the Angular workspace folder and project name |
| `{services}` | the .NET solution folder |
| `{Backend}` | the .NET project and namespace prefix (`{Backend}.Functions`, `{Backend}.DataAccess`) |
| `{prefix}`, `{short}` | the Azure app prefix in resource names; the short code in scripts and storage keys |
| `{app}` | the project name (the SPA app registration is `{app}-spa`) |
| `{dev-rg}` | the dev resource group |
| `{swa-host}`, `{region}`, `{n}` | the Static Web App host name parts |

### Active Sprint
*A project writes its current sprint here.*

### Stack Rules Reference
Each rule is path-scoped, so only the ones matching the files you touch load.

| Angular / TypeScript | ASP.NET Core / C# | Any stack |
|---|---|---|
| `stack-angular.md` — architecture, state, DI, structure | `stack-dotnet-core.md` — syntax, architecture, testing, async, nullability | `stack-github-actions.md` |
| `stack-shared-ui.md` — shared primitives, controls, form grid | `stack-dotnet-api.md` — endpoints, validation, security | |
| `stack-navigation.md` — routing and placement | `stack-dotnet-data.md` — persistence, resilience, DB auth | |
| `stack-i18n.md` — assets and translation | | |
| `stack-angular-testing.md` — frontend test strategy | | |
| `stack-css.md` — styling, tokens, budgets | | |

All live in `.agents/rules/`.
