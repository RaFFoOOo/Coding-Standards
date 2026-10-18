---
paths:
  - "**/*.cs"
  - "**/*.csproj"
---

# C# / .NET

The language-agnostic rules — decoupling, strict typing, exceptions, async, testing — are `AGENTS.md`
§2–§3, which loads every session. This file holds their C# form and what only C# needs.

> **Moved — numbers kept, so existing citations still resolve:**
> - §7 API Design, §8 Security & Validation → `stack-dotnet-api.md` (`{services}/{Backend}.Functions/**`)
> - §3's entity-relationship and visual-half-first rules, §9 Azure SQL authentication →
>   `stack-dotnet-data.md` (`{Backend}.DataAccess/**`, `{Backend}.Domain/Models/**`)

## 1. Syntax & Formatting

- **4-space indentation** in `.cs` files — the .NET and `dotnet format` default; the frontend uses 2.
- **Member order:** fields → constructor → public methods → private methods.
- **Immutability** (`AGENTS.md §2`): dependency fields are `readonly`; DTOs and immutable data are `record`s.

## 2. Architecture & Design Patterns

The C# form of `AGENTS.md §2` *Design for replaceable parts*:

- **Register every service in the DI container and receive it through the constructor.** Never `new` a
  service.
- **[ARCHITECT REQUIRED] No third-party type in business logic.** Wrap it — an `IPdfGenerator` and one
  implementation — so changing or upgrading the library touches only the wrapper.
- **An endpoint is thin**, whether a controller action or a function: it reads the request, calls a
  service and maps the result to a status code. Business logic lives in the service or domain layer.
- **[STRICT] Never hand-list properties into a type that inherits them.** A derived record built with
  `new Derived { A = s.A, B = s.B }` compiles on every new base property and reads it back as its
  default — `TenantListEntry` silently dropped `EnableCustomerOrders`, sending every tenant's orders to
  the WhatsApp/email handoff. Chain a copy constructor instead (`public Derived(Base source) :
  base(source)`, `{Backend}.Domain/Models/Tenants/TenantConfig.cs:102`), and guard the class with a
  reflective round trip that sets **every** property to a non-default value
  (`TenantListEntryProjectionTests.cs`).
- **[STRICT] A class with a platform half and a domain half keeps the domain half in a `*.Domain.cs`
  partial**, reached through a `partial void` method the platform half calls — `Program.AddDomainServices`
  (`{Backend}.Functions/Program.Domain.cs`). The backend template (`scripts/template/manifest.txt`) leaves
  those files out; `ci-backend.yml` builds and tests what it generates, so a domain type in a platform
  file fails CI.

## 3. Resilience & Data

- **No magic strings or numbers:** a `const` in `{Backend}.Functions/Constants/AppConstants.cs`, or an
  `enum` for anything that drives a branch (`AGENTS.md §3` *Config Separation*).
- **Exceptions** (`AGENTS.md §3` *Exception Safety*): middleware catches everything unhandled and returns
  one error shape. A method uses `try/catch` only to handle the error, or to wrap it in a
  `DomainException` subclass (`{Backend}.Domain/Exceptions/DomainException.cs`).
- **Never concatenate user input into a query** — `stack-dotnet-api.md` §8.2 A03.

## 4. Testing Strategy

- **Test only what `AGENTS.md §3` *Testing* makes mandatory** — on this stack, a validator, an
  authorization check, a capacity/occupancy/pricing rule, date/time/money logic, a repository query, a
  migration, or a shipped-defect regression. A test that only proves a function reaches its service, or
  a DTO mapping, is not written. What is tested covers the standard case, the boundary (empty string,
  max int) and the error case that must throw a specific exception.
- **[STRICT] Filter by class or namespace while iterating;** the unfiltered `dotnet test` is for the
  `/verify` gate before a PR:
  ```bash
  dotnet test --filter "FullyQualifiedName~RequestFunctionListHandlerTests"
  dotnet test --filter "FullyQualifiedName~{Backend}.IntegrationTests.Catalog"   # a whole namespace
  ```
  A full run on every iteration costs time and hides which tests relate to the change.
- **[STRICT] Test data and the unit under test come from shared helpers in
  `{Backend}.IntegrationTests/Helpers/`** — a static `*TestFixtures` class returning a valid
  instance that a test adjusts with `with { … }`, and a factory for a class with more than a few
  constructor dependencies. Pattern: `UserTestFixtures.cs`; `TenantConfigTestFixtures.cs` is enforced by
  `scripts/ci/project/check-test-fixture-builders.sh`.
  **Why:** in S59 T11 one new `required` property edited **10** test files, and removing one
  constructor dependency from `RequestFunction` edited **38** construction sites across **9** files.

## 5. Async Patterns

The C# form of `AGENTS.md §3` *Asynchronous work never blocks*:

- **`async`/`await` all the way.** Never `.Result` or `.Wait()` — they deadlock.
- **Every async method accepts and passes a `CancellationToken`** — endpoints and Entity Framework calls
  above all.
- **Consider `ValueTask<T>`** on a hot path whose result is often already complete.

## 6. Nullable Safety

- **Every project file sets `<Nullable>enable</Nullable>`.**
- **No null-forgiving `null!`** unless a comment directly above it justifies it; handle the null instead.

## 10. Compiler Warnings

- **Every backend project sets `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`.** A warning is
  fixed, never left for later — a new project copies the setting.
- **A project with `PackageReference`s also keeps NuGet audit warnings as warnings:**
  `<WarningsNotAsErrors>$(WarningsNotAsErrors);NU1901;NU1902;NU1903;NU1904</WarningsNotAsErrors>`
  (`{Backend}.Functions.csproj:8`). A newly published advisory must not break a build nobody changed;
  `dotnet list package --vulnerable` at the gate is where it is handled.
- **`NU1510` is therefore an error:** do not add an explicit `PackageReference` to a package the
  framework already provides (e.g. `System.Text.Json`). Recorded in #1001.
