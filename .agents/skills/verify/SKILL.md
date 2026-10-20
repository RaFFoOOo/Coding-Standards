---
name: verify
description: Prove a change before its PR and at the sprint gate — quick scan, console zero-tolerance, viewports, accessibility, backend checks, the performance budget with its unit, and the UAT walk on a real Http environment.
---

# verify

The result goes in the **PR body** as a `STATUS: PASS` block (§8) — never a `QA_REPORT.md` file.

## 1. Quick scan — on the changed files
1. Runtime errors, null paths, unhandled edge cases? Do calculations and data flows agree?
2. Re-renders, missing `OnPush`, waterfall subscriptions?
3. Unsanitised input, exposed secret, missing error handling?
4. Methods over ~30 lines, duplicated logic, a file crossing 200 lines?
5. Alignment, spacing, responsiveness; optimistic updates where a user waits; consistency with the
   approved mockup and the shared primitives.
6. Every rule in `AGENTS.md` and the stack rule for these files followed?
7. Every **added** test is one `AGENTS.md §3` *Testing* makes mandatory; every in-scope change
   (a server rule, date/time/money, a query or migration, a shipped defect) has one.
8. If `assets/mock/` changed: `grep -r "sig=" {webapp}/src/assets/mock/` — any hit blocks.
9. **Orphan scan** — if the change unwires a shared component or service (`shared/`, `core/services/`):
   `git grep -n "<selector>\|<ClassName>" -- {webapp}/src/app ':!*.spec.ts'`. Zero uses left means it
   is deleted in this PR, with its specs, and `DECISIONS.md` names the replacement (`AGENTS.md §2`).

## 2. Console zero-tolerance
Drive the changed flow in the browser with the console open. Any app-origin `console.error` or
`console.warn` stops the gate: capture the stack, map it to source, fix, re-run. Third-party origins
(an IdP page, a blocked font) are reported, not counted.

## 3. Viewports and interaction
Render at **375** and **1920**: no horizontal scroll on mobile (`scrollWidth <= innerWidth`), no
overlap, tap targets ≥ 44 px, primary action thumb-reachable; click every new interactive element;
hover and active states visible; fonts and colours resolve to the design tokens, not literals.
**A correctness bug found here is fixed before done. A usability gap is logged to `backlog/`,
never fixed mid-gate.**

## 4. Accessibility baseline
Contrast on text and controls; tab through every new control with a visible focus state; semantic
elements; every icon-only button has an accessible name — **resolve the computed name and check it
is correct for the current state**, not merely present. A file existing is not a translation
complete; a route declared is not a route resolving; prefer the computed value in every check.

## 5. Backend
Every touched endpoint returns the expected 2xx or a typed 4xx; payload shape checked; domain
exceptions map to RFC 7807 `ProblemDetails`; the server test covers the rule.

## 6. Performance budget
- Bundle headroom is **`1 000 kB − initial total`** (Angular counts 1 kB = 1 000 B). Report it.
- A test count carries its configuration (backend Debug runs `#if DEBUG` tests Release does not).
- Context budget: `wc -c CLAUDE.md AGENTS.md .agents/rules/agent-workarounds.md`.
- `FILE_LENGTH_NEAR=190 bash scripts/ci/generic/check-file-length.sh` — one line per listed file: split
  (what moves) or keep (why cohesive).

## 7. UAT walk on a real Http environment
Runs at the sprint gate, after a fix a Mock walk cannot see, and when a shared component or route
changed. **Local Http + `devauth` is the default**: real backend, real dev database, real
authorization, no sign-in. The all-Mock `preview` walk (`npm run smoke:walk`) is not UAT.
**In a remote sandbox** it runs too, with the backend in `DATA_ACCESS_MODE=Mock`:
`agent-workarounds.md` *The Http + `devauth` walk in the sandbox*. Never report it as impossible.

