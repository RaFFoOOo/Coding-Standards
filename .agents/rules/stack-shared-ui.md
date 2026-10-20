---
paths:
  - "**/*.html"
  - "**/src/app/shared/components/**"
  - "**/projects/ui/**"
  - "**/src/styles/_forms.scss"
  - "**/src/styles/_buttons.scss"
---

# Shared UI — primitives, controls, overlays and form layout

These are `stack-angular.md` §4 (*Iconography* and the shared-component rules), §4a, §11 and §14; the
headings keep the numbers, so those citations land here. Paths are relative to `{webapp}/src/app/`.

## 4a. Shared-Surface Inventory — grep before you draw, and before you build [STRICT]

Every new surface reuses the app's existing primitives. **Run the inventory and record its output** at
the Mockup Gate (`plan/SKILL.md` step 3), and again before building a surface whose mockup
predates this rule. Every row was a defect shipped to a preview in Sprint 45 and caught by the Tech
Lead, not by a gate.

| Element on your surface | Run | Use what it shows |
|---|---|---|
| A page-level commit (Save / Continue / Confirm) | `grep -rn "app-action-bar" src/app --include=*.html` | `<app-action-bar>`, not a button in the page body. A bare `type="submit"` is only for a sub-action — save one card, add a row. |
| A page title and subtitle | `grep -rn "page-header" src/app --include=*.html` | `<header class="page-header">` > `.section-title` + `.intro-text`. Never a hand-rolled heading: the global `h1` is hero-sized (`stack-css.md` *Hero tokens*). |
| Any button | `grep -n "&--" src/styles/_buttons.scss` | BEM variants — `.btn.btn--primary`, `.btn--confirm`, `.btn--cancel`, `.btn--danger`. `.btn-primary` (one dash) matches nothing and renders a grey box. |
| A form row's column widths | `grep -rho "form-col-[a-z0-9-]*" src/app --include=*.html \| sort \| uniq -c` | Rows are filled `6+6` pairs or `12 → md-4/md-6`. No row leaves an unfilled half on mobile — a lone `col-6` reads as an accident, whatever §14 permits. |
| A hint under a control | `grep -rn "form-hint" src/styles/_forms.scss` | `.form-hint` as a child of the field it describes, with `aria-describedby` on the `<input>`, not the wrapper. |
| An empty state, badge, dropdown or overlay | §4 and §11 below | The existing primitive. |
| Photos an owner adds, removes, reorders or replaces | `grep -rn "app-media-strip" src/app --include=*.html` | `<app-media-strip>`, never a new list of thumbnails with its own upload button (§4 *Photos edited in place*). |
| An alignment, spacing or rhythm rule added to an existing stylesheet | `grep -n "on purpose\|deliberately\|INTERNALLY\|not on desktop\|stays" <that file>.scss` | The decision already recorded there — contradicting it is a regression that passes every gate (`DECISIONS.md` 2026-09-07). The weakest row, since it resolves to prose a reader must weigh; it stays because the check is one grep. |

**Two silent traps:**

1. **A class that matches nothing looks exactly like one that works** — lint, `ngc` and the unit suite
   stay green. Only a computed-style assertion on a real build catches it: add `getComputedStyle` /
   `getBoundingClientRect` to the smoke walk, not a "does it render" check.
2. **Is the partial global?** Read `src/styles.scss`'s `@use` list: `_forms`, `_buttons`, `_badges` need
   no `@use`; `_shared-sections` (`.page-header`, `.section-title`, `.intro-text`) does.

**Placing a shared component somewhere new, re-check its assumptions there.** `<app-action-bar>` sits
at `bottom: var(--mobile-nav-height)` (`{webapp}/projects/ui/src/lib/action-bar/action-bar.component.scss:14`) and
relies on `margin-top: auto` in a flex column — neither holds on a route that hides the bottom nav and
the footer. Measure it where you put it.

**`<app-action-bar>` shows only while one of its actions can run** (`hasExecutableAction`,
`DECISIONS.md` 2026-10-09). Gate every button on what is staged; a navigate-only Cancel is disabled at
rest, and the page's breadcrumb is its exit. Never reserve room for the bar in a page: it publishes its
height to `<main>` itself.

## 4. Shared components

### Icons

- **Never a text character as an icon** (`x`, `<`, `>`, `+`).
- **Icons are FontAwesome, rendered with `<fa-icon>`** — never `<i class="fa-solid …">`; the component
  tree-shakes and type-checks.

### Primitives [STRICT]

- **A visual block used in 3 templates becomes a shared primitive before the 4th.**
- **Empty states use `EmptyStateComponent`** (`[icon]`, `[message]`) — never a fresh
  `<div class="empty-state">`.
- **Status and source badges are global classes in `src/styles/_badges.scss`** — never redefined in a
  component stylesheet.

### A card's actions: one row, no ground [STRICT]

