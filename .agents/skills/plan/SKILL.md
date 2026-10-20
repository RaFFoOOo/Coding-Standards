---
name: plan
description: Open a sprint — branch and draft PR, scope from the backlog, tasks with sizes and a change-cost pass, the Mockup Gate — and get the plan approved before any code.
---

# plan

Numbered steps; run them in order. Rules cited by title are in `AGENTS.md`.

## 1. Read first
`CLAUDE.md`, `AGENTS.md`, `DECISIONS.md` (recent epoch + the 🔒 index), `docs/ARCHITECTURE.md`,
the previous sprint's plan in `archive/`, and `backlog/README.md`. Each task's design names the rules
that govern its files and is drawn to them from the start — a plan never leaves a rule for review.

## 2. Branch and draft PR
```bash
git checkout main && git pull origin main
git checkout -b sprint/<N>-<kebab-slug> && git push -u origin sprint/<N>-<kebab-slug>
```
Open the sprint PR to `main` as a **draft** at once (MCP `create_pull_request`, `draft: true`);
it stays draft until every task PR is in. Its title type follows its content — `feat(sprint/<N>)`
for product work, `chore(sprint/<N>)` for a process or tooling sprint — because the prose guard
judges a `feat` PR by its code-to-Markdown ratio. Task branches are cut from the sprint branch, never
from `main`. Standalone work (hotfix, chore, docs) needs no sprint branch.

## 3. Candidates, by priority, re-measured
```bash
awk '/^## /{h=$0} /^\*\*Category:\*\* .* · \*\*Priority:\*\* (critical|high)$/{sub(/.*\*\*Priority:\*\* /,""); print $0"\t"FILENAME"\t"substr(h,4)}' backlog/[a-z]*.md
```
- A ⏳ entry is not a candidate until its trigger fired; a ⚖ entry not until the decision exists.
- **Re-measure every candidate before sizing it** — run its `Verified` command. An entry records
  what was true when written; cancel the task if the measurement says the work is gone.
- Anything below `high` in the sprint states why: it shares a file with scheduled work, unblocks a
  `high`, or the Tech Lead asked for it.
- The pilot's users decide what is built; the rules decide how. A process item enters a sprint only
  through the monthly `review`.

## 4. The plan file
`PLAN_sprint_<N>.md` at the root, named in `CLAUDE.md`'s Active Sprint block (`validate-archive.sh`
requires it). Sections, in this order:

1. Header: `STATUS`, branch, base SHA, draft PR number, a "for a fresh session" reading list.
2. **Why this sprint exists** — the decision and the numbers behind it, five lines.
3. **Tasks** — `| # | Status | Task | Size | Depends |`, dependency order, sizes `S/M/L/XL`.
   A task row holds what a fresh session needs to build it; long designs go in a `§T<n>` section.
4. **Evidence, measured <date>** — `| # | Measurement | Re-take with |`, one row per task.
5. **Change-cost pass** — `| # | Essential | Incidental | Gate |` for every task M or larger or
   touching more than 3 files (step 6).
6. **Not in this sprint, and why** — each rejected candidate with its reason (⏳, ⚖, a decision).
   A gap on a surface a task already touches is never here: it joins that task (the Tech Lead, 2026-09-29).
7. **Gates** — what proves each task, and the sprint gate.

Promoted backlog entries are marked `→ promoted to PLAN_sprint_<N> T<n>` in the same commit.

## 5. Order and foundations
Dependency-first (schema → API → service → UI). When a pattern will recur across surfaces **and
two real cases exist**, the shared foundation is task 1 and the surfaces depend on it. One case:
build it concretely; extract on the second.

## 6. Change-cost pass — every task M+ or > 3 files
1. Enumerate every site with `grep` / `git grep`; keep the commands in the plan.
2. Classify each site **essential** (behaviour changes there) or **incidental** (a fixture, a
   construction of the unit under test, a forwarded input, duplicated data, a comment).
3. If incidental sites outnumber essential ones, or any incidental group reaches **5 files**,
   schedule a refactor task (a builder, a factory, a value read at the leaf) **before** the feature.
4. A design may not add a pattern step 3 would flag.
5. Record the counts in the plan's change-cost table.
6. **Siblings.** A task that fixes a defect names the *state* that went wrong and lists, by `grep`
   (the command beside it), every other trigger of that state; one that fixes or guards a *shape*
   (a constructor, a fixture, a forwarded input) lists every sibling of the shape. A row without that
   list is not sized: a fix for one trigger fixes one.

## 7. Mockup Gate — every task with a UI half
File: `mockup_sprint_<N>_<slug>.md` at the root (archived at close). It must carry:
1. **Shared-surface inventory first** — grep how the app already does each element
   (`stack-shared-ui.md §4a` lists the elements and commands) and record element → shared
   component → the command that proves it. Draw `<app-action-bar>`, not "a Save button".
2. **AS-IS traced** — every label, state and control cites a `file:line`; labels are read from
   **both** i18n bundles, never from a key; states come from the actual `@switch`/`@if` set.
   Nothing is drawn that cannot be cited.
3. **TO-BE marked as a proposal**, with component hierarchy and mobile (375) vs desktop where the
   layout differs.
4. **A hierarchy, rhythm or separation finding gets two mutually exclusive rendered specimens**,
   built on the local preview server, and the Tech Lead chooses. One specimen plus prose is not
   ready to lock.
5. **The shipped convention wins over the wireframe.** Where the drawing and an existing pattern
   disagree, the fix is a `DECISIONS.md` entry, never a faithful build of the drawing.

Save the approved mockup; after approval it is **frozen** for the sprint — a new idea goes to
`backlog/`, and re-opening needs a recorded Tech-Lead decision.

## 8. Approval
Present the plan (and mockup) to the Tech Lead. Open points are discrete questions with concrete
options, one at a time, never a list at the end of a summary. **No code before approval.**
Commit the plan with `docs(sprint-<N>): plan — <title>`.
