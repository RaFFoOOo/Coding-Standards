---
name: Stack Angular Testing
trigger: glob
globs: ["**/*.spec.ts", "**/*.testing.ts", "e2e/**"]
description: Frontend test strategy and harness rules
---

# Stack Angular Testing

## 12. Testing [STRICT]

- **Targeted runs during development:** Never run the full suite while iterating. Pass only the spec
  files (or directories) touched by the current change — the exact command depends on whether the
  project has its own standalone `vitest.config.ts`:
  - **Project has a standalone `vitest.config.ts`** (this project does — see `<spa-app>/vitest.config.ts`,
    a hand-built config that mirrors Angular's `templateUrl`/`styleUrls` inlining so bare Vitest can
    JIT-compile components): run it directly —
    ```bash
    npx vitest run src/app/path/to/changed/component/ src/app/path/to/other/spec.ts
    ```
  - **Project has no standalone `vitest.config.ts`** (relies solely on the integrated
    `@angular/build:unit-test` builder to bootstrap Vitest + `TestBed`): a bare `npx vitest run` skips
    that bootstrap and fails immediately with `Need to call TestBed.initTestEnvironment() first`, even
    for specs that are otherwise valid. Use the builder's own filter instead:
    ```bash
    ng test --include 'src/app/path/to/changed/component/**/*.spec.ts' --watch=false
    ```
  - **Don't confuse this with vitest-cache corruption** (`local-vitest-cache-corruption` memory): the
    identical `TestBed.initTestEnvironment()` error can also come from a stale
    `node_modules/.vite`/`.vitest` cache even though this project's `vitest.config.ts` is present and
    working — that class clears with `rm -rf node_modules/.vite node_modules/.vitest` and doesn't
    recur. A project with no `vitest.config.ts` at all is the *other* failure class described above,
    not cache corruption.
  - **The full-suite gate run MUST be `ng test`, never bare `npx vitest run` [STRICT].** Targeted
    iteration may use either; the `/run-qa` gate may not. `ng test` is what CI runs, and the two
    runners **do not agree** — measured 2026-08-12 on `sprint/45` at a commit whose CI was green:

    | Runner | Result | Why |
    |---|---|---|
    | `ng test --watch=false` | **1600 passed** | AOT build; `environment.development.ts` |
    | `npx vitest run` | **20 failed**, 3 files | JIT; `environment.ts` |

    Both divergences were already known — the environment split from an earlier CI-only failure
    (transcribed into `app.routes.structure.spec.ts`'s own header table) and the JIT `input()`
    limitation in the very next bullet — but each was written as a *spec-authoring* caveat, so
    neither stopped the gate itself being pointed at the weaker runner. The two shapes seen:
    - **4 failures — the environment split.** `onboarding.guard.ts` early-returns on
      `!environment.enableLoginFeatures`. The base `environment.ts` resolves that flag from an
      injected token (**false** locally); `environment.development.ts` hardcodes `true`. So under bare
      vitest the guard returns `true` and every redirect assertion fails.
    - **16 failures — `NG0303: Can't bind to 'pending'`** on a signal `input()` of a shared component
      that is correctly listed in the consumer's `imports`. JIT does not register it; AOT does.

    **The failure mode is the dangerous direction: bare vitest reports *phantom* failures here, but the
    same divergence can hide a real one** — a spec that only passes under JIT/`environment.ts` is
    exactly the CI-only break that has bitten this project twice. Do not "fix" a spec that fails under
    bare vitest and passes under `ng test`; re-run it the CI way first, and only then decide whether
    there is anything to fix.

    Targeted runs still stay targeted: running everything on every iteration wastes a cycle and
    obscures which tests relate to the work in progress.

- **JIT `input()` limitation:** In Vitest JIT mode, signal inputs declared with `input()` /
  `input.required()` cannot be set via `fixture.componentRef.setInput()` — Angular registers them
  only under AOT. Override the signal field directly on the instance:
  ```typescript
  (component as unknown as { myInput: WritableSignal<T> }).myInput = signal(value);
  ```
  AOT (production build) resolves `input()` normally; this workaround is test-only.

- **`toObservable(signal)` sources flush via `ApplicationRef.tick()`, not `detectChanges()`:** a component-scoped controller (`*-data.controller` / `*-facet.controller`) that sources data
  from `toObservable(someSignal).pipe(switchMap(...))` emits **asynchronously** in JIT — reading a derived
  signal right after `createComponent` returns the `toSignal` `initialValue`, not the data. Do **not**
  reach for `fixture.detectChanges()` to flush: it renders the full template and mounts heavy child
  components whose providers a unit test doesn't supply (`NG0201`). Instead **test the controller directly**
  (provide it in a `TestBed`, `TestBed.inject(TheController)`, mock its deps) and flush its effects with
  `TestBed.inject(ApplicationRef).tick()` — render-free, so no child providers needed. Keep the *component*
  spec to the synchronous thin aliases/handlers. (`flushEffects` is not in Angular 22's public testing API.)

- **`ng test`'s builder unreliably intercepts `vi.mock()` — design the seam instead of mocking around
  it:** `ng test`'s `@angular/build:unit-test` Vitest builder (a) hard-bans `vi.mock()` on **relative**
  imports outright (`"The 'vi.mock' and related methods are not supported for relative imports...
  Please use Angular TestBed for mocking dependencies"`), and (b) has also been observed to **silently
  fail to intercept** a `vi.mock()` on a **package** (non-relative) import — a mocked third-party SDK
  class's methods reported zero calls under `ng test` despite passing locally under a bare
  `npx vitest run` (observed on a telemetry-SDK wrapper service and its spec). A bare
  `vitest run` doesn't route through the same builder, so this class of failure is CI-only and
  invisible to local iteration. **The durable fix is structural, not a better mock:** design the seam
  so nothing needs mocking —
  1. Anything read from `environment` inside a service under test: pass it as a **method parameter**
     instead of importing `environment` directly; the spec passes a literal value.
  2. Anything that directly `new`s a third-party SDK/library class: move the construction behind a
     `protected`, **overridable factory method**; the spec subclasses the service under test and
     overrides the factory to return a lightweight test double.
  Treat any new service test needing to fake a config value or a third-party class construction as a
  candidate for this pattern **by default** — don't reach for `vi.mock()` first and only fall back to
  this after CI fails.

- **Shared test-only fixtures/helpers that are NOT themselves a `.spec.ts` file MUST be named
  `*.testing.ts` and excluded from `tsconfig.app.json`** (mirrors `@angular/core/testing`,
  `@angular/common/http/testing`'s own naming convention). `tsconfig.app.json`'s `exclude` is only
  `src/**/*.spec.ts` — a shared fixture file (e.g. hoisted `vi.fn()` stubs, a `MOCK_TENANT` const, a
  `setupModule()` helper reused across several split spec files) that doesn't match that pattern is
  still included in the production app's TypeScript program and gets bundled by `ng build`, which
  fails with `TS2304: Cannot find name 'vi'` (or `describe`/`expect`) the moment the file uses a
  test-runner-only global — `tsconfig.app.json` sets `"types": []` deliberately, so nothing makes
  `vi` a recognized ambient identifier there. **This is invisible to `ngc -p tsconfig.spec.json`**
  (which type-checks clean — `vitest/globals` is included there) and to plain `npx vitest run`
  (esbuild transpiles per-file, doesn't do the same whole-program ambient-global resolution `ngc`'s
  full type-checker does for `tsconfig.app.json`) — only a real `ng build` or `ngc -p
  tsconfig.app.json --noEmit` **run after the fixture file exists** catches it (`LESSONS_LEARNED.md`
  when a large spec file was split and its shared fixtures hoisted). Fix: name the file
  `some-name.testing.ts` and add `"src/**/*.testing.ts"` to `tsconfig.app.json`'s `exclude` (a
  one-time project-level addition, already done) — `tsconfig.spec.json` needs no corresponding
  change, since TypeScript still pulls the file into that program transitively via any `.spec.ts`
  file's `import`. **Re-run `ngc -p tsconfig.app.json --noEmit` after every round of file changes**,
  not just once early in a session — a later edit (especially adding a new non-`.spec.ts` file) can
  silently invalidate an earlier "clean" result for a tsconfig that edit didn't touch.
