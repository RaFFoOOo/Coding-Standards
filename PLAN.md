# PLAN.md

### 1. Current Sprint Context
- **Sprint:** `sprint/1.0-lean-standards`
- **Goal:** Reduce the token cost of the standards corpus (rules + skills + workflows + `AGENTS.md`) and improve agent retrieval accuracy — **without losing a single `STRICT`/`MANDATORY` rule**. "Performance" here means token cost when loaded + retrieval clarity (structure), not runtime speed.
- **Approach (Tech-Lead approved):** Scope = rules + skills + workflows. Aggressiveness = **Conservative / dedup-first** — cut duplication and dead prose, preserve every rule's wording and intent.
- **Status:** Tasks complete (T1–T6) — **awaiting Tech-Lead decision** on the token-reduction target miss (see Acceptance Criteria + §5 T6 report).

### 2. Feature Specification
#### Feature: Lean Standards Corpus
- **User Story:** As the Tech Lead, I want the rules/skills/workflows to cost fewer tokens and be faster to navigate, so that every session loads cheaper and the agent applies the right rule without wading through duplicated prose — while every governance rule remains intact.
- **Acceptance Criteria:**
  - [-] ~15–20% token reduction — **NOT met. Honest result: corpus net +0.6% (+937 B).** Lean cuts removed ~844 B of real duplication, but the approved mid-sprint T2b sync-integrity fix added ~1781 B of necessary structural content (Step 6c + 4 CLAUDE.md rows), more than offsetting it. Root reason the target was unreachable conservatively: PR #20 already leaned this corpus, so little fat remained. See §5 T6 report.
  - [x] **Zero** `STRICT`/`MANDATORY`/`[X]` rules dropped — **verified: 81/81 tagged rules intact** (rule-inventory re-derived in T6, identical count).
  - [x] Each cross-cutting concept (Mockup Gate, branching/merge strategy) single-sourced in `AGENTS.md` + cross-referenced (T2/T3). (200-line rule & Iterative Review were already single-sourced.)
  - [x] No file's *meaning* changed; only redundancy/dead refs removed (verified each task via Iterative Review Gate).

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
- [x] **T3 `[M]`** — Skills lean pass: dedup'd `manage-artifacts` against AGENTS.md §1 + todo-manager (cross-refs, both tagged rules preserved). `run-qa`/`todo-manager`/`plan-sprint` already tight — no manufactured churn. *(dep: T1)*
- [x] **T4 `[L]`** — Workflows lean pass. Honest finding: workflows are mostly necessary procedure (low removable fat; the big *structural* fix was T2b). Real wins: removed dead `PR #108` cross-repo refs in `recursive-review` (×2), fixed stale `sync-template.md`→`sync-templates.md` reference. No manufactured churn on already-tight files (sessions, resolve-pr). *(dep: T2)*
- [x] **T5 `[S]`** — Light rules pass. Honest finding: **no dedup needed** — the stack rules already cross-reference AGENTS.md correctly (e.g., stack-github-actions §5 "Per AGENTS.md §5…") and don't duplicate global process rules. #20's lean pass + good authoring left them clean; no manufactured churn. *(dep: T2)*
- [x] **T6 `[S]`** — Verify: rule-inventory diff + token-delta report (see report below). *(dep: T2–T5)*

### 5. T6 Verification Report (2026-06-11)
- **Meaning-loss guard:** rule-inventory re-derived → **81/81 tagged rules present** (identical to T1 baseline). No `STRICT`/`MANDATORY`/`GLOBAL RULE` rule dropped. `rule-inventory.md` archived to `archive/`.
- **Token delta (bytes/4 proxy) vs `main`:** baseline 152,045 B (~38,011 tok) → current 152,982 B (~38,245 tok) = **+937 B (+0.6%)**.
  - Genuine lean cuts: manage-artifacts −452 B, plan-sprint −191 B, recursive-review −174 B, run-feature −27 B = **−844 B** of real duplication removed.
  - Necessary additions (approved T2b sync fix): sync-templates Step 6c +1253 B, CLAUDE.md 4 rows +528 B = **+1781 B**.
- **Verdict:** the 15–20% reduction target was **not achievable conservatively** — PR #20 already leaned this corpus, so the remaining fat was ~0.8 KB, and the T2b correctness fix (Tech-Lead approved) necessarily exceeded it. Defensible wins delivered: a real correctness fix (4 orphaned workflows wired + recurrence prevented), genuine single-sourcing/dedup, dead-reference cleanup, and a verified-intact rule set. **Open question for Tech Lead:** accept this honest outcome, or authorize an *aggressive* pass to actually hit a token target?

**Dependency order:** T1 → T2 → T2b → (T3, T5) → T4 → T6. Each task = atomic commit on its own `task/sprint-1.0/<id>-<slug>` branch, PR'd into the sprint branch; Iterative Review Gate (min 3 passes) per task.
