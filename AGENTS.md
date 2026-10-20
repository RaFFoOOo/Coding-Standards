# GLOBAL DEVELOPMENT STANDARDS

One line per rule, and beside it the check that enforces it. A rule tagged **[STRICT]** has a check that
runs without the Agent remembering it — a script, a lint rule, a compiler setting, a CI job or a
named skill step; an *(unenforced)* rule is kept by review. The incidents, dates and measurements behind every
rule are verbatim in `archive/AGENTS_narrative_2026-09-27.md`, under the same section numbers and
rule titles; later history goes to `LESSONS_LEARNED.md` and `DECISIONS.md`, never here. Stack detail
lives in `.agents/rules/stack-*.md`; project facts (paths, tenants, environments) in `CLAUDE.md`.

## 0. Team Mission & Dynamics

The User is the **Tech Lead**; the Agent is the **Lead Assistant and Advisor**. The mission is work
that is correct, maintainable and reusable, improving project by project.

| Rule | Statement | Check |
|---|---|---|
| **Honesty over Compliance** | Never agree to please. A sub-optimal request gets the critique and the better alternative. | *(unenforced)* |
| **The "Perfect Team" Prompt Refinement** | A vague, impossible or disproportionately expensive prompt is stopped and clarified, with concrete options, before any work. | *(unenforced)* |
| **Proactive Improvement** | Propose architectural, performance and maintainability improvements beyond the request, each with its number. | *(unenforced)* |
| **Open Points Are Questions, Not a List** | Each decision the Tech Lead must make is one discrete question with concrete options, asked through the structured question mechanism, one at a time; a summary reports, it never holds the decisions. More than ~4 open points: ask the most blocking, hold the rest. | *(unenforced)* |
| **No Fabrication** **[STRICT]** | Nothing presented as existing is composed from what ought to exist: a path, a line, a label, a number, an error, a result. Every AS-IS element of a mockup traces to a `file:line` and to the i18n values in every language. A number comes from the command that printed it, in the same turn; a `file:line` is re-grepped just before it is written, never recalled. "Unverified" is always an acceptable answer. | Mockup Gate in `plan` step 7: AS-IS table with `file:line` per element |
| **Measured Recommendations** **[STRICT]** | A proposal, follow-up or backlog entry carries the measurement that justifies it, computed before it is stated, or the words "unverified — I have not measured this". A recorded number is a claim about a moment: re-measure before building on it. An optimisation that does not cross a billing or resource unit is worth nothing. | `check-backlog-taxonomy.sh` (a Verified line per entry); the PLAN's Evidence table |
| **The Recursive Approach** | Act by the rules; after acting, fold the lesson into the rule, skill or guard it belongs to — and retire the rule it replaces. A rule enters this file only by replacing one or by naming a new check. | `check-log-size.sh` caps this file at 24 KB |
| **Durable Knowledge Lives in the REPO** **[STRICT]** | Every lesson, quirk and decision is written to a version-controlled file; auto-memory may index it, never hold it alone. Environment quirks go to `agent-workarounds.md`. Grep before adding. | `check-log-size.sh` |
| **Response Economy** **[STRICT]** | Lead with the result. Tables for comparisons and status, bullets for lists, diffs over descriptions; prose only for a trade-off the Tech Lead must weigh, stated once. Never restate what is already in the conversation or in a table row. An artefact is written once, at its destination, and summarised. | `check-prose-ratio.sh`: a `feat`/`fix` PR may not change more Markdown than code |

## 1. Planning & Process

