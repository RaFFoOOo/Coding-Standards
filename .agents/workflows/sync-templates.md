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
Every rule/skill/workflow/CI-template is resolved to a **shape-agnostic concept id**, independent of where each repo happens to store it:
- `rule:<slug>` — filename stem of any file under a repo's `ruleRoot`.
- `skill:<slug>` — folder name under `skillRoot` (real bodies only, never a shim).
- `workflow:<slug>` — filename stem under `workflowRoot` (flat mode), or folder name under `skillRoot` classified as `workflow` in that repo's `reverseTaxonomy` (folded mode).
- `github:<relative-path>` — **not** a directory scan like the other three. `.github/` mixes genuine reusable CI/CD templates with project-only data (tenant config, one-off smoke tests), so a wholesale scan would re-open exactly the leak this sprint's Hub Completeness work closed for rules/skills/workflows. Instead, each repo declares its own allowlist in `githubTemplates` (its `sync-state.json`, alongside `skipList`/`shapeProfile`): `["dependabot.yml", "workflows/ci-angular.yml", ...]`, relative to that repo's `.github/`. Only listed paths become concepts; everything else under `.github/` is invisible to this workflow — excluded by scope, not by `skipList`. `.github/` layout doesn't vary by agent shape (GitHub itself dictates it), so a `github:` concept's relative path is identical across every participant that declares it.

Build one table: rows = concept id, columns = each participant, cell = the concept's literal path in that repo (empty if absent). This registry is the shared coordinate system every later diff/merge/fan-out step operates on — it replaces the old workflow's implicit assumption that "the same relative path" identifies the same file across repos, which the observed profiles above disprove (e.g. `rule:naming-azure-resources` lives at `.claude/rules/naming-azure-resources.md` in le-cementine but `.agents/rules/naming-azure-resources.md` in the hub).

### Step 3 — Load Local State
For **every** participant (using its `syncRoot` from Step 2a):
- Look for `<repo>/<syncRoot>/sync-state.json`.
- If it exists, read `skipList` (paths/concepts this repo excludes) and any previously stored `shapeProfile`. If the stored profile disagrees with Step 2a's fresh detection, trust the fresh detection — the repo's layout changed since the last sync — and note the discrepancy for the user.
- Hub `skipList` entries that resolve to a real concept in the Concept Registry (Step 2b) are a **Hub Completeness** flag, not a valid exclusion — enforced in Step 4c.

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
| **New, single-source** | **no baseline exists** for this concept, and it currently exists in exactly one participant | Ask once: adopt as a shared standard everywhere, or confirm it's intentionally repo-local (e.g. a project-only stack rule) — a repo-local answer is recorded as a `skipList` entry on every *other* participant, **never** on the hub. For a `rule:`/`skill:`/`workflow:` concept, repo-local *also* requires a `DECISIONS.md` entry on the hub (Step 4c enforces this). A `github:` concept is the one exception: its opt-in `githubTemplates` allowlist (Step 2b) already *is* the "hasn't adopted this" signal, so repo-local needs no `DECISIONS.md` entry — Step 4c's coverage check doesn't re-scan `.github/` at all |
| **New, converged** | **no baseline exists**, and 2+ participants already hold the concept with an **identical** current digest | Auto-adopt as canonical — every side already independently agrees, nothing to arbitrate |
| **Multi-repo conflict** | either a baseline exists and 2+ participants differ from it, **or** no baseline exists and 2+ participants hold the concept with **differing** digests | Route to the N-way merge step (Step 4b) — never resolved automatically here |

Present one classification table (concept id, class, participants involved) spanning **all** participants — this replaces the old single-repo `[ADD]/[MODIFY]/[SKIP]` categorization, which only ever compared one Source against one Target.

Ask the user: "Do you approve this classification? Respond 'yes' to proceed, or list concepts to move to a permanent `skipList` on specific repos."
- A skip requested on the **hub** is rejected per the Hub Completeness invariant unless the user confirms the concept is provably non-standard project data (enforced in Step 4c, which also requires the matching `DECISIONS.md` entry).

### Step 4b — N-Way Merge & Contradiction Arbitration

Resolves every concept from Step 4 into one canonical version, written directly into the **hub's own tree** on its already-checked-out sync branch. Per the Sprint 2.0 staging decision, **the hub's branch is the staging area — there is no separate temp or scratch directory.** `git diff` on the hub's branch is the review surface, exactly like any other change in this workflow. This is also the mechanism that satisfies Hub Completeness (validated next, in Step 4c): after this step, the hub's tree holds a resolved version of every concept in the registry. Genericization is not repeated here per-concept — it stays in the agnostic review gate (Step 4d), which runs once on the hub's tree right after this step.

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

