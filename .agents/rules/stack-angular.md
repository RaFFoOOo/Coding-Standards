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
  - **[STRICT] …and never nest a shorthand token inside another shorthand — that failure is *worse*
    than the dropped one above.** Substituting a multi-value token into a shorthand **slot** yields
    valid CSS with a silently wrong meaning, so nothing is dropped and nothing warns:
    ```scss
    // ❌ --section-padding is `2rem 3rem 3rem`, so this expands to `padding: 0 2rem 3rem 3rem`
    //    → top 0 · right 2rem · bottom 3rem · LEFT 3rem. Horizontally asymmetric, plus a bottom
    //    padding nobody wrote. Valid CSS. No error. Survived review for three sprints.
    padding: 0 var(--section-padding, 1.5rem);

    // ✅ single-value tokens, one axis at a time
    padding-block: var(--section-gap);
    padding-inline: var(--section-pad-x);
    ```
    **What this does NOT ban:** the ban is on the TOKEN'S ARITY, not on shorthand properties. A
    **single-valued** token in a shorthand slot is correct and expected — `padding: var(--space-2)
    var(--space-4)` is legal and means exactly what it says. Reading this rule as "never substitute
    inside a shorthand" inverts it, and a project that inherited that reading was driven toward a
    **147-entry** exemption baseline in its own token-guard script — the anti-pattern such a guard
    exists to refuse. The real risk in a shorthand is a **dropped or reordered slot**, which is
    mechanical: verify it with a computed-style comparison, not by avoiding the substitution.

    The bullet above describes the *dropped-declaration* case, which at least renders visibly wrong.
    This one renders **plausibly** wrong — a 1rem left/right asymmetry reads as a design choice.
    **Corollary — a token that is only ever read is a bug.** `.contact-band` read
    `var(--section-padding-block, 3rem)`, a custom property defined nowhere in the codebase, so it had
    always silently used its fallback. `grep` every `var(--x)` for a matching definition; an undefined
    token with a fallback is indistinguishable from a working one until someone changes the "token"
    and nothing moves. Both found 2026-08-02 by measuring `getComputedStyle` on the assembled page —
    neither was visible from reading the source, which is why the computed-style rule above is STRICT.
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

