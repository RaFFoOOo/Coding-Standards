---
paths:
  - "**/*.Functions/**"
---

# Backend HTTP API

Section numbers continue from `stack-dotnet-core.md`, so a `stack-dotnet-core.md §8` citation lands
here. Rules are written for **ASP.NET Core**, the intended host. Today's host is the Azure Functions
isolated worker; what differs there is collected in [Current host](#current-host--azure-functions-isolated-worker)
at the end, so a migration deletes that section and nothing else.

## 7. API Design

- **Routes are plural nouns, versioned from day one:** `v1/reservations/{tenantId:guid}`, never
  `v1/getReservations`.
- **Errors are `ProblemDetails`;** successful responses share one envelope shape.

## 8. Security & Validation

### §8.1 Baselines

- **Every endpoint is closed unless opening it is a documented choice.** Anonymous access is explicit
  (`[AllowAnonymous]` in ASP.NET Core), carries its reason on the endpoint, and an anonymous endpoint's
  writes still check ownership per request (`RequireOwnerAsync`) — `docs/ARCHITECTURE.md:157`.
- **Authorization is role-based application logic, never token claims.** Roles come from
  `TenantUserRole` and are enforced per tenant by `ITenantScopeAuthorization` / `RequireOwnerAsync`.
  Combine role-based and policy-based checks. The token only authenticates the caller; its claims,
  `scp` included, grant nothing. 🔒 `archive/DECISIONS_ARCHIVE.md` 2026-05-22.
- **Server-side validation is the security boundary** (`AGENTS.md §3` *Dual-Side Validation*). Validate
  the body, the query string and route values before any business logic, and reject with
  `ProblemDetails` / `4xx`. Never assume a request came through the frontend. Parameterized queries
  (A03) make a filter injection-safe; they do not replace validating its shape.
  - **Idiom:** an inline static validator returning the first error or `null`
    (`Http/TenantConfigUpdateValidator.cs:16`); a single scalar gets a route constraint (`{id:guid}`)
    or an inline guard. **FluentValidation is not used here** — 🔒 `DECISIONS.md` 2026-07-20 and
    2026-06-24.
- **CORS and rate limiting are least-privilege** on every public-facing API.

### §8.2 OWASP-aligned mandates

#### A02 — Cryptographic Failures [STRICT]

No secret in a committed file, and no provider-specific secret reference either.

- ❌ `"Default": "Server=prod;Password=secret"` — a literal secret
- ❌ `"Default": "@Microsoft.KeyVault(SecretUri=...)"` — couples committed config to one cloud
- ✅ `"Default": ""` committed; the deploy pipeline sets the real value as a platform app setting
  (`ConnectionStrings__Default` — `__` separates sections)

Locally: a git-ignored `appsettings.Development.json` or `dotnet user-secrets`. **Every required secret
is listed** in `{services}/README.md` → *Secrets & Configuration*.

#### A03 — Injection [STRICT]

EF Core or parameterized queries only; never concatenate input into a SQL or NoSQL filter.

```csharp
// ❌
var sql = $"SELECT * FROM Orders WHERE TenantId = '{tenantId}'";
// ✅
var orders = await _db.Orders.Where(o => o.TenantId == tenantId).ToListAsync(ct);
```

#### A05 — Security Misconfiguration [STRICT]

- **Every response carries the security headers**, registered before routing: `nosniff`,
  `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`, a CSP, and HSTS.
  ```csharp
  app.Use(async (ctx, next) => { ctx.Response.Headers["X-Content-Type-Options"] = "nosniff"; /* … */ await next(); });
  app.UseHsts();
  ```
- **No stack trace in an error response outside development** (`IncludeExceptionDetails =
  env.IsDevelopment()`).

#### A07 — Authentication Failures [STRICT]

Token validation is delegated to `Microsoft.Identity.Web`. Never hand-roll signature, lifetime or
refresh checks.

```csharp
// ❌ banned
new JwtSecurityTokenHandler().ValidateToken(token, validationParams, out _);
// ✅ register once
builder.Services.AddMicrosoftIdentityWebApiAuthentication(builder.Configuration);
```

#### A09 — Logging Failures [STRICT]

Structured `ILogger<T>` with a per-request correlation id. Never log tokens, raw request bodies,
passwords or PII (email, phone, address). A failed authn/authz event logs at `Warning` with the
Object ID, never the email; before a token validates there is no trusted identity, so log the
correlation id only.

```csharp
// ❌
_logger.LogWarning("Login failed for {Email}", userEmail);
// ✅
_logger.LogWarning("Authn rejected. UserId={ObjectId} CorrelationId={CorrelationId}",
    objectId, correlationId);
```

## Current host — Azure Functions isolated worker

The worker has **no ASP.NET Core request pipeline**: `[Authorize]`, `[AllowAnonymous]`, `app.Use(...)`
and `UseHsts()` do not apply. Delete this section when the API moves to an ASP.NET Core host.

| Rule | Where the worker does it |
|---|---|
| §8.1 closed by default | `[FunctionAuthorize]` opts a function in — **23 of 34** `[Function]` methods, counted 2026-09-14; the rest are anonymous by design. Why a custom attribute: 🔒 `archive/DECISIONS_ARCHIVE.md` 2026-04 |
| §8.1 CORS, rate limiting | `Middleware/CorsMiddleware.cs`, `Middleware/RateLimitingMiddleware.cs` |
| A02 app settings | `az functionapp config appsettings set` |
| A05 headers | `host.json` `extensions.http.customHeaders` — the host adds them to every response, its own 404s included; JSON-API CSP `default-src 'none'`, CORP `same-origin` |
| A05 no stack trace | `ExceptionHandlingMiddleware.cs:72` gates the detail on `IsDevelopment()` |
| A09 correlation id | `context.InvocationId`; before validation, `Function` + `InvocationId` only (`FunctionAuthorizationMiddleware.cs:103`) |

- **A07 — the manual validation is compliant; do not "fix" it into `[Authorize]`.** `Program.cs:48`
  registers `AddMicrosoftIdentityWebApi` for discovery, key rotation and issuer/audience;
  `FunctionAuthorizationMiddleware.cs:94` calls `JsonWebTokenHandler.ValidateTokenAsync` with
  parameters taken from those resolved options, never hand-built. Reviewed in the Sprint 33 OWASP
  audit (`archive/PLAN_sprint_033.md:140`).
- **A07 — keep the DI stub, or the host crashes at startup with no useful error.**
  `AddMicrosoftIdentityWebApi` v3+ registers `AuthorizationPolicyCache`, which needs an
  `EndpointDataSource` the worker does not have:
  - `<FrameworkReference Include="Microsoft.AspNetCore.App" />` — `{Backend}.Functions.csproj:11`
  - `services.AddSingleton<EndpointDataSource>(_ => new DefaultEndpointDataSource([]));` —
    `Program.cs:55`
