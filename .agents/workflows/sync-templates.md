---
name: sync-templates
description: Synchronize template artifacts (AGENTS.md, .agents/, .github/) across 2 or more local repositories via an N-way merge, with agent-aware path and tool transformation preserving each repo's native shape.
---

# Template Synchronization Workflow

> This workflow references `gh` CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

This workflow merges standard configurations, rules, skills, and CI/CD pipelines across **2 or more** local repositories (the SYNC participants — e.g. `Coding-Standards` plus one or more project repos), converging every participant on the same set of concepts rather than letting one direction's content simply overwrite another's. It maintains a `sync-state.json` (location and shape vary per repo — see Step 2) holding each repo's skip list and detected shape profile.

It also handles **shape-aware transformation**: when participants use different agent layouts (Claude Code ↔ Gemini / Generic ↔ hybrid), the workflow rewrites directory layout (`.claude/` ↔ `.agents/`), promotes/demotes skills to/from workflows according to each repo's `reverseTaxonomy`, and applies content substitutions for agent-specific tool references — while never allowing a participant's own project-specific content to leak into another's copy (see the agnostic review gate).

## Prerequisites
- This workflow can be invoked from any participant repo; verify each participant path with `git -C <path> rev-parse --show-toplevel`.
- For the very first execution in a new project, this file (`.agents/workflows/sync-templates.md`) must be manually copied from the `Coding-Standards` repo into the target project first.

## Execution Sequence

