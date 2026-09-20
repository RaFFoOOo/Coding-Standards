---
name: Stack Angular
trigger: glob
globs: ["**/*.ts", "**/*.html"]
description: Angular/TypeScript architecture, state, DI and structure
---

# Stack Angular

## 1. TypeScript Strictness
- **Type Safety:**
  - `strict: true` is mandatory.
  - **[ARCHITECT REQUIRED]** The `any` keyword is forbidden. If a type is unknown, use `unknown` and type-guard it, or create a `Generic<T>` interface.
- **Interfaces:** Define explicit interfaces for all input properties (`input()`), API responses, and Domain models.
- **[STRICT] Explicit Property Types:** Every class property (component or service) **MUST** carry an explicit type annotation — no reliance on TypeScript inference alone.
  - This applies to all `readonly` fields, injected service aliases, `computed()` signals, `toSignal()` results, and any other class-level declaration.
  - For Angular signals, always declare the full generic form: `Signal<T>`, `InputSignal<T>`, `WritableSignal<T>`, `ModelSignal<T>`.
  - ❌ `readonly isReady = computed(() => true)`
  - ✅ `readonly isReady: Signal<boolean> = computed(() => true)`

## 2. Component Architecture (The "Building Block" Strategy)
- **Smart vs. Dumb Components:**
  - **Dumb (Presentation):** Receive data via `input()` / `model()`, emit actions via `output()`. No dependency on API Services.
  - **Smart (Container):** Orchestrate data fetching and pass it down to Dumb components.
- **Config-Driven UI:**
  - Complex components (Tables, Forms) must accept a `Config` object (e.g., `TableColumnDefinition[]`) rather than hardcoded HTML structures.
- **Reactive Forms — `FormArray` Hierarchy:**
  - A `formArrayName` directive MUST be present on the parent container element before any `[formGroupName]="index"` children can resolve their controls. Angular reactive forms fail silently without it — the error `Cannot find control with path: 'N -> fieldName'` indicates a missing `formArrayName` ancestor.
- **Client-side validation is UX, not security [STRICT]:** Form/`Validators` checks exist for fast feedback only — the server re-validates everything and is the real boundary (`AGENTS.md §3 Dual-Side Validation`). Mirror each server constraint (allowed values, patterns, required, range) in the form so the client never submits what the backend will reject, but **never** treat a client check as sufficient, and never ship a constraint that exists only on the client.
- **Performance:**
  - **Change Detection:** Use `ChangeDetectionStrategy.OnPush` by default for all components to maximize rendering efficiency.
  - **Parallel Loading:** When a page needs multiple data sources, use `forkJoin` (RxJS) to load them in parallel. Never chain independent subscriptions (Waterfall effect).
- **[STRICT] A component is CREATED only if it is RENDERED — never `display: none` a whole component.**
  A component shown at only one breakpoint (or in only one state) MUST be gated by `@if`, not hidden
  with CSS. `display: none` suppresses **paint, not work**: Angular still constructs the component,
  builds its DOM subtree, and runs every subscription it opens — including HTTP requests whose
  response nothing can ever render.
  ```html
  <!-- ❌ created at every width; the hidden one still fetches and still builds its subtree -->
  <app-footer></app-footer>          <!-- footer.scss: @media (max-width: 768px) { display: none } -->
  <app-mobile-nav></app-mobile-nav>  <!-- mobile-nav.scss: :host { display: none } on desktop -->

  <!-- ✅ exactly one of them exists -->
  @if (isDesktop()) { <app-footer /> } @else { <app-mobile-nav /> }
  ```
  **Measured, which is why this is STRICT rather than advice** (2026-09-01, Home at 375px): with the
  footer hidden by a media query it still built **14 DOM nodes** and still fired its own
  `contact.json` request — **3 identical fetches** on one page. Gating it with `@if` took that to
  **1 request and 0 nodes**. The waste is invisible to every gate this project runs: the layout is
  correct, the tests pass, and nothing renders wrong. It is visible only in a network panel.
  - **Use `ViewportService`** (`core/services/ui`) for the breakpoint signal — `matchMedia`-backed, so
    it fires only when the query result actually flips, unlike a `resize` listener. Do not hand-roll
    a second one, and do not read `window.innerWidth` in a component.
  - **CSS media queries remain correct for LAYOUT** — spacing, columns, font sizes, and hiding an
    *inner element* of a component that is rendering anyway. The ban is on hiding a **whole
    component** that way. The test is simple: if the thing you are hiding has its own selector in a
    template, it should be an `@if`.
  - **`jsdom` has no `matchMedia`.** Anything reaching the viewport throws
    `window.matchMedia is not a function` and takes down its entire spec file, not one test — this
    broke all 5 of `app.spec.ts` when the shell first injected `ViewportService`. `src/test-setup.ts`
    stubs it, defaulting to `matches: false` (desktop) because every query in this app is a
    `max-width` mobile query. A stub answering `true` would silently put every spec in a mobile
    layout nothing asked for.
