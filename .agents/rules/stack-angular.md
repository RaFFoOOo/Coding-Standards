---
paths:
  - "**/*.ts"
  - "**/*.html"
---

# Angular / TypeScript

The language-agnostic rules — decoupling, strict typing, exceptions, async — are `AGENTS.md` §2–§3,
which loads every session. This file holds their Angular form and what only Angular needs. Paths are
relative to `{webapp}/src/app/`.

> **Moved — numbers kept, so existing citations still resolve:**
> - §4 *Styling* → `stack-css.md` · §4 *Text Content* and §9 → `stack-i18n.md` · §4 icons and shared
>   components, §4a, §11, §14 → `stack-shared-ui.md`
> - §12 → `stack-angular-testing.md` · §13, §13a → `stack-navigation.md`

## 1. TypeScript Strictness

The Angular form of `AGENTS.md §2` *Strict typing*.

- **`"strict": true`** (`{webapp}/tsconfig.json:6`). **[ARCHITECT REQUIRED] No `any`** — narrow an
  `unknown`, or write a generic.
- **Explicit interfaces** for every `input()`, API response and domain model.
- **[STRICT] Every class property carries an explicit type**, signals in their full generic form
  (`Signal<T>`, `InputSignal<T>`, `WritableSignal<T>`, `ModelSignal<T>`):
  - ❌ `readonly isReady = computed(() => true)`
  - ✅ `readonly isReady: Signal<boolean> = computed(() => true)`

  ESLint enforces the constructor case:
  `@typescript-eslint/consistent-generic-constructors: type-annotation` (`{webapp}/eslint.config.js:47`).

## 2. Component Architecture

- **Presentational components take `input()` / `model()` and emit `output()`**, with no API service;
  containers fetch and pass data down (`AGENTS.md §2` *Keep the boundary thin*).
- **A complex component — a table, a form — takes a config object** (`TableColumnDefinition[]`), not
  hardcoded markup.
- **`ChangeDetectionStrategy.OnPush` on every component.**
- **Independent data sources load in parallel with `forkJoin`** — never a chain of subscriptions.
- **`formArrayName` sits on the parent of `[formGroupName]="index"` children.** Without it the controls
  do not resolve: `Cannot find control with path: 'N -> fieldName'`.
- **Client validators are UX, not security** (`AGENTS.md §3` *Dual-Side Validation*): mirror every server
  constraint in the form, and never ship a constraint that exists only on the client.
- **Animate with CSS transitions, not JavaScript**, and avoid layout thrashing.
- **A value that is constant for the tenant is read where it is used — by a pipe or a service — never
  passed down as an input.** `MoneyPipe` reads `TenantConfig.currencySymbol` itself. As an input, the
  symbol ran through 27 files, and removing it touched every one (S59 T11). The multi-language
  editors read the tenant's languages through `injectTenantLanguages()` for the same reason (S60 T4).

### A component is created only if it is rendered [STRICT]

A component shown at one breakpoint, or in one state, is gated by `@if` — never hidden with
`display: none`. CSS hides paint, not work: the component is still built and still runs its
subscriptions and HTTP requests.

```html
<!-- ❌ both exist at every width; the hidden one still fetches -->
<app-footer></app-footer>          <!-- footer.scss: @media (max-width: 768px) { display: none } -->
<app-mobile-nav></app-mobile-nav>  <!-- mobile-nav.scss: :host { display: none } on desktop -->

<!-- ✅ exactly one exists — app.html:25 -->
@if (isDesktop()) { <app-footer /> } @else { <app-mobile-nav /> }
```

Measured on Home at 375 px (2026-09-01): the CSS-hidden footer still built **14 DOM nodes** and fired
its own `contact.json` request — **3 identical fetches** on one page. `@if` made it 1 request and 0 nodes.

- **The breakpoint comes from `ViewportService`** (`{webapp}/projects/platform/src/services/ui/viewport.service.ts`), which is
  `matchMedia`-backed — never a `resize` listener, never `window.innerWidth` in a component.