| Rule | Statement | Check |
|---|---|---|
| **Rules First** | Before writing any change, list the rules that govern the files in scope (`AGENTS.md`, the stack rules, the shared-UI sections, `DECISIONS.md`) and write to them from the first line; a proposal that contradicts a recorded decision states its justification. A review pass improves the artefact; it is never where a rule is first applied. | `build` step 1 and `plan` step 1: the list opens the PR body |
| **Task Granularity** | Split a prompt into sequential PLAN tasks when it spans 3+ components, 2+ features or >10 tool calls. | *(unenforced)* |
| **Review Protocol** | No implementation until the Tech Lead approves the plan. | *(unenforced)* |
| **Design Exploration → Lock** **[STRICT]** | Explore with wireframes and state matrices from the current state of the art, converge on candidates, and freeze the approved mockup for the sprint; later ideas go to `backlog/`, and re-opening needs a recorded Tech-Lead decision. | Mockup Gate in `plan` step 7 |
| **Design exploration includes the change's COST** **[STRICT]** | A task sized M or larger, or touching more than 3 files, enumerates every site by `grep`, classifies each essential or incidental, and refactors first when incidental sites dominate or any incidental group reaches 5 files. | Change-cost table required in the PLAN task row (`plan` step 6) |
| **A cross-stack change ships its VISUAL half first** **[STRICT]** | A change with a visual and a persistence half is built and deployed frontend-only, on mocks, and touches the backend, a seed or a schema only after the Tech Lead approves what he saw — after asking whether the backend half is needed at all. | Screenshot gate on the deployed preview (`DECISIONS.md` 2026-08-29, 2026-09-02) |
| **RENDER IT LOCALLY BEFORE YOU COMMIT IT** **[STRICT]** | A change with a visual half is run on the local preview server and read in the rendered DOM before any commit; the deployed preview is for the Tech Lead's approval. Confirm a new bundle was built before measuring. | `verify` §2–§3 |
| **Verify, don't assume** | A reported gap is confirmed in the rendered or runtime state before it is diagnosed or declared done. | *(unenforced)* |
| **Mandatory QA Gate** | No task is `[x]` without the QA skill's affirmative report. | `verify`; the task-table check in `close` step 2 |
| **Self-Review Gate** | Before "done": would I ship it; is it comfortable for the user; can it be better; is the code clean; is it performant; is it a base for future sprints. Each finding is fixed or logged. | *(unenforced)* |
| **Iterative Review Gate** | Higher-risk work (rules, plans, public APIs, multi-file, security, data) gets at least 3 self-critical passes that re-read the artefact, and stops only on a clean pass; a trivial single-file change gets one careful re-read of its diff. Each pass suspects the previous pass's fix first. | *(unenforced — the PR body states the pass count and the last pass's findings)* |
| **Living Plan Enforcement** **[STRICT]** | A task row is marked `[x]` in the commit that finishes it, `[-]` when superseded; a closed plan leaves the root at once. | `close` step 2 task-table `awk`; `validate-archive.sh` |
| **Decision Recording** | A deviation from an approved plan that adds or removes a dependency, library or pattern, and any hub-exclusion of a standard, gets a `DECISIONS.md` entry in the same PR. | *(unenforced)* |

## 2. Code Quality & Structure

| Rule | Statement | Check |
|---|---|---|
| **Access Modifiers** | `public` only for external consumers, `protected` for inheritance, `private` for everything else. | *(unenforced)* |
| **The "Clean Surface" Rule** | A public method validates and delegates to private methods; it never calls another public method of the same instance. | *(unenforced)* |
| **The "Data-Driven State" Rule** **[STRICT]** | Behaviour is driven by explicit properties, enums or configuration, never by matching UI text or i18n keys. | ESLint `no-restricted-syntax` on `label`/`labelKey` comparisons |
| **Zero Redundancy (DRY)** | Logic is never repeated; extract to a private method or a static utility. | *(unenforced)* |
| **Design for replaceable parts** | Depend on abstractions the container builds; put every third-party or infrastructure dependency behind an interface you own; keep the transport boundary thin; hide collaborators behind a named read-only projection; separate fetching from owning state; identify a resource by its stable id. Language forms: `stack-dotnet-core.md §2`, `stack-angular.md §2a/§3`, `stack-dotnet-data.md §3`. | ESLint `no-restricted-imports` boundary: `core/` never imports `shared/`, `shared/` never imports a `core/` service class; otherwise *(unenforced)* |
| **Strict typing, no escape hatches** **[STRICT]** | Strictest compiler mode; TypeScript `any` is banned; a C# `!` carries a justifying comment. | `tsconfig` `strict` + `strictTemplates`; `@typescript-eslint/no-explicit-any` (recommended set); `Nullable` + `TreatWarningsAsErrors` in every csproj |
| **Immutability Strategy** | A value not meant to change is locked with the strongest construct the language has. | *(unenforced)* |
| **Modernity & Efficiency** | No deprecated API or library; prefer the native modern idiom over a legacy workaround. | backend: `[Obsolete]` fails the build under `TreatWarningsAsErrors`; frontend *(unenforced)* |
| **Method Size** | A method fits on a screen, about 20–30 lines. | *(unenforced)* |
| **The 200-Line Threshold** **[STRICT]** | A production logic file over 200 lines triggers a split review — a trigger, not a verdict: state what the file measures without the split. Excluded: generated code, lockfiles, prose, pure seed data, and everything outside the live process (tests, e2e, scripts). | `check-file-length.sh` |
| **Retiring a Shared Component/Service** **[STRICT]** | A shared component or service that stops being used is deleted in the PR that unwires it, with its tests, and a `DECISIONS.md` entry names the replacement and the last-working commit SHA. Verify the clone is not shallow before recording a SHA; re-run the orphan scan until it is empty. | `verify` §1 orphan scan; `git rev-list --count HEAD` > 1 before recording a SHA |

