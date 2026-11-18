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
builder.HasOne<CatalogConfig>().WithMany().HasForeignKey(c => c.CatalogConfigId).OnDelete(DeleteBehavior.Restrict);
```

Only a real FK makes a cascading or restricted delete possible. Here:
`{Backend}.DataAccess/Database/Configurations/CatalogItemConfiguration.cs:27`. A string-matched
reference orphans rows silently.

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

### A read returns what its screen shows [STRICT]

- **Every endpoint reads only the fields its caller uses, and the browser never receives more.** A subset of an
  entity is projected into a type of its own (`TenantCard`, `OccupiedStay`), never an entity read whole for a few
  of its fields, and never the entity's own type filled in part: a field it does not read would come back as its
  default.
- **A text's languages are one field.** Read whole it costs the database nothing to unpack, a language switch needs
  no new request, and the owner's editor needs every language; a read is kept to one language only where the
  language decides which rows match (the order search's text).
- **A list returns the fields its rows show,** selected in the query; the rest is read when one item opens.
- **Related rows come in the same query** — a join or a projection — never a read per row afterwards, and never
  a wrapper that patches results after the repository returns them.
- **One query where a small join does:** never a first query whose result only feeds a second (the catalog types
  once read their catalog ids, then the items).
- **A list that can grow past a handful travels as one JSON parameter** (`EF.Parameter`), joined as a set; a short
  list keeps EF's padded parameters. Measure both on a realistic seed: one JSON parameter costs the
  smallest reads more pages and cuts a long list's by an order of magnitude.
- **No persisted computed column.** A derived value is derived in the query or by the code that writes it.
- **The checks:** `scripts/ci/project/check-query-appendix-coverage.sh` (every read is recorded in
  `docs/queries/`, so its SQL is reviewed) and `scripts/ci/generic/check-no-persisted-columns.sh`.

### A query is designed from its SQL, and read before anything builds on it [STRICT]

- **Write the SQL you want first, then the LINQ that produces it,** and compare the generated SQL with it: each
  table joined once per relationship, every related row reached by key, a page cut before its joins, only the
  columns the screen shows.
- **Read the generated SQL for the worst practices:** a table joined twice for one relationship (an owned
  collection comes with its whole owner, so a column from a line's link needs the owner projected field by field);
  two collections over the same rows (rows multiply, lines × lines); a correlated subquery or scalar function run
  per row; a condition evaluated in both the count and the page; a column no screen shows; a scan where a key
  could seek. A derived table is not one of them: the optimizer flattens it. What costs is work repeated per row.
- **The schema is part of the answer.** When a read keeps recomputing the same thing from data that rarely
  changes (a JSON column unpacked on every query), propose a stored form with its cost on writes: a table kept up
  to date on write, a computed column, an index.
- **A changed query reaches the Tech Lead before anything builds on it:** its SQL, a plain description of each
  step, and the siblings that share its shape, found by grep. When its plan is in doubt, one run of the actual
  plans on the seeded data, shown as an operator tree with executions and logical reads, never a standing
  budget suite.
- **The check:** `{Backend}.IntegrationTests/Performance/QueryAppendixTests.cs` keeps each read's SQL in
  `docs/queries/`, and a changed query changes its file in the same PR. Regenerate it in Release, the
  configuration CI tests: a Debug build names the parameters differently.

### Queries are fluent LINQ; SQL is never a string [STRICT]

- **The fluent form** (`.Where(…).LeftJoin(…)`), not query syntax (`from … in … select`), unless a query can only be
  written in query syntax; then a comment says why.
- **No SQL text assembled in code**, not even from table or column names the model supplies: the next edit can add
  one that is not. A bulk change is `ExecuteUpdateAsync` / `ExecuteDeleteAsync` per table; raw SQL, when nothing
  else can express it, is interpolated (`ExecuteSqlInterpolated`, `SqlQuery($"…")`), so every value is a parameter.
  Migrations write constant SQL.
- **The check:** `scripts/ci/generic/check-ef-query-style.sh`.

### Stored names, folders and document saves [STRICT]

How each kind of data is saved, and what happens when a save fails: `docs/ARCHITECTURE.md` §6 *How data and
media are saved*.

- **Every row and every file belongs to one tenant, or is declared shared** in `docs/DATA_SEGREGATION.md`, so
  one tenant's data can be exported, restored and erased on its own. A tenant's files live in its own
  containers, never in a container another tenant writes to; a new table or container is added to that file
  in the PR that creates it.

- **A blob's name and its folder are ids, never text a person typed** — a renamed catalog, a phone's
  `image.jpg` and a reordered slide each broke or overwrote a photo that had a typed name or a position in
  its path. A field a user typed that already names stored files is fixed once saved, on the server.
- **A whole-document write carries the version it started from** — the blob `ETag` as a
  `BlobRequestConditions.IfMatch`, 409 on a mismatch — so a concurrent save is refused, never overwritten.
- **A personal photo is written only to a private container** and read through an endpoint that checks the
  caller; a public read link never reaches it.
- **A file and the record that names it are written in an order, since no transaction spans both stores:**
  the file first, then the record, and the file deleted again if the record fails; on removal the record
  first, then the file. A failure leaves a file nothing names, which a sweep deletes, never a record naming a
  missing file. Erasing a person's data is the one exception: their files go first, so a failure part-way
  never loses track of a personal file, and the erasure is retried until it finishes.

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
