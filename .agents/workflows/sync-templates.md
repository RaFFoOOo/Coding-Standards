---
name: sync-templates
description: Synchronize template artifacts (AGENTS.md, .agents/, .github/) between the current repository and a remote repository (Push or Pull Model), with agent-aware path and tool transformation for the target project.
---

# Template Synchronization Workflow

> This workflow references `gh` CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

This workflow automates the process of pulling or pushing standard configurations, rules, skills, and CI/CD pipelines between the **current** repository and another local repository (e.g., the `Coding-Standards` template repository). It maintains `.agents/sync-state.json` (or `.claude/sync-state.json` for Claude Code targets) skip lists in the target repository to remember explicit exclusions.

It also handles **bidirectional agent-aware transformation**: when the source and target use different agents (Claude Code ↔ Gemini / Generic), the workflow rewrites the directory layout (`.claude/` ↔ `.agents/`), promotes/demotes skills to/from workflows according to the source's `reverseTaxonomy`, and applies content substitutions for agent-specific tool references.

## Prerequisites
- This workflow must be executed from **the root directory of the current project repository** (verify with `git rev-parse --show-toplevel`).
- For the very first execution in a new project, this file (`.agents/workflows/sync-templates.md`) must be manually copied from the `Coding-Standards` repo into the target project first.

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

- **Detect `SOURCE_AGENT` from the filesystem** (do not ask the user — the layout is authoritative):
  - If `<Source>/.claude/` exists → `SOURCE_AGENT = Claude Code`.
  - Else if `<Source>/.agents/` exists → `SOURCE_AGENT = Gemini / Generic`.
  - Else → STOP: the Source is not a sync-managed repository.
- The Target does not need an existing agent configuration; it will be initialized by Step 5.
- The four supported `(SOURCE_AGENT → TARGET_AGENT)` execution paths and their handlers:
  - `Gemini → Gemini`: Step 5a (copy `.agents/` as-is).
  - `Gemini → Claude Code`: Step 5b (forward transformation).
  - `Claude Code → Gemini`: Step 5c (reverse transformation).
  - `Claude Code → Claude Code`: Step 5e (copy the `.claude/` tree with sanitization, no path transform).

### Step 3 — Load Local State
- If `TARGET_AGENT = Claude Code`:
  - Look for `<Target_Repo>/.claude/sync-state.json`.
- Otherwise (Gemini / Generic):
  - Look for `<Target_Repo>/.agents/sync-state.json`.
- If it exists, read the `skipList` array. Files matching these paths must be completely ignored during the diff/sync phase.

### Step 3b — Sync History Verification [MANDATORY]

Before proceeding with the diff, verify that this sync will not overwrite more recent changes by checking the **Sync History Ledger**.

1. **Locate the ledger** in the **Target** repository:
   - Claude Code targets: `<Target_Repo>/.claude/sync-history.json`
   - Gemini / Generic targets: `<Target_Repo>/.agents/sync-history.json`

2. **If the ledger exists**, read the `executions` array and find the **most recent entry** (last element).
   - Compare the `sourceBranch` of the last entry against the **current** Source branch (`git rev-parse --abbrev-ref HEAD` in the Source repo).
   - Compare the `targetBranch` of the last entry against the **current** Target branch being created/used.
   - **Staleness Check:** If the last sync `date` is **more recent** than the latest commit date on the Source's current branch (`git log -1 --format=%aI`), the Source may contain stale content. **STOP** and warn the user:
     > "The target was last synced on `<date>` from `<sourceRepo>@<sourceBranch>`, but the source branch's latest commit is older than that sync. This means the target may already have newer standards. Proceeding could overwrite more recent changes. Continue anyway? (yes/no)"
   - If the user declines, abort the workflow.

3. **If the ledger does not exist**, this is the first tracked sync — proceed normally.

**Sync History Ledger schema** (`sync-history.json`):
```json
{
  "executions": [
    {
      "date": "2026-03-30T14:30:00Z",
      "direction": "PUSH",
      "sourceRepo": "Coding-Standards",
      "sourceBranch": "main",
      "targetRepo": "<your-project>",
      "targetBranch": "chore/sync-standards",
      "agent": "claude-code"
    }
  ]
}
```

