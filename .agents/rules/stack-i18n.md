---
name: Stack i18n
trigger: glob
globs: ["**/*.ts", "**/*.html", "**/*.json"]
description: Assets and internationalization
---

# Stack i18n

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
