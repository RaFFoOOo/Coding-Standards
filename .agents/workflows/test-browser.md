---
name: test-browser
description: Execute the persisted UAT plan against a real Http environment, report per-case pass/fail, and review the UX of every surface it touched.
---

# UAT Walk

Executes **`docs/uat/`** — the persisted, per-feature acceptance plan — against a running app, and
reports per-case results plus a UX review.

> [!NOTE]
> Ask before running: a full walk is expensive. A targeted subset usually is not.

Run it after the build passes and before opening a PR, and at the sprint gate.

**Why it exists.** A smoke walk against an all-Mock build never exercises an HTTP adapter, so a
defect in real role resolution or a real query passes every gate. **This walk runs against the real
backend, real database and real authorization.** Do not reduce it to another Mock-mode run.

## Step 0 — Which environment, and how it authenticates [ANSWER THIS FIRST]

A mock-mode helper signs in by seeding cookies, and a real identity provider accepts none of them.

| Environment | Services | Auth | Automatable? |
|---|---|---|---|
| **Local Http + dev-auth** | real backend, real dev database | **dev fake auth** — no sign-in at all | **Yes, fully** |
| Local preview | all Mock | mock cookies | Yes — but this is the smoke walk's blind spot, not UAT |
| **Deployed environment** | real | **real identity provider** | **No.** Interactive sign-in by the Tech Lead, then drive it |

**Default to local Http + dev-auth.** It exercises the HTTP adapters, real role resolution and the
real authorization checks — the exact gap an all-Mock walk cannot see — and it needs nothing from the
Tech Lead. Requests then carry a dev-user header chosen through the app's own role picker; **sign
out, then pick**, because a Mock session left over from another build carries no identity. The role
still comes from the server, so authorization is real.

> **Verify the identity before trusting a single result.** A misconfigured header degrades silently
> to anonymous, and an anonymous run passes the read-only cases. Call the "who am I" endpoint and
> confirm the role it reports.
>
> **A direct HTTP call proves only the server half** — it sends no CORS preflight and runs no
> interceptor, and both have broken the browser path while the direct call passed. Confirm one
> *browser* request as well: the backend log must show the dev-auth acceptance for it.
>
> **Restore the local settings file when finished.** A committed dev-auth user value fails the
> repo-hygiene gate — which is the guard doing its job.

**Dev-auth cannot reach a deployed environment, by design:** the stub is compiled out of Release and
its key is absent from the deploy allow-list. A deployed walk is therefore interactive, and its
report must say so.

## Step 1 — Scope the run

| Situation | Scope |
|---|---|
| Verifying one fix | that feature's cases, plus the cases the fix could regress |
| Sprint gate or pre-merge of a sprint PR | every case |
| Shared component or routing changed | every case that renders it |

## Step 2 — Enumerate the cases — do NOT hand-write a plan

**`docs/uat/` is the plan.** Never write a per-sprint test-plan file: a second list drifts from the
first, and the coverage guard only watches `docs/uat/`.

Drive the run from a case-listing script that filters by feature and by role and can emit JSON. It
must **exit non-zero on a heading it cannot parse**, so a malformed case surfaces instead of being
silently dropped. Fix the heading; never skip the case.

Each row gives the id, role, route and `file:line`. Read that case's own **Expected** block before
executing it — the row is an index, not the assertion.

## Step 3 — Start the stack

Memory is the practical limit on a developer machine. Two dev servers plus a browser will starve it,
and the failures look like application bugs: a backend host self-terminating on a health check, a
renderer freezing mid-walk. Run **one** dev server, and check free memory before starting a second.
Signatures: `agent-workarounds.md`.

## Step 4 — Execute

**Driver — the choice is not free** (`agent-workarounds.md`):

| Driver | Use when | Constraint |
|---|---|---|
| Browser-extension driver | the default for a local walk, and the only option when a human must sign in | drives the Tech Lead's **real** browser; never touch a tab you did not open |
| Playwright MCP | scripted, repeatable runs | **shares one browser session across concurrent agents** — verify tab isolation before relying on it |

**Only real pointer events drive a reactive app.** A scripted `.click()` and a framework's debug API
are **read-safe, not write-safe**: they update signal-bound DOM without flowing through the event
path that dirty-tracking and save-enablement watch, so a debug-driven "edit" silently never
registers. Click and type for real; read state through the debug API, change it through the UI.

Traps that cost a walk each:
- **Selectors:** a control may not be the element it looks like — a calendar cell rendered as a
  `div`, not a `button`. A static class can say nothing about state; find the class the component
  actually toggles.
- **A dialog swallows the click.** A confirm action fires on the dialog's own button. A failed click
  reporting an overlay element at the centre means exactly this.
- **Re-measure coordinates after any scroll or reflow**, or the click lands outside the frame.
- **A page load resets in-memory Mock state** — in Mock mode, never verify a write by navigating.

