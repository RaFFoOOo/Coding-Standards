# BACKEND SPECIFICATIONS (ASP.NET Core / C#)

## 1. Syntax & Formatting
- **Indentation:** FORCE 2-space indentation for all `.cs` files to match the frontend standard.
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