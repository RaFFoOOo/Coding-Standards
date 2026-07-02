# PLAN — Sprint 2.0: N-Way Standards Sync Engine

## 1. Current Sprint Context
- **Goal:** Replace the directional PUSH/PULL `sync-templates` workflow with a true N-way SYNC that merges divergent standards content across 2+ sibling repos (Coding-Standards as hub, plus any project spokes such as le-cementine, one-talent) into one converged, agent-agnostic concept set, then projects it back into each repo's native shape.
- **Status:** In Progress (T1, T2 done)

## 2. Feature Specification

#### Feature: N-Way Standards Sync
- **User Story:** As the Tech Lead maintaining standards across multiple independent project repos, I want one sync operation that merges every repo's local improvements together — instead of a one-directional push/pull that only lets one repo's version win — so that no repo's contribution is silently lost or overwritten, while every repo keeps operating in its own agent shape (Claude Code `.claude/` vs Generic `.agents/`).
- **Acceptance Criteria:**
  - [x] Given 2+ repo paths, the workflow auto-detects each repo's **shape profile** (rule root, skill root, workflow mode, sync-tracking root) instead of asking a binary Claude-Code/Generic question — this fixes the already-observed drift where le-cementine keeps rules under `.claude/rules/` but the current workflow assumes `.agents/rules/`. (T1)
  - [x] Every rule/skill/workflow is resolved through a shape-agnostic **concept id** (e.g. `rule:naming-azure-resources`, `skill:run-qa`), so the same standard can be compared across repos that store it at different paths. (T1)
  - [x] Given content that diverged in 2+ repos since the last recorded sync, the workflow performs a **baseline-aware classification** (unchanged / single-repo-change / new-single-source / new-converged / multi-repo-conflict — the last two split out during review since baseline absence is per-concept, not a single global "first sync" mode) using digests persisted in `sync-history.json` from the prior run — not a blind "current state wins" diff. (T2)
  - [ ] Single-repo divergence fast-paths (today's PUSH behavior); multi-repo divergence triggers an **LLM semantic merge** that deduplicates additive changes and raises genuine contradictions in a table for Tech Lead arbitration — never auto-resolved silently.
  - [ ] The merged canonical concept set passes the existing agnostic-review gate (Step 5f) exactly once, before fan-out to any participant.
  - [ ] Each participant receives its own branch + PR, projected into its native shape via the existing transform/sanitize/shim-reconciliation logic (Steps 5a/5b/5c/5e/6c), now driven by `shapeProfile` instead of a hardcoded Claude/Generic switch.
  - [ ] **Hub Completeness invariant:** Coding-Standards' `skipList` may only contain entries provably non-standard (project-specific data/config); any concept present in a spoke but absent from the hub is flagged as a violation requiring promotion or explicit non-standard justification — never silently skipped. (Concrete instance already fixed standalone: `naming-azure-resources.md`, see `chore/promote-naming-azure-resources-rule`.)
  - [ ] `.github/` sync scope is narrowed to templated CI workflow files; project-specific artifacts (e.g. `tenant-meta.json`, a project's own smoke-test workflow) are excluded by scope definition, not by skipList.
  - [ ] PUSH/PULL language is fully removed from Step 1 — the skill always collects 2+ repo paths and runs SYNC.
  - [ ] Existing `sync-history.json` entries (old `direction`/`sourceRepo`/`targetRepo` shape) remain valid, unmigrated, historical records — no backfill required.

## 3. Technical Implementation Plan
*Must be approved before any task branch is opened.*

- **Workflow Changes (`.agents/workflows/sync-templates.md`):**
  - [x] Step 1 rewrite: collect N repo paths (2+), no PUSH/PULL prompt. (T1 — pulled forward from T6 since it's inseparable from shape detection; T6 now scopes to Step 6a ledger rework + `.github/` narrowing only)
  - [x] New step — **Shape Profile Detection**: auto-detect `ruleRoot`/`skillRoot`/`workflowMode`/`syncRoot` per repo from the filesystem, replacing the binary Claude Code / Gemini-Generic detection. (T1)
  - [x] New step — **Concept Registry**: build the shape-agnostic id → per-repo-path mapping across all participants. (T1)
  - [x] New step — **Baseline-aware diff**: classify each concept (unchanged / single-repo-change / new-single-source / new-converged / multi-repo-conflict) using `fileDigests` from the last `sync-history.json` entry. (T2)
  - [ ] New step — **N-way merge**: fast-path single-repo changes; LLM semantic merge + contradiction table + Tech Lead approval gate for multi-repo conflicts.
  - [ ] New step — **Hub Completeness validation**: after merge, diff the canonical set against the hub's current `.agents/`; flag any gap.
  - [ ] Rework Steps 5a/5b/5c/5e path-mapping tables to read from `shapeProfile` instead of hardcoded literals.
  - [ ] Keep Step 5f (agnostic review) and 6c (shim reconciliation) as-is; 5f now runs once pre-fan-out instead of once per target.
  - [ ] Step 6a rewrite: log `participants[]` + `fileDigests{}` instead of single `sourceRepo`/`targetRepo`.
  - [ ] Redefine `.github/` sync surface to explicit templated-file patterns, dropping wholesale-directory copy.
- **Schema Changes:**
  - [x] `sync-state.json`: add optional `shapeProfile` object per repo (`ruleRoot`, `skillRoot`, `workflowMode`, `syncRoot`). (T1 — landed in Coding-Standards' own file as the reference example)
  - [x] `sync-history.json`: new entry shape for future runs — `mode: "SYNC"`, `participants: [{repo, path, branch}]`, `fileDigests: {conceptId: {repo: <git blob hash>}}` (corrected from "sha256" — using `git hash-object` needs no external hashing tool). Old entries untouched. (T2 — schema documented in Step 3b; **Step 6a does not write it yet**, that's T6)
- **Risks/Notes:**
  - Token cost is materially higher than the old copy-based sync (full semantic merge pass across N repos' rules/skills) — recommend running the merge/arbitration step on Opus, not Sonnet.
  - First real execution should be a 2-participant run (Coding-Standards ↔ one repo) to validate the engine before attempting all 3 repos at once.
  - This is a meta-change to the tooling itself, not an app feature — "Backend/Frontend" labels above are adapted to "Workflow/Schema" per this repo's nature.

## 4. Task Progress
- [x] T1 — Shape Profile Detection + Concept Registry (replaces binary agent detection). Scope note: absorbed old Step 1's peer-path collection and Step 1b's agent question too (inseparable from detection) — new Steps 1–2 replace old Steps 1/1b/2 with no renumbering of Steps 3+, which now carry a transitional banner marking them pending T2–T6.
- [x] T2 — Baseline digest storage + baseline-aware diff classification. Scope note (found during review): baseline absence is per-concept, not a single global "first sync" mode — split the class set into `unchanged` / `single-repo-change` / `new-single-source` / `new-converged` / `multi-repo-conflict`. Reworked old Steps 3/3b/4 in place (same numbering); Step 6a still writes the legacy ledger shape, so no `SYNC`-mode baseline can exist until T6 lands — every run is effectively first-sync until then.
- [ ] T3 — N-way merge step (semantic merge + contradiction arbitration UX)
- [ ] T4 — Hub Completeness validation step
- [ ] T5 — Generalize fan-out (5a/5b/5c/5e) to `shapeProfile`-driven path mapping
- [ ] T6 — Rework Step 6a for ledger logging (`participants[]` + `fileDigests{}`); narrow `.github/` scope
- [ ] T7 — QA gate: dry-run SYNC against Coding-Standards ↔ one-talent (2-participant), verify no data loss vs. current PUSH result