- **Every action on a card sits in its one `.card-action-bar` row** — state (a toggle) then actions,
  destructive last (`src/styles/_card-action-bar.scss`). No second button block below the card's
  content: *Modifica* on an order is the row's ✎.
- **No resting background on the row or its controls** — a hairline above the row separates it; the
  hover wash is the only fill. A glyph with no circle is the whole affordance, so it takes a text
  token (`--primary-text`, AA), never `--primary` (under 3:1).

### Mutually exclusive elements share one slot

Two elements that are never on screen together take the same place: a state **replaces** the element
it excludes, it never adds a row beside a disabled or hidden one. Fewer elements, no layout shift
between states, and the answer sits where the user looks to act.

- **The canonical case:** a refused catalog card shows ⛔ *Al completo* where *Aggiungi* was — not a
  reason chip under the details plus a disabled button (`catalog-card.component.html`, `DECISIONS.md`
  2026-10-03).
- **A disabled control is the tell.** Before shipping one, ask whether its reason could stand in its
  place instead. Keep it disabled only when the user needs to see the action exists and what unlocks it
  (*Salva* on a form with an error).
- **Check at the Mockup Gate:** for each state in the matrix, name the element it replaces; a state that
  only adds is a finding.

### Photos edited in place are one strip [STRICT]

- **A collection of photos, or other compact media of one shape, edited in place is
  `<app-media-strip>`** (`{webapp}/projects/ui/src/lib/media-strip/`). It is one row of equal tiles that scrolls
  sideways, with the next tile always partly visible. Each tile has its controls under it; tapping the
  photo replaces it. The add tile comes last and picks a file.
- **The strip reports and the host decides.** It emits `reordered`, `removed`, `replaced`, `added` and
  `coverRequested`, and owns no list. Home confirms a removal, the item editor does not; each host's
  draft rules stay in its own controller.
- **A list of text items stays vertical.** The strip is for things recognised by their picture.

### A shared control takes a value in, not only out

**Ask of any shared control: could a host restore it to a previous state?** A control that only emits
(`dateChange` out, nothing in) works until the first consumer needs to reopen saved data — then the
value is correct in the model and invisible on screen (Sprint 46 T17, `app-date-picker`).

### Share the renderer when the fields match; share the component only when the lifecycle does

Two surfaces that render the same fields are not therefore one component. **Same fields ⇒ share the
renderer. Same lifecycle and same audience ⇒ share the component.** The order confirmation (a cart
draft, anonymous-capable) and the order detail (a persisted order, behind guards) share the line
renderer, `<app-order-lines>` (`features/reservation/booking.component.html:25`,
`features/account/order-detail/order-detail.component.html:102`), and stay two components (Sprint 46 T19).

- **A shared renderer takes capabilities, never a variant:** `canEditQuantity`, `canRemove`
  (`shared/components/order-lines/order-lines.component.ts:44`, `:46`) — not `variant: 'cart' | 'detail'`.
  Branching on *who renders it* moves the divergence inside one file, where it is harder to see.

### Filter, search and view bar — one shared component [STRICT]

- **Every list surface with filters, sort, search or a view toggle uses `FilterBarComponent`**, driven
  by a config object. No bespoke filter row.
- **Data controls and presentation stay separate:** filter facets and sort are config facets and
  search is optional; the **view toggle is not in the filter bar** — it sits in `<app-results-bar>`
  under it, right of the count (`/history`; the catalog and friends have one layout and no toggle, `DECISIONS.md` 2026-10-15). Never fold the view into the facets or
  branch on `key === 'view'` (`AGENTS.md §2` *Data-Driven State*).
- **A segmented toggle shows its icon and its word at every width** (`<app-view-toggle>`):
  *Lista | Calendario*, *Approva | Rifiuta*. No icon-only or
  selected-word-only variant — the choice must not depend on which segment is selected.
- **The bar is presentational.** It emits `facetChange` and `searchQuery`; the host owns state and URL
  sync.
- **A row of controls stays one row.** The results bar's count and toggle never
  wrap (`white-space: nowrap`); when they do not fit at 360 px the content gets shorter — *1 richiesta*,
  not *1 richiesta a settembre* when the period is already on screen — never a second line or an
  ellipsis. Checked by the smoke walk at 360 px on `/history`.

### Dropdowns and overlays close on an outside click, one open at a time [STRICT]

A floating panel closes on a `document:click` whose target is outside its host, and **its trigger click
never calls `stopPropagation()`** — that propagation is what lets a sibling's listener close the sibling.

```typescript
// ❌ opening dropdown B leaves A open
toggle(event: Event) { event.stopPropagation(); this.isOpen.update(v => !v); }

// ✅
toggle() { this.isOpen.update(v => !v); }
@HostListener('document:click', ['$event'])
onDocumentClick(event: Event) { if (!this.eRef.nativeElement.contains(event.target)) this.close(); }
```

