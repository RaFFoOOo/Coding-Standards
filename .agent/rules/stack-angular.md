# FRONTEND SPECIFICATIONS (Angular / TypeScript)

## 1. TypeScript Strictness
- **Type Safety:** `strict: true` is mandatory.
- **[ARCHITECT REQUIRED]** The `any` keyword is forbidden. Use `unknown` with type guards or `Generic<T>` interfaces.

## 2. Component Architecture
- **Smart vs. Dumb:** Separate Container (Smart) and Presentation (Dumb) components.
- **Config-Driven UI:** Complex components must use Configuration Objects, not hardcoded HTML.
- **Performance:** Use `ChangeDetectionStrategy.OnPush`. Use `forkJoin` for parallel data loading.

## 3. Data Service & Mocking
- **Offline Capability:** **[ARCHITECT REQUIRED]** Every API Service must have a `Mock` version.
- **Latency Simulation:** Mock services must use `delay()` to simulate realistic network behavior.

## 4. Assets & Styling
- **No Style Inlining:** No CSS in HTML.
- **Theming:** Use CSS Variables defined in global files. Never use `!important`.
- **Debugging:** Log errors with specific "Reproduction Steps" via a global Error Interceptor.