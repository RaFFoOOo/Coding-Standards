---
name: ux-review
description: Full-site heuristic UX review — usability, clarity, attractiveness, utility, and standards compliance across every page, evaluated per user role. Produces a single docs/UX_REVIEW_<date>.md deliverable, analysis-only.
---

# SKILL: ux-review

> **Claude Code:** Uses Playwright MCP (`mcp__playwright__*`) against a **live deployed** SWA
> (dev slot or preview slot), not a local `ng serve`. Confirm the target URL with the Tech Lead
> before starting if it isn't obvious from the most recent deploy.
>
> **Why deployed, and not the reason this note used to give.** It previously said the sandbox
> *cannot* run a local dev server. Asserting a toolchain is unavailable without attempting it is
> exactly what `agent-workarounds.md` forbids, and where that claim was checked it turned out to be
> false. The instruction survives for a different and better reason: **a local run is all-Mock, and
> Mock fixtures have holes** — fields no fixture populates, and image URLs that need credentials the
> local build does not carry. A UX review judges what users actually see, so it targets an
> environment serving real data.

Execute this skill to produce a candid, evidence-based assessment of the application's UX —
distinct from `/recursive-review` (code/process/rules health) and `/run-qa §4` (per-feature,
per-task responsiveness spot-check). This skill looks at **rendered pages**, judged the way a real
user experiences them, not the code that produces them.

## § 0. When to Invoke

- Tech-Lead-triggered — no fixed cadence yet (unlike `/recursive-review`'s monthly/2-sprint rule).
  Natural triggers: before a pilot launch, after a UX-heavy sprint closes, or whenever asked "how
  does this actually feel to use."
- Not a substitute for `/run-qa §4` (still required per-feature before every PR) or
  `/recursive-review` (still required for code/rule health) — this skill is a third, separate axis.

## § 1. Pre-flight [MANDATORY]

1. Read `CLAUDE.md`, `AGENTS.md`, `.agents/rules/stack-angular.md` in full — most findings will be
   frontend, and a finding that just restates an already-STRICT rule is redundant, not a discovery.
2. Read the most recent `docs/UX_REVIEW_*.md` (if any) — carry forward undelivered findings (§7).
   For the very first run, also read `docs/UX_AUDIT_sprint_025.md` as historical baseline — it
   covered element-style consistency only (buttons/forms/color tokens, code-analysis, no rendering);
   this skill supersedes it in scope but should not re-litigate what it already fixed.
3. Read `<spa-app>/src/app/app.routes.ts` for the current route inventory. Build the page list from
   it directly — a route added since the last review is new scope, not an omission.
4. Confirm the live URL to point Playwright at (the dev SWA's own hostname, or a fresh preview
   deploy) and which tenant it resolves to.

## § 2. Scope Decisions [confirm with Tech Lead before starting, then reuse]

- **Chunk by role, two separate passes/PRs** (default): Pass 1 = every
  anonymous-guest + authenticated-customer page. Pass 2 = every owner/admin page. Each pass appends
  its own section to the **same** `docs/UX_REVIEW_<date>.md` (first pass creates the file with a
  `STATUS: PASS 1 OF 2` header; second pass completes it) — same one-doc-multiple-addenda pattern
  already established for `archive/QA_REPORT_sprint_*.md`.
- **Tenant scope (multi-tenant projects): one primary tenant at full depth, spot-check the others**
  (default). Primary = the tenant with the richest content and the most edge cases. For the rest,
  only check pages/flows that plausibly diverge: business-type-specific UI (order vs. reservation vs.
  appointment terminology and flows), and the tenant's own theme colors against WCAG-AA (a
  contrast pass that PASSES on one tenant's palette can FAIL on another's — this is exactly the
  class of bug `ColorFieldComponent`'s contrast badge exists to catch at config-time, so verify it
  actually holds at render-time too).
- Re-confirm both decisions with the Tech Lead if scope has changed materially since 2026-07-22
  (new tenant onboarded, new role introduced) — don't silently assume the same defaults forever.

## § 3. Page Inventory Template

Build this table before evaluating anything — it IS the scope, not just documentation of it:

| Page | Route | Roles it renders differently for | Pass |
|---|---|---|---|
| Home | `/` | Anonymous / Customer / Owner (edit-mode chip) | 1 |
| ... | ... | ... | ... |

## § 4. Execution — per page

For each page, for **both** viewports (375px mobile, 1920px desktop, per `run-qa §4`'s existing
standard):