### Step 4c — Hub Completeness Validation [MANDATORY]

After Step 4b lands merge results, verify the hub's tree is actually complete **before fan-out (Step 5) is allowed to proceed.** This turns the earlier one-off fix (`naming-azure-resources.md` — a real standard that sat `skipList`-excluded from the hub with no justification, see `chore/promote-naming-azure-resources-rule`) into a structural gate instead of something only caught by manual inspection.

1. **Re-scan the hub's tree** (its `ruleRoot`/`skillRoot`/`workflowRoot`, per its own `shapeProfile`) to get its current concept set, post-Step-4b.
2. **Coverage check:** every concept id present in the pre-merge Concept Registry (Step 2b) must now resolve to a real file in the hub's tree, with exactly two exceptions:
   - **Explicit global retirement** — the concept was deleted everywhere via Step 4b's `single-repo-change — deletion` global-retirement branch. Legitimately absent by design.
   - **Confirmed non-standard / repo-local**, *only* when backed by a corresponding entry in the hub's `DECISIONS.md` justifying why this concept will never be promoted (reusing the existing Decision Recording convention from `AGENTS.md §1` rather than inventing new schema for a rare case). This is the **only** way a real rule/skill/workflow concept may be permanently missing from the hub.
   - Anything missing without one of these two justifications is a **Hub Completeness violation**: Step 4b's landing rule wasn't actually applied for that concept — go back and land it before proceeding.
3. **`skipList` check:** for every entry in the hub's own `skipList` (Step 3) that matches the literal path of a real concept in the registry, verify a matching `DECISIONS.md` justification exists. No match is a violation — the fix is either to promote the concept into the hub (remove the skip entry) or to record the missing decision, whichever the Tech Lead confirms. **The hub is never allowed to silently opt out of a standard.**
4. **Report** every violation found as a table (concept id, current hub state, suggested fix) and **STOP** — do not proceed to Step 5 while any violation is open.

### Step 4d — Agnostic Review Gate [MANDATORY]

`git diff` on the hub's branch already shows exactly what Step 4b wrote — but a regex substitution pass (like the superseded `templateSanitization`, see below) only catches **token-level** leaks (class names, resource IDs, `Sprint N lesson` attributions), never prose. A sentence like *"Sprint 21 T7 churned ~15 commits…"* needs rewriting to cause-effect, which no substitution rule can do. So **before any fan-out begins**, grep the hub's own tree for residual project-signal patterns and present every hit for manual genericization — once, here, not once per target:

```bash
grep -rnE "Sprint [0-9]|DECISIONS?\.md|\blc-[a-z]|PR #[0-9]+|le-cementine|provideByMode" \
  <Hub>/AGENTS.md <Hub>/.agents/
```

- Bare `Sprint N` prose attributions, **dated** `DECISIONS.md` citations (e.g. *"see DECISIONS.md (2026-05-22, …)"*), and project-specific class/file/service names that survive the regex pass MUST be hand-genericized (to cause-effect / generic placeholders) before fan-out. *(This is the lesson of PRs #20/#30, where exactly these slipped through verbatim and were cleaned by hand after merge.)*
- **Not leaks — skip:** branch-naming examples that illustrate the convention (`sprint/<semver>-<slug>`); factual ledger state (`sync-history.json` `sourceRepo`/`sourceBranch`); `DECISIONS.md` referenced as the standard decision-log **convention**; and helper names used as explicit generic `e.g.` examples.
- Record the outcome in every fan-out PR body: list the hand-fixed leaks, or note "agnostic review: clean".

**Why this replaces per-spoke `templateSanitization`:** the old pairwise model ran a spoke's own regex-substitution array (`templateSanitization` in its `sync-state.json`) whenever that spoke acted as Source. Under SYNC, the hub is *always* Source (see Step 5 below), and its tree is already verified clean right here, once, before any spoke ever sees it — so `templateSanitization` arrays are no longer consulted by this workflow. Existing arrays in spoke `sync-state.json` files are harmless to leave (inert for SYNC; still meaningful if a spoke's `sync-state.json` is ever consulted outside this workflow).

### Step 5 — Fan-Out from Hub

