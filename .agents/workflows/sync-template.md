---
name: Sync Template
description: Synchronize template artifacts (AGENTS.md, .agents/, .github/) between the current repository and a remote repository (Push or Pull Model), with agent-aware path and tool transformation for the target project.
---

# Template Synchronization Workflow

This workflow automates the process of pulling or pushing standard configurations, rules, skills, and CI/CD pipelines between the **current** repository and another local repository (e.g., the `Coding-Standards` template repository). It maintains `.agents/sync-state.json` (or `.claude/sync-state.json` for Claude Code targets) skip lists in the target repository to remember explicit exclusions.

It also handles **agent-aware transformation**: when the target project uses Claude Code, the workflow generates the correct `.claude/` structure, `CLAUDE.md`, and performs content substitutions to replace Antigravity-specific tools with Claude Code equivalents.

## Prerequisites
- This workflow must be executed from **the root directory of the current project repository** (verify with `git rev-parse --show-toplevel`).
- For the very first execution in a new project, this file (`.agents/workflows/sync-template.md`) must be manually copied from the `Coding-Standards` repo into the target project first.

## Execution Sequence

### Step 1 — Direction & Peer Path
- Ask the user: "Do you want to **PULL** templates from another repository into the current one, or **PUSH** templates from the current repository into another?"
- Define the **Target** repository (the repo receiving changes) and **Source** repository (the repo sending changes) based on the direction.
- Ask the user for the absolute path of the peer repository.
- Run `gh pr list` in the **Target** repository. If there are any open, unmerged PRs in the Target repository, **STOP and warn the user**.
- If clear, checkout a new branch in the **Target** repository: `git checkout -b chore/sync-standards`

### Step 1b — Agent Detection
Ask the user:
> "Which coding agent does the **target** project use?
> 1. **Claude Code** — generates `.claude/` structure + `CLAUDE.md`, replaces Antigravity-specific tools
> 2. **Gemini / Generic** — copies `.agents/` as-is (existing behavior, no transformation)
> 3. **Other** — specify the agent name; treat as Generic unless a known transformation exists"

Store the selection as `TARGET_AGENT`.

### Step 2 — Identify Source & Target
- Verify both Source and Target absolute paths contain the `.agents/` directory.
- If `TARGET_AGENT = Claude Code`, also note that the target will receive a `.claude/` directory (it does not need to already have one).

### Step 3 — Load Local State
- If `TARGET_AGENT = Claude Code`:
  - Look for `<Target_Repo>/.claude/sync-state.json`.
- Otherwise (Gemini / Generic):
  - Look for `<Target_Repo>/.agents/sync-state.json`.
- If it exists, read the `skipList` array. Files matching these paths must be completely ignored during the diff/sync phase.

### Step 4 — Diff & Plan Review
- Determine the effective source file set based on `TARGET_AGENT`:
  - **Claude Code**: Source files are `AGENTS.md`, `.agents/rules/`, `.agents/skills/`, `.agents/workflows/`, `.agents/sync-state.json`, `.github/`
  - **Gemini / Generic**: Source files are `AGENTS.md`, `.agents/`, `.github/`
- For each source file, determine its **target path** (see Step 5b for Claude Code mapping).
- Filter out any files matching the `skipList`.
- Present a categorization to the user:
  - `[ADD]`: File missing in Target repo.
  - `[MODIFY]`: Target file differs from the Source.
  - `[SKIP]`: Skipped due to `sync-state.json`.
- Ask the user: "Do you approve this synchronization plan? Respond 'yes' to proceed, or list specific files to add to the `[SKIP]` list permanently."
  - If new skips provided: update internal list, recalculate, repeat review.

### Step 5 — Execution

#### Step 5a — Gemini / Generic Target
For all `[ADD]` and `[MODIFY]` files, copy them from the *Source* repository into the exact corresponding relative path in the *Target* repository. Use `mkdir -p` where directories are missing.

Write the final, approved array of skipped relative paths to `<Target_Repo>/.agents/sync-state.json`.

#### Step 5b — Claude Code Target

**Path Mapping (Source → Target):**

| Source Path | Target Path |
|---|---|
| `AGENTS.md` | `AGENTS.md` (copy as-is) |
| `.agents/rules/*.md` | `.claude/rules/*.md` |
| `.agents/skills/*/SKILL.md` | `.claude/skills/*/SKILL.md` |
| `.agents/workflows/X.md` | `.claude/skills/X/SKILL.md` |
| `.agents/sync-state.json` | `.claude/sync-state.json` |
| `.github/` | `.github/` (copy as-is) |

**Content Substitutions** (apply to every copied `.md` file going into `.claude/`):

| Find | Replace |
|---|---|
| `.agents/skills/` | `.claude/skills/` |
| `.agents/rules/` | `.claude/rules/` |
| `.agents/workflows/` | `.claude/skills/` |
| `generate_image` tool calls | Text wireframe instruction: *"Create a markdown wireframe describing the layout, component hierarchy, interactions, and color tokens for this UI task. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`."* |
| `notify_user` tool calls | *"Output a message to the user asking for explicit approval. Wait for the user's response before proceeding."* |
| `browser_subagent` tool calls | *"Use the `/browser-test` skill. Note: requires the Playwright MCP server configured in `.mcp.json` (`@playwright/mcp`). If not available, perform browser testing manually and document results."* |
| `// turbo-all` | *(remove the line entirely)* |

