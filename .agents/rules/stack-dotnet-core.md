---
name: Stack Dotnet Core
trigger: glob
globs: ["**/*.cs", "**/*.csproj"]
description: Backend stack rules for ASP.NET Core / C# projects
---

# BACKEND SPECIFICATIONS (ASP.NET Core / C#)

## 1. Syntax & Formatting
- **Indentation:** Use standard 4-space indentation for all `.cs` files (aligning with the broader .NET ecosystem, `dotnet format`, and editorconfig defaults). *(Note: Deviates from frontend 2-space to prevent fighting tooling)*.
- **Member Ordering:** Fields -> Constructor -> Public Methods -> Private Methods.
- **Immutability:** Use `readonly` for dependency injection fields. Use `record` types for DTOs and immutable data structures.

## 2. Architecture & Design Patterns
- **Dependency Injection:** - All services must be registered in the DI container.
  - Never use `new` for service instantiation.
- **The Adapter Pattern (Third-Party Isolation):**
  - **[ARCHITECT REQUIRED]** Never use a third-party library object (e.g., a specific logger, a PDF generator, a Cloud SDK) directly in the business logic.
  - Create an interface (e.g., `IPdfGenerator`) and a wrapper implementation.
  - This ensures that updating or changing the library only affects the wrapper, not the core logic.
- **Controller Logic:**
  - Controllers must be "Thin". They only handle HTTP Protocol (Status codes, Request/Response).
  - Business logic must reside in the Service Layer or Domain Layer.

## 3. Resilience & Data
- **Constants & Enums:**
  - Strict Ban on Magic Strings/Numbers.
  - Use `const` strings in a central `AppConstants` class or specific `Enums` for logic branching.
- **Exception Handling:**
  - **Global Handling:** Use Middleware for unhandled exceptions to ensure uniform API error responses.
  - **Specific Safety:** In specific methods, use `try/catch` only if you can handle the error or need to wrap it in a custom `DomainException`.
- **SQL/NoSQL Safety:** User input must never be concatenated into query strings — see §8.2 A03 for the parameterized-query mandate.

## 4. Testing Strategy
- **Equivalence Classes:** Tests must cover:
  1.  **Standard Case:** Typical valid data.
  2.  **Boundary Case:** Min/Max values (e.g., empty strings, max int).
  3.  **Error Case:** Invalid inputs that should trigger specific exceptions.

## 5. Async Patterns
- **Async All The Way:** Always use `async` and `await` for I/O bound operations. Never use `.Result` or `.Wait()` (prevents deadlocks).
- **Cancellation Tokens:** All async methods, especially Controller endpoints and Entity Framework calls, MUST accept and pass a `CancellationToken`.
- **ValueTask:** Consider using `ValueTask<T>` instead of `Task<T>` for hot-paths where the result might frequently be completed synchronously.

## 6. Nullable Safety
- **Strict Nullables:** Project files must have `#nullable enable` turned on.
- **Suppression Ban:** Do not use the null-forgiving operator (`null!`) unless you can explicitly justify it in a comment above the statement. Handle possible nulls explicitly.

## 7. API Design
- **RESTful Routing:** Use noun-based, pluralized routing (`api/v1/users` instead of `api/v1/getUsers`).
- **Response Envelopes:** Use a standard envelope for API responses or standard ProblemDetails for errors.
- **Versioning:** Always implement API versioning from Day 1 to prevent breaking changes for mobile/external clients.

## 8. Security & Validation

### §8.1 Existing Baselines
- **Authentication/Authorization:** Secure all endpoints by default. Expose explicitly using `[AllowAnonymous]`. Combine Role-based and Policy-based authorization.
- **Input Validation:** Use `FluentValidation` instead of data annotations for DTOs to separate validation logic from data models.
- **CORS & Rate Limiting:** Apply explicit, least-privilege CORS policies and rate limiting middleware for public-facing APIs.

### §8.2 OWASP-Aligned Mandates

#### A02 — Cryptographic Failures [STRICT]
All secrets (connection strings, API keys, tokens) MUST be sourced at runtime from the deployment platform — never hardcoded in `appsettings.json` or any source-controlled file. Configuration must be **cloud-agnostic**: no provider-specific secret references in committed files (e.g., `@Microsoft.KeyVault(...)` is forbidden in checked-in config because it couples the codebase to a specific cloud service).

- ❌ `"ConnectionStrings": { "Default": "Server=prod;Password=secret" }` — literal secret in source
- ❌ `"ConnectionStrings": { "Default": "@Microsoft.KeyVault(SecretUri=...)" }` — provider-specific reference in committed config
- ✅ `"ConnectionStrings": { "Default": "" }` in `appsettings.json`; the CD pipeline injects the real value as a platform application setting (`ConnectionStrings__Default`, `AzureAd__TenantId`, etc.)

**How secrets reach the runtime:**
- **Azure Functions / App Service:** CD pipeline sets values via `az functionapp config appsettings set` — Azure stores them encrypted at rest and exposes them as environment variables that override `appsettings.json` at startup (double-underscore = section separator).
- **Local development:** set values in `appsettings.Development.json` (must be git-ignored) or via `dotnet user-secrets`.
- **[MANDATORY]** All required secret names MUST be documented in `README.md` under a clearly labelled "Secrets & Configuration" section so operators know exactly what to provision.

#### A03 — Injection [STRICT]
Parameterized queries or typed ORM repositories only. String concatenation into SQL or NoSQL filter clauses is strictly forbidden. See §3 for general data safety.
```csharp
// ❌ String-concat — SQL injection vector
var sql = $"SELECT * FROM Orders WHERE TenantId = '{tenantId}'";

// ✅ EF Core (parameterized automatically) or Dapper named param
var orders = await _db.Orders
    .Where(o => o.TenantId == tenantId)
    .ToListAsync(ct);
```