- **Media queries stay correct for layout**, and for hiding an inner element of a component that
  renders anyway. The test: if what you are hiding has its own selector in a template, it is an `@if`.
- **jsdom has no `matchMedia`**, and a missing stub fails a whole spec file.
  `{webapp}/src/test-setup.testing.ts` stubs it with `matches: false` (desktop), because every media
  query here is a `max-width` query.

## 2a. Modern Angular Standards [STRICT]

- **`inject()`, never constructor injection**, for services and tokens. A plain class built with
  `new` is not DI (`{webapp}/projects/ui/src/lib/custom-dropdown/custom-dropdown-keyboard.controller.ts`).
- **Inject the interface token, never the Mock or Http class** — `inject(IOrderService)`. Each token is
  bound per service by `provideByMode` (`app.providers.ts:43`): the Angular form of `AGENTS.md §2`
  *Depend on abstractions*.
- **A Mock class bound through a token does not declare `@Injectable({ providedIn: 'root' })`**, so
  injecting the class directly fails at resolution instead of silently creating a second instance.
  All 18 comply (`git grep -nE "^@Injectable" -- '{webapp}/src/app/**/mock-*.ts'`, 2026-10-16);
  grep the decorator, not the text — each file's "Does NOT declare" comment matches a bare search.
- **Injected services are `private`, and templates never reach them.** Expose a named `readonly`
  property instead:
  - ❌ `[value]="myService.someSignal()"`
  - ✅ `readonly someValue = this.myService.someSignal;` → `[value]="someValue()"`
- **`viewChild()` references are `private`;** a template never reaches a child's internals
  (`childForm.form.invalid`). Expose proxy signals (`computed(() => child()?.value())`) and proxy
  methods instead. Prefer signal `viewChild()` to `@ViewChild()`.
- **To bridge a child form's state into a signal,** bump a version signal from
  `form.statusChanges.pipe(takeUntilDestroyed())` and read it inside
  `computed(() => { version(); return this.form.invalid; })`.
  - **[STRICT] `dirty`/`pristine` and `touched`/`untouched` emit nothing.** `markAsPristine()`,
    `markAsDirty()`, `markAsUntouched()` and `reset()` change the flag silently, so bump the version in
    the same method that calls them — as `CatalogDirtyTrackingController.markSaved()` does
    (`archive/LESSONS_LEARNED_ARCHIVE.md` Sprint 37).
  - **[STRICT] So does every `{ emitEvent: false }` write** — `patchValue`, `setValue`, `enable`,
    `disable`, `updateValueAndValidity`. Each one that can move validity bumps the version where it
    happens, including inside an `effect()` fed by data that arrives after construction. The all-Mock
    build resolves most such data synchronously, before the `computed` first reads, so **no Mock test
    or walk sees the stale value**: S62 T14 locked *Conferma Prenotazione* on a valid form for every
    customer on the real backend (`LESSONS_LEARNED.md` Sprint 62).
- **Control flow is `@if` / `@for` / `@switch`**, never `*ngIf` / `*ngFor`.
- **Separate `.html` and `.scss` files**, unless the template is static text under 3 lines.
  **`standalone: true`** on every component.
- **No logic in a template:** ❌ `(click)="isOpen = false"`, ❌ `(click)="isOpen.set(false)"`;
  ✅ `(click)="closeDropdown()"`.

## 3. Data Service & Mocking Strategy

- **[ARCHITECT REQUIRED] Every API service has a Mock** (`BookingService` → `MockBookingService`).
- **Each service switches on its own `ServiceMode`** (`'Mock' | 'Http'`, `environments/service-mode.ts:2`)
  under `services.*` in `environment.*.ts`, wired by `provideByMode` — never one global `useMocks` flag.