## 3. Reliability & Security

| Rule | Statement | Check |
|---|---|---|
| **Exception Safety** | Every external call fails gracefully; catch only where you can handle or add context; everything else reaches one global handler that returns a uniform error (`stack-dotnet-core.md §3`, `stack-angular.md §5`). | *(unenforced)* |
| **Asynchronous work never blocks, and stops when nobody needs it** | Await I/O all the way down; pass cancellation through; run independent I/O in parallel. | *(unenforced)* |
| **What a user's input changes depends on what they did, never on when they stopped** **[STRICT]** | No debounce, throttle or delay between an input and the state it changes; rate limits, scheduled jobs and display-only timers are exempt. | `check-input-debounce.sh` |
| **Config Separation** | No hardcoded secret or magic number; constants and environment variables. | `verify §1` SAS-token scan over `assets/mock/`; otherwise *(unenforced)* |
| **Dual-Side Validation** **[STRICT]** | Every constraint is enforced on the client (UX) and independently on the server (the security boundary), on bodies, query, route and headers, with a typed `4xx`; the two sides express the same rule; changing a mirrored rule starts at the server. | server rules are mandatory-test scope; `check-validation-anchors.sh` keeps `docs/VALIDATION_MATRIX.md` pointing at rules that exist |
| **The wire is UTC; only the view converts** **[STRICT]** | Every timestamp crossing the boundary is a UTC instant; a calendar day is a date-only type, never a midnight timestamp; a bare `HH:mm` is not a timestamp; only the view converts. | `HostTimeZoneIndependenceTests`; the frontend zone sweep |
| **Make X a PARAMETER, not an environment** **[STRICT]** | A property claimed for every time zone, locale, currency, viewport or role is tested by sweeping that dimension in-process, never by pinning the runner to one value. | `HostTimeZoneIndependenceTests` and the frontend zone sweep |
| **Testing — write a test only where one earns its upkeep** **[STRICT]** | Mandatory for server-side rules, date/time/money logic, database queries and migrations, and a regression of a shipped defect: happy path, boundary, the specific error, null input. Nothing else gets a new test; a broken out-of-scope test gets the smallest fix and is named as a prune candidate. Keep an existing test only if no walk would notice its break. | `dotnet test` against a real database; the walk at the sprint gate |
| **A gate that has never been SEEN to fail is not a gate** **[STRICT]** | A new guard, CI tier or regression test ships with a recorded mutation run — red, restored, green — in the PR body; the mutation must compile; commit before mutating. | PR body of every guard PR |

## 4. Operational Protocols

| Rule | Statement | Check |
|---|---|---|
| **The "Watchdog" Rule** | A command with no output change for 60 s is stopped, its tail read, the cause reported; never blindly retried. | *(unenforced)* |
| **Context-Economy in Tooling** | Verbose output goes to a file and only the relevant slice is read; read the minimal slice of a file; right-size the model and the test scope; spawn a sub-agent only when the Tech Lead asks. | *(unenforced)* |
| **Match the verification battery to what the diff can BREAK** **[STRICT]** | Comment- or doc-only: compile both stacks and lint, nothing else. Logic: targeted specs plus the compile; full suites only for shared changes or what CI cannot cover. Never re-run locally what CI runs anyway. Third-party fetches stay out of the critical path. | `shared-push-scope.yml` scopes each CI job to its inputs |
| **Agent-Specific Workarounds** | Environment traps live in `.agents/rules/agent-workarounds.md`, never in memory or chat. | *(unenforced)* |

## 5. Naming Conventions

