# PLAN.md

### 1. Current Sprint Context
- **Sprint:** `sprint/1.0-lean-standards`
- **Goal:** Reduce the token cost of the standards corpus (rules + skills + workflows + `AGENTS.md`) and improve agent retrieval accuracy — **without losing a single `STRICT`/`MANDATORY` rule**. "Performance" here means token cost when loaded + retrieval clarity (structure), not runtime speed.
- **Approach (Tech-Lead approved):** Scope = rules + skills + workflows. Aggressiveness = **Conservative / dedup-first** — cut duplication and dead prose, preserve every rule's wording and intent.
- **Status:** In progress (T1 done — baseline + rule-inventory guard captured: 81 tagged rules)

### 2. Feature Specification
#### Feature: Lean Standards Corpus
- **User Story:** As the Tech Lead, I want the rules/skills/workflows to cost fewer tokens and be faster to navigate, so that every session loads cheaper and the agent applies the right rule without wading through duplicated prose — while every governance rule remains intact.
- **Acceptance Criteria:**
  - [ ] ~15–20% token reduction across the corpus (measured T1 → T6, bytes/4 proxy).
  - [ ] **Zero** `STRICT`/`MANDATORY`/`[X]` rules dropped — verified by the T1 rule-inventory diff in T6.
  - [ ] Each cross-cutting concept (Mockup Gate, 200-line rule, Iterative/Recursive Review, branching/merge strategy) lives in **one** canonical location; all others are one-line cross-references.
  - [ ] No file's *meaning* changed; only redundancy and verbosity removed.

### 3. Technical Implementation Plan
*Pending approval to execute.*

**Baseline (token proxy = bytes/4, captured 2026-06-11):**

| Cluster | Loaded when | ~Tokens |
|---|---|---|
| `AGENTS.md` + `CLAUDE.md` | every session | ~5.3k |
| Stack rules (×3: angular 5.0k, github-actions 3.5k, dotnet 2.8k) | glob-triggered | ~11.4k |
| Skills (×4) | on invoke | ~3.0k |
| Workflows (×9: sync-templates 336 ln is the largest) | on invoke | ~10.0k |

**Duplication map (probe counts):** Mockup Gate ×3 files · 200-line rule ×3 · Iterative/recursive review ×4 · branching/merge strategy ×3.

**Meaning-loss guard:** T1 produces a `rule-inventory.md` artifact listing every `STRICT`/`MANDATORY`/`[X]`-tagged rule with its source file:line. T6 re-derives the same inventory and diffs — any missing entry blocks the sprint.

### 4. Task Progress
- [x] **T1 `[S]`** — Baseline + method artifact: per-file token counts, the `rule-inventory.md` (meaning-loss guard, 81 tagged rules), acceptance criteria. *(dep: —)* → archived in T6.
- [x] **T2 `[M]`** — Cross-file dedup: choose canonical home (usually `AGENTS.md`) for each repeated concept; replace copies with one-line cross-references. *(dep: T1)* → PR #25.
- [x] **T2b `[M]` — Shim/sync integrity fix (folded in mid-sprint, Tech-Lead flagged):** 4 workflows synced into `.agents/` (#18, #20) were never wired into Claude Code — no `.claude/` shim, no `CLAUDE.md` row (`recursive-review`, `pause-session`, `resume-session`, `resolve-workflow`). Created the 4 shims + CLAUDE.md rows (table 9→13) **and** patched `sync-templates.md` with **Step 6c** self-sync reconciliation so it can't recur (root-cause per §0). *(dep: T2; precedes T4)*
- [ ] **T3 `[M]`** — Skills lean pass: `run-qa`, `todo-manager`, `manage-artifacts`, `plan-sprint`. *(dep: T1)*
- [ ] **T4 `[L]`** — Workflows lean pass: `sync-templates` (336 ln) first, then `recursive-review`, `run-feature`, `resolve-*`, session workflows. *(dep: T2)*
- [ ] **T5 `[S]`** — Light rules pass: apply dedup cross-refs + structure only; **do not** re-trim the prose PR #20 already leaned. *(dep: T2)*
- [ ] **T6 `[S]`** — Verify: rule-inventory diff (nothing dropped) + final token-delta report + README/metrics note. *(dep: T2–T5)*

**Dependency order:** T1 → T2 → T2b → (T3, T5) → T4 → T6. Each task = atomic commit on its own `task/sprint-1.0/<id>-<slug>` branch, PR'd into the sprint branch; Iterative Review Gate (min 3 passes) per task.
