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
- **Authorization owned by application logic [authorization model]:** When the application owns its own permission model, keep authorization **role/permission-based and resolved from the application's own data store** — do not delegate permission decisions to OAuth token claims. Separate the two concerns: the access token **authenticates** the caller (middleware validates the Bearer token and resolves identity), while **roles answer who the user is** and gate access (e.g. per-tenant ownership checks). Token claims such as `scp` should **not** be consulted for permission decisions in this model. Whether to additionally adopt OAuth scope-based authorization (`scp`-claim / `[RequireScope]` checks) is a per-project architectural choice — record the decision and its rationale in the project's decision log.
- **Input Validation:** Use `FluentValidation` instead of data annotations for DTOs to separate validation logic from data models.
  - **Server-side validation is mandatory and is the security boundary** (`AGENTS.md §3 Dual-Side Validation`): every endpoint independently validates **all** user-influenced input — request bodies **and query parameters and route values** — and rejects violations with `ProblemDetails`/`4xx` before any business logic runs. Never assume a request came through the frontend; a direct HTTP call bypasses it entirely.
  - Use `FluentValidation` for DTO/body validation. For a single scalar query/route value (e.g. an enum or slug filter) a route constraint (`{id:guid}`) or an inline guard returning `ProblemDetails` is sufficient and idiomatic — do **not** add `FluentValidation` solely for one query-string value if the project does not already use it there (native-over-third-party, §7). Parameterized queries (A03) make filters injection-safe, but shape validation is still required as contract/defense-in-depth.
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

**Isolated worker (Functions) DI stub [STRICT]:** in the Functions
isolated worker, `AddMicrosoftIdentityWebApi` v3+ chains into `AddAuthorization()`, which
in .NET 8+ registers `AuthorizationPolicyCache` — a component that resolves
`Microsoft.AspNetCore.Routing.EndpointDataSource`. That service is absent in the worker DI
container and the host crashes at startup with no actionable error. Add the framework
reference and a no-op `EndpointDataSource` to the Functions project:
```xml
<!-- <YourApp>.Functions.csproj -->
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