- **[STRICT] A toggleable panel's own open/closed CSS class MUST stay separate from an "active-descendant"
  highlight class — never reuse one class binding for both:**
  - When a collapsed trigger (dropdown, "More" button, nav-group) needs an active-descendant indicator
    (highlighting the trigger because the current route is one of its *contents*, without the panel being
    open — see `catalog-menu-state.service.ts`'s `isGroupActive`, CAT-8) alongside its own real toggle
    state, these are two independent concerns and MUST bind to two separate classes. A shared CSS rule
    keyed off one class for both the panel's `display`/visibility AND the trigger's highlight color means
    "active-descendant" silently pins the panel visually open the moment the route matches — not just
    highlighted — even though the user never clicked to open it.
  - ❌ `[class.open]="isActiveDescendant() || isManuallyOpened()"` when the SCSS has
    `&.open .panel { display: block }` — visiting a page inside the panel renders it permanently expanded.
  - ✅ `[class.open]="isManuallyOpened()"` (unchanged, drives panel visibility only) +
    `[class.is-active]="isActiveDescendant() || isManuallyOpened()"` (new, drives only the trigger's
    highlight color via `&.is-active .trigger { color: var(--primary) }`) — both classes apply together
    when genuinely open, but only `.is-active` applies when merely active-descendant.
  - This exact bug was written once in this codebase (desktop header's "More" dropdown) and caught only
    because live QA happened to be available — a real `ng serve` + Playwright — for that PR; 23/23 unit
    tests with a mocked `Router`/DOM had already passed and completely missed it, since they never
    rendered the real CSS cascade. Caught and fixed before merge, not after — but a session without a
    live browser available would have shipped it. Verify any new active-descendant indicator by reading
    the actual `getComputedStyle` of the panel/chevron in a live browser, not just the trigger's own
    signal value in a unit test.
  - **Recurred once already**, on the *same* "More" dropdown this bullet names as the origin case — a
    second feature adding active-descendant highlighting made the identical mistake, caught again only
    by that PR's own live QA pass. **Grep-on-touch:** before writing a new
    `[class.open]`/visibility binding on any collapsed trigger, grep this file for "active-descendant" —
    if the task's own description matches this rule's trigger condition, re-read this bullet against the
    specific change, not just at session start.

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

## 4a. Shared-Surface Inventory — grep before you draw, and before you build [STRICT]

Every new user-facing surface reuses this app's existing primitives. The rule is not "prefer the
shared component" — that is advice, and advice loses to a wireframe. **The rule is that you run the
inventory below and record its output**, at the Mockup Gate (`plan-sprint/SKILL.md` step 3) and again
before implementing a surface whose mockup predates this rule.

It is written as commands because **a rule you verify by grepping cannot be re-argued, and a rule you
verify by judgement will be.** Every row below was a real defect shipped to a preview build and
caught by the Tech Lead, not by any gate.

| Element on your surface | Run this | Use what it shows |
|---|---|---|
| A page-level commit (Save / Continue / Confirm) | `grep -rn "app-action-bar" src/app --include=*.html` | `<app-action-bar>`. **Not** a button in the page body. A bare `type="submit"` is only for a *sub-action* — save one card, add a row to a list. |
| A page title + subtitle | `grep -rn "page-header" src/app --include=*.html` | `<header class="page-header">` > `.section-title` + `.intro-text`. Never a hand-rolled heading: the global `h1` is hero-sized, which §4 *Token Scope* bans on inner pages. |
| Any button | `grep -n "&--" src/styles/_buttons.scss` | The **BEM** variants: `.btn.btn--primary`, `.btn--danger`, … `.btn-primary` (single dash) matches nothing and renders an unstyled grey box. |
| A form row's column widths | `grep -rho "form-col-[a-z0-9-]*" src/app --include=*.html \| sort \| uniq -c` | Rows are filled `6+6` pairs or `12 → md-4/6`. **No row in this app leaves an unfilled half on mobile** — a lone `col-6` reads as a layout accident, whatever §14 permits in the abstract. |
| A helper hint under a control | `grep -rn "form-hint" src/styles/_forms.scss` | `.form-hint` as a **child of the field it describes**, with `aria-describedby` on the `<input>`, not the wrapper. A hint in a cell of its own stacks margins and reads detached. |
| An empty state, badge, dropdown, overlay | §4 *Shared UI Primitives*, §11 | The existing primitive. |

**Two traps that make this fail silently, both hit by the same task:**

1. **A class name that resolves to nothing looks exactly like one that works.** `ng lint`, `ngc` and
   the unit suite were all green with the submit button unstyled — nothing in this project checks
   that a class in a template matches a rule. **The only gate that catches it is a computed-style
   assertion on a real build.** When you add a surface, add one (`getComputedStyle` /
   `getBoundingClientRect` in the smoke walk), not a "does it render" check.
2. **Is the partial global?** `styles.scss` loads `_forms.scss`, `_buttons.scss`, `_badges.scss`,
   `_theme-variables.scss` and others — those need no `@use`; read `styles.scss` for the live list. `_shared-sections.scss` is **not** loaded there, so
   `.page-header`/`.section-title`/`.intro-text` need an explicit `@use 'shared-sections'`. Check
   `styles.scss` rather than assuming either way; the tell-tale of getting it wrong is a class that
   works on one surface and silently does nothing on yours.

**And when you place a shared component somewhere new, re-check its own assumptions.**
`<app-action-bar>` positions itself `bottom: var(--mobile-nav-height)` and relies on `margin-top:
auto` against a flex column — both true on every page that existed when it was written, neither true
on a route that hides the bottom nav and the footer. A shared component is not automatically correct
in a context none of its consumers had; measure it where you put it.

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

## 11. Select / Dropdown / Native-Control Avoidance [STRICT]
- **Never use a native browser/OS-rendered control whose picker UI cannot be restyled with CSS —
  unless the User has explicitly requested that exact native control for that exact field.** This
  covers native `<select>`, `<input type="color">`, and `<input type="date">`/`type="time"`/
  `type="datetime-local">` — each hands rendering to the OS/browser chrome (Android's system color
  wheel, iOS's date wheel, …), which varies by platform, cannot be themed, and reads as visually
  disconnected from the rest of the app. Build a themed custom component instead, reusing the
  established overlay pattern already shipped twice (an icon picker, and a colour field after its
  live-walk fix): a trigger button + a `position: fixed; inset: 0` invisible
  backdrop (click-to-close, no `document:click` listener needed) + a `position: absolute` panel
  anchored under the trigger. **Exempt:** controls where the OS surface *is* the expected UX and
  has no themed equivalent — `<input type="file">` (the file picker is a filesystem/security
  boundary), camera/mic/geolocation permission prompts, `<input type="checkbox">`/`type="radio">`
  (themed via CSS `accent-color`/pseudo-elements, not a full OS takeover).
  *(Originated as the native-`<select>` ban below; generalized 2026-07-21 after
  a colour field shipped with a raw `<input type="color">` — the Android system
  color-picker dialog a live-device walk flagged as visually non-compliant. Explicit-request escape
  hatch matters: a future field genuinely needing OS-level pickers, e.g. a native file input, is not
  a violation.)*
- **`CustomDropdownComponent` (`shared/components/custom-dropdown/`) is the canonical dropdown
  widget project-wide** — never a native `<select>`. It renders its own option list so it stays
  visually consistent across desktop AND mobile (a native `<select>` falls back to the unstyled OS
  picker on mobile, which cannot be themed). Reactive-form consumers bind via `formControlName`
  (it implements `ControlValueAccessor`); non-form/per-row consumers (e.g. a table cell) use the
  legacy `[value]` + `(selectionChange)` API. *(Amends the 2026-07-10 catalog-manager decision,
  which restored `CustomDropdownComponent` after a locked mockup had briefly reverted to native
  `<select>` — that rationale is general, not scoped to one component. A follow-up task migrated the
  one remaining native-`<select>` holdout, a user-management role picker, to match.)*
- **Never render a raw value as an option label.** Every dropdown option (and any user-facing
  enum) MUST display an **i18n lookup label** resolved per active language — the underlying value
  (`'grid'`, `'order'`, `'website'`, a status enum, …) is for the form control and persistence only
  and must never reach the user verbatim.
- **Option shape:** model options as `DropdownOption[]` (`{ value, label }[]`, `label` already
  translated — e.g. via a `toDropdownOptions()` helper mapping `{ value, labelKey }` →
  `{ value, label: translate.instant(labelKey) }`). `CustomDropdownComponent` renders `option.label`
  directly with no pipe, so the label MUST already be resolved before it reaches the component.
- **Consistency:** all dropdowns in a form use `CustomDropdownComponent`'s default styling (which
  already matches `.form-input`'s height/padding, see `custom-dropdown.component.scss`) so field
  styling is uniform; do not introduce a parallel dropdown style.
- *(Rationale: raw lowercase enum values shipped as option labels (`grid`, `order`) read as
  untranslated and visually inconsistent with the form's labelled fields. A native `<select>` also
  reads as visually inconsistent with the rest of the app's design system, per the 2026-07-10
  finding above.)*

## 12. Testing [STRICT]

- **Targeted runs during development:** Never run the full suite while iterating. Pass only the spec
  files (or directories) touched by the current change — the exact command depends on whether the
  project has its own standalone `vitest.config.ts`:
  - **Project has a standalone `vitest.config.ts`** (this project does — see `<spa-app>/vitest.config.ts`,
    a hand-built config that mirrors Angular's `templateUrl`/`styleUrls` inlining so bare Vitest can
    JIT-compile components): run it directly —
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
  - **Don't confuse this with vitest-cache corruption** (`local-vitest-cache-corruption` memory): the
    identical `TestBed.initTestEnvironment()` error can also come from a stale
    `node_modules/.vite`/`.vitest` cache even though this project's `vitest.config.ts` is present and
    working — that class clears with `rm -rf node_modules/.vite node_modules/.vitest` and doesn't
    recur. A project with no `vitest.config.ts` at all is the *other* failure class described above,
    not cache corruption.
  - **The full-suite gate run MUST be `ng test`, never bare `npx vitest run` [STRICT].** Targeted
    iteration may use either; the `/run-qa` gate may not. `ng test` is what CI runs, and the two
    runners **do not agree** — measured 2026-08-12 on `sprint/45` at a commit whose CI was green:

    | Runner | Result | Why |
    |---|---|---|
    | `ng test --watch=false` | **1600 passed** | AOT build; `environment.development.ts` |
    | `npx vitest run` | **20 failed**, 3 files | JIT; `environment.ts` |

    Both divergences were already known — the environment split from an earlier CI-only failure
    (transcribed into `app.routes.structure.spec.ts`'s own header table) and the JIT `input()`
    limitation in the very next bullet — but each was written as a *spec-authoring* caveat, so
    neither stopped the gate itself being pointed at the weaker runner. The two shapes seen:
    - **4 failures — the environment split.** `onboarding.guard.ts` early-returns on
      `!environment.enableLoginFeatures`. The base `environment.ts` resolves that flag from an
      injected token (**false** locally); `environment.development.ts` hardcodes `true`. So under bare
      vitest the guard returns `true` and every redirect assertion fails.
    - **16 failures — `NG0303: Can't bind to 'pending'`** on a signal `input()` of a shared component
      that is correctly listed in the consumer's `imports`. JIT does not register it; AOT does.

    **The failure mode is the dangerous direction: bare vitest reports *phantom* failures here, but the
    same divergence can hide a real one** — a spec that only passes under JIT/`environment.ts` is
    exactly the CI-only break that has bitten this project twice. Do not "fix" a spec that fails under
    bare vitest and passes under `ng test`; re-run it the CI way first, and only then decide whether
    there is anything to fix.

    Targeted runs still stay targeted: running everything on every iteration wastes a cycle and
    obscures which tests relate to the work in progress.

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

- **`ng test`'s builder unreliably intercepts `vi.mock()` — design the seam instead of mocking around
  it:** `ng test`'s `@angular/build:unit-test` Vitest builder (a) hard-bans `vi.mock()` on **relative**
  imports outright (`"The 'vi.mock' and related methods are not supported for relative imports...
  Please use Angular TestBed for mocking dependencies"`), and (b) has also been observed to **silently
  fail to intercept** a `vi.mock()` on a **package** (non-relative) import — a mocked third-party SDK
  class's methods reported zero calls under `ng test` despite passing locally under a bare
  `npx vitest run` (observed on a telemetry-SDK wrapper service and its spec). A bare
  `vitest run` doesn't route through the same builder, so this class of failure is CI-only and
  invisible to local iteration. **The durable fix is structural, not a better mock:** design the seam
  so nothing needs mocking —
  1. Anything read from `environment` inside a service under test: pass it as a **method parameter**
     instead of importing `environment` directly; the spec passes a literal value.
  2. Anything that directly `new`s a third-party SDK/library class: move the construction behind a
     `protected`, **overridable factory method**; the spec subclasses the service under test and
     overrides the factory to return a lightweight test double.
  Treat any new service test needing to fake a config value or a third-party class construction as a
  candidate for this pattern **by default** — don't reach for `vi.mock()` first and only fall back to
  this after CI fails.

- **Shared test-only fixtures/helpers that are NOT themselves a `.spec.ts` file MUST be named
  `*.testing.ts` and excluded from `tsconfig.app.json`** (mirrors `@angular/core/testing`,
  `@angular/common/http/testing`'s own naming convention). `tsconfig.app.json`'s `exclude` is only
  `src/**/*.spec.ts` — a shared fixture file (e.g. hoisted `vi.fn()` stubs, a `MOCK_TENANT` const, a
  `setupModule()` helper reused across several split spec files) that doesn't match that pattern is
  still included in the production app's TypeScript program and gets bundled by `ng build`, which
  fails with `TS2304: Cannot find name 'vi'` (or `describe`/`expect`) the moment the file uses a
  test-runner-only global — `tsconfig.app.json` sets `"types": []` deliberately, so nothing makes
  `vi` a recognized ambient identifier there. **This is invisible to `ngc -p tsconfig.spec.json`**
  (which type-checks clean — `vitest/globals` is included there) and to plain `npx vitest run`
  (esbuild transpiles per-file, doesn't do the same whole-program ambient-global resolution `ngc`'s
  full type-checker does for `tsconfig.app.json`) — only a real `ng build` or `ngc -p
  tsconfig.app.json --noEmit` **run after the fixture file exists** catches it (`LESSONS_LEARNED.md`
  when a large spec file was split and its shared fixtures hoisted). Fix: name the file
  `some-name.testing.ts` and add `"src/**/*.testing.ts"` to `tsconfig.app.json`'s `exclude` (a
  one-time project-level addition, already done) — `tsconfig.spec.json` needs no corresponding
  change, since TypeScript still pulls the file into that program transitively via any `.spec.ts`
  file's `import`. **Re-run `ngc -p tsconfig.app.json --noEmit` after every round of file changes**,
  not just once early in a session — a later edit (especially adding a new non-`.spec.ts` file) can
  silently invalidate an earlier "clean" result for a tsconfig that edit didn't touch.

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
  - A route meant only for an **authenticated role that already has a natural hub** (e.g. the owner's
    `/admin`) MAY be reachable one hop from that hub (a dashboard card) without its own persistent
    header entry. This is the established, intentional pattern for `/admin/users` and
    `/admin/booking-availability` — do not treat it as license to bury a *public-facing* page the same
    way just because an owner also happens to manage it there.
- **Inline content links are additive, never exclusive:** a "see more" CTA embedded in another page's
  content (e.g. the homepage → a new feature route) is good UX *in addition to* persistent chrome,
  never a substitute for it.
- *(Rationale: a page reachable only via a buried inline link creates a "how did I get here / how do I
  get back" experience — the user has no durable mental model of where the feature lives. Codified
  after a new public-facing page shipped with only an inline
  homepage link and a dashboard card, missing a header entry point anonymous visitors could use.)*
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

## 13a. Navigation Placement Doctrine [STRICT]

§13 answers *"is this reachable?"*. This section answers *"reachable from **where**?"* — and exists
because that second question was re-litigated in four consecutive sprints (31, 37, 42, 43), twice by
literal reversal (S37 added an admin gear, S42 removed it; S37 made edit-mode a one-shot action, S42
made it a toggle again). That is oscillation, not refinement. Three root causes, none about taste:
no item taxonomy, placement argued from frequency intuition, and per-surface specs instead of one
model.

**Every rule below is structurally checkable.** That is the point: a rule you verify by grepping
cannot be re-argued, whereas a rule you verify by judgement will be. Where an earlier version of this
doctrine used a type-table alone, it was contradicted by the codebase on day one (see the note at the
end) — so the table is now subordinate to the invariants.

### The invariants

**1 — One model, N renderers.** Persistent navigation comes from a *single* ordered, typed list
(`NavModelService`). Each viewport is a **renderer** over it. Renderers may differ in **capacity and
chrome only** — never in composition, ordering, or labelling.
> *Check:* a renderer that builds or filters its own items is a violation. It may only `slice()`.
> *Origin:* desktop read `navigation.json` (role-blind) while mobile branched by role in its own
> service, so the two drifted **by construction** — a logged-in customer saw one app on a phone and a
> different one on a laptop.

**2 — The persistent nav row is role-invariant.** Every visitor sees the same ordered row. Anything
available to only one role is **not** a nav item — it belongs in the **corner icon cluster**, where
role- and session-scoped controls already live.
> *Check:* `grep` the nav model for a role read. There must be none — not a role branch that happens
> to produce equal lists today, but no role dependency at all. In this codebase `NavModelService` does
> not inject `IUserProfileService`, and its spec provides no such token, so re-introducing one fails
> the entire spec file with `NullInjectorError` rather than one assertion.
> *Why absence, not equality:* a branch producing identical output today keeps passing until the two
> arms diverge. Absence cannot drift.

**3 — Conditional presence is a dead-link guard, never a preference.** An item may be omitted **only**
when its destination does not exist for this tenant or user — an unconfigured catalog group, an order
history a guest cannot have. It may never be omitted, reordered, or promoted because someone judged it
more or less useful to a given audience.
> *Check:* every omission traces to a missing destination, not to a role or a frequency claim.

**4 — Anti-churn invariant.** *A new navigable item **never displaces** an existing item. It joins its
type's home. If that type's home is at capacity, **that type** grows a drawer — every other type is
untouched.*
> Applied retroactively this alone would have prevented all three reversals above. Applied forward, a
> future Notifications bell is *Mine* → it joins its home, and nothing else moves. No debate.
> *Corollary:* **removing** an item shortens its type's row without redistributing the freed slot.

**5 — A label is invariant too.** An item's label must not change **meaning** based on data shape,
cardinality, or role. Label by **what the item does**, not by what it currently contains.
> *Check:* no label expression branches on a count, a role, or an `isSingleton`-style flag.
> *Origin:* a one-catalog group was labelled with the catalog's own **title** (a noun) and a
> multi-catalog group with its **action** (a verb) — so the label silently flipped noun→verb when a
> second catalog was added, **and** the nav contradicted its own destination, whose page heading had
> always used the action key.

**6 — An in-page anchor is never a nav destination.** A navbar entry resolving to `#fragment` is a
false affordance: it looks like a route, behaves like a scroll, and breaks the back button's meaning.
If a section is important enough to need one, the obligation is to make it **prominent on its own
page**, not to prop it up with a fake nav entry. In-page anchors *within* page content are fine and
encouraged — the ban is on navbar chrome only.

### Type → home

Types are a *vocabulary for the invariants above*, not an independent authority. When a type
assignment and an invariant disagree, **the invariant wins**.

| Type | Definition | Home | Notes |
|---|---|---|---|
| **Act** | What the business exists to do (catalog → book/order) | Persistent row, after any *promoted* Learn item | Guaranteed a persistent slot; not guaranteed slot 2. |
| **Mine** | This user's own state (History) | Persistent row, after Act | Present only once the state can exist (invariant 3). |
| **Manage** | Role-exclusive administration (Admin) | **Corner cluster** | Role-exclusive ⇒ invariant 2 forbids the row. |
| **Shortcut** | A faster path to a destination the row already reaches (cart → checkout) | **Corner cluster**, and only while it beats the row | An empty cart resolves to the same page as the catalog row item, so it renders only when non-empty. |
| **Learn** | Brochure & trust content (About, Reviews, Friends) | **Promoted → leads the row; otherwise the drawer** | Promotion is *authored data*, never a code constant — see invariant 7. |
| **Mode** | Changes how the *current page* behaves (edit mode) | Corner cluster, contextual | **Not a destination.** Must also be scoped to surfaces where it applies. |
| **Session / Preference** | Login, account, logout, language | Corner cluster, fixed | Found by convention, not exploration. |

**Frequency intuition is banned as a placement argument.** "Owners touch Order daily", "Explore is
the lowest-frequency of the five" — unfalsifiable claims are re-litigable forever. *Type* determines
home; only *ordering within a type* may be argued from usage, and only with evidence.

### 7 — Promotion is authored, never argued

*A **Learn** item may outrank the **Act** block only by being in the tenant's `navigation.json`
`primary` array. Code never promotes a specific item, and never hardcodes which one leads.*

> *Check:* `grep` the nav model for a route/label literal deciding an item's rank. There must be
> none — the rank comes from which array the item was authored into.
> *Capacity guard:* `primary` precedes the Act block, so an over-long `primary` can push the catalog
> past a renderer's capacity. `nav-model.service.spec.ts` pins the catalog inside the mobile 4-tab
> window; that test is the alarm, and it is meant to fail loudly rather than degrade quietly.

**This invariant replaced a rule that had it backwards** (2026-08-02). §13a originally read
"Nothing outranks the commercial purpose", which made the *only* sanctioned way to give a tenant's
identity page a persistent slot a re-argument of the doctrine itself — exactly the re-litigation
this section exists to end. The real defect was upstream: `navigation.json` already distinguished
`primary` from `secondary`, and a later task flattened both into one `learn` block, deleting the tenant's
own means of expressing "this page leads." Restoring the split turns a recurring argument into a
data edit. See `DECISIONS.md` 2026-08-02 and `NavModelService.items`.

**Corollary — a drawer does not group.** A "More" drawer renders its overflow **flat, in model
order**. Sectioning it (two category headings, added and removed within one sprint) re-sorts the
overflow away from the single ordered model that invariant 1 exists to guarantee, and spends two
headings plus an ungrouped block organising four items. If a drawer ever holds enough items for
grouping to pay, that is evidence the row is under-capacity — fix the capacity, not the drawer.

> **Why the table is subordinate.** Its first version typed both `Admin` **and** the **cart** as
> *Manage* → "persistent slots", while the cart had shipped as a corner icon since long before that
> version was written. A rule the codebase contradicts on day one cannot settle a future argument —
> which is exactly how it failed. The invariants are checkable; the table is a summary of them.
> (`DECISIONS.md` 2026-08-02.)

## 14. Compact Forms — 12-Column Grid [STRICT]
- **`.form-row` is a Bootstrap-like 12-column CSS Grid**, not an equal-width flex row. Any owner/admin
  form with 2+ fields on a conceptual "row" MUST wrap them in the shared `.form-row` class
  (`src/styles/_forms.scss`) and give each direct `.form-field` child an explicit width via
  `.form-col-{n}` — never rely on equal flex-basis distribution (`flex: 1 1 0`) to size fields, and
  never leave a field's width unset inside a `.form-row`.
- **Values are restricted to Bootstrap's common divisors of 12 — `2, 3, 4, 6, 12`** — so every field
  lands on a clean fraction (1/6, 1/4, 1/3, 1/2, full) instead of an ad-hoc percentage. Size each field
  to its actual content, not to "however many siblings it has": a small trigger (icon picker) gets a
  small column (`form-col-2`/`form-col-3`); a free-text title gets a wide one (`form-col-8`+). A row's
  columns do **not** need to sum to 12 — unfilled columns are intentional compactness, not a bug;
  `.form-row` never redistributes leftover space to fill the row.
- **Mobile-first, Bootstrap-named breakpoint override:** the unprefixed `.form-col-{n}` is the
  **default that applies at every size** (including mobile) unless overridden; `.form-col-md-{n}`
  (`≥769px`, matching `.form-row`'s own `768px` mobile breakpoint) overrides it on desktop only. A
  field MUST NOT always be `form-col-12` (full width) on mobile by default — compact 2-up pairing
  (`form-col-6`) is the mobile baseline for short fields (single-line text inputs, small dropdowns);
  reserve `form-col-12` for content that genuinely needs the full line (a textarea, a 3-way dropdown
  row where the third field is the natural odd-one-out).
  ```html
  <!-- ✅ Mobile pairs 6+6; desktop compacts to 4+8 (title gets more room, id stays narrow) -->
  <div class="form-row">
    <div class="form-field form-col-6 form-col-md-4"> ... catalogType ... </div>
    <div class="form-field form-col-6 form-col-md-8"> ... title ... </div>
  </div>
  <!-- ❌ Equal flex distribution (the retired `.form-field--inline`) — wastes space when one
       field's content is much narrower than its sibling -->
  <div class="form-row">
    <div class="form-field form-field--inline"> ... icon-picker (small) ... </div>
    <div class="form-field form-field--inline"> ... currency dropdown ... </div>
  </div>
  ```
- **A conditionally-shown field group stays in the same `.form-row` as its trigger control**, not a
  separate nested row below it — e.g. a "Limit bookings" toggle and the two capacity fields it reveals
  sit in one `.form-row` (`toggle: form-col-md-4`, each revealed field `form-col-md-4`) so the revealed
  fields appear *beside* the toggle on desktop, not stacked underneath it. CSS Grid re-flows
  automatically when an `@if`-gated grid item is added/removed — no extra layout code needed.
- Reference implementation: `catalog-builder-form.component.html`/`.scss`, `_forms.scss`'s
  `.form-row`/`.form-col-*` classes.
- *(Rationale: the prior `.form-field--inline` (`flex: 1 1 0`, equal-width) split every row's fields
  evenly regardless of content — a small icon-picker trigger next to a currency dropdown each took 50%,
  leaving a large dead gap between them; mobile fell back to `flex-direction: column`, fully stacking
  every field to one-per-row even for short single-line inputs that could easily pair up. Codified
  after a live-walk flagged both — the Tech Lead explicitly requested a Bootstrap-like
  2/3/4/6/12 proportion system as the general, durable pattern, not a one-off fix to this one form.)*
