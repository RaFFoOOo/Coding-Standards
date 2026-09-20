---
name: Stack Navigation
trigger: glob
globs: ["**/*.routes.ts", "**/*.ts", "**/*.html"]
description: Routing, discoverability and navigation placement
---

# Stack Navigation

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
data edit.

**Corollary — a drawer does not group.** A "More" drawer renders its overflow **flat, in model
order**. Sectioning it (two category headings, added and removed within one sprint) re-sorts the
overflow away from the single ordered model that invariant 1 exists to guarantee, and spends two
headings plus an ungrouped block organising four items. If a drawer ever holds enough items for
grouping to pay, that is evidence the row is under-capacity — fix the capacity, not the drawer.

> **Why the table is subordinate.** Its first version typed both `Admin` **and** the **cart** as
> *Manage* → "persistent slots", while the cart had shipped as a corner icon since long before that
> version was written. A rule the codebase contradicts on day one cannot settle a future argument —
> which is exactly how it failed. The invariants are checkable; the table is a summary of them.