### Step 4 — Diff & Plan Review
- Determine the effective source file set based on `SOURCE_AGENT`:
  - **Gemini / Generic source**: `AGENTS.md`, `.agents/rules/`, `.agents/skills/`, `.agents/workflows/`, `.agents/sync-state.json`, `.agents/sync-history.json`, `.github/`.
  - **Claude Code source**: `AGENTS.md`, `.agents/rules/`, `.claude/skills/`, `.claude/sync-state.json`, `.github/`. **Never** include `CLAUDE.md` (agent-specific), `.claude/projects/`, `.claude/settings.local.json`, `.claude/scheduled_tasks.lock`, or `.claude/sync-history.json` — those are local-only or owned by the target's ledger (Step 6a).
- For each source file, determine its **target path** using the matrix in Step 5b (forward) or Step 5c (reverse). When `SOURCE_AGENT = TARGET_AGENT`, the target path is the same relative path with no transformation.
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
| `.agents/rules/*.md` | `.agents/rules/*.md` |
| `.agents/skills/*/SKILL.md` | `.claude/skills/*/SKILL.md` |
| `.agents/workflows/X.md` | `.claude/skills/X/SKILL.md` |
| `.agents/sync-state.json` | `.claude/sync-state.json` |
| `.agents/sync-history.json` | `.claude/sync-history.json` |
| `.github/` | `.github/` (copy as-is) |

**Content Substitutions** (apply to every copied `.md` file going into `.claude/`):

| Find | Replace |
|---|---|
| `.agents/skills/` | `.claude/skills/` |
| `.agents/rules/` | `.agents/rules/` |
| `.agents/workflows/` | `.claude/skills/` |
| `generate_image` tool calls | Text wireframe instruction: *"Create a markdown wireframe describing the layout, component hierarchy, interactions, and color tokens for this UI task. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`."* |
| `notify_user` tool calls | *"Output a message to the user asking for explicit approval. Wait for the user's response before proceeding."* |
| `browser_subagent` tool calls | *"Use the `/test-browser` skill. Note: requires the Playwright MCP server configured in `.mcp.json` (`@playwright/mcp`). If not available, perform browser testing manually and document results."* |
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
| `/run-qa` | Pre-merge QA verification (mandatory gate) |
| `/plan-sprint` | Break sprint into estimated tasks + mockup gate |
| `/manage-artifacts` | Manage PLAN.md structure and artifact lifecycle |
| `/run-feature` | Execute a full feature from PLAN.md to merged PR |
| `/resolve-pr` | Resolve PR review comments |
| `/sync-templates` | Sync standards to/from a target project repo |
| `/test-browser` | Plan and execute browser tests |
| `/deploy-azure` | Build for production and deploy to Azure |
| `/todo-manager` | Manage TODO.md lifecycle (append, mark done, archive, promote to PLAN.md) |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve the
plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Stack Rules
- Angular/TypeScript projects: `.agents/rules/stack-angular.md`
- ASP.NET Core/C# projects: `.agents/rules/stack-dotnet-core.md`

