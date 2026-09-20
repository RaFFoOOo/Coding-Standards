---
name: Naming Azure Resources
trigger: glob
globs: ["**/*.bicep", "**/*.tf", ".github/workflows/**", "**/INFRA.md", "**/infra/**"]
description: Azure resource naming convention — load when provisioning or referencing Azure infrastructure
---

# Azure Resource Naming Convention

```
{region}{region-suffix}{env}{app-prefix}{resource-type}{index}      e.g. euwdappazf01
```

| Segment | Values | Notes |
|---|---|---|
| `region` + `region-suffix` | `eu` + `w` | two-letter region code, then a project-defined suffix; pick once and keep it |
| `env` | `d` dev, `p` prod | |
| `app-prefix` | project-defined, 2–4 letters | fixed for the life of the project |
| `resource-type` | the acronym table below | lowercase |
| `index` | `01`, `02`… | per type, per environment; gaps are fine — never renumber |

**Region and its suffix come first, together, then environment.** A project that provisions
`{region}{env}{region-suffix}…` has the order backwards. Never rename live resources to fix it —
document the inconsistency and use the correct order for every **new** resource, accepting that the
environment mixes both prefixes until it is re-provisioned.

```
✅ a new dev storage account     euwdappsta03
❌ same, legacy order            eudwappsta03
❌ free-form                     app-dev-storage
```

## Resource type acronyms

| Acronym | Azure resource type |
|---|---|
| `rsg` | Resource Group |
| `azf` | Function App |
| `sta` | Storage Account |
| `umi` | User-Assigned Managed Identity |
| `swa` | Static Web App |
| `aai` | Application Insights |
| `sql` | Azure SQL Server |
| `sqldb` | Azure SQL Database |
| `spn` | App Registration / Service Principal — CD identities only |
| `kv` | Key Vault |
| `cr` | Container Registry |
| `aca` | Container App |

A type not listed gets its acronym in the PLAN or PR that proposes the resource.

## Not covered by the scheme

- **Authentication app registrations** (SPA sign-in, API audience) are not Azure infrastructure: they
  live in the customer identity tenant and use functional names. Never name one `…spnNN` — that
  conflates an auth identity with a CD identity, which `stack-github-actions.md §2` forbids.
- **Monitor artifacts** — an action group, a workbook's display name — use
  `<envprefix><app-prefix>-<descriptor>`. A workbook's *resource* name must be a UUID.
- **Names Azure generates** — a Consumption plan, a *Failure Anomalies* alert rule — stay as created.

## Rules

- **[STRICT] Name it before provisioning it.** Propose the name in the PLAN or PR and get approval
  before running `az`. Then add its row to the project's resource map and its default to the setup
  script the provisioning scripts read.
- **[STRICT] A runtime identity and a CD identity are always separate — one CD SPN per environment.**
  The `umi` holds only data-plane access roles on its own environment's storage and database. The
  `spn` holds only control-plane roles, such as `Reader` on the subscription and deploy rights on its
  own environment's Function App. Never grant a deployment role to a `umi`, and never share an SPN
  across environments. Full taxonomy: `stack-github-actions.md §2`.
