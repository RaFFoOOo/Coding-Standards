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
| `AGENTS.md` | **Global Rules.** One line per rule and the check that enforces it. Cross-agent. |
| `CLAUDE.md` | **Claude Code entry point.** Imports `AGENTS.md`; holds the skills index and the placeholder table a project fills in. |
| `.agents/rules/` | **Stack and agent rules.** Path-scoped with a `paths:` list; a rule without one always loads. |
| `.agents/skills/` | **Skills.** `plan`, `build`, `verify`, `close`, `review`, `ops`, `sync-templates`: numbered checklists of at most 8 KB. |
| `.agents/standards-manifest.txt` | **The shared set.** Exactly the files `sync.sh` merges between the hub and a project. |
| `.claude/rules`, `.claude/skills` | **Links** to the two `.agents/` folders: Claude Code reads only under `.claude/`. |
| `scripts/standards/sync.sh` | **The sync.** A three-way merge of the shared set, in either direction. |
| `.github/workflows/` | **CI/CD Pipelines.** Automated build, test, and deployment definitions using GitHub Actions. |

## 🤖 Agent Compatibility & Deployment Model

The standards are **agent-agnostic**: the files live once, in `AGENTS.md` and `.agents/`, which any
agent can read. Claude Code reads rules and skills only under `.claude/`, so `.claude/rules` and
`.claude/skills` are folder links into `.agents/`. On Windows, links need Developer Mode and
`git config core.symlinks true`. Shared files name a project only through placeholders (`{webapp}`,
`{services}`, `{Backend}`, …); each project maps them to its own values in its `CLAUDE.md`.

### Starting a new project
Use **"Use this template"** on GitHub. Then fill in the placeholder table in `CLAUDE.md`, add
`scripts/standards/project-terms.txt` (the words that identify the project), and run the first sync
from the hub to record the hub commit you started from:

```bash
scripts/standards/sync.sh <hub-checkout> <project-checkout>
```

### Keeping projects and the hub in step
The `sync-templates` skill drives `scripts/standards/sync.sh`, in either direction.

- **What it merges:** each shared file, three ways, against the hub commit the project last took.
  Each project records that commit in `.agents/standards-version`.
- **One-sided changes** are taken from the side that made them. **Overlapping edits** are left as
  conflict markers to resolve by hand.
- **Safety:** nothing that names a project reaches the hub. A merge into the hub refuses any line
  matching the project's term list.
- **Out of scope:** the GitHub workflows below are not part of the shared set. They will be shared
  from a dedicated repository once a second project needs them.

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