### Remote Execution
All rules and skills are version-controlled in `.claude/` and CLAUDE.md.
Remote/scheduled agents load context directly from this repository.
```

Write the final skipList to `<Target_Repo>/.claude/sync-state.json`.

#### Step 5c — Reverse Transformation (Claude Code Source → Gemini / Generic Target)

When `SOURCE_AGENT = Claude Code` and `TARGET_AGENT = Gemini / Generic`, apply the inverse of Step 5b. Each item under `.claude/skills/<name>/SKILL.md` must be classified as either a **skill** (folder + `SKILL.md` filename) or a **workflow** (flat `<name>.md` file directly under `.agents/workflows/`). Frontmatter is preserved in both cases — modern Antigravity workflows carry the same `name:` / `description:` frontmatter as Claude skills.

**Classification source — `reverseTaxonomy` in `<Source>/.claude/sync-state.json`:**

```json
{
  "skipList": [],
  "reverseTaxonomy": {
    "workflows": ["deploy-azure", "pause-session", "recursive-review", "resolve-pr", "resolve-workflow", "resume-session", "run-feature", "sync-templates", "test-browser"],
    "skills":    ["manage-artifacts", "plan-sprint", "run-qa", "todo-manager"]
  }
}
```

- Every directory under `<Source>/.claude/skills/` MUST appear in exactly one of the two arrays.
- If `reverseTaxonomy` is missing, or a skill is unlisted, **ask the user** for each unclassified skill and persist the answer back into the source `sync-state.json` (separate atomic commit, ahead of the sync).

**Path Mapping (Source → Target):**

| Source Path | Target Path |
|---|---|
| `AGENTS.md` | `AGENTS.md` (copy as-is) |
| `CLAUDE.md` | (NOT pushed — agent-specific generated artifact) |
| `.agents/rules/*.md` | `.agents/rules/*.md` |
| `.claude/skills/<name>/SKILL.md` (classified as `skill`) | `.agents/skills/<name>/SKILL.md` |
| `.claude/skills/<name>/SKILL.md` (classified as `workflow`) | `.agents/workflows/<name>.md` |
| `.claude/sync-state.json` | `.agents/sync-state.json` (drop `reverseTaxonomy`, keep `skipList` only) |
| `.claude/sync-history.json` | (NOT pushed — target maintains its own ledger per Step 6a) |
| `.claude/projects/`, `.claude/settings.local.json`, `.claude/scheduled_tasks.lock` | (NEVER pushed — local-only / user-scoped) |
| `.github/` | `.github/` (copy as-is) |

**Content Substitutions** (apply to every copied `.md` file going into `.agents/`):

| Find | Replace |
|---|---|
| `.agents/rules/` | `.agents/rules/` |
| `.claude/skills/<name>` where `<name>` is in `reverseTaxonomy.skills` | `.agents/skills/<name>` |
| `.claude/skills/<name>` where `<name>` is in `reverseTaxonomy.workflows` | `.agents/workflows/<name>` |
| Claude-Code-specific MCP preamble: `> **Claude Code:** This skill references gh CLI commands ... mcp__github__...` (single line, may include the `mcp__github__list_pull_requests` example) | Generic preamble: `> This workflow references gh CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.` |

**Frontmatter handling:** keep the YAML frontmatter (`name:`, `description:`) intact in both `skill` and `workflow` targets — the existing Antigravity workflows already use the same shape. No injection or stripping required.

Write the final, approved skipList to `<Target_Repo>/.agents/sync-state.json` (strip `reverseTaxonomy` — it belongs to the Claude source only).

#### Step 5e — Claude Code → Claude Code (sibling project sync)

When `SOURCE_AGENT = TARGET_AGENT = Claude Code`, both repos use the `.claude/` layout, so **no path or taxonomy transformation applies** — files map to the identical relative path. But the copy is **not** verbatim:

- **Apply `templateSanitization`** (from `<Source>/.claude/sync-state.json`, in array order — same procedure as Step 5c) to every `.md` file copied into the target's `.claude/`. Without this, the sibling inherits the source project's class names, resource IDs, and `Sprint N lesson` attributions — valid context in the source, noise in the target. If the source has no `templateSanitization`, warn the user that project-specific identifiers will be carried over verbatim and ask whether to proceed.
- **Never copy `CLAUDE.md`** — it is project-specific operational state (active-sprint pointer, sprint history), not a shared standard. This matches the Step 4 exclusion; copying it would clobber the target's own pointer. The target keeps its existing `CLAUDE.md`.
- **Preserve `reverseTaxonomy`** in the copied `sync-state.json` (the target is still a Claude repo and may later reverse-sync). Keep `skipList` as the approved final list.
- Apply the **Claude-Code preamble handling** rules from Step 5c only if the target is destined to also serve non-Claude agents; otherwise leave `> **Claude Code:**` notes intact.

#### Step 5f — Agnostic Review Gate [MANDATORY when the Target is a shared template / agnostic source of truth]

`templateSanitization` (regex find/replace) catches **token-level** leaks (class names, resource IDs, `Sprint N lesson` attributions) but **cannot restructure prose** — a sentence like *"Sprint 21 T7 churned ~15 commits…"* needs rewriting to cause-effect, which no substitution rule can do. So after the substitution pass and **before staging**, grep the synced output for residual project-signal patterns and present every hit to the user for manual genericization:

```bash
grep -rnE "Sprint [0-9]|DECISIONS?\.md|\blc-[a-z]|PR #[0-9]+|le-cementine|provideByMode" \
  <Target>/AGENTS.md <Target>/.agents/
```

- Bare `Sprint N` prose attributions, **dated** `DECISIONS.md` citations (e.g. *"see DECISIONS.md (2026-05-22, …)"*), and project-specific class/file/service names that survive the regex pass MUST be hand-genericized (to cause-effect / generic placeholders) before the sync PR is opened. *(This is the lesson of PRs #20/#30, where exactly these slipped through verbatim and were cleaned by hand after merge.)*
- **Not leaks — skip:** branch-naming examples that illustrate the convention (`sprint/<semver>-<slug>`); factual ledger state (`sync-history.json` `sourceRepo`/`sourceBranch`); `DECISIONS.md` referenced as the standard decision-log **convention** (the Decision Recording rule prescribes every project keep one); and helper names used as explicit generic `e.g.` examples.
- Record the outcome in the sync PR body: list the hand-fixed leaks, or note "agnostic review: clean".

### Step 5d — Old Agent Configuration Cleanup

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

#### Step 6a — Update Sync History Ledger [MANDATORY]
Before staging, append a new execution record to the **Sync History Ledger** in the Target repository.

- **Locate** (or create) the ledger file:
  - Claude Code targets: `<Target_Repo>/.claude/sync-history.json`
  - Gemini / Generic targets: `<Target_Repo>/.agents/sync-history.json`
- **Append** a new entry to the `executions` array:
  ```json
  {
    "date": "<current ISO 8601 UTC timestamp>",
    "direction": "<PUSH or PULL>",
    "sourceRepo": "<Source repository name>",
    "sourceBranch": "<Source branch name at time of sync>",
    "targetRepo": "<Target repository name>",
    "targetBranch": "<Target branch name>",
    "agent": "<TARGET_AGENT lowercase, e.g. claude-code, gemini>"
  }
  ```
- If the file did not exist, create it with the `executions` array containing this single entry.
- Include the ledger file in the staged changes.

#### Step 6b — Commit & Push
- In the *Target* repository, stage all added and modified files (including the sync-state and sync-history files).
- Commit with message:
  - Gemini / Generic: `chore(standards): sync template updates`
  - Claude Code: `chore(standards): sync template updates (claude-code)`
- Push the branch and instruct the user to open a Pull Request in the *Target* repository to merge the updated standards.

#### Step 6c — Self-maintaining template: reconcile `.claude/` shims [MANDATORY when target keeps both `.agents/` and `.claude/`]

The master template repo is a hybrid: `.agents/` is its canonical source **and** it ships its own `.claude/` shims + `CLAUDE.md` so it is natively usable in Claude Code. A Generic/reverse sync (Step 5c) writes only to `.agents/`, so any workflow/skill it **adds or removes** would otherwise leave the local `.claude/` layer stale — the defect that orphaned `recursive-review`, `pause-session`, `resume-session`, and `resolve-workflow` after the #18/#20 syncs.

When the target keeps both trees, after Step 5 reconcile them:
- For every `.agents/skills/<n>/SKILL.md` and `.agents/workflows/<n>.md` with **no** matching `.claude/skills/<n>/SKILL.md`, generate the shim (copy the source `name:`/`description:` frontmatter; body = `Read the full ... instructions from \`.agents/...\` and execute them.`) and add a row to the `CLAUDE.md` skill table.
- For every `.claude/skills/<n>/` shim whose `.agents/` source no longer exists, delete the shim and its `CLAUDE.md` row.
- Quick check (must show no diff): `diff <( { ls .agents/skills; ls .agents/workflows | sed 's/\.md$//'; } | sort -u) <(ls .claude/skills | sort)`.

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
- [ ] Set the following **Environment Variables** (per GitHub environment — `development` / `production`):
  - `ENABLE_TENANT_SELECTOR` — `false` unless multi-tenant UI is needed
  - `ENABLE_LOGIN_FEATURES` — `false` unless authentication UI is needed
  - `CD_AZURE_STA_BASE_URL` — Azure Blob Storage root endpoint (if using Blob Storage CD, production only)
  - `CD_AZURE_STA_BASE_PATH` — Target container (default: `$web`, production only)
- [ ] Set the following **Environment Secrets** (under the `production` environment):
  - `CD_AZURE_STA_SAS_TOKEN` — SAS token for Blob Storage deployment
  - `CD_AZURE_SWA_DEPLOYMENT_TOKEN` — Token for Azure Static Web Apps deployment

**[OPTIONAL] Claude Code — Browser Testing**
- [ ] Create `.mcp.json` in the project root to enable the `/test-browser` skill:
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