**Workflow-to-Skill Frontmatter Injection** (for each `.agents/workflows/X.md`):
- If the workflow file already has YAML frontmatter: replace the `name` field with the filename stem `X` (kebab-case) and keep the `description`.
- If no frontmatter exists: inject:
  ```yaml
  ---
  name: X
  description: [Extract the first sentence of the workflow's Description/Purpose section]
  ---
  ```

**Generate `CLAUDE.md` in target** (this file is always generated, never a raw copy):
```markdown
@AGENTS.md

---

## Claude Code — Agent Configuration

### Skills Available
| Command | Purpose |
|---|---|
| `/quality-assurance` | Pre-merge QA verification (mandatory gate) |
| `/sprint-manager` | Break sprint into estimated tasks + mockup gate |
| `/artifact-manager` | Manage PLAN.md structure and artifact lifecycle |
| `/feature-cycle` | Execute a full feature from PLAN.md to merged PR |
| `/pr-resolution` | Resolve PR review comments |
| `/sync-template` | Sync standards to/from a target project repo |
| `/browser-test` | Plan and execute browser tests |
| `/deploy-azure` | Build for production and deploy to Azure |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve the
plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Stack Rules
- Angular/TypeScript projects: `.claude/rules/stack-angular.md`
- ASP.NET Core/C# projects: `.claude/rules/stack-dotnet-core.md`

### Remote Execution
All rules and skills are version-controlled in `.claude/` and CLAUDE.md.
Remote/scheduled agents load context directly from this repository.
```

Write the final skipList to `<Target_Repo>/.claude/sync-state.json`.

### Step 5c — Old Agent Configuration Cleanup

Before staging, remove the **previous** agent's configuration from the target to ensure only **one** agent configuration is active at a time.

**If `TARGET_AGENT = Claude Code`** (new config is `.claude/`):
- Check if `.agents/` exists in the target repo.
- If it does, count its files and present to the user:
  > "The following old Gemini/Generic configuration will be removed from `<Target>`:
  > - `.agents/rules/` (N files)
  > - `.agents/skills/` (N files)
  > - `.agents/workflows/` (N files)
  > - `.agents/sync-state.json`
  >
  > Proceed with cleanup? (yes/no)"
- On approval: `rm -rf <Target_Repo>/.agents/`
- **`AGENTS.md` is always kept** — it is the cross-agent global standard, not agent-specific.
- If `.agents/` is not found: skip silently.

**If `TARGET_AGENT = Gemini / Generic`** (new config is `.agents/`):
- Check if `.claude/` or `CLAUDE.md` exist in the target repo.
- If they do, present to the user for approval, then:
  - `rm -rf <Target_Repo>/.claude/`
  - `rm -f <Target_Repo>/CLAUDE.md`
- If neither is found: skip silently.

Proceed to Step 6.

### Step 6 — Finalization
- In the *Target* repository, stage all added and modified files (including the sync-state file).
- Commit with message:
  - Gemini / Generic: `chore(standards): sync template updates`
  - Claude Code: `chore(standards): sync template updates (claude-code)`
- Push the branch and instruct the user to open a Pull Request in the *Target* repository to merge the updated standards.

### Step 7 — Post-Sync Configuration Checklist

After the PR is merged in the target project, present the user with the following checklist. Items marked **[REQUIRED]** must be completed before CI/CD is functional. Items marked **[OPTIONAL]** enable additional capabilities.

---

**✅ Post-Sync Setup Checklist**

**[REQUIRED] GitHub Repository Settings**
- [ ] In the target repository, go to **Settings → Environments** and create two environments: `production` and `development`.
- [ ] Set the following **Repository Variables** (`Settings → Secrets and variables → Actions → Variables`):
  - `NODE_VERSION` — Node.js LTS version (e.g., `24`)
  - `ANGULAR_WORKING_DIRECTORY` — Path to the Angular app (e.g., `.` or `frontend`)
  - `DISABLE_PIPELINES_FOR_TEMPLATE` — Set to `false` (or leave unset) to enable CI/CD
- [ ] Set the following **Environment Variables** (under the `production` environment):
  - `CI_DEFAULT_TENANT_ID` — Tenant UUID for the build (if multi-tenant)
  - `CI_ENABLE_TENANT_SELECTOR` — `false` unless multi-tenant UI is needed
  - `CD_AZURE_STA_BASE_URL` — Azure Blob Storage root endpoint (if using Blob Storage CD)
  - `CD_AZURE_STA_BASE_PATH` — Target container (default: `$web`)
- [ ] Set the following **Environment Secrets** (under the `production` environment):
  - `CD_AZURE_STA_SAS_TOKEN` — SAS token for Blob Storage deployment
  - `CD_AZURE_SWA_DEPLOYMENT_TOKEN` — Token for Azure Static Web Apps deployment

**[OPTIONAL] Claude Code — Browser Testing**
- [ ] Create `.mcp.json` in the project root to enable the `/browser-test` skill:
  ```json
  {
    "mcpServers": {
      "playwright": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@playwright/mcp@latest"]
      }
    }
  }
  ```

**[OPTIONAL] Claude Code — Project Customization**
- [ ] Open `CLAUDE.md` in the target project and add any project-specific instructions below the generated section (e.g., custom naming conventions, monorepo paths, environment bootstrap steps).

---

Remind the user: "CI/CD will not trigger until the GitHub Environments and secrets are configured."
