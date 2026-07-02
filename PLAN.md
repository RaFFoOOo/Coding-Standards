# PLAN — Sprint 2.0: N-Way Standards Sync Engine

## 1. Current Sprint Context
- **Goal:** Replace the directional PUSH/PULL `sync-templates` workflow with a true N-way SYNC that merges divergent standards content across 2+ sibling repos (Coding-Standards as hub, plus any project spokes such as le-cementine, one-talent) into one converged, agent-agnostic concept set, then projects it back into each repo's native shape.
- **Status:** In Progress (T1, T2, T3, T4, T5 done)

## 2. Feature Specification

#### Feature: N-Way Standards Sync
- **User Story:** As the Tech Lead maintaining standards across multiple independent project repos, I want one sync operation that merges every repo's local improvements together — instead of a one-directional push/pull that only lets one repo's version win — so that no repo's contribution is silently lost or overwritten, while every repo keeps operating in its own agent shape (Claude Code `.claude/` vs Generic `.agents/`).
- **Acceptance Criteria:**
  - [x] Given 2+ repo paths, the workflow auto-detects each repo's **shape profile** (rule root, skill root, workflow mode, sync-tracking root) instead of asking a binary Claude-Code/Generic question — this fixes the already-observed drift where le-cementine keeps rules under `.claude/rules/` but the current workflow assumes `.agents/rules/`. (T1)
  - [x] Every rule/skill/workflow is resolved through a shape-agnostic **concept id** (e.g. `rule:naming-azure-resources`, `skill:run-qa`), so the same standard can be compared across repos that store it at different paths. (T1)
  - [x] Given content that diverged in 2+ repos since the last recorded sync, the workflow performs a **baseline-aware classification** (unchanged / single-repo-change / new-single-source / new-converged / multi-repo-conflict — the last two split out during review since baseline absence is per-concept, not a single global "first sync" mode) using digests persisted in `sync-history.json` from the prior run — not a blind "current state wins" diff. (T2)
  - [x] Single-repo divergence fast-paths (today's PUSH behavior); multi-repo divergence triggers an **LLM semantic merge** that deduplicates additive changes and raises genuine contradictions in a table for Tech Lead arbitration — never auto-resolved silently. (T3)
  - [x] The merged canonical concept set passes the agnostic-review gate exactly once, before fan-out to any participant. (T5 — moved to Step 4d, since it validates the hub's own tree pre-fanout, not a post-copy per-target check)
  - [x] Each participant receives its own branch + PR, projected into its native shape via `shapeProfile`-driven path resolution and content substitution (Step 5a), plus shim reconciliation (6c, unchanged). (T5 — Steps 5c/5e deleted outright, not just reworked: under hub-and-spoke SYNC the hub is always Source, so the arbitrary-non-hub-Source cases they existed for can no longer occur)
  - [x] **Hub Completeness invariant:** Coding-Standards' `skipList` may only contain entries provably non-standard (project-specific data/config); any concept present in a spoke but absent from the hub is flagged as a violation requiring promotion or explicit non-standard justification — never silently skipped. (Concrete instance already fixed standalone: `naming-azure-resources.md`, see `chore/promote-naming-azure-resources-rule`.) (T4 — enforced in Step 4c, justification requires a `DECISIONS.md` entry, not just a bare `skipList` line)
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
  - [x] New step (4b) — **N-way merge**: lands single-repo/new-converged/adopted-new-single-source content into the hub's own tree (the staging area, per the locked design — no separate temp directory); LLM semantic merge + contradiction table (N columns, not hardcoded to 2) + Tech Lead approval gate for multi-repo conflicts. (T3)
  - [x] New step (4c) — **Hub Completeness validation** [MANDATORY]: re-scans the hub's tree post-merge, flags any registry concept missing from it unless backed by an explicit global-retirement or a `DECISIONS.md`-justified repo-local exclusion; also validates the hub's own `skipList` has zero entries matching a real concept. Blocks Step 5 (fan-out) until clean. (T4)
  - [x] Rework Steps 5a/5b/5c/5e path-mapping tables to read from `shapeProfile` instead of hardcoded literals. (T5 — collapsed into a single Step 5a "Shape-Driven Projection"; old 5c/5e deleted, old 5d renamed 5b)
  - [x] Move agnostic review (was Step 5f) to run once pre-fan-out instead of once per target. (T5 — now Step 4d, runs on the hub's tree before Step 5 starts; superseded per-spoke `templateSanitization` entirely, see Step 4d's design note)
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
- [x] T3 — N-way merge step (semantic merge + contradiction arbitration UX). Locked design: hub's own branch is the staging area (no scratch dir) — see conversation 2026-07-02. Scope note (found during review): a spoke's local deletion must never auto-delete from the hub; added a `single-repo-change — deletion` sub-case that asks global-retirement vs. repo-local-skip, mirroring the `new-single-source` ask. Also generalized the Contradiction Table to N columns (was hardcoded to 2).
- [x] T4 — Hub Completeness validation step. Found during review: the design text claimed to "reuse the existing Decision Recording convention" via `DECISIONS.md`, but Coding-Standards itself had no `DECISIONS.md` — created one (header/format only, matching le-cementine/one-talent's convention) and extended `AGENTS.md §1` Decision Recording to explicitly cover this new use case, so the claim in the workflow doc is actually true rather than aspirational.
- [x] T5 — Generalize fan-out (5a/5b/5c/5e) to `shapeProfile`-driven path mapping. Scope note: went further than "generalize" — Steps 5c (Reverse Transformation) and 5e (Claude→Claude sibling) are **deleted**, not reworked, since hub-and-spoke SYNC makes the hub always Source, eliminating the arbitrary-non-hub-Source case they existed to handle. Also retired per-spoke `templateSanitization` (superseded by the single Step 4d gate) and made `CLAUDE.md`'s skill table registry-derived instead of hardcoded. Found during review: 3 stale cross-references introduced or exposed by this rewrite (a misattributed leak-detection sentence, a false "unchanged" claim on the cleanup step, a dangling reference to a Step 4 file-exclusion list that T2 had already removed) — all fixed. Added an explicit known-gap note for `.github/` fan-out (deferred to T6, not silently dropped).
- [ ] T6 — Rework Step 6a for ledger logging (`participants[]` + `fileDigests{}`); narrow `.github/` scope
- [ ] T7 — QA gate: dry-run SYNC against Coding-Standards ↔ one-talent (2-participant), verify no data loss vs. current PUSH result
