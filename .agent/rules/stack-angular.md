# FRONTEND SPECIFICATIONS (Angular / TypeScript)

## 1. TypeScript Strictness
- **Type Safety:**
  - `strict: true` is mandatory.
  - **[ARCHITECT REQUIRED]** The `any` keyword is forbidden. If a type is unknown, use `unknown` and type-guard it, or create a `Generic<T>` interface.
- **Interfaces:** Define explicit interfaces for all input properties (`input()`), API responses, and Domain models.

## 2. Component Architecture (The "Building Block" Strategy)
- **Smart vs. Dumb Components:**
  - **Dumb (Presentation):** Receive data via `input()` / `model()`, emit actions via `output()`. No dependency on API Services.
  - **Smart (Container):** Orchestrate data fetching and pass it down to Dumb components.
- **Config-Driven UI:**
  - Complex components (Tables, Forms) must accept a `Config` object (e.g., `TableColumnDefinition[]`) rather than hardcoded HTML structures.
- **Performance:**
  - **Change Detection:** Use `ChangeDetectionStrategy.OnPush` by default for all components to maximize rendering efficiency.
  - **Parallel Loading:** When a page needs multiple data sources, use `forkJoin` (RxJS) to load them in parallel. Never chain independent subscriptions (Waterfall effect).
- **Visual Performance:** Avoid Layout thrashing. Use `CSS` transitions instead of JS animations where possible.

## 2a. Modern Angular Standards [STRICT]
- **Dependency Injection:**
  - **MUST** use the `inject()` function instead of constructor injection for all services and tokens.
- **Control Flow:**
  - **MUST** use the new Control Flow syntax (`@if`, `@for`, `@switch`) instead of legacy directives (`*ngIf`, `*ngFor`).
  - *Reason:* Better type checking, performance, and readability.
- **File Structure:**
  - **Inline Templates/Styles forbidden:** Components must have separate `.html` and `.scss` files unless they display static text < 3 lines.
  - *Reason:* Maintainability and SoC.
- **Standalone Components:** All components must be `standalone: true`.
- **Template Purity:**
  - **No Inline Logic:** Direct property assignment or Signal mutation in templates is forbidden.
    - ❌ `(click)="isOpen = false"` 
    - ❌ `(click)="isOpen.set(false)"`
  - **Explicit Handlers:** Always invoke a dedicated method that encapsulates the logic.
    - ✅ `(click)="closeDropdown()"` where method contains `this.isOpen.set(false)`
  - *Reason:* Enables debugging, testing, and clear separation of concerns.

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
  - **[BEST PRACTICE] Centralized Responsive Variables:** Layout constants (e.g., `--section-padding`, `--section-title-size`) must be defined globally and remapped within a global media query.
    - *Component usage:* Use the context variable `var(--section-padding)` directly.
    - *Benefit:* Avoids clashing/redundant media queries in feature-level SCSS files and maintains a DRY codebase.
  - Never use `!important`. Fix the specificity hierarchy instead.
- **Iconography:**
  - **Strict Ban on Textual Icons:** Never use text characters (e.g., "x", "<", ">", "+") to represent UI controls or icons.
  - **System Alignment:** Use a professional icon library aligned with the chosen Design System (e.g., FontAwesome, Material Icons, Bootstrap Icons).
  - **Implementation:** Render icons using the framework's dedicated component (e.g., `<fa-icon>`, `<mat-icon>`) or optimized SVGs.

## 5. Debugging & Reliability
- **Error Interception:**
  - Implement a global `HttpInterceptor` to catch errors.
  - Log errors to the console with specific "Reproduction Steps":
    `console.error("Context: [BookingForm]", "Input:", inputData, "Error:", error);`

## 6. Memory Safety & Subscriptions
- **Automatic Cleanup:** Use `takeUntilDestroyed()` on all manual RxJS subscriptions.
- **Declarative over Imperative:** Always prefer the `async` pipe or the `toSignal()` function over manually calling `.subscribe()`.
- **Subscription Ban:** It is strictly forbidden to use `.subscribe()` without an explicit cleanup strategy (e.g. `takeUntilDestroyed`, `DestroyRef`, or async pipe).

## 7. Reactive State Management
- **Local State:** Use `signal()` for all mutable component local state.
- **Derived State:** Use `computed()` for values derived from other signals.
- **Side Effects:** Use `effect()` strictly for side-effects (e.g., syncing to local storage, logging, external DOM manipulation) and never for state derivation.
- **Component API:** Use `input()`, `output()`, and `model()` for component communication.
- **Derived overrides:** Use `linkedSignal()` when you need state that is derived from props/inputs but can also be explicitly overridden by the user.

## 8. File & Folder Structure
- **Feature Modules:** Organize code by business feature rather than technical type (e.g., `features/auth/` containing its own components, services, models).
- **Naming Convention:** All Angular files must follow standard `kebab-case` naming (e.g., `user-profile.component.ts`).
- **Barrel Exports:** Use `index.ts` files inside feature folders to explicitly expose only the public API of that feature, preventing deep imports.