1. **Environment and identity.** Backend in Debug with, in `local.settings.json` (never commit a
   value): `"DEV_FAKE_AUTH_USERS": "owner=<oid>,customer=<oid>"`, `"BOOTSTRAP_OWNER_ENTRA_ID": "<owner oid>"`;
   `cd {webapp} && ng serve --configuration devauth`. Sign out, then pick the dev role. Prove it:
   ```bash
   curl -s "$API/v1/me?tenantId=$TID" -H 'X-Dev-User: owner'   # must report "role":"owner"
   ```
   and one **browser** request logged `DEV FAKE AUTH accepted` (curl skips CORS and interceptors).
   A deployed environment needs the Tech Lead's interactive sign-in; say so in the report.
2. **Scope.** One fix: its cases plus the ones it could regress. Sprint gate: every case. Shared
   component or routing: every case that renders it.
3. **Cases come from `docs/uat/`** — never a hand-written plan:
   ```bash
   node scripts/uat/list-cases.mjs [--feature <f>] [--role <r>] [--json]
   ```
   Read each case's **Expected** block before executing it. A heading it cannot parse exits
   non-zero: fix the heading, never skip the case.
4. **Stack:** `scripts/local-dev/{short}-dev up`; one dev server at a time; check `free -m` first.
5. **Execute with real pointer events.** `.click()` and `window.ng` are read-safe, not write-safe.
   Traps: calendar cells are `div.day-cell`, state is `.disabled`/`.empty`; `Conferma` opens a
   dialog and the action fires on its button; re-measure after any scroll; a page load resets
   Mock state; `locator.isVisible()` does not wait — assert with `expect(...).toBeVisible()`.
   Mark **✅ PASS**, **❌ FAIL**, **⛔ BLOCKED** (could not reach the state — say why). Inferred is
   BLOCKED, never PASS.
6. **Failures:** record in the case's own file under `docs/uat/`, add a fix task before the
   remaining ones in the plan, fix, re-run that case.
7. **UX observations of every surface touched** — always, even at 100 %: per surface score
   clicks-to-result (count them), element clarity (read the rendered copy), compliance (the shared
   primitives via the `stack-shared-ui.md §4a` greps, computed style not class), attractiveness
   against a **named competitor page you looked at (URL + date)** or "unverified", mobile-first and
   desktop-efficient (375 and desktop measured), your own read. Each observation: **where**, **what
   you saw** (measured), **what it costs the user**, **one proposal with its cost**. Ranked by cost
   to the user. Never invent the AS-IS; "could not reach that state" is a complete report.
   Checkpoints: `docs/uat/UX_CHECKPOINTS.md` holds one row per surface with a content fingerprint —
   `cat <files rendering the surface> | sha1sum | cut -c1-12`. Matching fingerprint and no failure:
   skip and carry its open observations forward; otherwise re-review and update the row in the
   same commit.
8. **Stop and restore:**
   ```bash
   scripts/local-dev/{short}-dev down; pkill -x func; docker rm -f {short}-dev-azurite   # only what you started
   git checkout -- {services}/{Backend}.Functions/local.settings.json
   bash scripts/ci/project/check-dev-auth-gate.sh                                         # exit 0 before any commit
   ```

## 8. Report — in the PR body
```
STATUS: PASS | FAIL
Environment: <local Http + devauth | preview Mock | deployed dev (interactive)> · Auth: <mode> · Tenant(s): <…>
Console: clean | <errors>          Viewports: 375 ✓ 1920 ✓          a11y: <notes>
Headroom: <n> kB of 1 000          Tests: <fe n/n> · <be n/n Release, n/n Debug>
UAT: <scope> — ✅ n · ❌ n · ⛔ n   (counts add up to the scope; ⛔ is never folded into a pass rate)
UX observations: <list or "none new; k carried forward unchanged">
```
`STATUS: PASS` requires a clean console, all cases ✅, and every FAIL fixed and re-run.