#### A05 — Security Misconfiguration [STRICT]
Security headers middleware MUST be registered in `Program.cs` before `app.UseRouting()`. `ProblemDetails` responses MUST NOT expose stack traces outside development (`IncludeExceptionDetails = env.IsDevelopment()`).
```csharp
// ✅ Required in Program.cs
app.Use(async (ctx, next) =>
{
    ctx.Response.Headers["X-Content-Type-Options"] = "nosniff";
    ctx.Response.Headers["X-Frame-Options"] = "DENY";
    ctx.Response.Headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
    ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'";
    await next();
});
app.UseHsts(); // HSTS via built-in middleware; configure MaxAge in appsettings
```

#### A07 — Authentication Failures [STRICT]
JWT validation MUST use `Microsoft.Identity.Web`. Hand-rolled `JwtSecurityTokenHandler` parsing is strictly forbidden — token lifetime, signature, and refresh are all handled by the library.
```csharp
// ❌ Hand-rolled — no lifetime/signature guarantees
new JwtSecurityTokenHandler().ValidateToken(token, validationParams, out _);

// ✅ Microsoft.Identity.Web — register once in Program.cs
builder.Services.AddMicrosoftIdentityWebApiAuthentication(builder.Configuration);
```

**Isolated worker (Functions) DI stub [STRICT — Sprint 10.5 lesson]:** in the Functions
isolated worker, `AddMicrosoftIdentityWebApi` v3+ chains into `AddAuthorization()`, which
in .NET 8+ registers `AuthorizationPolicyCache` — a component that resolves
`Microsoft.AspNetCore.Routing.EndpointDataSource`. That service is absent in the worker DI
container and the host crashes at startup with no actionable error. Add the framework
reference and a no-op `EndpointDataSource` to the Functions project:
```xml
<!-- LcServices.Functions.csproj -->
<ItemGroup>
  <FrameworkReference Include="Microsoft.AspNetCore.App" />
</ItemGroup>
```
```csharp
// Program.cs — after AddAuthentication / AddMicrosoftIdentityWebApi
services.AddSingleton<EndpointDataSource>(_ => new DefaultEndpointDataSource([]));
```

#### A09 — Logging Failures [STRICT]
Structured logging via `ILogger<T>` with a correlation ID injected per request. Logging tokens, raw request bodies, passwords, or PII (email, phone, address) is strictly forbidden. Failed authn/authz events MUST be logged at `Warning` with the user's Object ID — never email.
```csharp
// ❌ PII in logs
_logger.LogWarning("Login failed for {Email}", userEmail);

// ✅ Object ID only; structured + correlation-ID enriched
_logger.LogWarning("Authn rejected. UserId={ObjectId} CorrelationId={CorrelationId}",
    objectId, HttpContext.TraceIdentifier);
```

## 9. Azure SQL Authentication with Microsoft.Data.SqlClient 7+ [STRICT — Sprint 11 lesson]

`Microsoft.Data.SqlClient` 7.0 removed the built-in `Authentication=Active Directory*` connection-string keyword handlers. They must be replaced with the `AccessTokenCallback` pattern via an EF Core `DbConnectionInterceptor`.

**Never downgrade SqlClient to avoid this migration.** SqlClient 6.0 was the first version to support the native `json` column type; 7.0 is the current target. Pinning to an older version to sidestep the breaking change violates `AGENTS.md §7 No Downgrade Shortcut`.

**Correct implementation — `AzureSqlAuthInterceptor`:**
```csharp
// LcServices.DataAccess/Database/AzureSqlAuthInterceptor.cs
// Requires: Azure.Identity package in the DataAccess project
internal sealed class AzureSqlAuthInterceptor : DbConnectionInterceptor
{
    private static readonly DefaultAzureCredential Credential = new();
    private static readonly string[] Scopes = ["https://database.windows.net/.default"];

    public override async ValueTask<InterceptionResult> ConnectionOpeningAsync(
        DbConnection connection, ConnectionEventData eventData,
        InterceptionResult result, CancellationToken cancellationToken = default)
    {
        if (connection is SqlConnection sqlConnection)
            sqlConnection.AccessTokenCallback = FetchTokenAsync;
        return await base.ConnectionOpeningAsync(connection, eventData, result, cancellationToken);
    }

    public override InterceptionResult ConnectionOpening(
        DbConnection connection, ConnectionEventData eventData, InterceptionResult result)
    {
        if (connection is SqlConnection sqlConnection)
            sqlConnection.AccessTokenCallback = FetchTokenAsync;
        return base.ConnectionOpening(connection, eventData, result);
    }

    private static async Task<SqlAuthenticationToken> FetchTokenAsync(
        SqlAuthenticationParameters parameters, CancellationToken cancellationToken)
    {
        var token = await Credential.GetTokenAsync(
            new TokenRequestContext(Scopes), cancellationToken);
        return new SqlAuthenticationToken(token.Token, token.ExpiresOn);
    }
}
```

**Registration — both runtime and design-time:**
```csharp
// ServiceCollectionExtensions.cs (runtime)
services.AddDbContext<LcServicesDbContext>(opts =>
    opts.UseSqlServer(connectionString)
        .AddInterceptors(new AzureSqlAuthInterceptor()));

// LcServicesDbContextFactory.cs (EF CLI tooling / dotnet ef database update)
var options = new DbContextOptionsBuilder<LcServicesDbContext>()
    .UseSqlServer(connectionString)
    .AddInterceptors(new AzureSqlAuthInterceptor())
    .Options;
```

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