### Step 1 — Collect Participants
- Ask the user for **2 or more absolute local repo paths** to sync — the SYNC participants. If this workflow is invoked from Coding-Standards, it is always included as the **hub** (the repo expected to hold the complete canonical standards set — see the Hub Completeness check later in this workflow). If invoked from elsewhere and no participant is recognizably the master template (see Step 2's hub signature), ask the user which path is the hub.
- For each participant path:
  - Verify it is a git repository: `git -C <path> rev-parse --show-toplevel`.
  - Run `gh pr list` in it. If there are any open, unmerged PRs touching standards files, **STOP and warn the user** for that repo.
  - If clear, checkout a new branch in it: `git -C <path> checkout -b chore/sync-standards-<date>`.

### Step 2 — Shape Profile Detection & Concept Registry

This replaces the old binary "which agent does the target use" question. **The filesystem is authoritative — never ask.** Three distinct shapes are already known to exist across real projects (Coding-Standards, le-cementine, one-talent all differ), so detection must produce a full per-repo profile, not a two-way enum.

#### Step 2a — Shape Profile Detection
For each participant, detect and record:

| Field | How it's detected |
|---|---|
| `ruleRoot` | `.agents/rules/` if present and non-empty, else `.claude/rules/` |
| `skillRoot` | `.agents/skills/` if it holds real (non-shim) `SKILL.md` bodies, else `.claude/skills/` if it holds real bodies |
| `shimRoot` | the *other* skill dir, if it exists and holds only thin shims (body = `Read the full … from \`.agents/…\``) — quick check (no output = all shims): `grep -L "Read the full" <repo>/.claude/skills/*/SKILL.md` |
| `workflowRoot` / `workflowMode` | `"flat"` with `workflowRoot = .agents/workflows/` if such files exist; otherwise `"folded"` (workflows live as `.claude/skills/<n>/SKILL.md`, classified via that repo's `reverseTaxonomy.workflows`) |
| `syncRoot` | wherever `sync-state.json` / `sync-history.json` actually live today (`.claude/` or `.agents/`) |

A repo with **all three** of `ruleRoot`, `skillRoot`, and `workflowRoot` pointing at a non-empty `.agents/` tree, plus a `shimRoot` of Claude shims, is the **hub signature** (currently only Coding-Standards matches it).

Persist the detected profile into `<repo>/<syncRoot>/sync-state.json` under a `shapeProfile` key so future runs don't re-derive it from scratch — but always re-verify against the filesystem before trusting a stored value, since a repo's layout can change between syncs.

**`shapeProfile` schema** (fields omitted when not applicable, e.g. no hybrid shim layer or no flat workflow dir):
```json
{
  "shapeProfile": {
    "ruleRoot": ".agents/rules/",
    "skillRoot": ".agents/skills/",
    "shimRoot": ".claude/skills/",
    "workflowRoot": ".agents/workflows/",
    "workflowMode": "flat",
    "syncRoot": ".agents/"
  }
}
```

**Observed profiles (for reference, re-verify — do not assume these are still current):**

| Repo | ruleRoot | skillRoot | workflowMode | syncRoot |
|---|---|---|---|---|
| Coding-Standards (hub) | `.agents/rules/` | `.agents/skills/` (+ `.claude/skills/` shims) | flat | `.agents/` |
| le-cementine | `.claude/rules/` | `.claude/skills/` | folded | `.claude/` |
| one-talent | `.agents/rules/` | `.claude/skills/` | folded | `.claude/` |

#### Step 2b — Concept Registry
Every rule/skill/workflow is resolved to a **shape-agnostic concept id**, independent of where each repo happens to store it:
- `rule:<slug>` — filename stem of any file under a repo's `ruleRoot`.
- `skill:<slug>` — folder name under `skillRoot` (real bodies only, never a shim).
- `workflow:<slug>` — filename stem under `workflowRoot` (flat mode), or folder name under `skillRoot` classified as `workflow` in that repo's `reverseTaxonomy` (folded mode).

Build one table: rows = concept id, columns = each participant, cell = the concept's literal path in that repo (empty if absent). This registry is the shared coordinate system every later diff/merge/fan-out step operates on — it replaces the old workflow's implicit assumption that "the same relative path" identifies the same file across repos, which the observed profiles above disprove (e.g. `rule:naming-azure-resources` lives at `.claude/rules/naming-azure-resources.md` in le-cementine but `.agents/rules/naming-azure-resources.md` in the hub).

> **Sprint 2.0 status:** the steps below (originally written for the pairwise PUSH/PULL model) still speak of a single `Target`/`Source` and have not yet been generalized to N participants or wired to the Concept Registry above — that lands in tasks T2–T6 of `PLAN.md`. Until then, for a 2-participant run, treat the hub as `Target` and the other participant as `Source` to keep the remaining steps operable. Do not attempt a 3+-participant run before T2–T6 land.

### Step 3 — Load Local State
For **every** participant (using its `syncRoot` from Step 2a):
- Look for `<repo>/<syncRoot>/sync-state.json`.
- If it exists, read `skipList` (paths/concepts this repo excludes) and any previously stored `shapeProfile`. If the stored profile disagrees with Step 2a's fresh detection, trust the fresh detection — the repo's layout changed since the last sync — and note the discrepancy for the user.
- Hub `skipList` entries that resolve to a real concept in the Concept Registry (Step 2b) are a **Hub Completeness** flag, not a valid exclusion — full enforcement lands in T4; for now, surface them as a warning.

### Step 3b — Sync History Verification & Baseline Load [MANDATORY]

Before diffing, load the **merge baseline**: the content digest of every concept in every repo as of the last SYNC. This is what makes the diff in Step 4 a real three-way merge instead of a blind "current state wins" comparison — without it, a repo that intentionally deleted a sentence looks identical to a repo that never had it.

1. **Locate each participant's ledger** at `<repo>/<syncRoot>/sync-history.json`.
2. **Find the most recent `mode: "SYNC"` entry** across all participants' ledgers (a participant can join a later sync than another, so check every ledger, not just the hub's — the entry with the latest `date` wins as the baseline source).
3. **If a SYNC-mode entry exists**, load its `fileDigests` map (`{ conceptId: { repoName: <git blob hash> } }`) as the baseline for Step 4.
   - **Staleness check:** if any participant's ledger records a `SYNC` entry **newer** than the one just selected as baseline, STOP and warn the user — a more recent sync happened that this run doesn't know about; re-run against that repo's latest branch first.
4. **If only legacy (`direction: PUSH`/`PULL`) entries exist, or no ledger exists at all:** there is no usable baseline anywhere (legacy entries carry no `fileDigests`) — every concept enters Step 4 with an empty baseline. Warn the user this first SYNC will surface more concepts for review than steady-state runs will, precisely because there's nothing to diff against yet. Note that baseline absence is evaluated **per concept**, not just globally: even with a valid ledger, a concept added independently by two repos since the last recorded sync has no baseline entry of its own — Step 4's classification handles that the same way as a fully first-sync repo, it is not a separate mode.
5. **Compute each current digest** via `git hash-object <resolved-path>` (git's own blob hash — no external hashing tool needed) for every concept × participant cell in the registry that has a path. Absence of a key means the repo doesn't have that concept; never store an empty-string digest for "missing."

**`sync-history.json` entry schema — SYNC mode (new, written by this workflow going forward):**
```json
{
  "mode": "SYNC",
  "date": "2026-07-02T00:00:00Z",
  "participants": [
    { "repo": "Coding-Standards", "path": "/abs/path/Coding-Standards", "branch": "chore/sync-standards-2026-07-02" },
    { "repo": "le-cementine", "path": "/abs/path/le-cementine", "branch": "chore/sync-standards-2026-07-02" }
  ],
  "fileDigests": {
    "rule:naming-azure-resources": {
      "Coding-Standards": "3f2504e...",
      "le-cementine": "9e107d9..."
    }
  }
}
```

**Legacy entry schema (still valid, read-only — SYNC mode never writes this shape again):**
```json
{
  "date": "2026-03-30T14:30:00Z",
  "direction": "PUSH",
  "sourceRepo": "Coding-Standards",
  "sourceBranch": "main",
  "targetRepo": "<your-project>",
  "targetBranch": "chore/sync-standards",
  "agent": "claude-code"
}
```
Legacy entries have no `fileDigests` and cannot serve as a baseline — treat their presence the same as "no ledger" (first-sync mode), but still tell the user pre-SYNC history exists so they understand why this run needs a fuller review pass.

### Step 4 — Baseline-Aware Diff & Classification

For every concept id in the Concept Registry (Step 2b), look up its baseline entry (Step 3b) — which may be **absent** for that concept alone even in a run that otherwise has a valid ledger (see Step 3b.4) — and classify:

| Class | Condition | Handling |
|---|---|---|
| **Unchanged** | a baseline exists, and every participant holding the concept matches it | Skip — no action |
| **Single-repo change** | a baseline exists, and exactly one participant's current digest differs from it (including a deletion — concept present in baseline but missing now) | Fast-path: that participant's current version becomes the canonical candidate (today's PUSH behavior) |
| **New, single-source** | **no baseline exists** for this concept, and it currently exists in exactly one participant | Ask once: adopt as a shared standard everywhere, or confirm it's intentionally repo-local (e.g. a project-only stack rule) — a repo-local answer is recorded as a `skipList` entry on every *other* participant, **never** on the hub (Hub Completeness, T4) |
| **New, converged** | **no baseline exists**, and 2+ participants already hold the concept with an **identical** current digest | Auto-adopt as canonical — every side already independently agrees, nothing to arbitrate |
| **Multi-repo conflict** | either a baseline exists and 2+ participants differ from it, **or** no baseline exists and 2+ participants hold the concept with **differing** digests | Route to the N-way merge step (Step 4b) — never resolved automatically here |

Present one classification table (concept id, class, participants involved) spanning **all** participants — this replaces the old single-repo `[ADD]/[MODIFY]/[SKIP]` categorization, which only ever compared one Source against one Target.

Ask the user: "Do you approve this classification? Respond 'yes' to proceed, or list concepts to move to a permanent `skipList` on specific repos."
- A skip requested on the **hub** is rejected per the Hub Completeness invariant unless the user confirms the concept is provably non-standard project data (full enforcement lands in T4).

### Step 4b — N-Way Merge & Contradiction Arbitration

Resolves every concept from Step 4 into one canonical version, written directly into the **hub's own tree** on its already-checked-out sync branch. Per the Sprint 2.0 staging decision, **the hub's branch is the staging area — there is no separate temp or scratch directory.** `git diff` on the hub's branch is the review surface, exactly like any other change in this workflow. This is also the mechanism that satisfies Hub Completeness (Step 4c, T4): after this step, the hub's tree holds a resolved version of every concept in the registry. Genericization is not repeated here per-concept — it stays in the existing agnostic review gate (Step 5f), wired into the fan-out sequence in T5.

**Landing rule, by Step 4 classification:**

| Class | Action |
|---|---|
| `unchanged` | nothing to do |
| `single-repo-change` — content edit | if the winning participant is not the hub, copy its content into the hub's tree at the concept's canonical path (per the hub's own `shapeProfile`); if the winner *is* the hub, it's already there |
| `single-repo-change` — **deletion** (concept existed at baseline, now absent from that one participant) | **Never auto-delete from the hub.** Ask once, same pattern as `new-single-source`: is this an intentional retirement of the standard (delete from the hub's tree — it will then propagate as a deletion to every participant in fan-out, T5), or does the standard simply no longer apply to that one repo (add a `skipList` entry for the concept **on that repo only**; the hub and every other participant keep it unchanged) |
| `new-converged` | write the (already-identical) agreed content into the hub's tree — no arbitration needed |
| `new-single-source`, **adopted** branch only | if the adopted source is not the hub, copy its content in. (**Repo-local** answers never reach this table — Step 4 already recorded them as `skipList` entries on the other participants and they don't touch the hub.) |
| `multi-repo-conflict` | run the N-way merge procedure below |

**N-way merge procedure (`multi-repo-conflict` only):**
1. Gather every participant's current content for the concept via the Concept Registry (Step 2b).
2. **LLM semantic merge — never a mechanical line-based diff3.** Prose rule/skill docs cannot be safely merged line-by-line: it risks interleaving contradictory instructions or leaving literal `<<<<<<<` conflict markers in a SKILL.md. Read every variant and synthesize one version that unions every distinct instruction, deduplicates near-identical restatements, and preserves each variant's rationale where the rationales don't conflict.
3. Distinguish **additive difference** (one variant simply has more content than another) from **genuine contradiction** (variants give incompatible instructions — e.g. "always X" vs. "never X", or assign different values to the same convention). Additive differences are unioned silently in step 2; only genuine contradictions require arbitration.
4. For every genuine contradiction, add a row to the **Contradiction Table** — one column per participant that holds a differing version of that concept (2 columns for a 2-way conflict, N columns for an N-way one; do not hardcode a fixed "Repo A / Repo B" shape):

| Concept | Contradiction | `<Repo 1>` says | `<Repo 2>` says | … `<Repo N>` says | Proposed resolution |
|---|---|---|---|---|---|
| `rule:<slug>` | one-line statement of what's actually incompatible | quote/paraphrase | quote/paraphrase | … | agent's suggested pick, clearly marked as a suggestion, not a decision |

5. Present the full table to the Tech Lead **before writing the affected concepts** (non-conflicting concepts from the landing rule above may already be staged). Ask: "Approve the proposed resolutions, or specify per-row overrides?"
6. On approval, write the final merged content into the hub's tree at the concept's canonical path.

**Never:** auto-resolve a genuine contradiction silently, or leave diff3-style conflict markers in a file — both are explicitly forbidden by the Sprint 2.0 design lock.

> **T4/T5/T6 status:** Hub Completeness validation (Step 4c) and shape-driven fan-out to non-hub participants (Step 5, generalized) land next, along with wiring the agnostic review gate into that sequence and Step 6a actually writing the `mode: "SYNC"` ledger entry. Until then, this step lands resolved content into the hub's own tree but does not yet propagate it to other participants, validate hub completeness, or persist a baseline for the next run — every run remains effectively first-sync until T6.

### Step 5 — Execution

#### Step 5a — Gemini / Generic Target
For all `[ADD]` and `[MODIFY]` files, copy them from the *Source* repository into the exact corresponding relative path in the *Target* repository. Use `mkdir -p` where directories are missing.

Write the final, approved array of skipped relative paths to `<Target_Repo>/.agents/sync-state.json`.

#### Step 5b — Claude Code Target

**Path Mapping (Source → Target):**

| Source Path | Target Path |
|---|---|
| `AGENTS.md` | `AGENTS.md` (copy as-is) |
| `.agents/rules/*.md` | `.agents/rules/*.md` |
| `.agents/skills/*/SKILL.md` | `.claude/skills/*/SKILL.md` |
| `.agents/workflows/X.md` | `.claude/skills/X/SKILL.md` |
| `.agents/sync-state.json` | `.claude/sync-state.json` |
| `.agents/sync-history.json` | `.claude/sync-history.json` |
| `.github/` | `.github/` (copy as-is) |

**Content Substitutions** (apply to every copied `.md` file going into `.claude/`):

| Find | Replace |
|---|---|
| `.agents/skills/` | `.claude/skills/` |
| `.agents/rules/` | `.agents/rules/` |
| `.agents/workflows/` | `.claude/skills/` |
| `generate_image` tool calls | Text wireframe instruction: *"Create a markdown wireframe describing the layout, component hierarchy, interactions, and color tokens for this UI task. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`."* |
| `notify_user` tool calls | *"Output a message to the user asking for explicit approval. Wait for the user's response before proceeding."* |
| `browser_subagent` tool calls | *"Use the `/test-browser` skill. Note: requires the Playwright MCP server configured in `.mcp.json` (`@playwright/mcp`). If not available, perform browser testing manually and document results."* |
| `// turbo-all` | *(remove the line entirely)* |

**Workflow-to-Skill Frontmatter Injection** (for each `.agents/workflows/X.md`):
- If the workflow file already has YAML frontmatter: replace the `name` field with the filename stem `X` (kebab-case) and keep the `description`.
- If no frontmatter exists: inject:
  ```yaml
  ---
  name: X
  description: [Extract the first sentence of the workflow's Description/Purpose section]
  ---
  ```

**Generate `CLAUDE.md` in target** (this file is always generated, never a raw copy):
```markdown
@AGENTS.md

---

## Claude Code — Agent Configuration

### Skills Available
| Command | Purpose |
|---|---|
| `/run-qa` | Pre-merge QA verification (mandatory gate) |
| `/plan-sprint` | Break sprint into estimated tasks + mockup gate |
| `/manage-artifacts` | Manage PLAN.md structure and artifact lifecycle |
| `/run-feature` | Execute a full feature from PLAN.md to merged PR |
| `/resolve-pr` | Resolve PR review comments |
| `/sync-templates` | Sync standards to/from a target project repo |
| `/test-browser` | Plan and execute browser tests |
| `/deploy-azure` | Build for production and deploy to Azure |
| `/todo-manager` | Manage TODO.md lifecycle (append, mark done, archive, promote to PLAN.md) |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve the
plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Stack Rules
- Angular/TypeScript projects: `.agents/rules/stack-angular.md`
- ASP.NET Core/C# projects: `.agents/rules/stack-dotnet-core.md`

### Remote Execution
All rules and skills are version-controlled in `.claude/` and CLAUDE.md.
Remote/scheduled agents load context directly from this repository.
```

Write the final skipList to `<Target_Repo>/.claude/sync-state.json`.

#### Step 5c — Reverse Transformation (Claude Code Source → Gemini / Generic Target)

When `SOURCE_AGENT = Claude Code` and `TARGET_AGENT = Gemini / Generic`, apply the inverse of Step 5b. Each item under `.claude/skills/<name>/SKILL.md` must be classified as either a **skill** (folder + `SKILL.md` filename) or a **workflow** (flat `<name>.md` file directly under `.agents/workflows/`). Frontmatter is preserved in both cases — modern Antigravity workflows carry the same `name:` / `description:` frontmatter as Claude skills.

**Classification source — `reverseTaxonomy` in `<Source>/.claude/sync-state.json`:**

```json
{
  "skipList": [],
  "reverseTaxonomy": {
    "workflows": ["deploy-azure", "pause-session", "recursive-review", "resolve-pr", "resolve-workflow", "resume-session", "run-feature", "sync-templates", "test-browser"],
    "skills":    ["manage-artifacts", "plan-sprint", "run-qa", "todo-manager"]
  }
}
```

- Every directory under `<Source>/.claude/skills/` MUST appear in exactly one of the two arrays.
- If `reverseTaxonomy` is missing, or a skill is unlisted, **ask the user** for each unclassified skill and persist the answer back into the source `sync-state.json` (separate atomic commit, ahead of the sync).

**Path Mapping (Source → Target):**

| Source Path | Target Path |
|---|---|
| `AGENTS.md` | `AGENTS.md` (copy as-is) |
| `CLAUDE.md` | (NOT pushed — agent-specific generated artifact) |
| `.agents/rules/*.md` | `.agents/rules/*.md` |
| `.claude/skills/<name>/SKILL.md` (classified as `skill`) | `.agents/skills/<name>/SKILL.md` |
| `.claude/skills/<name>/SKILL.md` (classified as `workflow`) | `.agents/workflows/<name>.md` |
| `.claude/sync-state.json` | `.agents/sync-state.json` (drop `reverseTaxonomy`, keep `skipList` only) |
| `.claude/sync-history.json` | (NOT pushed — target maintains its own ledger per Step 6a) |
| `.claude/projects/`, `.claude/settings.local.json`, `.claude/scheduled_tasks.lock` | (NEVER pushed — local-only / user-scoped) |
| `.github/` | `.github/` (copy as-is) |

**Content Substitutions** (apply to every copied `.md` file going into `.agents/`):

| Find | Replace |
|---|---|
| `.agents/rules/` | `.agents/rules/` |
| `.claude/skills/<name>` where `<name>` is in `reverseTaxonomy.skills` | `.agents/skills/<name>` |
| `.claude/skills/<name>` where `<name>` is in `reverseTaxonomy.workflows` | `.agents/workflows/<name>` |
| Claude-Code-specific MCP preamble: `> **Claude Code:** This skill references gh CLI commands ... mcp__github__...` (single line, may include the `mcp__github__list_pull_requests` example) | Generic preamble: `> This workflow references gh CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.` |

**Frontmatter handling:** keep the YAML frontmatter (`name:`, `description:`) intact in both `skill` and `workflow` targets — the existing Antigravity workflows already use the same shape. No injection or stripping required.

Write the final, approved skipList to `<Target_Repo>/.agents/sync-state.json` (strip `reverseTaxonomy` — it belongs to the Claude source only).

#### Step 5e — Claude Code → Claude Code (sibling project sync)

When `SOURCE_AGENT = TARGET_AGENT = Claude Code`, both repos use the `.claude/` layout, so **no path or taxonomy transformation applies** — files map to the identical relative path. But the copy is **not** verbatim:

- **Apply `templateSanitization`** (from `<Source>/.claude/sync-state.json`, in array order — same procedure as Step 5c) to every `.md` file copied into the target's `.claude/`. Without this, the sibling inherits the source project's class names, resource IDs, and `Sprint N lesson` attributions — valid context in the source, noise in the target. If the source has no `templateSanitization`, warn the user that project-specific identifiers will be carried over verbatim and ask whether to proceed.
- **Never copy `CLAUDE.md`** — it is project-specific operational state (active-sprint pointer, sprint history), not a shared standard. This matches the Step 4 exclusion; copying it would clobber the target's own pointer. The target keeps its existing `CLAUDE.md`.
- **Preserve `reverseTaxonomy`** in the copied `sync-state.json` (the target is still a Claude repo and may later reverse-sync). Keep `skipList` as the approved final list.
- Apply the **Claude-Code preamble handling** rules from Step 5c only if the target is destined to also serve non-Claude agents; otherwise leave `> **Claude Code:**` notes intact.

#### Step 5f — Agnostic Review Gate [MANDATORY when the Target is a shared template / agnostic source of truth]

`templateSanitization` (regex find/replace) catches **token-level** leaks (class names, resource IDs, `Sprint N lesson` attributions) but **cannot restructure prose** — a sentence like *"Sprint 21 T7 churned ~15 commits…"* needs rewriting to cause-effect, which no substitution rule can do. So after the substitution pass and **before staging**, grep the synced output for residual project-signal patterns and present every hit to the user for manual genericization:

```bash
grep -rnE "Sprint [0-9]|DECISIONS?\.md|\blc-[a-z]|PR #[0-9]+|le-cementine|provideByMode" \
  <Target>/AGENTS.md <Target>/.agents/
```

- Bare `Sprint N` prose attributions, **dated** `DECISIONS.md` citations (e.g. *"see DECISIONS.md (2026-05-22, …)"*), and project-specific class/file/service names that survive the regex pass MUST be hand-genericized (to cause-effect / generic placeholders) before the sync PR is opened. *(This is the lesson of PRs #20/#30, where exactly these slipped through verbatim and were cleaned by hand after merge.)*
- **Not leaks — skip:** branch-naming examples that illustrate the convention (`sprint/<semver>-<slug>`); factual ledger state (`sync-history.json` `sourceRepo`/`sourceBranch`); `DECISIONS.md` referenced as the standard decision-log **convention** (the Decision Recording rule prescribes every project keep one); and helper names used as explicit generic `e.g.` examples.
- Record the outcome in the sync PR body: list the hand-fixed leaks, or note "agnostic review: clean".

### Step 5d — Old Agent Configuration Cleanup

Before staging, remove the **previous** agent's configuration from the target to ensure only **one** agent configuration is active at a time.

**If `TARGET_AGENT = Claude Code`** (new config is `.claude/`):
- Check if `.agents/` exists in the target repo.
- If it does, count its files and present to the user:
  > "The following old Gemini/Generic configuration will be removed from `<Target>`:
  > - `.agents/rules/` (N files)
  > - `.agents/skills/` (N files)
  > - `.agents/workflows/` (N files)
  > - `.agents/sync-state.json`
  >
  > Proceed with cleanup? (yes/no)"
- On approval: `rm -rf <Target_Repo>/.agents/`
- **`AGENTS.md` is always kept** — it is the cross-agent global standard, not agent-specific.
- If `.agents/` is not found: skip silently.

**If `TARGET_AGENT = Gemini / Generic`** (new config is `.agents/`):
- Check if `.claude/` or `CLAUDE.md` exist in the target repo.
- If they do, present to the user for approval, then:
  - `rm -rf <Target_Repo>/.claude/`
  - `rm -f <Target_Repo>/CLAUDE.md`
- If neither is found: skip silently.

Proceed to Step 6.

### Step 6 — Finalization

#### Step 6a — Update Sync History Ledger [MANDATORY]
Before staging, append a new execution record to the **Sync History Ledger** in the Target repository.

- **Locate** (or create) the ledger file:
  - Claude Code targets: `<Target_Repo>/.claude/sync-history.json`
  - Gemini / Generic targets: `<Target_Repo>/.agents/sync-history.json`
- **Append** a new entry to the `executions` array:
  ```json
  {
    "date": "<current ISO 8601 UTC timestamp>",
    "direction": "<PUSH or PULL>",
    "sourceRepo": "<Source repository name>",
    "sourceBranch": "<Source branch name at time of sync>",
    "targetRepo": "<Target repository name>",
    "targetBranch": "<Target branch name>",
    "agent": "<TARGET_AGENT lowercase, e.g. claude-code, gemini>"
  }
  ```
- If the file did not exist, create it with the `executions` array containing this single entry.
- Include the ledger file in the staged changes.

#### Step 6b — Commit & Push
- In the *Target* repository, stage all added and modified files (including the sync-state and sync-history files).
- Commit with message:
  - Gemini / Generic: `chore(standards): sync template updates`
  - Claude Code: `chore(standards): sync template updates (claude-code)`
- Push the branch and instruct the user to open a Pull Request in the *Target* repository to merge the updated standards.

#### Step 6c — Self-maintaining template: reconcile `.claude/` shims [MANDATORY when target keeps both `.agents/` and `.claude/`]

The master template repo is a hybrid: `.agents/` is its canonical source **and** it ships its own `.claude/` shims + `CLAUDE.md` so it is natively usable in Claude Code. A Generic/reverse sync (Step 5c) writes only to `.agents/`, so any workflow/skill it **adds or removes** would otherwise leave the local `.claude/` layer stale — the defect that orphaned `recursive-review`, `pause-session`, `resume-session`, and `resolve-workflow` after the #18/#20 syncs.

When the target keeps both trees, after Step 5 reconcile them:
- For every `.agents/skills/<n>/SKILL.md` and `.agents/workflows/<n>.md` with **no** matching `.claude/skills/<n>/SKILL.md`, generate the shim (copy the source `name:`/`description:` frontmatter; body = `Read the full ... instructions from \`.agents/...\` and execute them.`) and add a row to the `CLAUDE.md` skill table.
- For every `.claude/skills/<n>/` shim whose `.agents/` source no longer exists, delete the shim and its `CLAUDE.md` row.
- Quick check (must show no diff): `diff <( { ls .agents/skills; ls .agents/workflows | sed 's/\.md$//'; } | sort -u) <(ls .claude/skills | sort)`.

### Step 7 — Post-Sync Configuration Checklist

After the PR is merged in the target project, present the user with the following checklist. Items marked **[REQUIRED]** must be completed before CI/CD is functional. Items marked **[OPTIONAL]** enable additional capabilities.

---

**✅ Post-Sync Setup Checklist**

**[REQUIRED] GitHub Repository Settings**
- [ ] In the target repository, go to **Settings → Environments** and create two environments: `production` and `development`.
- [ ] Set the following **Repository Variables** (`Settings → Secrets and variables → Actions → Variables`):
  - `NODE_VERSION` — Node.js LTS version (e.g., `24`)
  - `ANGULAR_WORKING_DIRECTORY` — Path to the Angular app (e.g., `.` or `frontend`)
  - `DISABLE_PIPELINES_FOR_TEMPLATE` — Set to `false` (or leave unset) to enable CI/CD
- [ ] Set the following **Environment Variables** (per GitHub environment — `development` / `production`):
  - `ENABLE_TENANT_SELECTOR` — `false` unless multi-tenant UI is needed
  - `ENABLE_LOGIN_FEATURES` — `false` unless authentication UI is needed
  - `CD_AZURE_STA_BASE_URL` — Azure Blob Storage root endpoint (if using Blob Storage CD, production only)
  - `CD_AZURE_STA_BASE_PATH` — Target container (default: `$web`, production only)
- [ ] Set the following **Environment Secrets** (under the `production` environment):
  - `CD_AZURE_STA_SAS_TOKEN` — SAS token for Blob Storage deployment
  - `CD_AZURE_SWA_DEPLOYMENT_TOKEN` — Token for Azure Static Web Apps deployment

**[OPTIONAL] Claude Code — Browser Testing**
- [ ] Create `.mcp.json` in the project root to enable the `/test-browser` skill:
  ```json
  {
    "mcpServers": {
      "playwright": {
        "type": "stdio",
        "command": "npx",
        "args": ["-y", "@playwright/mcp@latest"]
      }
    }
  }
  ```

**[OPTIONAL] Claude Code — Project Customization**
- [ ] Open `CLAUDE.md` in the target project and add any project-specific instructions below the generated section (e.g., custom naming conventions, monorepo paths, environment bootstrap steps).

---

Remind the user: "CI/CD will not trigger until the GitHub Environments and secrets are configured."
