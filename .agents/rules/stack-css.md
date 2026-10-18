---
paths:
  - "**/*.scss"
---

# Styles — SCSS and design tokens

These are the *Styling* rules from `stack-angular.md` §4; the heading keeps the number, so a §4 citation
about styling lands here. Paths are relative to `{webapp}/src/`.

## 4. Styling

### Tokens

- **Colours are CSS custom properties** (`var(--primary)`), defined in `styles/_theme-variables.scss`.
- **Every theme colour ships with an `-rgb` companion** — `--primary: #79C1B0; --primary-rgb: 121, 193,
  176;` — so transparency is `rgba(var(--primary-rgb), 0.2)`, with no preprocessor function.
- **Layout constants are global and remapped in one media query** — `styles/_variables.scss`
  (`--section-padding`, `--section-title-size`, `--section-gap`, `--section-pad-x`). A component reads
  `var(--section-padding)` and writes no media query of its own for them.
- **[STRICT] Hero tokens stay on hero surfaces.** `--section-title-size` is sized for landing sections;
  an admin, account or detail page sets its own smaller heading size locally.
- **[STRICT] A token that is only ever read is a bug.** A `var(--x, fallback)` whose `--x` is defined
  nowhere always renders the fallback, and looks exactly like a working token until someone changes
  it. Grep for the definition of every `var(--x)` you add.

### Shorthands — a token's arity must fit its slot [STRICT]

- **A multi-value token in a single-value property is dropped silently.** `--section-padding` is
  `2rem 3rem 3rem` (`styles/_variables.scss:3`), so `top: var(--section-padding)` is discarded.
- **A multi-value token inside a shorthand is worse: valid CSS with the wrong meaning.**
  ```scss
  // ❌ expands to `padding: 0 2rem 3rem 3rem` — top 0, right 2rem, bottom 3rem, LEFT 3rem
  padding: 0 var(--section-padding, 1.5rem);

  // ✅ single-value tokens, one axis at a time
  padding-block: var(--section-gap);
  padding-inline: var(--section-pad-x);
  ```
- **A single-valued token in a shorthand slot is fine:** `padding: var(--space-2) var(--space-4)`. The
  ban is on the token's arity, not on shorthand properties — `DECISIONS.md` 2026-09-04. Read the other
  way, it would need a 147-entry exemption baseline in `check-design-tokens.sh`.
- **Verify position and spacing by computed style** (`getComputedStyle`), never by reading the
  authored rule — none of these failures is visible in the source.

### Screen-sized layout [STRICT]

- **`--header-height` is the header's rendered height.** Re-measure it (`getBoundingClientRect`) after
  any change to the header's padding or logo row. It read 70px against a 77px header: every
  screen-sized section ran 7px under the bottom nav, and the sticky filter bar parked under the header.
- **One screen is `--screen-content-height`** (`styles/_variables.scss`): the viewport below the
  header and above the phone's bottom nav. A page carrying the section chips' sticky row sizes anything
  a chip lands on with `--section-screen-height`, the screen minus that row. Never re-derive either
  from `100vh` in a component.
- **A bar fixed under the header carries `data-anchor-offset`**: `ScrollRestorationService` adds its
  height to every in-app anchor jump. The page raises `--anchor-scroll-offset` by the same token, so
  a cold `#hash` load lands the same way.
- **A section a chip lands on shows whole**, unless its content alone is longer than a screen. Check it
  by jumping to every chip at 375×690 and 360×640 and reading where the section's last element ends
  against the bottom nav's top.

### Encapsulation and budget

- **Never hide a whole component with `display: none`** — gate it with `@if`, or it is still built and
  still fetches. CSS hides only inner elements of a component that renders anyway. Full rule:
  `stack-angular.md §2`.
- **Before persisting a new value, check whether CSS can derive it** from tokens that already ship
  (`color-mix()`, `calc()`) — no seed, migration or backend deploy. Full rule: `stack-angular.md §3`.
- **Never `!important`.** Fix the specificity instead.
- **[STRICT] A component that applies a shared class `@use`s its partial.** View encapsulation emits a
  partial's rules only into components that import it; without the `@use`, the class is silently
  unstyled — right on some surfaces, wrong on the ones missing the import. Example: `.inline-edit-chip`
  from `styles/_inline-edit.scss`. **Exception:** partials that `styles.scss` loads are global and need
  no `@use` — read its `@use` list rather than assuming (`_forms`, `_buttons`, `_badges` are global;
  `_shared-sections`, `_inline-edit` are not).
- **[STRICT] Before adding an alignment, spacing or rhythm rule to an existing stylesheet, grep it for
  the decision already recorded there:**
  `grep -n "on purpose\|deliberately\|INTERNALLY\|not on desktop\|stays" <that file>.scss`. A rule
  contradicting one is a regression, and it passes every gate. Full inventory: `stack-angular.md §4a`.
- **[STRICT] Component style budget: 8.5 kB warning, 10 kB error** (`anyComponentStyle`,
  `{webapp}/angular.json:55`). A partial loaded with `@use` counts against its host component, so:
  - shared visual styles for a base element (colour, transition, border, typography) live once in the
    component's root SCSS; partials hold layout-only overrides (size, spacing, flex or grid context);
  - never duplicate a block across two partials the same component loads — it is the main cause of
    breaches.
