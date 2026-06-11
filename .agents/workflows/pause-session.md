---
name: pause-session
description: End-of-session checkpoint. Generates a self-contained `__resume_prompt.txt` for tomorrow's agent and persists durable lessons to auto-memory.
---

# SKILL: pause-session

> **Pairs with `/resume-session`** — the inverse skill that consumes the `__resume_prompt.txt`
> this skill writes. Author the prompt for that consumer: verification first, gates explicit,
> protected files named.

## § 0. When to Use This Skill

Invoke when:
- The User signals end of session with pending work (*"let's resume tomorrow"*, *"save state"*, *"it's late"*).
- Session context has grown past ~70% and there is structured work that should outlive this session.
- Before a `/clear` when meaningful state would otherwise be lost.

Do **NOT** invoke when:
- All work in the session is committed AND merged — there is no pending state to preserve.
- The session was purely advisory/diagnostic with no follow-up work.
- The User explicitly asks for `/compact` or `/clear` — those have different semantics.

## § 1. Operating Procedure

### Step 1 — Audit pending state [MANDATORY]
Identify everything in flight:
- **Open PRs** (`gh pr list`) — note number, title, base branch, head branch, CI status.
- **Branches** with unmerged commits ahead of their base (`git branch -vv`).
- **Active tasks** marked `[/]` or `[ ]` in the current `PLAN_sprint_*.md`.
- **TODO.md items** picked up but not yet promoted to a PLAN.
- **Architectural decisions** made this session that are not yet in code.
- **Operator actions** the User committed to running (Azure CLI, env vars, RBAC grants, manual UI clicks).

### Step 2 — Triage where each item persists
| What | Goes where | Why |
|---|---|---|
| Durable preferences / architectural decisions | **Auto-memory** | Applies to future sessions, not just tomorrow |
| In-sprint tasks and progress | **`PLAN_sprint_*.md`** | Sprint-scoped, lives until sprint closes |
| New backlog items | **`TODO.md`** | Pre-sprint, awaiting promotion |
| Operational state (PR numbers, merge order, verification steps, operator follow-ups) | **`__resume_prompt.txt`** | Session-local, only useful for the immediate next session |

### Step 3 — Generate `__resume_prompt.txt` [MANDATORY]

Write the file at the **project root** (NOT inside `.claude/`). Required sections in order:

1. **Context header** — absolute date, active sprint, role assumed by the User.
2. **PRIORITY 0 — Verification** — what to check BEFORE any code change (PR status, branch state, anything that may have changed overnight). Lead with verification, not action.
3. **PRIORITY 1..N — Active work** — for each: branch name, exact file paths, line numbers, exact commands. Concrete, no hand-waving.
4. **Merge order** — explicit PR sequence for any open chain (e.g., `#148 → main first because …`).
5. **Operator actions** — Azure CLI, GitHub UI, manual steps the User (not the agent) must run.
6. **Reading list** — files the resuming agent must read before touching anything (CLAUDE.md, AGENTS.md, active PLAN, relevant stack rules).

**Rules:**
- **Self-contained.** A fresh agent must succeed without reading any prior conversation. No *"as we discussed"*, no implicit references — every term defined or pointing to a file.
- **Lead with verification.** Yesterday's state may have changed (PRs merged, branches force-pushed, deploys completed).
- **Point, don't restate.** Reference memory slugs, PLAN files, and stack rules by path — do not copy their content into the prompt. `/resume-session` reads the named files directly. This keeps the checkpoint lean and prevents it drifting out of sync with the source it duplicated.
- **Mark gates explicitly.** Any approval/STOP gate (e.g. *"Tech Lead deploy-verifies before merging"*) and any protected file (e.g. a locally-modified env file that must not be committed) must be called out in the relevant priority — the resuming agent enforces them verbatim.
- **Use a fenced ``` block** so the User can copy-paste directly into a new chat.
- **No duplication.** If the file already exists, Read it first, then **rewrite** with `Write` — do not append.
- **Close with the handoff cue.** End the file with a one-line pointer telling the next session to run `/resume-session`.

### Step 4 — Persist durable items to auto-memory
Apply the auto-memory rules from `CLAUDE.md`:
- New `feedback` memory if the User corrected an approach or confirmed a non-obvious one.
- New `project` memory only if there's a durable fact (decision, deadline, stakeholder ask).
- Skip if nothing crossed the bar — auto-memory rejects ephemeral task details.

### Step 5 — Report back [MANDATORY]
Output a short summary (max 5 lines):
- Path to `__resume_prompt.txt`
- Titles of memories created/updated
- One sentence "see you next session" closer

**Do NOT paste the full resume prompt back in chat** — it is already in the file, and pasting it bloats the session being saved.

## § 2. `.gitignore` Convention

`__resume_prompt.txt` is session-local and should not be committed. Verify it appears in `.gitignore`; if not, add it with the comment `# session-local checkpoint from /pause-session skill`. Use the leading double underscore prefix as a project convention for ephemeral session files.

## § 3. Anti-patterns

- **Pasting the prompt back in chat.** Inflates the saved session. The file is the artifact.
- **Saving session-local state to memory.** Memory is cross-session; `__resume_prompt.txt` is for "tomorrow."
- **Vague resume prompts.** *"Continue the work from yesterday"* fails — name the PRs, the branches, the files.
- **Skipping verification.** Always lead the resume prompt with `gh pr list` / `git status` / "check that X is still true" — overnight reality drifts.
