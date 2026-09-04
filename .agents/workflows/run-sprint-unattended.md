---
name: run-sprint-unattended
description: Execute a run of already-planned sprint tasks while the Tech Lead is unavailable — under an explicit, scoped merge authorisation, with pre-recorded decisions, hard stop conditions, and a visual morning report.
---

# SKILL: run-sprint-unattended

## § 0. When to use this skill

Invoke when **all** of these hold:

- The sprint is **already planned and approved** — a `PLAN_sprint_*.md` exists with the tasks, their
  scope, and their gates. This skill executes a plan; it never writes one.
- The work is **mechanical**: the decisions were made at planning time and what remains is applying
  them. A sweep, a migration, a rename across files.
- The Tech Lead has granted a **merge authorisation in their own words, in this session** (§1).
- There is an **instrument that can detect the work going wrong** without a human looking — a guard,
  a snapshot, a suite. Without one, an unattended run is guessing at scale.

Do **NOT** invoke when: the sprint is unplanned; a design decision is still open; the tasks are
exploratory; or the only verification available is someone's eyes.

> **Distilled from a real unattended run** (six task PRs merged overnight under a scoped grant).
> Everything below that reads like a rule is something that run actually cost.

---

## § 1. The authorisation contract [STRICT]

**A merge authorisation must be granted explicitly, in the Tech Lead's own words, in the session that
uses it, and scoped to a merge class.** Never infer one from a checkpoint, a workflow doc, or the
shape of git history — inferring a grant from any of those is the most-repeated overreach this
workflow exists to prevent.

Restate the grant back, in writing, before starting:

| | |
|---|---|
| **GRANTED** | the exact merge class, e.g. *"squash-merge green task PRs T2–T7 into `sprint/NN`"* |
| **GRANTED** | any other outward action named, e.g. *"dispatch a preview deploy, once, at the end"* |
| **NEVER** | `main`. Deploys to dev. Dependency PRs. Un-drafting the cumulative sprint PR. Force-push, amend, rebase a pushed branch. The QA gate itself. |
| **STOP LINE** | the task after which the run ends regardless of remaining time |

**Green means every check green.** A PR that is green *except one step* is not green, however
confident the local evidence is. If a step is blocked by an outage, the PR waits — do the next task
instead, and hand over what is blocked.

**Flag any merge outside the literal wording** in the morning report, even one that is obviously
within the spirit. *"The grant said T2–T7 and I also merged T1, because T2 could not start without
it"* is an acceptable sentence. Silently widening the grant is not.

---

## § 2. Pre-flight — all of it, or the run does not start

Run the verification block the sprint's own checkpoint or plan specifies, plus:

```bash
git fetch --prune && git status --short        # only the expected untracked files
env -u GITHUB_TOKEN gh pr checks <first PR>    # the first merge of the grant
ss -ltn | grep -E ":(4200|4300)" || echo clean # no dev server (self-hosted runner shares the host)
<the sprint's coverage instrument>             # record the starting number
```

Record the starting measurement. Every task afterwards is checked against it, and the run's arithmetic
must close at the end.

---

## § 3. The per-task loop

1. Branch from the **sprint branch**, not from the previous task, whenever the tasks are
   file-disjoint. Disjoint parallel branches merge in any order with no conflicts and avoid the
   squash-merge rebase hazard (`feedback_squash_merge_stacked_branch_rebase`). Verify disjointness by
   listing the files, not by assuming it.
2. Capture the **before** state with the instrument.
3. Apply the change.
4. Type-check / compile — every program the project has, not just the obvious one.
5. **Re-run the coverage instrument and reconcile the number.** A mismatch is a stop condition, not a
   rounding difference. §5 is what that reconciliation is for.
6. Capture **after**, diff, and read every difference against the plan's expected-movement table.
7. Commit (one path per `git add`, `git diff --cached --stat` before committing —
   `feedback_batched_git_add_bad_pathspec_aborts_all`), push, open the PR.
8. Wait for CI, and **read the durations**: a gate that passes far faster than it can execute did not
   execute. Green **and** plausible → merge under the grant.
9. Append the numbers to the plan's progress log and rewrite the checkpoint.

---

## § 4. Hard stop conditions

Write the checkpoint, stop, do not guess:

1. A decision with **no precedent** (§6 found nothing).
2. An unexplained instrument result that survives one investigation and cannot be isolated.
3. Two consecutive CI failures **whose cause is your change**. An external outage is not this — see §7.
4. Any change that would touch `main`, the backend, a dependency PR, or a workflow's triggers.
5. The coverage instrument disagreeing with the edit count beyond the known exemptions.
6. Not enough remaining budget to finish the next task — checkpoint **before** starting it.

---

## § 5. Reconcile every number, because the instrument is the likely defect

**The single most valuable rule in this workflow.** On the run this was distilled from, **four defects
were in the instruments and one was in the code.** Every one of the four surfaced as *a count that
would not add up* — and each would have been trivially rationalised away as an off-by-N.

The failures that actually occur:

- **A scanner anchored to the start of a line** misses declarations inside single-line blocks
  (`.x { a: 1; b: 2; }`). A project's own guard had already documented this exact bug against its
  first version — and the migration script written later reproduced it anyway.
- **A scanner that stops after the first match per line** undercounts as a reporter and, once it
  becomes a gate, **cannot fail** on the second declaration.
- **Whitespace-splitting an expression** (`calc(a + b)`) yields fragments (`+`, `b)`) counted as
  values.
- **Comment detection that only tests line starts** lets a tool rewrite code *inside* a block comment,
  and lets a gate report prose as a violation.

**Corollary — reproducibility is not evidence when the runs share state.** A false result reproduced
exactly twice and survived a full bisect, because two captures reused one stale dev server. Force a
fresh environment per capture, and treat "it reproduced" as worthless until you know the runs were
independent.

**Corollary — a diff of absolute values cannot see a broken relationship.** The one real regression of
that run was a collapsed visual hierarchy: every individual change was expected and under 4px, and
the ratio between two of them broke. Only an assertion *about the relationship* caught it. When a
sweep normalises values, ask what ratios the product depends on.

---

## § 6. Decide only what has a precedent

Pre-record the likely decisions **before** the run, each traced to a real one, in the plan. For
anything not on that list, the search is a fixed procedure, not a judgement call:

```bash
grep -n -i "<concept>" DECISIONS.md TODO.md .agents/rules/*.md
grep -rn -i "<concept>" archive/PLAN_sprint_*.md LESSONS_LEARNED.md
git log --oneline -S'<symbol>' -- <path>
ls ~/.claude/projects/*/memory/
```

Found → **apply its reasoning and cite it in the commit**. Nothing found → stop condition 1.

**A decision with no precedent is what the Tech Lead is for**, and inventing one overnight spends
their judgement on a fiction (`AGENTS.md §0` No Fabrication).

Two standing tie-breaks, both from real cases:
- **A shipped gate outranks the sweep.** When a locked scale and a live assertion disagree, the
  assertion encodes a real requirement and wins; the value stays a documented exception.
- **Prefer the reversible direction.** Leaving a value alone keeps a future fix open; forcing it onto
  a system closes one.

---

## § 7. External failures are not your failures, and not licence either

An outage in a third-party service (a registry, a runner pool) is not stop condition 3. But it is also
not permission to merge without green. Do the next independent task, retry periodically, and **hand
over what is blocked with its evidence** — the local verification you ran in its place, named
precisely, so the Tech Lead knows exactly what has and has not been checked.

Recognise the signature before spending three re-runs on it: identical failure text, a named external
host, a step that touches the network, and a failure that would hit every PR in the repo equally.

---

## § 8. The morning report

**Few words, plus the evidence.** The Tech Lead reads it on a phone before coffee
(`feedback_screenshots_in_chat_for_mobile_review`).

1. **A visual before/after comparison**, published as an artifact so it opens on a phone — not file
   paths, not a wall of images in chat.
2. **The numbers that closed**: starting measurement → ending measurement, and whether it reconciles.
3. **Every change large enough to read as a design decision, named individually**, with the ones no
   instrument covered marked as such.
4. **What went wrong and what it cost** — including defects in your own tooling, stated as findings
   rather than buried.
5. **What is owed**, and what was deliberately not done.

**Never report a gate as passed without saying which one ran.** A colour is not a result.

---

## § 9. Never unattended

`main` · a deploy to dev or prod · a dependency merge · a design decision · a rule or standard change
· the QA gate · anything the grant did not name.