- **Mocks return synthetic data with a realistic `delay()`.**
- **No secret in a committed mock payload.** A mock that needs one merges it in from
  `environment.development.ts` after loading — `{webapp}/projects/platform/src/services/tenant/tenant-config/mock-tenant-config.service.ts:99`
  (`mockStorageSasTokens`, read through `PLATFORM_ENVIRONMENT`).
- **[STRICT] Before proposing a persisted value, check whether CSS can derive it** from tokens that
  already ship (`color-mix()`, `calc()`) — no seed, no migration, no backend deploy (`AGENTS.md §1`).
- **[STRICT] A data adapter fetches; a service owns state** (`AGENTS.md §2` *Separate fetching data
  from owning state*). An `IFoo` / `MockFoo` fetches, maps and registers data — no `signal()`,
  `computed()`, `localStorage` or business logic. State, preferences and shared behaviour live in a
  `providedIn: 'root'` `FooService` that consumes the adapter.
  - ✅ `MockLanguageService` loads files; `TranslationService` owns the signals, activation and persistence.
  - **Check before committing a new adapter:** grep it for `signal(`, `WritableSignal`, `computed(` and
    `localStorage`.
- **[STRICT] Two halves of one user action share a lifetime.** When state accompanies something already
  persisted, ask what happens if only the other half survives a reload. `CartService` persisted the
  items while `EditOrderModeService` kept *"this is an edit"* in memory, so after a reload confirming
  created a second order (Sprint 46 T18). Test it with a **second `TestBed` seeded from what the first
  stored** — a mocked `setItem`/`getItem` pair with no store between them cannot fail this way.
- **[STRICT] Interface parameters identify a resource by its stable id** (`AGENTS.md §2`):
  `getAll(tenantId: string)`, never `getAll(tenantName: string)`. A mock that needs a name for a file
  path resolves it internally.
- **[STRICT] A server-state interface returns `Observable`, never `Signal`.** A mock simulates the
  backend with a plain array and `of(…).pipe(delay())`, so the Http adapter is a drop-in swap. The
  `Signal` cache lives in a `FooStateService` (`providedIn: 'root'`).
  - ✅ `IOrderService.getAll(): Observable<OrderRequest[]>` (`core/services/order/order-service.interface.ts:17`),
    cached by `OrderStateService`.
  - **Exception — client-side session state may be a `Signal`:** `IAuthService.isAuthenticated`
    (`{webapp}/projects/platform/src/services/auth/auth-service.interface.ts:16`). The test is ownership: server-owned →
    `Observable`, client-projected → `Signal`.

## 5. Debugging & Reliability

- **One global `HttpInterceptor` catches HTTP errors** (`AGENTS.md §3` *Exception Safety*) and logs the
  context, input and error together — `{webapp}/projects/platform/src/interceptors/error.interceptor.ts:130`.

## 6. Memory Safety & Subscriptions

- **Prefer `toSignal()` or the `async` pipe to `.subscribe()`.**
- **[STRICT] Every `.subscribe()` has a cleanup** — `takeUntilDestroyed()`, `DestroyRef` or the `async` pipe.
- **[STRICT] `take(1)` alone is allowed only in a `providedIn: 'root'` singleton**, which is never
  destroyed (`core/services/order/order-state.service.ts:169`). Anything with a real `DestroyRef` — a
  component, a component-scoped controller — combines both:
  `.pipe(take(1), filter(Boolean), takeUntilDestroyed(this.destroyRef))`. Reference: the confirm-dialog
  subscriptions in `features/services/services-inline-edit.controller.ts` and
  `features/catalog/catalog-grid-edit.coordinator.ts`.
- **[STRICT] A route param becomes a signal through `toSignal()` at the field**, never `.subscribe()` +
  `.set()`:
  ```typescript
  // ✅
  readonly catalogType: Signal<string> = toSignal(
    this.route.paramMap.pipe(map(params => params.get('catalogType') ?? '')), { initialValue: '' });

  // ❌
  ngOnInit() { this.route.paramMap.subscribe(params => this.catalogType.set(params.get('catalogType') ?? '')); }
  ```