Reference: `CustomDropdownComponent` (`{webapp}/projects/ui/src/lib/custom-dropdown/custom-dropdown.component.ts:143`
listener, `:148` trigger). Stopping propagation on an **option** click or a handled key is fine — only
the trigger must propagate.

### A panel's open class is not its active-descendant class [STRICT]

Bind the panel's visibility and the trigger's "a route inside me is active" highlight to **two
different classes**. One class for both pins the panel open whenever the route matches.

```html
<!-- ❌ with `&.open .panel { display: block }` -->
<li [class.open]="isActiveDescendant() || isManuallyOpened()">

<!-- ✅ -->
<li [class.open]="isManuallyOpened()" [class.is-active]="isActiveDescendant() || isManuallyOpened()">
```

- Reference: the header's "More" item (`layout/header/header.html:33`), fed by
  `CatalogMenuStateService.isGroupActive` (`core/services/catalog/catalog-menu-state.service.ts:130`).
- **Verify with `getComputedStyle` on the panel in a live browser.** Unit tests with a mocked DOM passed
  both times this shipped — the second time (PR #521) on the same dropdown.
- **Grep on touch:** before writing a `[class.open]` on a collapsed trigger, grep this file for
  "active-descendant".

### A full-viewport overlay is a root-level sibling [STRICT]

`<app-bottom-sheet>`, or any `position: fixed` overlay, sits at the template root — **never inside an
ancestor that is a stacking context** (`sticky` or `fixed` with a `z-index`). Inside one, its own
`z-index` competes only within that context and loses to page-level fixed elements, which can then
block the sheet's touch and scroll.

```html
<!-- ❌ -->
<div class="sticky-bar-with-zindex"> … <app-bottom-sheet>…</app-bottom-sheet> </div>

<!-- ✅ -->
<div class="sticky-bar-with-zindex">…</div>
<app-bottom-sheet>…</app-bottom-sheet>
```

It shipped twice, in two unrelated components, before it became a rule.

## 11. Select / Dropdown / Native-Control Avoidance [STRICT]

- **No native control whose picker the OS draws** — `<select>`, `<input type="color">`, `type="date"`,
  `type="time"`, `type="datetime-local"` — unless the Tech Lead asked for that exact control on that
  exact field. Build a themed component instead: a trigger button, a `position: fixed; inset: 0`
  invisible backdrop that closes on click, and a `position: absolute` panel under the trigger — as
  `IconPickerComponent` and `ColorFieldComponent` do.
  **Exempt:** `type="file"` (a filesystem boundary), permission prompts, and checkbox/radio (themed with
  `accent-color`).
- **`CustomDropdownComponent` is the dropdown**, never `<select>`. It implements
  `ControlValueAccessor`, so a form binds it with `formControlName`; outside a form use `[value]` +
  `(selectionChange)`. Its styling already matches `.form-input` — no second dropdown style.
- **Never show a raw value as a label.** Every option and user-facing enum shows a translated label; the
  value is for the control and for persistence only.
- **Options are `DropdownOption[]`** (`{ value, label, icon?, description? }`) **with `label` already
  translated** — the component renders it without a pipe. A mapping example: `toDropdownOptions()` in
  `features/admin/components/catalog-manager/catalog-form-options.controller.ts`.

## 14. Compact Forms — 12-Column Grid [STRICT]

- **`.form-row` is a 12-column CSS grid** (`src/styles/_forms.scss`). Two or more fields on one
  conceptual row share a `.form-row`, and every direct `.form-field` child sets its width with
  `.form-col-{n}` — never equal flex distribution, never an unset width.
- **`n` is `2`, `3`, `4`, `6` or `12`; nothing else exists.** `_forms.scss:122` generates only those, so
  `form-col-8` compiles, lints and renders with no error while matching nothing. Check a field's real
  width with `getComputedStyle(el).gridColumn`. Size a field to its content: a row's columns need not
  sum to 12, and leftover space is never redistributed.
- **Mobile-first.** `.form-col-{n}` applies at every width; `.form-col-md-{n}` overrides it from 769 px
  (`_forms.scss:129`; mobile is ≤ 768 px). Short fields pair `6+6` on mobile; `12` is for content that
  needs the whole line — a textarea, the odd one out of three.
- **A field group that an input reveals stays in that input's `.form-row`**, so it appears beside the
  input on desktop; the grid re-flows when an `@if`-gated item appears.

```html
<!-- ✅ features/admin/components/catalog-manager/catalog-builder-form.component.html:81 -->
<div class="form-row">
  <div class="form-field form-col-12 form-col-md-4"> … limit-bookings toggle … </div>
  @if (form.controls['limitBookings'].value) {
    <div class="form-field form-col-6 form-col-md-4"> … max per day … </div>
    <div class="form-field form-col-6 form-col-md-4"> … max per hour … </div>
  }
</div>
```
