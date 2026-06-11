---
name: resume-session
description: Session-start bootstrap. Reads `__resume_prompt.txt` and executes the saved resume protocol — verification first, then prioritized work, honoring every gate. The inverse of pause-session.
---

# SKILL: resume-session

## § 0. When to Use This Skill

Invoke when:
- A new session starts and a `__resume_prompt.txt` exists at the project root with pending work (the User says *"resume"*, *"continue from yesterday"*, or hands you the file).
- You are picking up structured, multi-step work that a prior session checkpointed via `/pause-session`.

Do **NOT** invoke when:
- No `__resume_prompt.txt` exists, or it is empty / clearly stale (all its PRs already merged).
- The User is starting genuinely new work unrelated to the saved state — run the normal Agent Bootstrap Protocol and proceed.

## § 1. Operating Procedure

### Step 1 — Load the checkpoint + bootstrap context [MANDATORY]
1. Read `__resume_prompt.txt` in full.
2. Execute the **Agent Bootstrap Protocol** from `CLAUDE.md`, then read every file in the resume prompt's "Reading list" (CLAUDE.md, AGENTS.md, the active PLAN, relevant stack rules, named memories) **before any action**.
3. Do not skip files the prompt names — they encode the constraints the prior session was operating under. Read the named files directly; do not re-explore the whole repo to re-derive what the prompt already points to.

### Step 2 — Run PRIORITY 0 verification FIRST [MANDATORY]
Yesterday's state drifts overnight. Before any code change, run the verification block exactly as written in the resume prompt:
- `git fetch` + PR status (`gh pr view` / `gh pr list`) — did anything merge, close, or get force-pushed?
- `git status` / branch divergence — is the working tree what the prompt assumed?

Report drift to the User in one short block. **If reality contradicts the prompt's assumptions, STOP and reconcile before proceeding** — never run PRIORITY 1 steps against a repo that changed underneath the checkpoint.

### Step 3 — Execute priorities in order, honoring gates [MANDATORY]
- Work PRIORITY 1..N in the stated sequence; respect the documented merge order.
- **Honor every STOP / approval gate verbatim** (e.g., *"Tech Lead deploy-verifies before merging"* → open the PR, do **not** merge it).
- **Skip operator-gated and calendar-gated items.** Anything the prompt assigns to the User, or anything blocked on an external date/event (a DNS transfer, a CI run you can't trigger, a manual `az` login), is NOT agent work — surface it, don't attempt it.
- **Preserve protected files the prompt names** (e.g., a locally-modified env file that must not be committed) — stage paths explicitly, never `git add -A`.

### Step 4 — Keep the checkpoint honest
- The resume prompt becomes stale as items complete. Do **NOT** edit it mid-session.
- At session end, if pending work remains, regenerate it via `/pause-session` (which rewrites the file in place). If everything is now committed **and** merged, the checkpoint is spent — tell the User it can be deleted.

### Step 5 — Report back [MANDATORY]
Short summary (max ~6 lines): drift found in Step 2, what was completed, what is blocked on a gate or operator, and the single next action owed. Do not paste the resume prompt back — it is already on disk.

## § 2. Relationship to auto-memory
`__resume_prompt.txt` holds **session-local** operational state (PR numbers, merge order, this-week's gates). Durable facts live in **auto-memory** and are recalled automatically. If the resume prompt restates something that is actually durable (a standing preference, an architectural decision), treat the recalled memory as the source of truth and the prompt's copy as a convenience pointer that may be out of date.

## § 3. Anti-patterns
- **Acting before verifying.** Running PRIORITY 1 before PRIORITY 0 against an overnight-drifted repo is the primary failure mode this skill exists to prevent.
- **Blowing through gates.** A *"STOP — Tech Lead verifies"* line is a hard stop, not a suggestion.
- **Attempting operator/calendar-gated work.** Watching for a DNS transfer or running a login the User owns is not agent work.
- **Editing or committing the checkpoint.** It is session-local and `.gitignore`d; `/pause-session` owns its lifecycle.