Steps 4b/4c/4d guarantee the hub's tree is complete and clean *before* this step starts. Combined with the locked hub-and-spoke topology (Step 1 — the hub is always one of the participants), this means **fan-out is always hub → each other participant, never participant → participant directly.** The old pairwise model's arbitrary Source/Target matrix collapses: **Steps 5c (Reverse Transformation) and 5e (Claude → Claude sibling) are removed** — both existed only to handle a non-hub Source, which can no longer occur. What's left is one shape-driven projection, run once per non-hub participant, plus a migration-cleanup step reworked below to read `shapeProfile` instead of the retired `TARGET_AGENT` variable.

#### Step 5a — Shape-Driven Projection

For each participant that is not the hub, project every concept from the hub's tree into that participant's own shape using its `shapeProfile` (Step 2a) — never a hardcoded Claude/Generic switch.

**Path resolution, by concept type** (`<target.X>` = that field from the target's own `shapeProfile`):

| Concept | Target path |
|---|---|
| `rule:<slug>` | `<target.ruleRoot><slug>.md` |
| `skill:<slug>` | `<target.skillRoot><slug>/SKILL.md` |
| `workflow:<slug>`, target `workflowMode = "flat"` | `<target.workflowRoot><slug>.md` |
| `workflow:<slug>`, target `workflowMode = "folded"` | `<target.skillRoot><slug>/SKILL.md` — add `<slug>` to that target's own `reverseTaxonomy.workflows` if not already listed. **No need to ask the user**, unlike the old Step 5c: the hub's concept id (`workflow:` vs `skill:`) already carries the correct classification, so this is bookkeeping, not a decision. |
| `github:<relative-path>` | `<target's .github/><relative-path>` — same relative path in every participant (`.github/` layout is GitHub-dictated, not agent-shape-dependent). Flows through the **same** Step 4 classification as every other concept type — no special-casing here: a target with no `githubTemplates` entry for this path was already asked the `new-single-source` adopt-vs-repo-local question back in Step 4, and a `repo-local` answer already excluded it via that target's own `skipList`. On adoption, also add the path to the target's `githubTemplates` allowlist so it's recognized as declared on future runs. |
| `AGENTS.md` | `AGENTS.md` (copy as-is) |

**Content substitutions** — apply only when the target's shape includes a `.claude/` root (`target.skillRoot` or `target.shimRoot` starts with `.claude/`); skip entirely for a target whose shape is already `.agents/`-rooted like the hub's, since no transformation is needed:

| Find | Replace |
|---|---|
| `.agents/skills/` | `.claude/skills/` |
| `.agents/workflows/` | `.claude/skills/` |
| `generate_image` tool calls | Text wireframe instruction: *"Create a markdown wireframe describing the layout, component hierarchy, interactions, and color tokens for this UI task. Save as `mockup_[feature].md` artifact and embed it in `implementation_plan.md`."* |
| `notify_user` tool calls | *"Output a message to the user asking for explicit approval. Wait for the user's response before proceeding."* |
| `browser_subagent` tool calls | *"Use the `/test-browser` skill. Note: requires the Playwright MCP server configured in `.mcp.json` (`@playwright/mcp`). If not available, perform browser testing manually and document results."* |
| `// turbo-all` | *(remove the line entirely)* |

**Workflow-to-Skill Frontmatter Injection** (workflow concepts landing in a `folded`-mode target):
- If the source workflow file already has YAML frontmatter: replace `name` with the concept's `<slug>` (kebab-case), keep `description`.
- If no frontmatter exists: inject `name`/`description` (description = first sentence of the workflow's purpose section).

**`CLAUDE.md` generation** — only for a target whose shape includes `.claude/`; always generated, never copied. `CLAUDE.md` is project-specific operational state, and it was never a fan-out candidate to begin with: the Concept Registry (Step 2b) only ever scans `ruleRoot`/`skillRoot`/`workflowRoot`, so `CLAUDE.md` never enters it. Its skill table is **derived from the hub's Concept Registry** (one `/<slug>` row per `skill:`/`workflow:` concept), never a hardcoded list, so it cannot drift from what's actually being synced:
```markdown
@AGENTS.md

---

## Claude Code — Agent Configuration

### Skills Available
| Command | Purpose |
|---|---|
| `/<slug>` | <first sentence of that concept's description, for every skill:/workflow: concept in the hub's registry> |

### Plan Mode
Claude Code enters plan mode for complex tasks. You (Tech Lead) review and approve the
plan before any code is written. This enforces the Review Protocol in AGENTS.md §1.

### Stack Rules
<one line per stack-*.md rule concept present in the hub's registry>

### Remote Execution
All rules and skills are version-controlled in `.claude/` and CLAUDE.md.
Remote/scheduled agents load context directly from this repository.
```

Write the approved `skipList` to `<target.syncRoot>sync-state.json`, merged with (never overwriting) that target's own existing entries.

#### Step 5b — Old Agent Configuration Cleanup

Before staging, check each target directly for a **stale, superseded** agent configuration left over from before it adopted its current `shapeProfile` (Step 2a) — e.g. its `skillRoot` resolves to `.claude/skills/` today, but a `.agents/skills/` tree from a prior Generic configuration is still sitting on disk. This is an independent filesystem check, not something Step 2a flags on its own (Step 2a only ever picks the one real-body skill root it finds; a leftover second one is exactly what this step exists to catch). Only one configuration may be active per participant.

**Migrating to a Claude-native shape:**
- Check if a stale `.agents/skills/` and `.agents/workflows/` tree exists (an agnostic `.agents/rules/` may legitimately remain — some shapes, like one-talent's, keep rules there permanently; this cleanup only targets the superseded skill/workflow layer).
- If found, present the file counts to the user and ask for approval before `rm -rf`.
- **`AGENTS.md` is always kept** — it is the cross-agent global standard, not agent-specific.
- If nothing stale is found: skip silently.

**Migrating to a Generic shape:**
- Check if `.claude/` or `CLAUDE.md` exist.
- If they do, present to the user for approval, then `rm -rf` the `.claude/` skills tree and `rm -f CLAUDE.md`.
- If neither is found: skip silently.

Proceed to Step 6.

### Step 6 — Finalization

#### Step 6a — Update Sync History Ledger [MANDATORY]
Before staging, append the **same** execution record to **every participant's own ledger** — not just the hub's. Step 3b's baseline lookup checks every participant's ledger for the most recent `mode: "SYNC"` entry (a future run might start from any of them), so if only one repo recorded it, the others would never find a baseline and every run would stay stuck in first-sync mode. This is also the step that finally makes T2's baseline mechanism real: until this entry is written, nothing persists between runs.

1. **Recompute `fileDigests`** for every concept in the Concept Registry (Step 2b), using each participant's content **as it now stands after Step 5's fan-out** — this becomes the baseline for the *next* run, so it must reflect the post-sync state, not the pre-merge digests from Step 3b.5.
2. **Locate** (or create) each participant's ledger at `<repo>/<syncRoot>/sync-history.json` (per its own `shapeProfile`).
3. **Append the identical entry** to every participant's ledger:
   ```json
   {
     "mode": "SYNC",
     "date": "<current ISO 8601 UTC timestamp>",
     "participants": [
       { "repo": "<repo name>", "path": "<absolute local path>", "branch": "<branch name for this run>" },
       { "repo": "<repo name 2>", "path": "<absolute local path 2>", "branch": "<branch name for this run>" }
     ],
     "fileDigests": {
       "<conceptId>": { "<repo name>": "<git blob hash>" }
     }
   }
   ```
4. If a participant's ledger file did not exist, create it with an `executions` array containing this single entry (matching the array name any pre-existing legacy ledger already used). **Never rewrite or remove** legacy (`direction: PUSH`/`PULL`) entries — this workflow only ever appends.
5. Include each ledger file in *that participant's own* staged changes — it travels in the same PR as that participant's content changes, not a separate commit.

#### Step 6b — Commit & Push
For **every** participant (hub included):
- Stage all added and modified files in that participant's own repo (including its `sync-state.json` and `sync-history.json`).
- Commit with a message reflecting that participant's own shape: `chore(standards): sync template updates` (Generic-shaped) or `chore(standards): sync template updates (claude-code)` (a shape whose `skillRoot`/`shimRoot` includes `.claude/`).
- Push that participant's branch and instruct the user to open a Pull Request in **that** repository. A SYNC run with N participants produces **N independent PRs**, one per repo — never a single cross-repo commit, and never skipping the hub's own PR just because it's "the source."

#### Step 6c — Self-maintaining template: reconcile `.claude/` shims [MANDATORY when target keeps both `.agents/` and `.claude/`]

The master template repo is a hybrid: `.agents/` is its canonical source **and** it ships its own `.claude/` shims + `CLAUDE.md` so it is natively usable in Claude Code. Step 4b's N-way merge writes only to `.agents/` (that's the hub's `shapeProfile`), so any workflow/skill it **adds or removes** would otherwise leave the local `.claude/` shim layer stale — the same defect that orphaned `recursive-review`, `pause-session`, `resume-session`, and `resolve-workflow` after the pre-SYNC #18/#20 syncs (back when this same drift was caused by the old reverse-transformation path instead).

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