Mark each case **✅ PASS**, **❌ FAIL**, or **⛔ BLOCKED** (could not reach the state — say why).
**BLOCKED is not PASS.** A case whose result you inferred rather than saw is BLOCKED.

## Step 5 — Handle failures

For every ❌ FAIL:
1. Record it **in that case's own file** under `docs/uat/`, so the next run sees it.
2. Add a fix task to the sprint `PLAN.md`, before the remaining tasks.
3. Fix, then re-run **that case**, not the suite.

Every run states which environment and which auth mode it used. A Mock-mode result and an Http-mode
result are not comparable, and that gap is the whole reason this workflow exists.

## Step 5b — UX review of every surface the walk touched [MANDATORY]

A walk is the only time anyone looks at the running product. A pass/fail table throws that away.

Output a **UX observations** section separate from the pass/fail table, even when every case passed.
Proposals only — a design idea found mid-sprint is logged, never built in-flight (`AGENTS.md §1`).

### The six parameters — score each surface on all six

| # | Parameter | How to measure it, not judge it |
|---|---|---|
| 1 | **Clicks to result** | Count taps from entry to completed result. State the count and the shortest path the IA allows. A step that only confirms something already visible is a finding. |
| 2 | **Element clarity** | Does each control's label say what it *does*? Is exactly one primary action visually dominant? Is every result announced? Read the rendered copy, never the i18n key. |
| 3 | **Compliance across the app** | Does this surface use the shared primitives, or a local re-roll? Run the shared-surface grep inventory in the stack rule: action bar, page header, button and form-grid classes, empty state, filter bar, breadcrumb. A class that resolves to nothing looks exactly like one that works — check the **computed** style. |
| 4 | **Attractiveness vs the real market** | Name a **real competitor shipping this same feature** and say concretely what they do that we do not. "Looks dated" is not a finding; "they show the total before the date picker closes, we show it two screens later" is. **Cite the page you looked at, URL and date, or write "unverified — not looked at"**: a comparison written from memory is a fabricated finding (`AGENTS.md §0`). |
| 5 | **Mobile-first, desktop-efficient** | Measure at 375 px and at desktop. Mobile: no horizontal scroll, tap targets ≥44 px, thumb-reachable primary action. Desktop: not a stretched phone layout — is the extra width doing work? |
| 6 | **Your own expert read** | Anything the five above miss. Say it plainly. |

### Each observation carries four things, or it is not reported

**Where** (route and element) · **What you saw** (measured where measurable — a count, a px value,
the actual copy) · **What it costs the user** (a step repeated, a state unreachable, a thing
misread) · **One proposal** and its cost.

Rank by cost to the user, never by ease of fix.

**Never invent the AS-IS half** (`AGENTS.md §0`). Every observation names something reached in the
browser *this run*. "I could not reach that state" is a complete report.

**Say what is right, briefly.** A deliberate constraint misread as a defect is the most expensive
wrong report — a dropdown capped at a real capacity limit looks like a missing option until you
notice it is dual-side validation working exactly as specified.

### Checkpoints — never re-review an unchanged surface

Keep one row per surface: route, the files that render it, a **content fingerprint**, the date
reviewed, and any open observations. Fingerprint the rendering files' content, not their git history
— a shallow clone falsifies `git log`.

| Condition | Do |
|---|---|
| Fingerprint matches the row | **Skip.** Report "unchanged since `<date>`" and carry its open observations forward verbatim. |
| Fingerprint differs | Re-review all six parameters. Update the row. |
| No row yet | Review and add a row. |
| **A case on this surface FAILED this run** | **Re-review regardless of fingerprint.** A defect means the surface behaves differently from what the last review saw, whatever the files say. |

Update the checkpoint file in the same commit as the run report — one that lags is worse than none,
because it silently suppresses a review.

## Step 6 — Stop the stack, and put the settings back

Stop only what you started yourself, restore the local settings file that dev-auth modified, and run
the repo-hygiene gate before any commit. A dev server left running on a self-hosted runner's own
machine fails the next CI job.

## The report

```markdown
# UAT run — <date>
**Environment:** local Http + dev-auth · **Auth:** dev fake auth (owner) · **Tenant(s):** <tenant>
**Scope:** <all | feature X | the cases touching Y>

| Case | Result | Note |
|---|---|---|
| UAT-booking-01 | ✅ | |
| UAT-booking-04 | ❌ | expected …, saw … |
| UAT-admin-06b  | ⛔ | could not reach: no past block-out exists on this tenant |

**Failures:** <each linked to the case file and the PLAN task raised>
**UX observations:** <Step 5b — always present, even at a full pass>
```

Counts must add up to the scope, and **⛔ is reported as its own column value, never folded into a
pass rate**. A run that reports a pass rate while a case was unreachable is a false report.
