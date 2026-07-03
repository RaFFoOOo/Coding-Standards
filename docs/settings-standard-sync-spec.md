# Spec — `settingsStandard`: sync standard `settings.json` keys across repos

> **Status:** DRAFT (backlog). Future sync-engine enhancement. Sketched 2026-07-03 after
> `CLAUDE_AFK_TIMEOUT_MS` had to be hand-applied to all three repos (Coding-Standards,
> le-cementine, one-talent) because `.claude/settings.json` is not a synced concept.

## 1. Problem

`.agents/workflows/sync-templates.md` syncs `rule:` / `skill:` / `workflow:` / `AGENTS.md` /
`github:` concepts. It does **not** sync `.claude/settings.json`. So a project-scoped Claude Code
setting that should be uniform everywhere (e.g. `env.CLAUDE_AFK_TIMEOUT_MS`) must be added to each
repo by hand — no single source of truth, and it silently drifts.

Wholesale file-sync is **not** the answer: `settings.json` mixes two kinds of key, and clobbering
the second kind would repeat the exact "flavor" regression the rule-sync was built to avoid.

| Standard-worthy (should be uniform) | Project / personal (must NOT be clobbered) |
|---|---|
| `env.CLAUDE_AFK_TIMEOUT_MS`, `attribution.*`, `includeCoAuthoredBy`, `autoUpdatesChannel` | `model`, `effortLevel`, `permissions`, `enabled*McpjsonServers`, `enabledPlugins`, `worktree` |

## 2. Goal

The hub declares a **subset of settings keys** as canonical. The sync **deep-merges only those
keys** into each spoke's committed `.claude/settings.json`, leaving every other key untouched —
hub-authoritative for the declared subset, preserve-spoke-flavor for the rest (same model as rules).

## 3. Design

- **Declaration (hub `sync-state.json`):** a new `settingsStandard` object — an allowlist of canonical
  key→value pairs by dotted path, opt-in exactly like `githubTemplates` declares *which* `.github/`
  files sync:
  ```json
  "settingsStandard": { "env.CLAUDE_AFK_TIMEOUT_MS": "2147483647", "includeCoAuthoredBy": true }
  ```
- **Concept type (Step 2b):** `setting:<dotted.key.path>` — value read from each participant's
  committed `settings.json` (never `settings.local.json`, which is personal/gitignored/runtime-wins).
- **Classification (Step 4):** compare each declared key's value hub-vs-spoke. Hub value is canonical
  (the hub is the standard source). Absent-in-spoke → will be added; differing-in-spoke → hub wins.
- **Fan-out (Step 5a):** **deep-merge** the canonical value into each spoke's `settings.json` at the
  dotted path, creating intermediate objects as needed. **Never** touch an undeclared key. Preserve
  file formatting/ordering as much as practical (JSON round-trip).
- **Baseline/ledger (Step 6a):** record per-key value digests, same as any other concept, so steady-
  state runs classify unchanged keys as `unchanged`.

## 4. Edge cases & rules

- **Deep, not shallow:** merging `env.X` must not replace the whole `env` object — only set the leaf.
- **Retire a standard key:** removing a key from `settingsStandard` follows the same
  retire-vs-repo-local ask as a `single-repo-change — deletion` (global delete from spokes, or leave).
- **Per-spoke opt-out:** a spoke may exclude a specific `setting:` key via its own `skipList`
  (e.g. a project that deliberately runs a different `autoUpdatesChannel`).
- **Personal vs team:** only the committed `settings.json` is ever read/written; `settings.local.json`
  is out of scope by definition.
- **Never sync secrets or machine paths:** `settingsStandard` is for portable, non-sensitive keys only
  (governed by `AGENTS.md §3 Config Separation`).

## 5. Open questions

- Which keys form the **initial standard set**? Proposed: `env.CLAUDE_AFK_TIMEOUT_MS`,
  `includeCoAuthoredBy`. Defer `attribution.*` and `model`/`effortLevel` (arguably personal).
- Do we enforce **value** or merely **presence**? → Value (enforcing presence-only defeats the purpose).
- Interaction with the future `/config`-exposed AFK setting (which will default off) — once that lands,
  drop `CLAUDE_AFK_TIMEOUT_MS` from the standard set and rely on `/config`.

## 6. Effort

Small–medium: one new declaration key, one new concept type, one deep-merge projection path, ledger
digest reuse. Fits a single sprint task. **No new dependency** (native JSON deep-merge).
