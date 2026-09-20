---
name: Stack Shared UI
trigger: glob
globs: ["**/*.ts", "**/*.html", "**/*.scss"]
description: Shared UI primitives — inventory before building, controls, form grid
---

# Stack Shared UI

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
