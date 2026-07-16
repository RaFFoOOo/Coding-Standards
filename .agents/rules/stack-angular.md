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
- **[STRICT] ViewChild Clean Surface**
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
  - **[STRICT] Shared SCSS class ⇒ `@use` its partial** When a component template
    applies a class defined in a shared `src/styles/_*.scss` partial (e.g. `.inline-edit-chip`,
    `.edit-bar`), that component's own `.scss` MUST `@use` the partial. View encapsulation only emits a
    partial's rules into a component's scoped CSS if the component imports it — otherwise the class is
    silently unstyled (the element renders in normal flow). Tell-tale: the styled element is correct on
    some surfaces but not others (the ones missing the `@use`). Related: never put a multi-value
    **shorthand** custom property (e.g. `--section-padding: 2rem 3rem 3rem`) into a single-value property
    (`top`, `right`, …) — the declaration is dropped silently; use single-value tokens. Verify positioning
    by the **computed style**, not the authored rule.
  - **[STRICT] Component Style Budget:** Angular enforces a per-component CSS budget (`anyComponentStyle`). Before adding styles to any component SCSS file or its partials loaded via `@use`, assess the cumulative size.
    - **Shared visual styles** (colors, transitions, borders, typography) that apply to a base element across multiple partials (e.g., grid, list) MUST be defined once in the root component SCSS file. Partials must contain layout-only overrides (sizing, spacing, flex/grid context).
    - **Never duplicate** a style block across two or more partials loaded by the same component — duplication is the primary cause of budget breaches.
    - *Why:* `@use`-imported partial files are bundled into the host component's output CSS. Duplicated rules across partials sum directly against the component's budget.
- **Iconography:**
  - **Strict Ban on Textual Icons:** Never use text characters (e.g., "x", "<", ">", "+") to represent UI controls or icons.
  - **System Alignment:** Use a professional icon library aligned with the chosen Design System (e.g., FontAwesome, Material Icons, Bootstrap Icons).
  - **Implementation:** Render icons using the framework's dedicated component (e.g., `<fa-icon>`, `<mat-icon>`) or optimized SVGs (NOT `<i class="fa-solid">` style — use the framework component for tree-shaking and type safety).
- **[STRICT] Shared UI Primitives**
  - When the same visual block (empty-state, badge, status-pill, etc.) appears in 3+ component templates, extract it into a reusable primitive before adding the 4th instance.
  - Empty-states use a single shared component (e.g. an `EmptyStateComponent` with `[icon]` + `[message]` inputs) — never re-roll a fresh `<div class="empty-state">` block per feature.
  - Recurring status / source badges use global SCSS classes defined once in a shared stylesheet (loaded via the root `styles` entry point) — never redefine the same badge styles in component SCSS.
  - **Why:** duplicated badge SCSS across components and hand-rolled empty-state blocks are a maintenance trap — each copy is a style-drift risk and a CSS-budget consumer.
  - **Consistency across pages [STRICT]:** once a primitive exists, every surface consumes it — a user must never meet the "same" control (search bar, filter panel, confirm/cancel action bar, pagination, cards, badges, empty/loading states) in a different shape, position, or behavior between pages. A second, page-local re-implementation of an existing primitive is a rule violation, not a shortcut: consume the shared component (config-driven via `input()`, per §2) instead of hand-rolling its markup/logic.
  - **Extend, don't fork:** when a page needs a variant, add a config option/input to the shared primitive rather than cloning it. Forking is only allowed when the interaction is genuinely different — and that divergence is recorded, not incidental.
  - **Cross-project candidates:** a primitive generic enough to serve more than one product (e.g. a config-driven `FilterBarComponent`) is a candidate for a shared UX library — evaluate promoting it there before duplicating it into another repo.
