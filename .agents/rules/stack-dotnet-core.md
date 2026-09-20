---
name: Stack .NET Core
trigger: glob
globs: ["**/*.cs"]
description: C# syntax, architecture, testing, async and nullability
---

# Stack .NET Core

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

## 4. Testing Strategy
- **Equivalence Classes:** Tests must cover:
  1.  **Standard Case:** Typical valid data.
  2.  **Boundary Case:** Min/Max values (e.g., empty strings, max int).
  3.  **Error Case:** Invalid inputs that should trigger specific exceptions.
- **[STRICT] Targeted runs during development:** Never run the full integration-test suite while
  iterating. Filter by the class or namespace under change:
  ```bash
  dotnet test --filter "FullyQualifiedName~SomeHandlerTests"
  # or by namespace:
  dotnet test --filter "FullyQualifiedName~<YourApp>.IntegrationTests.<Area>"
  ```
  Full-suite `dotnet test` (no filter) is reserved exclusively for the `/run-qa` gate before opening
  a PR. Running everything on every iteration wastes significant time and masks which tests actually
  relate to the work in progress.

## 5. Async Patterns
- **Async All The Way:** Always use `async` and `await` for I/O bound operations. Never use `.Result` or `.Wait()` (prevents deadlocks).
- **Cancellation Tokens:** All async methods, especially Controller endpoints and Entity Framework calls, MUST accept and pass a `CancellationToken`.
- **ValueTask:** Consider using `ValueTask<T>` instead of `Task<T>` for hot-paths where the result might frequently be completed synchronously.

## 6. Nullable Safety
- **Strict Nullables:** Project files must have `#nullable enable` turned on.
- **Suppression Ban:** Do not use the null-forgiving operator (`null!`) unless you can explicitly justify it in a comment above the statement. Handle possible nulls explicitly.