## 7. Reactive State Management

- **`signal()`** for mutable local state · **`computed()`** for derived state · **`effect()`** only for
  side effects (storage, logging, DOM), never to derive state · **`linkedSignal()`** for state derived
  from inputs that the user can override · **`input()` / `output()` / `model()`** between components.
- **[STRICT] Optimistic updates on a server-owned list:** `toSignal(http$, { initialValue })` →
  `linkedSignal(() => serverSignal())`. `toSignal` owns the subscription; the `linkedSignal` takes
  `.update()` edits, resets itself when the source re-emits (a route or tenant switch, a refetch), and a
  failed PATCH reverts with `.update()`. **Banned:** a constructor `loadX()` + `WritableSignal` + `.set()`
  inside `.subscribe()` — it loses `switchMap` cancellation on a fast tenant switch. Migrate a legacy
  component when you next touch it.
- **[STRICT] No debounce or delay between an input and the state it changes** — the Angular form of
  `AGENTS.md §3` *What a user's input changes depends on what they did*: no `debounceTime` or
  `setTimeout` on that path, and worst of all on a persisted identity (a route slug, a storage key). A
  display-only timer is fine — `{webapp}/projects/platform/src/services/ui/toast.service.ts:67` auto-dismisses a toast.
  - **The tell:** a spec needs `vi.useFakeTimers()` to describe production behaviour.
  - **The number:** the booking-draft write the deleted debounce batched cost **0.10 ms, 0.64 % of a
    16 ms frame** (#911, #912). Why it is a rule: `archive/LESSONS_LEARNED_ARCHIVE.md` Sprint 54, finding 3.
- **[STRICT] A dependent filter follows its parent.** Its options are a `computed()` of the parent's
  value, and its selection resets to "All" the moment it becomes invalid — never a stale child selection.
  Reference: `setType()` in `features/group-tab-page/group-surface-facet.controller.ts:161` clears
  `selectedCategory` once it is no longer in `availableCategories()`.

## 8. File & Folder Structure

- **Code is organised by business feature** — `features/<feature>/` holds its components, services and
  models — not by technical type.
- **File names are kebab-case** (`user-profile.component.ts`).
- **A feature folder exposes its public API through an `index.ts` barrel**, so nothing imports deep into
  it. Today 1 of 15 feature folders has one (`features/fallback/index.ts`); the other 14 are logged in
  `backlog/frontend.md`. The `core/services/*` folders already have theirs.

## 10. Multi-Tenant Architecture [STRICT]

- **Tenant assets resolve at runtime** through `StorageService.getResourceUrl()`
  (`{webapp}/projects/platform/src/services/tenant/storage/storage.service.ts:96`) — never a hardcoded `assets/` path to a tenant's
  logo, favicon or image.
- **Browser storage keys are tenant-prefixed** — `{short}_{tenantId}_{key}`, built in
  `{webapp}/projects/platform/src/services/persistence/local-persistence.service.ts:23`.
- **Components adapt their behaviour and wording to the tenant's business type.**
- **[STRICT] A config value that drives behaviour in several components is centralised in one service of
  named signals** — never `config.type === 'x'` in a component or template (`AGENTS.md §2`
  *Data-Driven State*). Reference: `BusinessModeService` — `isReservationMode`, `isOrderMode`,
  `isAppointmentMode` (`core/services/business-mode/business-mode.service.ts:79`) and typed config
  signals such as `datePickerConfig` (`:103`) that templates bind to.

## 13. Routing & Navigation — moved

Every navigation rule is in `stack-navigation.md`. Two of them apply to any page, so they are stated here:

- **A route meant for repeat access is reachable from persistent chrome** (header icons, the nav row, the
  account menu) — an inline link in another page does not count.
- **A detail page that no nav entry reaches renders `<app-breadcrumb>` first**, built as a `computed()`
  `BreadcrumbItem[]`.
