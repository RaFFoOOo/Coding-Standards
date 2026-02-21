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
- **Authentication/Authorization:** Secure all endpoints by default. Expose explicitly using `[AllowAnonymous]`. Combine Role-based and Policy-based authorization.
- **Input Validation:** Use `FluentValidation` instead of data annotations for DTOs to separate validation logic from data models.
- **CORS & Rate Limiting:** Apply explicit, least-privilege CORS policies and rate limiting middleware for public-facing APIs.