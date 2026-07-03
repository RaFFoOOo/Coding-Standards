---
name: Stack Angular
trigger: glob
globs: ["**/*.ts", "**/*.html", "**/*.scss"]
description: Frontend stack rules for Angular / TypeScript projects
---

# FRONTEND SPECIFICATIONS (Angular / TypeScript)

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
- **[STRICT] ViewChild Clean Surface:**
  - `viewChild()` / `@ViewChild()` references MUST be `private`. Templates must not access child-component internals directly (e.g., `childForm.form.invalid` or `childForm.submit()` in the template is forbidden).
  - Expose proxy signals (`Signal<>` derived from the child via `computed(() => child()?.value())`) and proxy methods (`public foo(): void { this.child()?.foo(); }`) on the parent component. Templates bind only to those.
  - Prefer signal-based `viewChild()` over the legacy decorator `@ViewChild()` — the result is a `Signal<T | undefined>` that integrates naturally with `computed()`.
  - To bridge child reactive-form state into a signal, the child can wire `form.statusChanges.pipe(takeUntilDestroyed()).subscribe(() => versionSignal.update(v => v + 1))` and expose `formInvalid: Signal<boolean> = computed(() => { versionSignal(); return this.form.invalid; })`.
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
- **[STRICT] Interface Parameters Must Use Stable IDs:**
  - Service interface method parameters that identify a resource (tenant, user, entity) MUST use the immutable primary key (`tenantId: string`, `userId: string`) — never a display name, slug, or file-path artifact.
  - If the mock implementation needs a display name for internal file paths, it resolves it from the config service internally. The interface contract is stable and ID-based from day one.
  - ❌ `abstract getAll(tenantName: string): Observable<...>` — name is a display artifact; changes break the interface
  - ✅ `abstract getAll(tenantId: string): Observable<...>` — GUID is immutable; mock resolves name internally

- **[STRICT] Server-state interfaces expose Observable, not Signal:**
  - When a `IFooService` interface represents **server-owned data** (orders, catalog items, reviews, …), every method MUST return `Observable<>`. The interface MUST NOT declare `Signal<>` properties.
  - The mock implementation simulates the backend with a plain in-memory array (NOT signals) and returns observables via `of(…).pipe(delay())`. This makes the interface 1:1 swap-compatible with an HTTP adapter later.
  - The reactive cache (`Signal<>` state) belongs to a separate `FooStateService` (`providedIn: 'root'`) that subscribes to `IFooService` on init and exposes signals to components.
  - ❌ `abstract readonly all: Signal<readonly Foo[]>` in `IFooService`
  - ✅ `abstract getAll(): Observable<Foo[]>` in `IFooService`; `FooStateService.all: Signal<readonly Foo[]>` for consumers.
  - **Exception — client-side state:** an `IAuthService.isAuthenticated: Signal<boolean>`, a config service's `Signal<Config>`, and similar interfaces representing **session-scoped client state** MAY expose signals. Distinguish by ownership: server-owned (Observable) vs. client-projected (Signal).
  - **Why this matters:** an interface that exposes `Signal<>` for server-owned data makes a later HTTP-adapter implementation impossible without breaking every consumer — swapping the in-memory mock for a real backend forces a multi-file migration. Keeping server data behind `Observable<>` from day one reduces that swap to a single-file change.

## 4. Assets & Internationalization
- **Text Content:**
  - No hardcoded text in HTML.
  - Use a centralized translation/label file (JSON or Constant Object) to separate content from structure.
- **Styling:**
  - Use CSS Variables (`var(--primary)`) defined in a global theme file (e.g., `_theme-variables.scss`).
  - **[BEST PRACTICE] Dual Token Pattern for Alpha Transparency:** When defining a theme color, always provide both the hex token and a companion `-rgb` token (e.g., `--primary: #79C1B0; --primary-rgb: 121, 193, 176;`). This enables `rgba(var(--primary-rgb), <alpha>)` without preprocessor functions.
  - **[BEST PRACTICE] Centralized Responsive Variables:** Layout constants (e.g., `--section-padding`, `--section-title-size`) must be defined globally and remapped within a global media query.
    - *Component usage:* Use the context variable `var(--section-padding)` directly.
    - *Benefit:* Avoids clashing/redundant media queries in feature-level SCSS files and maintains a DRY codebase.
    - **[STRICT] Token Scope Awareness:** Hero/landing-page tokens (e.g., `--section-title-size: 3.5rem`) are sized for splash contexts. Inner pages (admin panels, account pages, detail views) MUST define their own smaller heading sizes locally — never reuse hero tokens for inner-page typography.
  - Never use `!important`. Fix the specificity hierarchy instead.
  - **[STRICT] Shared SCSS class ⇒ `@use` its partial:** When a component template applies a class defined in a shared `src/styles/_*.scss` partial (e.g. a chip or bar class), that component's own `.scss` MUST `@use` the partial. View encapsulation only emits a partial's rules into a component's scoped CSS if the component imports it — otherwise the class is silently unstyled (the element renders in normal flow). Tell-tale: the styled element is correct on some surfaces but not others (the ones missing the `@use`). Related: never put a multi-value **shorthand** custom property (e.g. `--section-padding: 2rem 3rem 3rem`) into a single-value property (`top`, `right`, …) — the declaration is dropped silently; use single-value tokens. Verify positioning by the **computed style**, not the authored rule.
  - **[STRICT] Component Style Budget:** Angular enforces a per-component CSS budget (`anyComponentStyle`). Before adding styles to any component SCSS file or its partials loaded via `@use`, assess the cumulative size.
    - **Shared visual styles** (colors, transitions, borders, typography) that apply to a base element across multiple partials (e.g., grid, list) MUST be defined once in the root component SCSS file. Partials must contain layout-only overrides (sizing, spacing, flex/grid context).
    - **Never duplicate** a style block across two or more partials loaded by the same component — duplication is the primary cause of budget breaches.
    - *Why:* `@use`-imported partial files are bundled into the host component's output CSS. Duplicated rules across partials sum directly against the component's budget.
