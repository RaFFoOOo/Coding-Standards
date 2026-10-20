---
paths:
  - "**/*.DataAccess/**"
  - "**/*.Domain/Models/**"
---

# Backend data — entities, persistence, Azure SQL

Section numbers continue from `stack-dotnet-core.md`, so a `stack-dotnet-core.md §3` or `§9` citation
for these rules lands here. Paths below are relative to `{services}/`.

## 3. Resilience & Data

### Entity relationships — real foreign keys, never string-matching [STRICT]

Two entities that reference each other are linked by a stable id **and** a database constraint. A
readable business key (slug, type, code) may be copied onto the child for the API, but it is derived
from the parent at write time, never set independently by a client, and never used as the join.

```csharp
// ❌ two independent string columns: nothing stops them drifting, and a lookup can silently match 0 rows
public record CatalogItem { public required string Type { get; init; } }
await Context.CatalogItems.Where(c => c.Type == catalogType).ToListAsync(ct);

// ✅ the FK is the relationship; Type is a write-time copy of the parent's key, and reads go through the FK
public record CatalogItem { public required Guid CatalogConfigId { get; init; } public required string Type { get; init; } }
builder.HasOne<CatalogConfig>().WithMany().HasForeignKey(c => c.CatalogConfigId).OnDelete(DeleteBehavior.Cascade);
```

Only a real FK makes a cascading or restricted delete possible. Here:
`{Backend}.DataAccess/Database/Configurations/CatalogItemConfiguration.cs:27`. The string-matched
version had already orphaned **3** seed items — 🔒 `archive/DECISIONS_ARCHIVE.md` 2026-07-23.

### A persisted field with a visual half ships the visual half first [STRICT]

Before adding a property to a persisted record (`ThemeSettings`, `TenantConfig`, …), seeding it or
writing its migration, the rendered result is approved on the **deployed preview SWA**, built
frontend-only — and first ask whether it needs persisting at all. Both are `AGENTS.md §1`. What a new
persisted field costs here:

- **`required` breaks every construction site** (good — the compiler finds them) **and every existing
  row needs a backfill before any read.** `ThemeSettings` is one native `json` column
  (`{Backend}.DataAccess/Database/Configurations/TenantConfigConfiguration.cs:50`), so EF scaffolds an
  **empty** migration and the data half is hand-written. Precedent:
  `{Backend}.DataAccess/Migrations/20260726150958_BackfillThemeSettingsPrimaryText.cs` (`JSON_MODIFY`,
  keyed by `TenantId`). Every value in a backfill is the computed output of the derivation function,
  never a mockup's illustrative table.
- **A full-replace update wipes a field its request does not carry.** `ConfigurationFunction.MergeTheme`
  (`{Backend}.Functions/Http/ConfigurationFunction.cs:174`) rebuilds `ThemeSettings` on every owner
  save, so a `required` field missing from `ThemeSettingsUpdateRequest` is lost. Derive it there, as
  `PrimaryText` is, or it cannot be a persisted field.

## 9. Azure SQL authentication — Microsoft.Data.SqlClient 7+ [STRICT]

SqlClient 7 removed the `Authentication=Active Directory*` connection-string handlers. The token comes
from an EF Core `DbConnectionInterceptor` instead.

- **Never downgrade SqlClient to avoid this** (`AGENTS.md §7` *No Downgrade Shortcut*). 6.0 was the
  first version with the native `json` column type; 7 is the target
  (`{Backend}.DataAccess/{Backend}.DataAccess.csproj:12`).
- **The interceptor** — `{Backend}.DataAccess/Database/AzureSqlAuthInterceptor.cs`: a sealed
  `DbConnectionInterceptor` overriding **both** `ConnectionOpeningAsync` (`:24`) and the sync
  `ConnectionOpening` (`:36`). Each sets `SqlConnection.AccessTokenCallback` from one static
  `DefaultAzureCredential` for scope `https://database.windows.net/.default`. Needs `Azure.Identity`
  (`{Backend}.DataAccess.csproj:10`).
- **Register it twice; both are required:** the runtime context
  (`{Backend}.DataAccess/ServiceCollectionExtensions.cs:142`) and the design-time factory
  (`{Backend}.DataAccess/Database/{Backend}DbContextFactory.cs:24`). Without the second, `dotnet ef`
  cannot connect.
- **The connection string has no `Authentication=` keyword:**
  `Server=<host>.database.windows.net;Database=<db>;Encrypt=True;TrustServerCertificate=False;`
  `DefaultAzureCredential` finds a credential (Managed Identity, Azure CLI, Visual Studio, …), so the
  string does not change between environments.

| SqlClient | `SqlDbType.Json` | Built-in AAD auth | `AccessTokenCallback` |
|---|---|---|---|
| 5.x | ❌ | ✅ | ✅ |
| 6.x | ✅ | ✅ | ✅ |
| 7.x (target) | ✅ | ❌ — use the interceptor | ✅ |
