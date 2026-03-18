# Coding Standards Template

This repository serves as the master template and "brain" for all subsequent projects. It contains strictly enforced configurations, global rules, agent skills, and Continuous Integration/Continuous Deployment (CI/CD) pipelines designed to maximize code quality, maintainability, and efficiency.

## 🧠 The Agent Concept & Mission
The core operational dynamic is defined in our internal ruleset (`AGENTS.md`):
- **Role:** The **User runs as the Tech Lead**. The **Agent runs as the Lead Assistant & Advisor**.
- **Mission:** Write only high-quality work, zero redundancy, with strict architectural push-back against sub-optimal solutions.
- **Recursive Evolution:** The Agent autonomously updates its own rules, workflows, and pipelines at the end of every feature cycle. This makes the standards evolve recursively.

## 📂 Repository Map
The most important configurations do not live in standard project files, but inside specific directories intended for the AI Agent:

| Path | Purpose |
| ---- | ------- |
| `AGENTS.md` | **Global Rules.** The absolute baseline rules for architecture, security, and agent behavior that apply to every project. |
| `.agents/rules/` | **Stack & Agent Rules.** Stack-specific constraints (e.g., `stack-angular.md`) and agent-level workarounds, loaded via glob or always-on triggers. |
| `.agents/skills/` | **Specialized Capabilities.** Detailed instructions for the agent to perform complex reviews (e.g., `QUALITY_ASSURANCE`, `SPRINT_MANAGER`). |
| `.agents/workflows/` | **Standard Operating Procedures.** Explicit step-by-step procedures the agent must follow (e.g., `feature-cycle.md` for sprint execution). Contains `sync-template.md` which is designed to be **copied to new projects** to allow them to "pull" standards updates dynamically. |
| `.github/workflows/` | **CI/CD Pipelines.** Automated build, test, and deployment definitions using GitHub Actions. |

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

### 🔑 Required GitHub Secrets and Variables
Because the pipelines are designed to be environment-agnostic, **all secrets and dynamic configurations must be stored in GitHub Repository/Environment settings**, never hardcoded.

#### GitHub Environments
Ensure you have created the following **Environments** in your GitHub repository settings:
- `production`
- `development`

#### Secrets and Variables Map
| Name | Type | Level | Default | Required For | Description |
| ---- | ---- | ----- | ------- | ------------ | ----------- |
| `DISABLE_PIPELINES_FOR_TEMPLATE` | Variable | Repository | — | `ci-angular.yml` & `cd-angular-azure-storage.yml` | If set to `true`, completely disables the GitHub Actions. Used by the source template repository to prevent unnecessary billing while remaining fully active for any project it is copied to. |
| `NODE_VERSION` | Variable | Repository | `20` | `ci-angular.yml` & `cd-angular-azure-storage.yml` | The Node.js version to use for the build (e.g., `20` or `22.x`). |
| `ANGULAR_WORKING_DIRECTORY` | Variable | Repository | `.` | `ci-angular.yml` & `cd-angular-azure-storage.yml` | The directory where the Angular app lives (e.g. `.` or `frontend`). |
| `AZURE_STORAGE_BASE_URL` | Secret | Environment | — | `cd-angular-azure-storage.yml` & `shared-build-angular.yml` | The base URL of the Azure Storage account. |
| `AZURE_STORAGE_DEPLOY_BASE_PATH` | Secret | Environment | — | `cd-angular-azure-storage.yml` | The container/path to deploy to (e.g. `$web`). |
| `AZURE_STORAGE_DEPLOY_SAS_TOKEN` | Secret | Environment | — | `cd-angular-azure-storage.yml` | The SAS token mapped specifically with write/delete permissions to deploy the static app. |
| `AZURE_STORAGE_IMG_BASE_PATH` | Secret | Environment | — | `shared-build-angular.yml` | The base path to prepend for image blobs. |
| `AZURE_STORAGE_IMG_SAS_TOKEN` | Secret | Environment | — | `shared-build-angular.yml` | The SAS token to append to image blobs (read permission). |

## 🔄 Updating this Documentation
As part of the `feature-cycle.md` workflow, the Agent is mandated to keep this `README.md` updated. If you add a new pipeline, a new secret, or a major new rule category, this file will be updated synchronously to reflect the new state of our templates.