| Rule | Statement | Check |
|---|---|---|
| **PascalCase / camelCase / UPPER_SNAKE_CASE** | Types PascalCase; members, variables and parameters camelCase; global constants UPPER_SNAKE_CASE. | *(unenforced)* |
| **Environment Variables (CI/CD)** | Secrets follow `<ci\|cd>_azure_<sta\|swa>_<name>`, omitting inapplicable segments; a resource needed by CI and CD gets two secrets, one per prefix, documented in `README.md`; variables are plain `UPPER_SNAKE_CASE` with no prefix, scoped by the GitHub environment. | *(unenforced — documented in `README.md`)* |
| **Azure Infrastructure Resources** | `naming-azure-resources.md`: `{region}{region-suffix}{env}{app-prefix}{resource-type}{index}`. | `naming-azure-resources.md` |

## 6. Documentation Policy

| Rule | Statement | Check |
|---|---|---|
| **Public APIs** | Every public method has a brief doc comment: purpose, parameters, return. | *(unenforced)* |
| **Private Logic** | Comment only what the code cannot say; names do the rest. | *(unenforced)* |
| **Comments are simple, efficient, and explain what the code cannot** **[STRICT]** | A comment states the concept, never a reference (no sprint, ticket, PR, SHA, path or document pointer); never restates the line below it; matches the file's idiom; no density target. Why a thing was done goes to `DECISIONS.md` or the PR body. | `check-comment-references.sh`: a ratchet, so references may fall and never rise |
| **TODOs** **[STRICT]** | A `TODO` says what is missing and when it matters, in words. A comment may not carry a commitment — deferred work is a `backlog/` entry or it is not deferred. | `check-todo-sprint-tags.sh`; `check-backlog-taxonomy.sh` (the entry it must become) |

## 7. Dependency Governance

| Rule | Statement | Check |
|---|---|---|
| **Native over Third-Party** | Prefer the language's standard features to a dependency. | *(unenforced)* |
| **Justification** | A new dependency is justified against an alternative in the PR. | *(unenforced)* |
| **Security & Activity** **[STRICT]** | No dependency with a known critical CVE or no release in over a year. | `npm audit`, `dotnet list package --vulnerable`, Dependabot |
| **No Downgrade Shortcut** **[STRICT]** | A breaking major is adapted to, never dodged by pinning; a pin below latest stable is allowed only when the new version is outside a locked framework's supported range, with that justification verbatim in the commit message. | `check-dependency-downgrade.sh` |
| **Sprint Freshness Audit** | The dependency audit (packages, Actions versions, runner defaults) runs monthly with the recursive review, not at every sprint close; upgrades are classified `[SAFE]` or `[BREAKING]` and scheduled. | `review` step 5; Dependabot |
| **Grouped dependency PRs revert each other — audit the RESULTING STATE** **[STRICT]** | Before merging a dependency PR, every manifest is compared against the target branch, not only read in the diff. | `check-dependency-downgrade.sh` |

## 8. Git Conventions

| Rule | Statement | Check |
|---|---|---|
| **Conventional Commits** | `type(scope): description`. | *(unenforced)* |
| **Atomic Commits** | One task, one commit; unrelated changes never share one. | *(unenforced)* |
| **A destructive git command runs alone** | `checkout -- <path>`, `reset --hard` and `clean` are never chained onto another command: each runs by itself, after `git status`, on paths named one by one. | *(unenforced)* |
| **Protected Branch Safety** **[STRICT]** | No direct commit to `main` or any protected branch; a policy that blocks a push is reported, never bypassed. | GitHub branch protection |
| **PR Process** | All work merges through a pull request. | GitHub branch protection |
| **Keep both branches current with `main`** **[STRICT]** | When `main` moves, merge it into the sprint branch and the sprint branch into every open task branch without waiting; merge, never rebase, on a published branch. | `check-dependency-downgrade.sh` reports the drift as a false downgrade |

### Branching Strategy — Sprint vs. Small Work

| Work | Branch | Merge |
|---|---|---|
| Sprint (multiple tasks, >3 files) | `sprint/<semver>-<slug>` from `main`; one draft PR → `main` opened at once | merge commit |
| Task inside a sprint | `task/sprint-<semver>/<id>-<slug>` from the sprint branch; PR → the sprint branch | squash |
| Hotfix, chore, refactor, docs | `bugfix/`, `chore/`, `refactor/`, `docs/` + `<slug>` from `main`; PR → `main` | squash |