- **Visual Performance:** Avoid Layout thrashing. Use `CSS` transitions instead of JS animations where possible.

## 2a. Modern Angular Standards [STRICT]
- **Dependency Injection:**
  - **MUST** use the `inject()` function instead of constructor injection for all services and tokens.
  - **Strict Interface Tokens:** When providing a concrete Mock class mapping to an abstract interface token in `app.config.ts`, components **MUST** strictly invoke `inject(ITokenInterface)`, never the concrete class directly.
  - **Ambient Provider Ban:** Concrete Mock classes intentionally bound within `app.config.ts` providers MUST NOT declare `@Injectable({ providedIn: 'root' })`. This forces explicit dependency resolution failures over silent uninitialized dual-instantiations if developers accidentally breach token mappings.
- **[STRICT] Service Decoupling from Templates:**
  - Injected services **MUST** always be declared `private`. Templates must never call service methods or access service signals directly (e.g., `myService.someSignal()` in HTML is forbidden).
  - Expose named `readonly` component properties (computed signals or direct signal aliases) that delegate to the service internally. Templates bind only to component properties.
  - ❌ `[value]="myService.someSignal()"` in template
  - ✅ `readonly someValue = this.myService.someSignal;` in component, then `[value]="someValue()"` in template
- **[STRICT] ViewChild Clean Surface**
  - `viewChild()` / `@ViewChild()` references MUST be `private`. Templates must not access child-component internals directly (e.g., `childForm.form.invalid` or `childForm.submit()` in the template is forbidden).
  - Expose proxy signals (`Signal<>` derived from the child via `computed(() => child()?.value())`) and proxy methods (`public foo(): void { this.child()?.foo(); }`) on the parent component. Templates bind only to those.
  - Prefer signal-based `viewChild()` over the legacy decorator `@ViewChild()` — the result is a `Signal<T | undefined>` that integrates naturally with `computed()`.
  - To bridge child reactive-form state into a signal, the child can wire `form.statusChanges.pipe(takeUntilDestroyed()).subscribe(() => versionSignal.update(v => v + 1))` and expose `formInvalid: Signal<boolean> = computed(() => { versionSignal(); return this.form.invalid; })`.
  - **[STRICT] Imperative-only form flags need their own manual version bump:** `value`/`status` always
    have a matching `Observable` (`valueChanges`/`statusChanges`) to key a bridge's version counter off
    of. `dirty`/`pristine` and `touched`/`untouched` do **not** — `markAsPristine()`, `markAsDirty()`,
    `markAsUntouched()`, and `reset()`'s touched-reset all mutate the flag directly with **no** emission
    on either observable. A bridge for one of these flags must bump its own version signal at every call
    site that mutates the flag programmatically, in the same method — there is no event to subscribe to
    instead. Found in a form-dirty-tracking controller: a
    `valueChanges`-keyed `isDirty` bridge kept reading stale `true` forever after a legitimate save,
    because the save handler's own `form.markAsPristine()` never woke the bridge — fixed by bumping the
    version counter inside `markSaved()` itself, alongside the `markAsPristine()` call.