- **Iconography:**
  - **Strict Ban on Textual Icons:** Never use text characters (e.g., "x", "<", ">", "+") to represent UI controls or icons.
  - **System Alignment:** Use a professional icon library aligned with the chosen Design System (e.g., FontAwesome, Material Icons, Bootstrap Icons).
  - **Implementation:** Render icons using the framework's dedicated component (e.g., `<fa-icon>`, `<mat-icon>`) or optimized SVGs (NOT `<i class="fa-solid">` style — use the framework component for tree-shaking and type safety).
- **[STRICT] Shared UI Primitives:**
  - When the same visual block (empty-state, badge, status-pill, etc.) appears in 3+ component templates, extract it into a reusable primitive before adding the 4th instance.
  - Empty-states use a single shared component (e.g. an `EmptyStateComponent` with `[icon]` + `[message]` inputs) — never re-roll a fresh `<div class="empty-state">` block per feature.
  - Recurring status / source badges use global SCSS classes defined once in a shared stylesheet (loaded via the root `styles` entry point) — never redefine the same badge styles in component SCSS.
  - **Why:** duplicating badge SCSS across components and hand-rolling empty-state blocks per feature is a maintenance trap — every copy drifts independently on a style change, and each duplicate counts against the per-component CSS budget.
  - **Consistency across pages [STRICT]:** once a primitive exists, every surface consumes it — a user must never meet the "same" control (search bar, filter panel, confirm/cancel action bar, pagination, cards, badges, empty/loading states) in a different shape, position, or behavior between pages. A second, page-local re-implementation of an existing primitive is a rule violation, not a shortcut: consume the shared component (config-driven via `input()`, per §2) instead of hand-rolling its markup/logic.
  - **Extend, don't fork:** when a page needs a variant, add a config option/input to the shared primitive rather than cloning it. Forking is only allowed when the interaction is genuinely different — and that divergence is recorded, not incidental.
  - **Cross-project candidates:** a primitive generic enough to serve more than one product (e.g. a config-driven `FilterBarComponent`) is a candidate for a shared UX library — evaluate promoting it there before duplicating it into another repo.
- **[STRICT] Filter / search / view bar — one shared component:**
  - Every "list/collection" surface that offers filtering, sorting, free-text search, and/or a view toggle MUST use one shared, config-driven `FilterBarComponent` driven by a declarative config object. Bespoke per-page filter/search/view layouts are **forbidden** — the bar must look and behave identically on every page.
  - **Model concerns separately:** *data* controls (filter facets + sort — they change *which* records show or *in what order*) are config facets (single-select chip dropdowns); the *presentation* view toggle is its **own** typed slot, rendered set-apart. Never fold view into the facet array or branch on `key === 'view'` (data-driven-state smell, `AGENTS.md §2`). Search is an optional slot.
  - The bar is dumb (§2): it emits keyed `facetChange` / `viewChange` / `search`; the host owns state + URL sync and builds the config from its signals.
  - **Why:** when multiple surfaces each grow their own filter row, the layout and the sticky/positioning SCSS drift; unifying onto one config-driven bar kills the drift and the duplication.

## 5. Debugging & Reliability
- **Error Interception:**
  - Implement a global `HttpInterceptor` to catch errors.
  - Log errors to the console with specific "Reproduction Steps":
    `console.error("Context: [ComponentName]", "Input:", inputData, "Error:", error);`

