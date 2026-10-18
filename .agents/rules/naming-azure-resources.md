---
paths:
  - ".github/workflows/**"
  - "**/INFRA.md"
  - "scripts/azure-setup/**"
---

# Azure Resource Naming Convention

```
{region}{region-suffix}{env}{app-prefix}{resource-type}{index}      e.g. euwp{prefix}azf01
```

| Segment | Values | Notes |
|---|---|---|
| `region` + `region-suffix` | `eu` + `w` | West Europe |
| `env` | `d` dev, `p` prod | |
| `app-prefix` | `{prefix}` | the project's code — `CLAUDE.md` *Placeholders* |
| `resource-type` | the acronym table below | lowercase |
| `index` | `01`, `02`… | per type, per environment; gaps are fine — never renumber |

**Dev is the exception.** Every existing dev resource is `eudw…` — `env` placed before the
region-suffix, a recorded mistake. **Never rename one.** A **new** dev resource uses the corrected
order, `euwd…` (`DECISIONS.md` 2026-09-14), so dev mixes both prefixes until it is re-provisioned. The
dev resource group, `{dev-rg}` (`scripts/azure-setup/env.sh:55`), predates the scheme.

```
✅ a new dev storage account     euwd{prefix}sta03
❌ same, legacy order            eudw{prefix}sta03
❌ free-form                     {prefix}-dev-storage
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

A type not listed — an App Service for a future ASP.NET Core host, say — gets its acronym in the PLAN
or PR that proposes the resource.

**Not covered by the scheme:**
- **Authentication app registrations** (SPA sign-in, API audience) are not Azure infrastructure: they
  live in the customer identity tenant and use functional names, `{app}-spa` and
  `{services}-api`. Never name one `…spnNN` — that conflates an auth identity with a CD identity
  (`stack-github-actions.md §2`).
- **Monitor artifacts** — the action group and the workbook's display name — use
  `<envprefix>{prefix}-<descriptor>`, e.g. `euwp{prefix}-oncall` (`env.sh:30`). A workbook's resource
  name must be a UUID.
- **Names Azure generates** — the dev Consumption (`Y1`) plan `ASP-{dev-rg}-…`, the *Failure
  Anomalies* alert rules — stay as created.

## Rules

- **[STRICT] Name it before provisioning it.** Propose the name in the PLAN or PR and get approval
  before running `az`. Then add its row to **`docs/INFRA.md §2`**, the resource map, and its default
  to **`scripts/azure-setup/env.sh`**, which the scripts read.
- **[STRICT] A runtime identity and a CD identity are always separate — one CD SPN per environment.**
  The UAMI holds only access roles: Storage Blob Delegator and Blob/Queue/Table/File data roles on its
  environment's storage, and `db_datareader` + `db_datawriter` on SQL (`assign-roles.sh:81`–`:117`). The SPN holds
  `Reader` on the subscription and `Website Contributor` on its own environment's Function App
  (`provision-cd-identity.sh:131`–`:132`). Never grant a deployment role to a UAMI, and never share an
  SPN across environments. Full taxonomy: `stack-github-actions.md §2`.