- **[STRICT] Filter / search / view bar — one shared component:**
  - Every "list/collection" surface that offers filtering, sorting, free-text search, and/or a view toggle
    MUST use one shared, config-driven `FilterBarComponent` driven by a declarative config object. Bespoke
    per-page filter/search/view layouts are **forbidden** — the bar must look and behave identically on
    every page.
  - **Model concerns separately:** *data* controls (filter facets + sort — they change *which* records show
    or *in what order*) are config facets (single-select chip dropdowns); the *presentation* view
    toggle is its **own** typed slot, rendered set-apart. Never fold view into the facet array or branch on
    `key === 'view'` (data-driven-state smell, `AGENTS.md §2`). Search is an optional slot.
  - The bar is dumb (§2): it emits keyed `facetChange` / `viewChange` / `search`; the host owns
    state + URL sync and builds the config from its signals.
  - **Why:** when multiple surfaces each grow their own filter row, the layout and the sticky/positioning
    SCSS drift; unifying onto one config-driven bar kills the drift and the duplication.
- **[STRICT] Shared dropdown/overlay components MUST close on outside interaction, single-open:**
  - Any shared component that opens a floating/toggleable panel (dropdown, popover, chip-menu) MUST close
    on a `document:click`/focus-out where the event target is outside the component's host, AND must not
    call `stopPropagation()` on its own open-trigger click — that propagation is what lets a sibling
    instance's outside-click listener see the event and dismiss itself, giving "single open at a time" for
    free with zero extra coordination code.
  - ❌ `toggle(event: Event) { event.stopPropagation(); this.isOpen.update(v => !v); }` — blocks a sibling's
    outside-click listener from ever firing; opening dropdown B leaves dropdown A open too.
  - ✅ `toggle() { this.isOpen.update(v => !v); }` + a `@HostListener('document:click')` that closes when
    `!this.eRef.nativeElement.contains(event.target)`.
  - This exact bug has shipped in production (two chip-filter dropdowns stayed open simultaneously) before
    being fixed by removing the `stopPropagation`. Every future shared dropdown/overlay must ship with
    this from day one, not discover it in QA.

- **[STRICT] `<app-bottom-sheet>` (or any `position:fixed` full-viewport overlay component) MUST be a
  root-level template sibling — never nested inside an ancestor that itself is a stacking context
  (`position:sticky`/`fixed` + a `z-index`):**
  - A CSS stacking context composites as ONE unit at its creator's z-index relative to sibling contexts —
    a `position:fixed` descendant's OWN z-index only wins comparisons against other elements inside that
    SAME context; it cannot use its z-index to outrank something outside the context, no matter how high
    the number. Nesting the overlay inside a z-index-having wrapper (e.g. a sticky filter/search bar) traps
    it there, silently losing to any page-level fixed element with a lower-looking-but-actually-unrelated
    z-index (e.g. a fixed `app-action-bar`) — and the visual symptom is confusing: the "losing" element
    can appear to block touch/scroll input on the sheet even when the sheet looks like it's rendering fine.
  - ❌ `<div class="sticky-bar-with-zindex"> ... <app-bottom-sheet>...</app-bottom-sheet> </div>` — the
    sheet is trapped inside the sticky bar's stacking context.
  - ✅ `<div class="sticky-bar-with-zindex">...</div> <app-bottom-sheet>...</app-bottom-sheet>` — sibling
    at the component's template root, competing directly in the ambient/page stacking context.
  - This exact mistake has shipped twice independently in the same codebase — once documented only as an
    inline code comment, and again in an unrelated component that nested its own overlay inside a sticky,
    z-indexed wrapper, only caught via a live screenshot showing a page-level fixed element blocking the
    sheet's lower content and scroll. A comment in one file didn't stop the mistake recurring in another —
    this is now a named, searchable rule instead.