- **Control Flow:**
  - **MUST** use the new Control Flow syntax (`@if`, `@for`, `@switch`) instead of legacy directives (`*ngIf`, `*ngFor`).
- **File Structure:**
  - **Inline Templates/Styles forbidden:** Components must have separate `.html` and `.scss` files unless they display static text < 3 lines.
- **Standalone Components:** All components must be `standalone: true`.
- **Template Purity:**
  - **No Inline Logic:** Direct property assignment or Signal mutation in templates is forbidden.
    - ❌ `(click)="isOpen = false"` 
    - ❌ `(click)="isOpen.set(false)"`
  - **Explicit Handlers:** Always invoke a dedicated method that encapsulates the logic.
    - ✅ `(click)="closeDropdown()"` where method contains `this.isOpen.set(false)`

## 3. Data Service & Mocking Strategy
- **Offline Capability:**
  - **[ARCHITECT REQUIRED]** Every API Service (e.g., `BookingService`) must have a corresponding `MockBookingService`.
  - Switch providers per-service via a `ServiceMode` flag (`'Mock' | 'Http'`), not a single global `useMocks` boolean. Each service flips independently in `environment.*.ts` (e.g. under a `services.*` map) and is wired via a per-service provider factory (e.g. `provideByMode(token, MockCtor, HttpCtor, mode)`) in the app's providers config.
  - Mock services must return synthetic data with realistic delays (using `delay()` operator) to simulate network latency.
- **Local Environment Secure Mocking:**
  - Mock configuration payloads tracked in version control (e.g., `app-config.json`) **MUST NEVER** contain hardcoded secrets or SAS tokens.
  - To mock backend-level secure payload injections natively during local development, the consuming Mock Service MUST intercept the parsed JSON structure and dynamically merge active secrets isolated securely within `environment.development.ts` into the configuration state prior to distribution.
- **[STRICT] Data Layer vs. Shared Behavior Separation:**
  - `IFoo` / `MockFooService` implementations are **data-source adapters only**. They fetch, transform, and register data. They MUST NOT own reactive state (signals), persist user preferences, or contain business logic.
  - Shared state, derived signals, user preference persistence, and cross-component behavior MUST live in a dedicated `FooService` annotated `@Injectable({ providedIn: 'root' })` — following the `CartService` / `TranslationService` / `AuthService` pattern.
  - The shared service is the single source of truth consumed by components. The data-layer interface is an internal collaborator injected by the shared service.
  - ❌ Signals, `switchLanguage()`, persistence calls inside `MockLanguageService`
  - ✅ `MockLanguageService` → loads files; `TranslationService` → owns signals, activation, persistence
  - **[PRE-QA CHECK]:** Before committing any new `IFoo`/`MockFooService`, verify it contains NO `signal()`, `WritableSignal`, `computed()`, or `localStorage` calls. If any are present, extract them to a dedicated `FooService` first. Catching this at authoring time avoids a full PR-cycle rework.
- **[STRICT] Interface Parameters Must Use Stable IDs**
  - Service interface method parameters that identify a resource (tenant, user, entity) MUST use the immutable primary key (`tenantId: string`, `userId: string`) — never a display name, slug, or file-path artifact.
  - If the mock implementation needs a display name for internal file paths, it resolves it from the config service internally. The interface contract is stable and ID-based from day one.
  - ❌ `abstract getAll(tenantName: string): Observable<...>` — name is a display artifact; changes break the interface
  - ✅ `abstract getAll(tenantId: string): Observable<...>` — GUID is immutable; mock resolves name internally

