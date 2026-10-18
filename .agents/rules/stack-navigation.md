---
paths:
  - "**/src/app/core/services/nav/**"
  - "**/src/app/layout/**"
  - "**/src/app/*.routes.ts"
  - "**/navigation.json"
  - "**/SeedNavigation.cs"
  - "**/lib/breadcrumb/**"
  - "scripts/ci/*/check-nav-*.sh"
---

# Navigation — reachability and placement

These are `stack-angular.md` §13 and §13a; the headings keep the numbers, so those citations land here.
Paths are relative to `{webapp}/src/app/`. §13 answers *is it reachable?*; §13a answers *from where?*

## 13. Routing & Navigation Discoverability [STRICT]

- **No orphan routes.** A route meant for repeat access is reachable from **persistent chrome** — the
  header icon cluster, the nav row (`NavigationConfig` `primary` / `secondary`) or the account menu.
  An inline link inside another page's content is additive, never the only way in. Exempt: redirect
  targets (`not-found`, `access-denied`, `wip`) and steps inside an already-guarded flow.
- **The entry point must be visible to the route's audience.**
  - A page for **every visitor, anonymous included**, needs a header icon or a nav-row item. The
    account menu does not count: an anonymous visitor sees it empty, or is sent to log in.
  - A page for **one role that already has a hub** may sit one hop from it — `admin/users` and
    `admin/booking-availability` behind `/admin` (`admin.routes.ts:50`, `:39`). That never licenses
    burying a public page the same way (`/friends` once shipped with only an inline link and a
    dashboard card — Sprint 30 T6).
- **A detail page that no nav entry reaches renders `<app-breadcrumb>` as its first element**, before
  the page header: one crumb per level back to the list (`routerLink`, translated label), ending with
  the current page, unlinked — `BreadcrumbComponent` refuses to link the last crumb. Build the trail as
  a `computed()` `BreadcrumbItem[]` whenever a label resolves later (the entity's own name). A back link
  or the browser's back button is not a substitute. Reference: `history/:orderId` —
  `features/account/order-detail/order-detail.component.html:7` and `.ts:123`.

## 13a. Navigation Placement Doctrine [STRICT]

Placement was reversed in **four consecutive sprints (31, 37, 42, 43)** — an admin gear added then
removed, edit mode made an action then a toggle again. Every rule below is checkable, so it cannot be
re-argued; where the type table and an invariant disagree, **the invariant wins**. Decisions:
`DECISIONS.md` 2026-08-02.

### The invariants

1. **One model, N renderers.** Persistent navigation is one ordered, typed list,
   `NavModelService.items`. Renderers may differ in capacity and chrome only — never in composition,
   order or labels.
   *Check:* a renderer only `slice()`s the model (`layout/header/header-nav.controller.ts:35`,
   `layout/mobile-nav/mobile-nav.ts:42`); one that builds or filters its own items is a violation.
2. **The nav row is role-invariant.** Every visitor sees the same row. Anything only one role can use
   is not a nav item: it goes in the corner icon cluster.
   *Check:* the nav model has no role dependency at all — not a branch that happens to agree today.
   `NavModelService` does not inject `IUserProfileService`, and `nav-model.service.spec.ts:175` proves
   the model resolves without that provider.
3. **Conditional presence is a dead-link guard, never a preference.** An item is omitted only when its
   destination does not exist for this tenant or user — an unconfigured catalog group, order history
   for a guest. Never omitted, reordered or promoted because it was judged more or less useful.
   *Check:* every omission traces to a missing destination, not to a role or a frequency claim.
4. **A new item never displaces an existing one.** It joins its type's home; if that home is full,
   *that type* grows a drawer and nothing else moves. Removing an item shortens its row without
   redistributing the slot.
5. **A label never changes meaning** with data shape, count or role — label by what the item does.
   *Check:* no label expression branches on a count, a role or an `isSingleton`-style flag. (A
   one-catalog group was once labelled with the catalog's name and a multi-catalog group with its
   action, so the label flipped noun → verb when a second catalog was added.)
6. **A `#fragment` is never a nav destination.** It looks like a route and behaves like a scroll. Make
   the section prominent on its own page instead; in-page anchors inside content are fine.
7. **Promotion is authored, never argued.** A *Learn* item outranks the *Act* block only by being in
   the tenant's `navigation.json` `primary` array.
   *Check:* no route or label literal in the nav model decides an item's rank.
   *Capacity alarm:* `primary` precedes the *Act* block, so a long `primary` can push the catalog past a
   renderer's capacity. `nav-model.service.spec.ts:106` pins the catalog inside the mobile tab window
   and is meant to fail loudly.

**A drawer does not group.** The "More" drawer renders its overflow flat, in model order
(`layout/mobile-nav/components/more-sheet/more-sheet.component.html:3`). If it ever holds enough items
to need headings, the row is under capacity — fix that, not the drawer.

### Type → home

| Type | What it is | Home |
|---|---|---|
| **Act** | What the business exists to do (catalog → book or order) | Nav row, after any promoted *Learn* item — a guaranteed slot, not guaranteed slot 2 |
| **Mine** | This user's own state (History) | Nav row, after *Act* — once the state can exist (invariant 3) |
| **Manage** | Role-exclusive administration (Admin) | Corner cluster — invariant 2 forbids the row |
| **Shortcut** | A faster path to a destination the row already reaches (cart → checkout) | Corner cluster, only while it beats the row: the cart shows only when non-empty (`layout/header/header-chrome.controller.ts:65`) |
| **Learn** | Brochure and trust content (About, Reviews, Friends) | Leads the row when authored into `primary` (invariant 7); otherwise the drawer |
| **Mode** | Changes how the current page behaves (edit mode) | Corner cluster, only on surfaces where it applies — not a destination |
| **Session / Preference** | Login, account, logout, language | Corner cluster, fixed |

**Frequency is not a placement argument** ("owners use Order daily"). Type decides the home; only the
order *within* a type may be argued from usage, and only with evidence.