## 6. Memory Safety & Subscriptions
- **Automatic Cleanup:** Use `takeUntilDestroyed()` on all manual RxJS subscriptions.
- **Declarative over Imperative:** Always prefer the `async` pipe or the `toSignal()` function over manually calling `.subscribe()`.
- **Subscription Ban:** It is strictly forbidden to use `.subscribe()` without an explicit cleanup strategy (e.g. `takeUntilDestroyed`, `DestroyRef`, or async pipe).
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
- **[STRICT] Optimistic Server-State Updates:** When a component must render an
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

## 8. File & Folder Structure
- **Feature Modules:** Organize code by business feature rather than technical type (e.g., `features/auth/` containing its own components, services, models).
- **Naming Convention:** All Angular files must follow standard `kebab-case` naming (e.g., `user-profile.component.ts`).
- **Barrel Exports:** Use `index.ts` files inside feature folders to explicitly expose only the public API of that feature, preventing deep imports.

## 9. ngx-translate Runtime Usage [STRICT]
- **`instant()` Timing Rule:** Never call `TranslateService.instant()` before `translate.use(lang)` has resolved. The HTTP loader fires lazily — calling `instant()` before the Observable completes returns the raw key string silently.
  - **Correct pattern in APP_INITIALIZER / async init methods:**
    ```typescript
    // 1. Merge tenant translations
    this.translate.setTranslation(lang, data, true);
    // 2. Wait for the global file to load
    await firstValueFrom(this.translate.use(lang));
    // 3. Now instant() is safe
    const label = this.translate.instant('LANG.it');
    ```
- **Tenant Translation Files:** Per-tenant content (slogans, page copy) must live in
  `assets/mock/{tenantName}/lang/{langCode}.json` under the `TENANT.*` namespace.
  Global UI strings (NAV, CONTACT, etc.) stay in `assets/i18n/{langCode}.json`.
- **Language Codes in Config, Labels in i18n:** `TenantConfig.supportedLanguages` holds ISO codes
  only (`['it', 'en']`). Display labels are resolved at runtime from `LANG.{code}` keys in the
  global i18n files — never hardcoded in components or tenant config.
- **`@for` over translated arrays [STRICT]:** Never use `@for` directly over a `translate` pipe result without an array-length guard. If the key is missing or translations haven't resolved, the pipe returns the raw key string and `@for` iterates its characters silently.
  ```html
  <!-- ✅ Safe -->
  @if (arrayKey() | translate; as items) {
    @if ($any(items).length) {
      @for (item of items; track $index) { ... }
    }
  }
  <!-- ❌ Unsafe -->
  @for (item of (arrayKey() | translate); track $index) { ... }
  ```

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

## 11. Select / Dropdown Option Labeling [STRICT]
- **Never render a raw value as an option label.** Every `<select>` / dropdown option (and any user-facing enum) MUST display an **i18n lookup label** resolved per active language — the underlying value (`'grid'`, `'order'`, a status enum, …) is for the form control and persistence only and must never reach the user verbatim.
- **Option shape:** model options as `{ value, labelKey }[]` and bind `<option [value]="opt.value">{{ opt.labelKey | translate }}</option>`. Do **not** bind `{{ opt }}` over a bare `string[]`.
- **Consistency:** all selects in a form reuse the same control class as the sibling inputs (e.g. `.form-input`) so the field styling is uniform; do not introduce a parallel select style.

## 12. Testing [STRICT]
- **Targeted runs during development:** Never run the full test suite while iterating. Pass only the spec files (or directories) touched by the current change:
  ```bash
  npx vitest run src/app/path/to/changed/component/ src/app/path/to/other/spec.ts
  ```
  Full-suite `npx vitest run` (no filter) is reserved exclusively for the pre-PR QA gate. Running everything on every iteration wastes time and obscures which tests actually relate to the work in progress.
- **JIT `input()` limitation:** In Vitest JIT mode, signal inputs declared with `input()` / `input.required()` cannot be set via `fixture.componentRef.setInput()` — Angular registers them only under AOT. Override the signal field directly on the instance:
  ```typescript
  (component as unknown as { myInput: WritableSignal<T> }).myInput = signal(value);
  ```
  AOT (production build) resolves `input()` normally; this workaround is test-only.
- **`toObservable(signal)` sources flush via `ApplicationRef.tick()`, not `detectChanges()`:** a component-scoped controller that sources data from `toObservable(someSignal).pipe(switchMap(...))` emits **asynchronously** in JIT — reading a derived signal right after `createComponent` returns the `toSignal` `initialValue`, not the data. Do **not** reach for `fixture.detectChanges()` to flush: it renders the full template and mounts heavy child components whose providers a unit test doesn't supply (`NG0201`). Instead **test the controller directly** (provide it in a `TestBed`, `TestBed.inject(TheController)`, mock its deps) and flush its effects with `TestBed.inject(ApplicationRef).tick()` — render-free, so no child providers needed. Keep the *component* spec to the synchronous thin aliases/handlers.