- **[STRICT] Server-state interfaces expose Observable, not Signal**
  - When a `IFooService` interface represents **server-owned data** (orders, catalog items, reviews, …), every method MUST return `Observable<>`. The interface MUST NOT declare `Signal<>` properties.
  - The mock implementation simulates the backend with a plain in-memory array (NOT signals) and returns observables via `of(…).pipe(delay())`. This makes the interface 1:1 swap-compatible with an HTTP adapter later.
  - The reactive cache (`Signal<>` state) belongs to a separate `FooStateService` (`providedIn: 'root'`) that subscribes to `IFooService` on init and exposes signals to components.
  - ❌ `abstract readonly all: Signal<readonly Foo[]>` in `IFooService`
  - ✅ `abstract getAll(): Observable<Foo[]>` in `IFooService`; `FooStateService.all: Signal<readonly Foo[]>` for consumers.
  - **Exception — client-side state:** `IAuthService.isAuthenticated: Signal<boolean>`, a config service's `Signal<Config>`, and similar interfaces representing **session-scoped client state** MAY expose signals. Distinguish by ownership: server-owned (Observable) vs. client-projected (Signal).
  - **Why this matters:** an interface exposing `Signal<>` for server-owned data makes a later HTTP-adapter swap impossible without breaking every consumer — caught early it is a small extraction; caught after backend integration it is a fire-drill across dozens of files.

## 5. Debugging & Reliability
- **Error Interception:**
  - Implement a global `HttpInterceptor` to catch errors.
  - Log errors to the console with specific "Reproduction Steps":
    `console.error("Context: [ComponentName]", "Input:", inputData, "Error:", error);`

## 6. Memory Safety & Subscriptions
- **Automatic Cleanup:** Use `takeUntilDestroyed()` on all manual RxJS subscriptions.
- **Declarative over Imperative:** Always prefer the `async` pipe or the `toSignal()` function over manually calling `.subscribe()`.
- **Subscription Ban:** It is strictly forbidden to use `.subscribe()` without an explicit cleanup strategy (e.g. `takeUntilDestroyed`, `DestroyRef`, or async pipe).
- **`take(1)`-only exception — non-destroyable `providedIn: 'root'` singletons only [STRICT]:** A
  bare `.pipe(take(1))` with no `takeUntilDestroyed()` is permitted **only** inside a
  `providedIn: 'root'` singleton service, where the subscriber is never destroyed during the app's
  lifetime — `takeUntilDestroyed()` there needs an injection-context/`DestroyRef` contrivance for
  code that never fires it, which is worse than the plain `take(1)` it would "fix." Every other
  subscriber (a component, a component-scoped controller, or any injectable with a real
  `DestroyRef`) MUST combine both: `.pipe(take(1), filter(Boolean), takeUntilDestroyed(this.destroyRef))`
  — `take(1)` self-completes on the expected single emission (e.g. a confirm-dialog result, a
  one-shot upload), `takeUntilDestroyed()` is the safety net if the component unmounts first. This
  is already the established pattern for confirm-dialog subscriptions
  (`services-inline-edit.controller.ts`, `catalog-grid-edit.coordinator.ts`) — codified here after
  `order-state.service.ts` (a singleton, correctly `take(1)`-only) and `booking.component.ts`/
  `media-upload.component.ts` (components, now converted to the combined pattern) were found
  diverging on the same shape without a documented rule (2026-07-18).
- **Route Param Signals [STRICT]:** Never derive a reactive signal from route params by calling `.subscribe()` and invoking `.set()` inside the callback. Always use `toSignal()` at the class field level:
  ```typescript
  // ✅ Correct
  readonly catalogType = toSignal(
    this.route.paramMap.pipe(map(params => params.get('catalogType') ?? '')),
    { initialValue: '' }
  );

  // ❌ Wrong — sets a signal inside a subscription
  readonly catalogType = signal('');
  ngOnInit() {
    this.route.paramMap.subscribe(params => this.catalogType.set(params.get('catalogType') ?? ''));
  }
  ```

