---
name: Stack .NET API
trigger: glob
globs: ["**/*.cs"]
description: Endpoint design, server-side validation and security
---

# Stack .NET API

## 7. API Design
- **RESTful Routing:** Use noun-based, pluralized routing (`api/v1/users` instead of `api/v1/getUsers`).
- **Response Envelopes:** Use a standard envelope for API responses or standard ProblemDetails for errors.
- **Versioning:** Always implement API versioning from Day 1 to prevent breaking changes for mobile/external clients.

## 8. Security & Validation

### §8.1 Existing Baselines
- **Authentication/Authorization:** Secure all endpoints by default. Expose explicitly using `[AllowAnonymous]`. Combine Role-based and Policy-based authorization.
- **Role-based authorization [authorization model]:** Authorization is **role-based and owned entirely by internal application logic** — never delegated to OAuth token claims. **Roles** (`owner`/`customer`, resolved from the `TenantUserRole` table) answer *who the user is* and are enforced per-tenant via `ITenantScopeAuthorization` / `RequireOwnerAsync`. The access token is used **only** to authenticate the caller — `[FunctionAuthorize]` + `FunctionAuthorizationMiddleware` validate the Bearer token and resolve identity; the token's claims (including `scp`) are **not** consulted for permission decisions. OAuth scope-based authorization (`[RequireScope]`, `scp`-claim checks) is explicitly **out of scope** for this single-first-party-client project — see `DECISIONS.md` (2026-05-22, scope-based authorization rejected).
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

**Isolated worker (Functions) manual token validation — not a violation [documented pattern, found during
an OWASP audit]:** the ✅ example above (`AddMicrosoftIdentityWebApiAuthentication`
+ ASP.NET Core's `[Authorize]`/`UseAuthentication()` pipeline) has no direct equivalent in the Functions
isolated worker — there is no ASP.NET Core HTTP pipeline to hook into (`IFunctionsWorkerMiddleware` is a
different pipeline entirely). This project's `FunctionAuthorizationMiddleware` still registers
`AddMicrosoftIdentityWebApi` in `Program.cs` (for its OIDC discovery, signing-key rotation, and
issuer/audience resolution via `IOptionsMonitor<JwtBearerOptions>`), then explicitly calls
`JsonWebTokenHandler.ValidateTokenAsync(token, tvp)` — `JsonWebTokenHandler`, not the deprecated
`JwtSecurityTokenHandler` the ❌ example names — supplying `TokenValidationParameters` sourced entirely
from Microsoft.Identity.Web's own resolved options, never hand-constructed. This is the correct pattern
for isolated-worker Functions: the STRICT rule's intent (never write custom signature/lifetime
verification, always delegate to the library's resolved configuration) is satisfied even though the
literal code shape differs from the ASP.NET Core example. Do not "fix" this by trying to force
`[Authorize]`-attribute-style validation into a Functions isolated worker.

#### A09 — Logging Failures [STRICT]
Structured logging via `ILogger<T>` with a correlation ID injected per request. Logging tokens, raw request bodies, passwords, or PII (email, phone, address) is strictly forbidden. Failed authn/authz events MUST be logged at `Warning` with the user's Object ID — never email.
```csharp
// ❌ PII in logs
_logger.LogWarning("Login failed for {Email}", userEmail);

// ✅ Object ID only; structured + correlation-ID enriched
_logger.LogWarning("Authn rejected. UserId={ObjectId} CorrelationId={CorrelationId}",
    objectId, HttpContext.TraceIdentifier);
```