- **[STRICT] A toggleable panel's own open/closed CSS class MUST stay separate from an "active-descendant"
  highlight class — never reuse one class binding for both:**
  - When a collapsed trigger (dropdown, "More" button, nav-group) needs an active-descendant indicator
    (highlighting the trigger because the current route is one of its *contents*, without the panel being
    open) alongside its own real toggle state, these are two independent concerns and MUST bind to two
    separate classes. A shared CSS rule keyed off one class for both the panel's `display`/visibility AND
    the trigger's highlight color means "active-descendant" silently pins the panel visually open the
    moment the route matches — not just highlighted — even though the user never clicked to open it.
  - ❌ `[class.open]="isActiveDescendant() || isManuallyOpened()"` when the SCSS has
    `&.open .panel { display: block }` — visiting a page inside the panel renders it permanently expanded.
  - ✅ `[class.open]="isManuallyOpened()"` (unchanged, drives panel visibility only) +
    `[class.is-active]="isActiveDescendant() || isManuallyOpened()"` (new, drives only the trigger's
    highlight color via `&.is-active .trigger { color: var(--primary) }`) — both classes apply together
    when genuinely open, but only `.is-active` applies when merely active-descendant.
  - This exact bug shipped to production once (a desktop header dropdown highlighted as "active" via
    route match, which also silently forced the panel visually open) and was caught only because live
    QA — a real browser + interaction test, not a unit test with a mocked DOM — happened to be available
    for that PR; a full unit-test pass had already gone green and completely missed it, since it never
    rendered the real CSS cascade. It then **recurred** in a second, unrelated feature that added
    active-descendant highlighting to a different trigger, making the identical mistake — caught again
    only by that PR's own live QA pass. **Grep-on-touch:** before writing a new
    `[class.open]`/visibility binding on any collapsed trigger, grep this file for "active-descendant" —
    if the task's own description matches this rule's trigger condition, re-read this bullet against the
    specific change, not just at session start. Verify any new active-descendant indicator by reading
    the actual `getComputedStyle` of the panel/chevron in a live browser, not just the trigger's own
    signal value in a unit test.

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
- **Never render a raw value as an option label.** Every `<select>` / dropdown option (and any
  user-facing enum) MUST display an **i18n lookup label** resolved per active language — the
  underlying value (`'grid'`, `'order'`, `'website'`, a status enum, …) is for the form control and
  persistence only and must never reach the user verbatim.
- **Option shape:** model options as `{ value, labelKey }[]` and bind
  `<option [value]="opt.value">{{ opt.labelKey | translate }}</option>`. Do **not** bind
  `{{ opt }}` over a bare `string[]`.
- **Consistency:** all selects in a form reuse the same control class as the sibling inputs (e.g.
  `.form-input`) so the field styling is uniform; do not introduce a parallel select style.