## 7. Reactive State Management
- **Local State:** Use `signal()` for all mutable component local state.
- **Derived State:** Use `computed()` for values derived from other signals.
- **Side Effects:** Use `effect()` strictly for side-effects (e.g., syncing to local storage, logging, external DOM manipulation) and never for state derivation.
- **Component API:** Use `input()`, `output()`, and `model()` for component communication.
- **Derived overrides:** Use `linkedSignal()` when you need state that is derived from props/inputs but can also be explicitly overridden by the user.
- **[STRICT] Optimistic Server-State Updates** When a component must render an
  async server-owned list AND accept optimistic local mutations (role change, status toggle, etc.),
  layer signals as `toSignal(httpStream$, { initialValue }) → linkedSignal(() => serverSignal())`.
  - `toSignal` owns the reactive subscription to the http source.
  - `linkedSignal` exposes a `WritableSignal` consumers can `.update(...)` for optimistic edits.
  - On source re-emit (route param / tenant switch / refetch), `linkedSignal` automatically
    resets to the new server value — discarding stale optimistic overrides without ceremony.
  - On PATCH failure, revert by `.update(...)`-ing the previous value back into `linkedSignal`.
  - **Anti-pattern banned by this rule:** constructor-side-effect `loadX()` + `WritableSignal<T>` +
    imperative `_signal.set(response)` inside `.subscribe()`. That stack drops switchMap
    cancellation on rapid tenant switches and rebuilds what `linkedSignal` already gives you
    for free. The reactive pattern is mandatory for any new component fitting this shape;
    legacy components should be migrated when next touched.
- **[STRICT] Subordinate/dependent filters must stay reactively consistent with their parent:**
  - When one facet's valid option set depends on another facet's current selection (e.g. a catalog
    "category" filter that only makes sense within the active "type"), the subordinate's options MUST be
    a `computed()` derived from the parent's current value — never a static/pre-fetched list — and the
    subordinate's own selection MUST be reset (to its "All" value) the moment it becomes invalid under a
    new parent value. Never leave a stale child selection referencing an option that no longer exists
    under the new parent.
  - ✅ Reference pattern: a `categoryOptions` computed signal derives from an `availableCategories()`
    computed signal, itself derived from the active `type` selection; `setType()` explicitly clears
    `selectedCategory` when it no longer exists in the new set.
  - **Why:** an inconsistent child filter either shows the user options that silently produce zero
    results (bug), or worse, keeps a stale selection active that the UI no longer displays a chip for —
    invisible, unrecoverable-without-refresh state. Codified after Tech-Lead review confirmed this pattern
    must generalize beyond catalog type→category to any future dependent-filter pair.

## 8. File & Folder Structure
- **Feature Modules:** Organize code by business feature rather than technical type (e.g., `features/auth/` containing its own components, services, models).
- **Naming Convention:** All Angular files must follow standard `kebab-case` naming (e.g., `user-profile.component.ts`).
- **Barrel Exports:** Use `index.ts` files inside feature folders to explicitly expose only the public API of that feature, preventing deep imports.

## 10. Multi-Tenant Architecture [STRICT]
- **Resource Resolution:**
  - **MUST** resolve all brand-specific brand assets (logos, favicons, primary images) dynamically via the `ITenantConfigService.getResourceUrl()` pattern.
  - Hardcoded paths to tenant assets in the `assets/` directory are forbidden for multi-tenant features.
- **Data Segregation:**
  - **MUST** use tenant-segregated keys for all browser-side persistence (localStorage, sessionStorage).
  - Implementation: Keys must be prefixed with a unique tenant identifier (e.g., `{appPrefix}_{tenantId}_{key}`).
- **Mode-Aware UI:**
  - Standard components (Booking, Catalog) must adapt their behavior and terminology based on the `businessType` signal from `ITenantConfigService` to support diverse business models (e.g., Reservation vs. Order).
- **Mode Logic Centralization [STRICT]:**
  - When a config value drives conditional behavior across multiple components (e.g., a `businessType`, `userRole`, or `featureFlag`), create a dedicated injectable service that exposes named boolean signals and config methods derived from that value.
  - Direct string comparisons against config values (e.g., `config.type === 'x'`) are **forbidden** in components and templates. Components consume named signals from the centralized service instead.
  - Config methods on the service (e.g., `getDatePickerConfig()`, `getFormValidators()`) return typed config objects — templates bind to their properties rather than containing inline conditional expressions.
