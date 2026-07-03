# Project Backlog & Notes (TODO)

This file contains tasks, ideas, and architectural improvements that are **not processable in the current sprint**. It serves as the project's backlog and scratchpad for the team.

---

## 📌 Backlog / To Do
*Items to be evaluated for future sprints. When starting a new `PLAN.md`, the Agent must review this list and move processable items into the active sprint plan.*

- [ ] Configure Playwright MCP server (`.mcp.json`) to enable native browser testing via the `/browser-test` skill in Claude Code projects.
- [ ] Evaluate adding a `hooks` section to `.claude/settings.json` in the sync-template output for Claude Code targets (e.g., PostToolUse linting hook on Write/Edit).
- [ ] Consider adding a `Copilot` (GitHub Copilot) transformation path to `sync-template` once its agent file conventions stabilize.
- [ ] **Promote le-cementine's GitHub Actions cost-discipline standards (genericize first)** — surfaced by the first real N-way SYNC (T7, 2026-07-03). le-cementine's `stack-github-actions` carries genuinely-useful generic standards entangled with project specifics: (1) *preview CI is `workflow_dispatch`-only* (cost: each preview is a full build+deploy, Actions minutes are a hard cap); (2) *one job per logical gate except trivial guards* (GitHub bills per job rounded up to a whole minute — share sub-second checks in one job); (3) *CodeQL private-repo/GHAS licensing reality* (analysis runs but Security-tab upload needs paid Advanced Security; running the CLI with `upload:false` to dodge GHAS is license-gray). Deferred from T7 because promoting needs a genericization judgment (strip `ci-preview-swa.yml`/`validate-archive.yml`/dates/`Free private repo`) not appropriate to make on borrowed content mid-sync.
- [ ] **Engine finding — `sync-templates` Step 5a substitution corrupts meta-workflows** (T7, 2026-07-03). The blanket `.agents/skills/`→`.claude/skills/` content substitution mangles any workflow that discusses paths as *subject matter* rather than referencing its own operational paths — most acutely `sync-templates` itself (its shape-detection table reads `.agents/rules/ ... else .claude/rules/`). T7 delivered `sync-templates` to spokes **verbatim** (folded frontmatter only, no path substitution) as the correct behavior. Codify an exception in Step 5a: the `sync-templates` concept (and any concept flagged meta) is projected verbatim, never substituted.
- [x] **Forward-sync this session's standards into le-cementine** — done (le-cementine PR #345) after sprint/23 closed. Curated agnostic splice: sync-templates Step 5f+6c, manage-artifacts dedup, recursive-review dead-ref removal; genericizations deliberately skipped to preserve le-cementine's project-specifics.
- [x] **Harden `sync-templates` hybrid-source detection** — done (le-cementine PR #431, synced here). Step 2 now checks FIRST for a hybrid source (both `.agents/` and a `.claude/` of thin shims → treat `.agents/` as canonical, `SOURCE_AGENT = Gemini / Generic`) before the plain `.claude/` → Claude Code rule.
- [x] **Root-cause the sync re-leak (high value)** — addressed in two parts: (1) **this repo** `sync-templates.md` **Step 5f agnostic-review gate** (PR #31) greps synced output for residual project-signal patterns regex can't restructure; (2) **le-cementine** `templateSanitization` gained 3 missing token patterns (`lc-webapp`, `IOrderService`, `ci-preview-swa.yml` — le-cementine PR #344). Finding: regex handles *token* leaks; *prose* leaks (sprint-attribution sentences, the dotnet auth bullet) fundamentally need the manual gate.
- [x] **Repo-wide agnostic sweep** — PR #30. Genericized `run-qa` (mock path), `recursive-review` (DI specifics, SCSS example), plus 2 leaks that escaped #20: `AGENTS.md` Sprint-21 attribution and `stack-angular` ServiceMode names. `sync-state.json` skipList + `sync-history.json` left intact (functional/factual state, not prose). Branching-diagram `sprint/8.6` examples kept (naming-convention illustration).

## 📝 Ongoing Notes
*Architectural notes or reminders for the agent/user.*

- Running on Claude Code. `CLAUDE.md` + `.claude/skills/` shims provide native Claude Code integration. `.agents/` remains the cross-agent source of truth and is never modified for agent-specific concerns.
- When syncing standards to a new project, use `/sync-template` and select the target agent. Claude Code targets receive a full `.claude/` structure with `CLAUDE.md`, path-transformed skills, and Antigravity tool substitutions applied automatically.