1. `browser_navigate` to the page (as the role under evaluation — anonymous session, or a
   logged-in customer/owner session per this project's existing dev-login affordance).
2. `browser_resize` to the target viewport, `browser_take_screenshot` (keep as evidence).
3. `browser_console_messages` — any `console.error`/`console.warn` is a 🔴 finding on its own,
   zero-tolerance per `run-qa §1`, regardless of visual quality.
4. Evaluate against the heuristic checklist (§5) and record every finding that clears the bar in
   §6's format. A page with zero findings still gets a row — "reviewed, no findings" is a real,
   useful result, not an omission.

## § 5. Heuristic Checklist

Adapted from Nielsen's 10 usability heuristics + this project's own standards. Apply all of these
to every page — not every one will produce a finding, but skipping one silently is how a review
misses a category of bug entirely:

1. **Visibility of system status** — loading states, save confirmations, error states all visible?
2. **Match between system and the real world** — plain-language labels, no unexplained jargon or
   raw enum values (`AGENTS.md §2` Data-Driven State rule's UI-facing twin — a raw internal label
   surfaced to a user is this failure mode).
3. **User control and freedom** — is there always an obvious cancel/back/undo?
4. **Consistency and standards** — internal consistency (does this page match the visual language
   of every other page) AND external standards (`stack-angular.md`: no native OS controls per
   §11, `.form-row` 12-col grid per §14, icon rules per §4, breadcrumbs per §13).
5. **Error prevention** — can the user submit something invalid without warning first?
6. **Recognition rather than recall** — does the user have to remember something from a prior
   screen, or is it visible/available where they need it?
7. **Flexibility and efficiency of use** — is the common path short? Any avoidable extra taps?
8. **Aesthetic and minimalist design** — the "attractiveness" axis. Visual hierarchy, whitespace,
   alignment, does it look intentional or accidental. Judged from the actual screenshot, not code.
9. **Help recognize/diagnose/recover from errors** — do error messages say what went wrong AND
   what to do about it, or just "Error"?
10. **Utility** — does this page actually serve the task the role came here for, efficiently? Is
    the primary action obvious within 2 seconds of landing?
11. **Accessibility (WCAG-AA)** — contrast, focus-visible states, semantic HTML/ARIA
    (`run-qa §7`'s existing baseline, applied here at the rendered-page level, not just per-feature).
12. **Mobile icon-only buttons** — does each have a real accessible label (not a hardcoded string
    that ignores mode/auth state — e.g. an account menu concatenating a generic "Login" label with a
    signed-in user's name), is the icon/label balance right, is every action reachable in a
    sensible number of taps?
13. **Visual hygiene** — margin/spacing consistency, unnecessary whitespace, elements that don't
    earn their place on the page.
14. **Element sizing** — too big, too small, or the wrong shape for its content/importance relative
    to its neighbors.

## § 6. Finding Format [MANDATORY — mirrors `/recursive-review §3`]

Every finding gets:
- **Severity:** 🔴 breaks the task / actively misleading · 🟡 real friction, works around it ·
  🟢 polish, nice-to-have
- **Page + role + viewport**
- **Evidence:** the screenshot reference + which heuristic (§5, numbered) it violates
- **Proposed fix:** specific and actionable, never "improve the styling" — state what would change
- **Target:** existing `backlog/` entry to fold into, or "new — needs a Mockup Gate" if it's a visual
  design change (per `AGENTS.md §1` Design Exploration → Lock: a UX finding proposing a visual
  change is a design *idea*, not an approved design — it does not get implemented off this doc
  alone)

## § 7. Carry-forward Rule

The next run treats the prior `docs/UX_REVIEW_*.md` as mandatory input: which findings were acted
on, which weren't (flag if 2+ reviews raised the same one and it's still open), and whether a
finding this review would raise was already raised and dismissed with a recorded reason (don't
re-litigate a closed call silently — if dismissing again, cite the prior dismissal).

## § 8. Synthesis — the doc

Write to `docs/UX_REVIEW_<YYYY_MM_DD>.md`:

1. Reading guide (one paragraph) + scope recap (§2's decisions as applied this run)
2. **Executive summary** — top 5 takeaways, 60-second read
3. **Page × role inventory** (§3's table, filled in)
4. **Findings**, grouped by page, severity-tagged (§6)
5. **Cross-cutting patterns** — a finding that recurs on 3+ pages is a systemic issue, call it out
   once here instead of repeating it per-page
6. **Proposed roadmap** — priority-ordered table of every finding, each tagged with its target
   (existing `backlog/` entry / new `backlog/` entry / needs a Mockup Gate)
7. **Open questions for the Tech Lead**

Keep it readable in one sitting per pass — this is a review, not an archive.

## § 9. PR + Follow-up

1. Branch: `chore/ux-review-<YYYY-MM-DD>` from `main` (or continue the same branch for Pass 2).
2. Single commit per pass, conventional: `docs(ux): UX review pass 1 — guest/customer pages —
   <date>`.
3. Do **NOT** implement any finding in the same PR/branch — this skill produces a doc only, exactly
   like `/recursive-review §6` step 5. A 🔴 finding that's cheap and obviously correct (a typo, a
   missing `alt` text) is still logged here, not fixed inline — the review's value is being a
   trustworthy, complete inventory; mixing in opportunistic fixes makes it unclear what's reviewed
   vs. patched.
4. **[MANDATORY]** Every roadmap item gets a real `backlog/` entry (or a sprint task, if the Tech
   Lead resolves it concretely during PR review) in the **same** resolution pass — never leave a
   decision as review-doc prose alone (`/recursive-review §6` step 6's own hard-learned rule, same
   failure mode applies here identically).

## § 10. Anti-patterns

- **Vibes without evidence.** "The Home page feels dated" is not a finding. "Home's hero section
  (screenshot: `home-desktop.png`) has no visual hierarchy — H1, CTA, and body text are all the
  same weight, violating heuristic #8" is.
- **Fixing while reviewing.** The moment you edit a component file, you've left this skill's scope.
- **Skipping the screenshot.** A claim about visual quality without the screenshot that shows it is
  unverifiable by the Tech Lead later.
- **Reviewing code instead of the rendered page.** If you catch yourself opening a `.scss` file to
  judge whether something looks good, stop — navigate to the page and look at it instead. Code
  review is `/recursive-review`'s job.
- **One page per role treated as the whole role.** Home looks different for Owner (edit chip) than
  Catalog Manager does — don't extrapolate one page's role-handling to the rest.
