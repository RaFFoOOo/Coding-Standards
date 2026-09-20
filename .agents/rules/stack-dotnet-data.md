---
name: Stack .NET Data
trigger: glob
globs: ["**/*.cs"]
description: Persistence, resilience and database authentication
---

# Stack .NET Data

## 3. Resilience & Data
- **Constants & Enums:**
  - Strict Ban on Magic Strings/Numbers.
  - Use `const` strings in a central `AppConstants` class or specific `Enums` for logic branching.
- **Exception Handling:**
  - **Global Handling:** Use Middleware for unhandled exceptions to ensure uniform API error responses.
  - **Specific Safety:** In specific methods, use `try/catch` only if you can handle the error or need to wrap it in a custom `DomainException`.
- **SQL/NoSQL Safety:** User input must never be concatenated into query strings — see §8.2 A03 for the parameterized-query mandate.
- **Entity Relationships — Real FKs, Not String-Matching [STRICT]:** Two entities that reference
  each other MUST be linked by a real foreign key (a stable ID + DB constraint) — never by matching
  two independently-mutable string/business-key columns across tables at query time. A
  human-readable business key (slug, type, code) may still be denormalized onto the child row for
  read/API convenience, but it must be **write-time derived from the parent, never independently
  client-settable**, and it must not itself be the join/query mechanism.
  ```csharp
  // ❌ No referential integrity — ChildItem.Type and ParentConfig.ItemType are two
  // independent string columns; nothing stops them drifting apart, and a lookup by string can
  // silently return zero rows (orphaned item) or attach to the wrong parent.
  public record ChildItem { public required string Type { get; init; } }
  await Context.ChildItems.Where(c => c.Type == itemType).ToListAsync(ct); // string-matched, no FK behind it

  // ✅ A real FK is the relationship; a string mirror kept for an existing URL/API addressing
  // scheme is always derived from the FK'd parent at write time, never independently settable,
  // and reads resolve via the FK, not the string.
  public record ChildItem { public required Guid ParentConfigId { get; init; } public required string Type { get; init; } }
  builder.HasOne<ParentConfig>().WithMany().HasForeignKey(c => c.ParentConfigId).OnDelete(DeleteBehavior.Cascade);
  ```
  **Why:** a matched-string relationship makes drift and orphaning *possible by construction* — a
  typo, a partial migration, or one direct API call bypassing the single code path that kept two
  strings in sync is all it takes, and nothing in the schema catches it. Found in a real codebase
  where a child entity and its parent config were joined purely on a `Type`/`ParentType` string
  pair — it had already silently orphaned 3 seed rows before anyone noticed. A real FK also makes cascading (or restricting) delete possible for the first time —
  that requires the DB to know the relationship exists at all.

## 9. Azure SQL Authentication with Microsoft.Data.SqlClient 7+ [STRICT]

`Microsoft.Data.SqlClient` 7.0 removed the built-in `Authentication=Active Directory*` connection-string keyword handlers. They must be replaced with the `AccessTokenCallback` pattern via an EF Core `DbConnectionInterceptor`.

**Never downgrade SqlClient to avoid this migration.** SqlClient 6.0 was the first version to support the native `json` column type; 7.0 is the current target. Pinning to an older version to sidestep the breaking change violates `AGENTS.md §7 No Downgrade Shortcut`.

**Reference implementation — `AzureSqlAuthInterceptor` (`<YourApp>.DataAccess/Database/`):**
a `sealed DbConnectionInterceptor` (override both `ConnectionOpeningAsync` and the sync
`ConnectionOpening`) that, when the connection is a `SqlConnection`, sets
`sqlConnection.AccessTokenCallback` to a static callback fetching a token from a shared
`DefaultAzureCredential` for scope `https://database.windows.net/.default`. Requires the
`Azure.Identity` package in the DataAccess project. Register it via
`.AddInterceptors(new AzureSqlAuthInterceptor())` in **both** the runtime DbContext
(`ServiceCollectionExtensions`) **and** the design-time factory
(`AppDbContextFactory`, used by `dotnet ef`). Both registrations are mandatory —
the EF CLI tooling fails to connect without the design-time one.

**Connection string requirements:**
- Must NOT contain `Authentication=` keyword — token injection is handled entirely by the interceptor.
- Minimal form: `Server=<host>.database.windows.net;Database=<db>;Encrypt=True;TrustServerCertificate=False;`
- `DefaultAzureCredential` resolves credentials in order: Managed Identity (Azure) → Azure CLI → Visual Studio → environment variables. No connection string changes are needed between environments.

**Dependency matrix:**

| SqlClient version | `SqlDbType.Json` | Built-in AAD auth | `AccessTokenCallback` |
|---|---|---|---|
| 5.x (EF Core 9 default) | ❌ | ✅ | ✅ |
| 6.x | ✅ | ✅ | ✅ |
| 7.x (current target) | ✅ | ❌ (use interceptor) | ✅ |
