---
name: Naming Azure Resources
trigger: glob
globs: ["**/*.bicep", "**/*.tf", ".github/workflows/**", "**/INFRA.md", "**/infra/**"]
description: Azure resource naming convention — load when provisioning or referencing Azure infrastructure
---

# Azure Resource Naming Convention

All Azure resources in a project follow a structured naming scheme derived from the
physical/logical context of the resource:

```
{region}{env}{region-suffix}{app-prefix}{resource-type}{index}
```

## Segments

| Segment | Values | Example | Notes |
|---|---|---|---|
| `region` | two-letter ISO region code | `eu` | e.g. `eu` for West Europe |
| `env` | `d` (dev), `p` (prod) | `d` | environment the resource belongs to |
| `region-suffix` | project-defined | `w` | e.g. `w` for "west" — pick once per project and keep it consistent across environments; if an inconsistency is discovered later, document it rather than renaming live resources |
| `app-prefix` | project-defined, short (2-4 letters) | `app` | application identifier, fixed for the life of the project |
| `resource-type` | see table below | `azf` | lowercase acronym identifying the Azure resource type |
| `index` | `01`, `02`… | `01` | per-type progressive index within the same environment |

## Resource Type Acronyms

| Acronym | Azure Resource Type |
|---|---|
| `rsg` | Resource Group |
| `azf` | Azure Function App |
| `sta` | Storage Account |
| `umi` | User-Assigned Managed Identity |
| `swa` | Static Web App |
| `aai` | Application Insights |
| `sql` | Azure SQL Server |
| `sqldb` | Azure SQL Database |
| `spn` | App Registration / Service Principal — **operational/CD identities only** (see note) |
| `kv` | Key Vault |
| `cr` | Container Registry |
| `aca` | Azure Container App |

> **`spn` scope [STRICT]:** This convention names **Azure infrastructure resources** and
> **operational** identities (e.g. the GitHub Actions CD service principal for an environment).
> **Authentication app registrations** — SPA sign-in, API JWT audience — are **not** Azure
> infrastructure and do **not** follow this scheme: they use descriptive functional names
> (e.g. `<spa-app>`, `<api-app>`) and live in the customer identity tenant, not the
> Azure subscription. Never name an auth app registration `…spnNN` — it conflates auth
> identities with CD identities, which `stack-github-actions.md §2` forbids.

## Example Resource Set (illustrative)

| Name | Type | Purpose |
|---|---|---|
| `eudwapprsg01` | Resource Group | Per-environment resource group |
| `eudwappswa01` | Static Web App | Frontend SPA |
| `eudwappazf01` | Function App | Backend API |
| `eudwappsta01` | Storage Account | Application content storage |
| `eudwappumi01` | User-Assigned Managed Identity | Runtime identity (data-plane only) |
| `eudwappspn01` | App Registration / SPN | CD identity (control-plane only), one per environment |

## Rules

- **[STRICT]** Every new Azure resource MUST follow this naming convention before provisioning.
  Propose the name in the PLAN or PR description and get approval before running `az` commands.
- **[STRICT]** One SPN per environment. Never share a CD SPN across environments.
- **[STRICT]** The `umi` identity (runtime) and the `spn` identity (CD deploy) are always separate.
  The `umi` has only data-plane permissions (e.g. SQL read/write). The `spn` has only control-plane
  permissions (e.g. `Website Contributor` on its environment's Function App). Never cross-assign.
- Index gaps are acceptable — do not renumber existing resources to fill a gap.
- If a region-suffix or app-prefix inconsistency is discovered after resources are already
  provisioned, document it in this file and in the project's infra docs rather than renaming
  live resources retroactively.
