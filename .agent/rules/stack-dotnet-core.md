# BACKEND SPECIFICATIONS (ASP.NET Core / C#)

## 1. Syntax & Formatting
- **Indentation:** FORCE 2-space indentation for all `.cs` files to match the frontend standard.
- **Member Ordering:** Fields -> Constructor -> Public Methods -> Private Methods.
- **Immutability:** Use `readonly` for DI fields. Use `record` types for DTOs.

## 2. Architecture & Design Patterns
- **Dependency Injection:** All services must be registered in the DI container. Never use `new`.
- **The Adapter Pattern:** **[ARCHITECT REQUIRED]** Never use a third-party library directly in business logic. Wrap it in an Interface/Adapter.
- **Controller Logic:** Controllers must be "Thin". Logic resides in the Service Layer.

## 3. Resilience
- **Constants:** Strict Ban on Magic Strings/Numbers. Use `AppConstants` class or `Enums`.
- **Exception Handling:** Global Middleware for API errors. `try/catch` only for specific recovery logic.