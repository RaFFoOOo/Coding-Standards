# Coding Standards Template

This repository serves as the master template and "brain" for all subsequent projects. It contains strictly enforced configurations, global rules, agent skills, and Continuous Integration/Continuous Deployment (CI/CD) pipelines designed to maximize code quality, maintainability, and efficiency.

## 🧠 The Agent Concept & Mission
The core operational dynamic is defined in our internal ruleset (`AGENTS.md`):
- **Role:** The **User runs as the Tech Lead**. The **Agent runs as the Lead Assistant & Advisor**.
- **Mission:** Write only high-quality work, zero redundancy, with strict architectural push-back against sub-optimal solutions.
- **Primary Agent:** [Claude Code](https://claude.ai/code) — the active coding agent for this repository.
- **Recursive Evolution:** The Agent autonomously updates its own rules, workflows, and pipelines at the end of every feature cycle. This makes the standards evolve recursively.

## 📂 Repository Map
The most important configurations live in directories intended for the AI Agent:

| Path | Purpose |
| ---- | ------- |
| `AGENTS.md` | **Global Rules.** The absolute baseline rules for architecture, security, and agent behavior. Cross-agent standard (Claude Code, Gemini, etc.). |
| `CLAUDE.md` | **Claude Code Entry Point.** Imports `AGENTS.md` and provides Claude Code-specific configuration: skills index, plan mode guidance, and remote execution notes. |
| `.agents/rules/` | **Stack & Agent Rules.** Stack-specific constraints (e.g., `stack-angular.md`) and agent-level workarounds. The canonical cross-agent source. |
| `.agents/skills/` | **Specialized Capabilities.** Detailed instructions for the agent to perform complex reviews (e.g., `QUALITY_ASSURANCE`, `SPRINT_MANAGER`). |
| `.agents/workflows/` | **Standard Operating Procedures.** Explicit step-by-step procedures the agent must follow (e.g., `feature-cycle.md` or `pr-resolution.md`). The `sync-template.md` workflow is designed to be **copied to new projects** to pull standards updates dynamically. |
| `.claude/skills/` | **Claude Code Shims.** Thin wrapper `SKILL.md` files enabling `/slash-command` invocation of all skills and workflows within Claude Code. Delegates to `.agents/` source files. **Not synced to target projects.** |
| `.github/workflows/` | **CI/CD Pipelines.** Automated build, test, and deployment definitions using GitHub Actions. |

## 🤖 Agent Compatibility & Deployment Model

This repository is **agent-agnostic** by design. The `.agents/` directory and `AGENTS.md` use the open cross-agent standard, readable by any AI coding assistant.

### Working in this Repository (Claude Code)
Claude Code loads `CLAUDE.md` at session start, which imports `AGENTS.md` and indexes all available skills. Skills and workflows are invocable via `/slash-commands` (handled by `.claude/skills/` shims that delegate to `.agents/`).

### Deploying Standards to a New Project
Use the `/sync-template` workflow. It supports both Push (template → project) and Pull (project ← template) directions, and performs **agent-aware transformation**:

| Target Agent | Entry Point | Rules Path | Skills Path | Tools |
|---|---|---|---|---|
| **Claude Code** | `CLAUDE.md` generated | `.claude/rules/` | `.claude/skills/` | Antigravity tools replaced with CC equivalents |
| **Gemini / Generic** | `AGENTS.md` (existing) | `.agents/rules/` | `.agents/skills/` | No transformation |

The `.claude/` directory in this template repo is intentionally excluded from syncing (see `.agents/sync-state.json`).

## 🚀 CI/CD Pipelines Overview
This repository uses a **"build once, deploy multiple"** methodology using GitHub Shared Workflows. All pipelines are YAML-based and deeply parameterized so they remain portable across different projects.

### Active Pipelines
1. **CI - Angular Build Validations (`ci-angular.yml`)**
   - **Trigger:** Push to `feature/**` branches, or Pull Requests against `main`.
   - **Purpose:** Compiles the application and asserts baseline integrity before a merge is allowed. It halts bad code at the PR boundary.
2. **CD - Deploy Angular to Azure Storage (`cd-angular-azure-storage.yml`)**
   - **Trigger:** Manual execution (`workflow_dispatch`) from any branch (typically `main` or `feature/**`).
   - **Target Environment:** `production`
   - **Purpose:** Downloads the verified build artifacts from the unified build step and deploys them to an Azure Blob Storage Static Website.
3. **CD - Deploy to Azure Static Web Apps (`cd-angular-azure-static-web-apps.yml`)**
   - **Trigger:** Manual execution (`workflow_dispatch`).
   - **Target Environment:** `production`
   - **Purpose:** Downloads artifacts and deploys them to native Azure Static Web Apps securely.

### 🔑 Required GitHub Secrets and Variables
Because the pipelines are designed to be environment-agnostic, **all secrets and dynamic configurations must be stored in GitHub Repository/Environment settings**, never hardcoded.

#### GitHub Environments
Ensure you have created the following **Environments** in your GitHub repository settings:
- `production`
- `development`

#### Secrets and Variables Map
| Name | Type | Level | Default | Required For | Description |
| ---- | ---- | ----- | ------- | ------------ | ----------- |
| `DISABLE_PIPELINES_FOR_TEMPLATE` | Variable | Repository | — | All pipelines (`ci/cd`) | If set to `true`, completely disables the GitHub Actions. Used by the source template repository to prevent unnecessary billing while remaining fully active for any project it is copied to. |
| `NODE_VERSION` | Variable | Repository | `24` | All pipelines (`ci/cd`) | The Node.js version to use for the build (e.g., `24`). |
| `ANGULAR_WORKING_DIRECTORY` | Variable | Repository | `.` | All pipelines (`ci/cd`) | The directory where the Angular app lives (e.g. `.` or `frontend`). |
| `CI_DEFAULT_TENANT_ID` | Variable | Environment | — | `shared-build-angular.yml` | The baseline Tenant UUID payload mapped natively into frontend environments at build-time. |
| `CI_ENABLE_TENANT_SELECTOR` | Variable | Environment | `false` | `shared-build-angular.yml` | Feature-flag enabling multi-tenant UI switching in frontend configurations natively. |
| `CD_AZURE_STA_BASE_URL` | Variable | Environment | — | `cd-angular-azure-storage.yml` | The root blob endpoint URI for the target Azure Storage Account. |
| `CD_AZURE_STA_BASE_PATH` | Variable | Environment | `$web` | `cd-angular-azure-storage.yml` | The static web container target to route the frontend deployment blocks. |
| `CD_AZURE_STA_SAS_TOKEN` | Secret | Environment | — | `cd-angular-azure-storage.yml` | The SAS token mapped specifically with write/delete constraints to deploy into the STA container. |
| `CD_AZURE_SWA_DEPLOYMENT_TOKEN` | Secret | Environment | — | `cd-angular-azure-static-web-apps.yml` | The native Azure Static Web Apps deployment API token. |

## 🔄 Updating this Documentation
As part of the `feature-cycle.md` workflow, the Agent is mandated to keep this `README.md` updated. If you add a new pipeline, a new secret, or a major new rule category, this file will be updated synchronously to reflect the new state of our templates.
