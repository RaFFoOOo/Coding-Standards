---
name: build
description: Implement one approved plan task — task branch, render locally, atomic commits, the PLAN row marked in the finishing commit, a PR into the sprint branch, and a watch on it.
---

# build

One task, one branch, one PR. Rules cited by title are in `AGENTS.md`.

## 1. Read
The task's row and its `§T<n>` section in `PLAN_sprint_<N>.md`; the approved mockup if the task
has a UI half; the stack rule for the files you will touch (`.agents/rules/stack-*.md`). If the row
is M or larger, or touches more than 3 files, and has no change-cost classification, run `plan`
step 6 now — if its gate trips, stop and propose the refactor to the Tech Lead instead.

**Then list the rules that govern the files in scope** — `AGENTS.md` (§2 structure and file length,
§3 tests, §6 comments), the stack rule, the `stack-shared-ui.md` sections the surface uses, the
`DECISIONS.md` entries it touches — and write the change to them from the first line. The list opens
the PR body (step 7). A rule is applied while writing, never first discovered in review.

## 2. Branch
```bash
git checkout sprint/<N>-<slug> && git pull origin sprint/<N>-<slug>
git checkout -b task/sprint-<N>/<id>-<brief>
```
Standalone work: `git checkout main && git pull origin main && git checkout -b <bugfix|chore|refactor|docs>/<slug>`.
When `main` has moved, merge it into the sprint branch and the sprint branch into every open task
branch now — merge, never rebase, on a published branch.

## 3. Implement
- Follow the plan's design. **Fix, don't defer:** a gap you find on the surface or in the files the task
  touches is fixed in this task, not logged. Only an unrelated idea goes to `backlog/`.
- **Tests only where they earn their upkeep:** server-side rules, date/time/money, database
  queries and migrations, a regression of a shipped defect. Nothing else gets a new spec. An
  out-of-scope test the change breaks gets the smallest fix and is named in the PR body as a prune
  candidate.
- A new guard or regression test ships with a **mutation run** in the PR body: break it, show red,
  restore, show green. The mutation must compile. Commit before mutating.
- **A cross-stack change ships its visual half first**, on mocks, and touches the backend, a seed
  or a schema only after the Tech Lead approves the deployed preview.
- Comments state the concept, never a reference; a comment may not carry a commitment.

## 4. Render it locally before you commit — any task with a visual half
```bash
cd {webapp} && npm run start:preview -- --port 4300     # stop the self-hosted runner first
```
Open the surface, read the rendered DOM (widths, heights, z-index, the actual text in **both**
bundles) at 375 and at desktop. After every edit require a **new** `Application bundle generation
complete` line in the serve log before re-measuring. Fix, then commit. The deployed preview is for
the Tech Lead's approval, not your first look.

## 5. Verify before the PR
Run `verify` §1 (the quick scan) on the changed files; §2 console zero-tolerance and §3 viewports
when a surface changed; the SAS scan when `assets/mock/` changed. Then the **self-review**, to make it better: would I
ship it; is it comfortable for the user; can it be simpler or clearer; is it correct at the edges;
is it performant; is it a base for future sprints. Fix every finding that belongs to
this task's surface or files; `backlog/` takes only what is unrelated to it.

## 6. Commit
- Atomic: one task, one commit (a separate `docs(sprint-<N>): mark T<n>` commit is fine).
- **The finishing commit marks the PLAN row `[x]`** and marks the backlog items the task ships
  (`- [x] … — #<PR>`). Never leave a finished row `[ ]` to batch later.
- `git diff --cached --stat` must match the size of the change you meant (a CRLF file inflates it —
  `agent-workarounds.md`).

## 7. PR
```bash
git fetch origin && git merge origin/sprint/<N>-<slug>      # or origin/main for standalone work
git push -u origin <branch>
```
Compile both stacks (`ngc -p tsconfig.app.json --noEmit`, `dotnet build`) and `ng lint`; targeted
specs for what changed. Full suites only for a shared change or what CI cannot cover.
Open the PR into the **sprint branch** (squash merge) — or `main` for standalone work. Body: first
the rules applied (step 1), then what changed and why in five lines, the numbers, the mutation run
if any, prune candidates, the review-pass count. Subscribe to the PR and drive it to green; a red check is work now, never
"waiting on review". Merge only after the Tech Lead approves.

## 8. When the Tech Lead is away
Merge only what they authorised **in their own words, in this session**, scoped to a merge class
(*"squash-merge green task PRs T2–T7 into sprint/NN"*); never infer a grant. Stop and write a
checkpoint in the plan when: a decision has no precedent in `DECISIONS.md`; an instrument result
cannot be explained after one investigation; two consecutive CI failures are caused by your change;
a change would touch `main`, the backend, a dependency PR or a workflow's triggers; a coverage count
disagrees with the edit count; the remaining budget cannot finish the next task. Report every merge
in the morning summary, including any outside the literal wording.
