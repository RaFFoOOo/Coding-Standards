---
paths:
  - "**/*.spec.ts"
  - "**/*.testing.ts"
  - "**/vitest.config.ts"
  - "**/tsconfig.spec.json"
---

# Frontend unit tests — Vitest through `ng test`

The section number continues from `stack-angular.md`, so a `stack-angular.md §12` citation lands here.
Paths are relative to `{webapp}/`. Test classes and when to run which battery: `AGENTS.md §3`
*Testing* and `§4`.

## 12. Testing [STRICT]

### What gets a spec

`AGENTS.md §3` *Testing* sets the scope. On this stack a new spec is written only for:

- date, time or money logic — a util, a pipe, a composer such as `composeScheduledAt`;
- a regression of a defect that shipped, named in the spec.

Nothing else gets a new spec: not a component's wiring, a controller that forwards a signal, a Mock
adapter's mapping, an i18n lookup, or a template's `@if`. The smoke walk and the screenshot gate cover
those. The client-side mirror of a server rule is also not re-tested, because the server test is the
one that matters (`AGENTS.md §3` *Dual-Side Validation*).

### Run what the change touches; gate with `ng test`

- **While iterating, run only the specs the change touches** — a full run on every iteration wastes a
  cycle and hides which tests relate to the change:
  ```bash
  npm test -- --include 'src/app/path/to/changed/component/**/*.spec.ts' --watch=false
  ```
  `--include` may repeat. A bare path is read as the project name and fails; `npx vitest run` skips
  the builder and compiles JIT, so its result is not CI's — `agent-workarounds.md`.
- **[STRICT] The full-suite gate is `ng test`, never bare `npx vitest run`.** CI runs `npm test` →
  `ng test` (`.github/workflows/shared-build-angular.yml:121`), and the two runners disagree. Measured
  2026-08-12 on a commit that was green in CI:

  | Runner | Result | Why |
  |---|---|---|
  | `ng test --watch=false` | **1600 passed** | AOT; `environment.development.ts` |
  | `npx vitest run` | **20 failed**, 3 files | JIT; `environment.ts` |

  - **4 failures, the environment split:** `onboarding.guard.ts:35` returns early on
    `!environment.enableLoginFeatures`, which `environment.development.ts:25` hardcodes `true` and
    `environment.ts:27` reads from an injected flag (`false` locally).
  - **16 failures, `NG0303: Can't bind to 'pending'`:** JIT does not register a signal `input()` —
    see the next section.

  **Never "fix" a spec that fails only under bare vitest.** Re-run it with `ng test` first. The same
  divergence can hide a real failure that only CI sees.

### JIT limitations, and how to test around them

- **A signal `input()` cannot be set with `setInput()` under JIT.** Override the field on the
  instance; AOT builds are unaffected:
  ```typescript
  (component as unknown as { myInput: WritableSignal<T> }).myInput = signal(value);
  ```
- **A `toObservable(signal)` source emits asynchronously.** In a component-scoped controller
  (`*-data.controller`, `*-facet.controller`), a derived signal read right after `createComponent`
  still holds the `toSignal` `initialValue`. Do not flush with `fixture.detectChanges()`: it mounts
  child components whose providers the test lacks (`NG0201`). Test the controller directly — provide
  it in `TestBed`, `TestBed.inject(TheController)`, mock its dependencies — and flush with
  `TestBed.inject(ApplicationRef).tick()`. Keep the component spec to its thin synchronous aliases and
  handlers. (`TestBed.flushEffects()` is deprecated in Angular 22.1.6 in favour of `TestBed.tick()`.)

### A fix the user must SEE needs one check on what renders [STRICT]

When a fix exists so that a user sees something — a prefilled value, a restored selection, a label —
at least one check reads the **rendered** element, not only the model or form control that
produces it. `expect(control.value).toBe('2026-09-05')` is a true statement about a broken feature:
S46 T15's prefill passed five specs while three downstream components never displayed the value
(`archive/LESSONS_LEARNED_ARCHIVE.md`, Sprint 46 T17). For a prefill or seed, that means a smoke-walk
step or the screenshot gate on the visible control (its value shown, its placeholder gone). Write a DOM
assertion in a spec only when the fix is a shipped-defect regression (*What gets a spec*).

### Design the seam instead of reaching for `vi.mock()`

`ng test`'s builder **bans `vi.mock()` on relative imports**, and has been seen to **silently not
intercept** one on a package import — a mocked SDK class reported zero calls under `ng test` while
passing under bare vitest, so only CI failed (`archive/LESSONS_LEARNED_ARCHIVE.md` Sprint 33). Make the
mock unnecessary:

1. **A value read from `environment`** → take it as a method parameter; the spec passes a literal.
2. **A third-party class the service constructs** → build it in a `protected` factory method that the
   spec's subclass overrides — `createSdk` in `{webapp}/projects/platform/src/services/telemetry/app-insights.service.ts:58`.
3. **Module state a spec must reset** (a cache) → export a reset function and call it; **never
   `vi.resetModules()`**. The runner is not isolated, so a reset re-evaluates every module the rest of
   the worker loads, while the TestBed environment keeps the providers from `src/test-providers.testing.ts`.
   A token provided there then no longer matches the token a service injects: S79 T12b failed 5–11
   specs, a different set each run, until `date-format.util.spec.ts` used `resetDateFormatters()`.

Use this by default for any service test that needs a fake config value or SDK — not only after CI
has failed.

### A domain object in a test comes from its shared builder [STRICT]

- **A spec never writes a whole domain object inline** — `TenantConfig` and `TenantListEntry` come from
  `aTenantConfig()` / `aTenantListEntry()` (`{webapp}/projects/platform/src/models/tenant-config.testing.ts`), overriding only
  what the test is about. Enforced by `scripts/ci/project/check-test-fixture-builders.sh`.
- **A partial `{ … } as TenantConfig` stub is allowed** (the Tech Lead, 2026-09-17): the cast compiles
  through a new required field, so it causes no churn. It must still carry every field the code
  under test reads.
- **Why:** adding one required field to `TenantConfig` edited **14 FE test files** in S59 T11, each
  gaining a `currencySymbol: '€'` that asserts nothing.

### Shared test fixtures are named `*.testing.ts`

- **A test helper that is not itself a spec is named `*.testing.ts`** — Angular's own convention
  (`@angular/core/testing`). `tsconfig.app.json` excludes `src/**/*.testing.ts` (line 14) and sets
  `"types": []` (line 7). Under any other name the file joins the app program, and `ng build` fails
  with `TS2304: Cannot find name 'vi'` the moment it uses a test global.
- **Only `ngc -p tsconfig.app.json --noEmit` or `ng build` catches it** — not
  `ngc -p tsconfig.spec.json`, and not `npx vitest run`. Re-run it after every round of file changes:
  adding a non-spec file can break a program an earlier clean run already covered
  (`archive/LESSONS_LEARNED_ARCHIVE.md` Sprint 35).