- *(Rationale: raw lowercase enum values shipped as option labels (`grid`, `order`) read as
  untranslated and visually inconsistent with the form's labelled fields.)*

## 12. Testing [STRICT]

- **Targeted runs during development:** Never run the full suite while iterating. Pass only the spec
  files (or directories) touched by the current change — the exact command depends on whether the
  project has its own standalone `vitest.config.ts`:
  - **Project has a standalone `vitest.config.ts`** (a hand-built config that mirrors Angular's
    `templateUrl`/`styleUrls` inlining so bare Vitest can JIT-compile components): run it directly —
    ```bash
    npx vitest run src/app/path/to/changed/component/ src/app/path/to/other/spec.ts
    ```
  - **Project has no standalone `vitest.config.ts`** (relies solely on the integrated
    `@angular/build:unit-test` builder to bootstrap Vitest + `TestBed`): a bare `npx vitest run` skips
    that bootstrap and fails immediately with `Need to call TestBed.initTestEnvironment() first`, even
    for specs that are otherwise valid. Use the builder's own filter instead:
    ```bash
    ng test --include 'src/app/path/to/changed/component/**/*.spec.ts' --watch=false
    ```
  - **Don't confuse this with vitest-cache corruption:** the identical `TestBed.initTestEnvironment()`
    error can also come from a stale `node_modules/.vite`/`.vitest` cache on a project that DOES have a
    working `vitest.config.ts` — that class clears with `rm -rf node_modules/.vite node_modules/.vitest`
    and doesn't recur. If the error persists after that, or the project has no `vitest.config.ts` at
    all, it's this config gap, not cache corruption.
  - Full-suite `ng test --watch=false` / `npx vitest run` (no filter) is reserved exclusively for the
    `/run-qa` gate before opening a PR. Running everything on every iteration wastes cycle time and
    obscures which tests actually relate to the work in progress.

- **JIT `input()` limitation:** In Vitest JIT mode, signal inputs declared with `input()` /
  `input.required()` cannot be set via `fixture.componentRef.setInput()` — Angular registers them
  only under AOT. Override the signal field directly on the instance:
  ```typescript
  (component as unknown as { myInput: WritableSignal<T> }).myInput = signal(value);
  ```
  AOT (production build) resolves `input()` normally; this workaround is test-only.

- **`toObservable(signal)` sources flush via `ApplicationRef.tick()`, not `detectChanges()`:** a component-scoped controller (`*-data.controller` / `*-facet.controller`) that sources data
  from `toObservable(someSignal).pipe(switchMap(...))` emits **asynchronously** in JIT — reading a derived
  signal right after `createComponent` returns the `toSignal` `initialValue`, not the data. Do **not**
  reach for `fixture.detectChanges()` to flush: it renders the full template and mounts heavy child
  components whose providers a unit test doesn't supply (`NG0201`). Instead **test the controller directly**
  (provide it in a `TestBed`, `TestBed.inject(TheController)`, mock its deps) and flush its effects with
  `TestBed.inject(ApplicationRef).tick()` — render-free, so no child providers needed. Keep the *component*
  spec to the synchronous thin aliases/handlers. (`flushEffects` is not in Angular 22's public testing API.)

## 13. Routing & Navigation Discoverability [STRICT]
- **No orphan feature routes:** a route meant for repeat/general access — as opposed to a redirect
  target (`/not-found`, `/access-denied`, `/wip`) or a step inside an already-guarded flow — MUST be
  reachable from **persistent UI chrome**: the header icon cluster, the primary/secondary
  `NavigationConfig` nav, a feature-registry menu service, or the account dropdown/hamburger menu.
  A route reachable only via an inline link buried in another page's content is an orphan route, even
  if that link exists — the user has no way back to it except retracing that exact page.
- **Match the entry point to the actual audience — this is the part that's easy to get wrong:**
  - A route meant for **every visitor, including anonymous** (a public content/feature page) needs an
    entry point that is *itself* visible to anonymous visitors — a header icon or the primary nav. The
    account dropdown/hamburger "actions" section does **not** satisfy this if it renders with no items
    (or redirects straight to login) for an unauthenticated visitor, gated by a login-features flag +
    `isAuthenticated()` — an entry placed only there is invisible to exactly the audience a public page
    needs to reach.
  - A route meant only for an **authenticated role that already has a natural hub** (e.g. an owner's
    `/admin`) MAY be reachable one hop from that hub (a dashboard card) without its own persistent
    header entry. This is the established, intentional pattern for admin-only management routes (e.g.
    a user-management or availability-settings page one hop from `/admin`) — do not treat it as license
    to bury a *public-facing* page the same way just because an owner also happens to manage it there.
- **Inline content links are additive, never exclusive:** a "see more" CTA embedded in another page's
  content (e.g. the homepage → a new feature route) is good UX *in addition to* persistent chrome,
  never a substitute for it.
- *(Rationale: a page reachable only via a buried inline link creates a "how did I get here / how do I
  get back" experience — the user has no durable mental model of where the feature lives. Codified
  after a new public-facing page shipped with only an inline homepage link and a dashboard card,
  missing a header entry point anonymous visitors could use.)*
- **Breadcrumb required on every page NOT directly reachable from persistent nav:** a detail/drill-down
  page — reached only by clicking a card/row from a list page, never a direct nav entry (e.g. an entity
  detail route like `/clubs/:id`, `/players/:id`) — is legitimate (it doesn't need its own header/nav
  entry, unlike the orphan-route case above), but it still leaves the user without a durable "where am
  I / how do I get back" cue once they're on it. Every such page MUST render a shared, config-driven
  `BreadcrumbComponent` as the **first element** in its template, before the page header: one crumb per
  level back to the entry list (`routerLink` set, resolved i18n label), ending with the current page's
  own name/title (no link, even if a `routerLink` is supplied for that last item — the component itself
  enforces this).
  - Config-driven, not hardcoded per page: build the trail as a `computed()` `BreadcrumbItem[]` when any
    crumb label is signal-derived (e.g. the entity's own name once resolved) — never a static array
    when the current-page label can change (loading vs. resolved vs. not-found).
  - This is a **STRICT, global** rule (§4's "Consistency across pages" primitive-reuse principle) — an
    in-page "back" link or relying on the browser's own back button is not a substitute; the breadcrumb
    is the uniform mechanism for every surface of this shape, not a per-page judgment call.

## 14. Compact Forms — 12-Column Grid [STRICT]
- **`.form-row` is a Bootstrap-like 12-column CSS Grid**, not an equal-width flex row. Any owner/admin
  form with 2+ fields on a conceptual "row" MUST wrap them in a shared `.form-row` class (defined once,
  e.g. `src/styles/_forms.scss`) and give each direct `.form-field` child an explicit width via
  `.form-col-{n}` — never rely on equal flex-basis distribution (`flex: 1 1 0`) to size fields, and
  never leave a field's width unset inside a `.form-row`.
- **Values are restricted to Bootstrap's common divisors of 12 — `2, 3, 4, 6, 12`** — so every field
  lands on a clean fraction (1/6, 1/4, 1/3, 1/2, full) instead of an ad-hoc percentage. Size each field
  to its actual content, not to "however many siblings it has": a small trigger (icon picker) gets a
  small column (`form-col-2`/`form-col-3`); a free-text title gets a wide one (`form-col-8`+). A row's
  columns do **not** need to sum to 12 — unfilled columns are intentional compactness, not a bug;
  `.form-row` never redistributes leftover space to fill the row.
- **Mobile-first, Bootstrap-named breakpoint override:** the unprefixed `.form-col-{n}` is the
  **default that applies at every size** (including mobile) unless overridden; `.form-col-md-{n}` (a
  desktop breakpoint matching `.form-row`'s own mobile breakpoint) overrides it on desktop only. A
  field MUST NOT always be `form-col-12` (full width) on mobile by default — compact 2-up pairing
  (`form-col-6`) is the mobile baseline for short fields (single-line text inputs, small dropdowns);
  reserve `form-col-12` for content that genuinely needs the full line (a textarea, a 3-way dropdown
  row where the third field is the natural odd-one-out).
  ```html
  <!-- ✅ Mobile pairs 6+6; desktop compacts to 4+8 (title gets more room, id stays narrow) -->
  <div class="form-row">
    <div class="form-field form-col-6 form-col-md-4"> ... type ... </div>
    <div class="form-field form-col-6 form-col-md-8"> ... title ... </div>
  </div>
  <!-- ❌ Equal flex distribution — wastes space when one field's content is much narrower than its
       sibling -->
  <div class="form-row">
    <div class="form-field form-field--inline"> ... icon-picker (small) ... </div>
    <div class="form-field form-field--inline"> ... currency dropdown ... </div>
  </div>
  ```
- **A conditionally-shown field group stays in the same `.form-row` as its trigger control**, not a
  separate nested row below it — e.g. a "Limit bookings" toggle and the two capacity fields it reveals
  sit in one `.form-row` (`toggle: form-col-md-4`, each revealed field `form-col-md-4`) so the revealed
  fields appear *beside* the toggle on desktop, not stacked underneath it. CSS Grid re-flows
  automatically when a conditionally-rendered grid item is added/removed — no extra layout code needed.
- *(Rationale: an equal-flex-distribution approach splits every row's fields evenly regardless of
  content — a small icon-picker trigger next to a currency dropdown each take 50%, leaving a large dead
  gap between them; mobile falls back to full-width stacking even for short single-line inputs that
  could easily pair up. A Bootstrap-like 2/3/4/6/12 proportion system fixes both as a general, durable
  pattern, not a one-off fix to a single form.)*