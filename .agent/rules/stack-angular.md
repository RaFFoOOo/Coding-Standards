# FRONTEND SPECIFICATIONS (Angular / TypeScript)

## 1. TypeScript Strictness
- **Type Safety:** - `strict: true` is mandatory.
  - **[ARCHITECT REQUIRED]** The `any` keyword is forbidden. If a type is unknown, use `unknown` and type-guard it, or create a `Generic<T>` interface.
- **Interfaces:** Define explicit interfaces for all Input props (`@Input`), API responses, and Domain models.

## 2. Component Architecture (The "Building Block" Strategy)
- **Smart vs. Dumb Components:**
  - **Dumb (Presentation):** Receive data via `@Input`, emit actions via `@Output`. No dependency on API Services.
  - **Smart (Container):** Orchestrate data fetching and pass it down to Dumb components.
- **Config-Driven UI:**
  - Complex components (Tables, Forms) must accept a `Config` object (e.g., `TableColumnDefinition[]`) rather than hardcoded HTML structures.
- **Performance:**
  - **Change Detection:** Use `ChangeDetectionStrategy.OnPush` by default for all components to maximize rendering efficiency.
  - **Parallel Loading:** When a page needs multiple data sources, use `forkJoin` (RxJS) to load them in parallel. Never chain independent subscriptions (Waterfall effect).
- **Visual Performance:** Avoid Layout thrashing. Use `CSS` transitions instead of JS animations where possible.

## 2a. Modern Angular Standards [STRICT]
- **Control Flow:**
  - **MUST** use the new Control Flow syntax (`@if`, `@for`, `@switch`) instead of legacy directives (`*ngIf`, `*ngFor`).
  - *Reason:* Better type checking, performance, and readability.
- **File Structure:**
  - **Inline Templates/Styles forbidden:** Components must have separate `.html` and `.scss` files unless they display static text < 3 lines.
  - *Reason:* Maintainability and SoC.
- **Standalone Components:** All components must be `standalone: true`.

## 3. Data Service & Mocking Strategy
- **Offline Capability:**
  - **[ARCHITECT REQUIRED]** Every API Service (e.g., `BookingService`) must have a corresponding `MockBookingService`.
  - Use Angular's `environment` flag (`useMocks: true/false`) to switch the provider at the module level.
  - Mock services must return synthetic data with realistic delays (using `delay()` operator) to simulate network latency.

## 4. Assets & Internationalization
- **Text Content:**
  - No hardcoded text in HTML.
  - Use a centralized translation/label file (JSON or Constant Object) to separate content from structure.
- **Styling:**
  - Use CSS Variables (`var(--primary-color)`) defined in a global file.
  - Never use `!important`. Fix the specificity hierarchy instead.

## 5. Debugging & Reliability
- **Error Interception:**
  - Implement a global `HttpInterceptor` to catch errors.
  - Log errors to the console with specific "Reproduction Steps":
    `console.error("Context: [BookingForm]", "Input:", inputData, "Error:", error);`