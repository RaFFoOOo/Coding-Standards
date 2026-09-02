---
name: recursive-review
description: Periodic, honest audit of the project — rules, skills, sprints, code, pipeline, planning artifacts, business direction. Surfaces drift, rule violations, redundancies, and strategic gaps. Produces a single PLAN_recursive_review_<date>.md deliverable.
---

# SKILL: recursive-review

> **Claude Code:** This skill references `gh` CLI commands for GitHub operations. In Claude
> Code environments with MCP GitHub tools, substitute all `gh` commands with the equivalent
> MCP tools (e.g., `mcp__github__list_pull_requests` for `gh pr list`).

> **Cron note:** This skill is invoked manually (`/recursive-review` or `/recursive-review YYYY-MM-DD`).
> If you want it to fire automatically on a schedule, wire `CronCreate` from a separate
> session — do **not** put cron logic inside this skill, because the skill is the *workflow*,
> not the *trigger*.

Execute this skill to produce a candid, evidence-based assessment of the project. The
deliverable is a single `PLAN_recursive_review_<YYYY_MM_DD>.md` file at the repo root,
followed by a PR.

## § 0. When to Invoke

- **Recommended cadence:** monthly, OR after every 2 sprints close — whichever is sooner.
- **Mandatory:** before any major release / pilot launch / public open-source switch.
- **Optional:** when the user asks "what's wrong with this project?", "review the
  architecture", or similar open-ended health questions.

## § 1. Pre-flight [MANDATORY]

1. Read these in full — never skim:
   - `CLAUDE.md`, `AGENTS.md`
   - Every `.md` at the repo root (PLAN_*, TODO.md, EPIC_*, README.md)
   - `.agents/rules/*.md`
   - The most recent `archive/PLAN_recursive_review_*.md` (if any) — what was promised, was
     it delivered? **Carry forward unresolved items as evidence in the new review.**
2. Run `git log --oneline -50` and identify:
   - The last 3 sprints' closing PRs
   - Recent bugfix clusters (3+ PRs to the same area in <72h is a smell — flag it)
3. Run `gh pr list --state open` — note any open PRs that may invalidate the audit.
4. Read the active sprint plan called out in `CLAUDE.md`.

## § 2. Inventory Phase [MANDATORY — the grep targets, not the delegation]

Run the inventory below. **Delegate it to an Explore subagent where agent spawning is enabled**
(it keeps large dumps out of the main thread); otherwise run the same targets inline with
`grep`/`wc`/`git`. **The mandate is the target list, not the mechanism** — some harnesses refuse to
spawn agents unless the user asks, and a skill whose first mandatory step cannot execute reads as a
skipped step rather than an adapted one. Whichever way it runs, say which in the deliverable.

**Do not skip the grep targets** — they encode lessons from prior reviews and prevent the audit from
missing rule violations.

```
You are auditing <repo-name> for a recursive review. Working directory: <abs-path>.
Report findings in the EXACT order below. ≤ 200 words per section. No code changes.

### 1. Frontend service inventory
For every IFooService interface in <frontend-src>: list the interface path, the Mock*Service
sibling path, whether an Http*Service exists, and where it's bound in app.providers.ts /
app.config.ts. Flag every interface still showing TODO [Sprint-N] in its provideByMode call.

### 2. Backend endpoint inventory
List every [Function(...)] HTTP endpoint in <backend-src>. For each: name, route, methods,
auth level. Cross-reference against the active sprint plan's Feature 1 acceptance criteria —
report which endpoints are NOT yet implemented.

### 3. Files exceeding the 200-line threshold (AGENTS.md §2)
wc -l on every .ts and .cs under <src-dirs>. Skip *.spec.ts, generated, and migrations.
Files > 200 lines, sorted desc, top 15. Note: 200-line rule applies to LOGIC files only —
.html and .scss are governed by framework-specific budgets (see §4).

### 4. Framework-specific size budgets [DO NOT SKIP]
Read <frontend>/angular.json. For every component .scss whose byte size exceeds the
production `anyComponentStyle.maximumError` setting, report file path + size + budget +
multiplier-over-error. **line count is not the right gate for SCSS.**

### 5. STRICT-rule grep targets [MANDATORY]
For each STRICT rule in .agents/rules/*.md, grep the codebase for the explicit forbidden
pattern. Report any hits with file:line. Minimum patterns to grep:
- `JwtSecurityTokenHandler\(`           (forbidden by stack-dotnet-core.md §8.2 A07)
- `\.Result;` or `\.Wait\(\)`           (forbidden by stack-dotnet-core.md §5)
- `\bany\b` outside type guards         (forbidden by stack-angular.md §1)
- `!important;`                         (forbidden by stack-angular.md §4)
- `providedIn:\s*'root'` on Mock\* class (forbidden by stack-angular.md §2a)
- `\.subscribe\(` without `takeUntil`   (forbidden by stack-angular.md §6)
- Hardcoded SAS / connection strings    (forbidden by A02)
Add patterns from any STRICT rule added since the prior review.

### 6. TODO/FIXME/HACK in code
grep -rn "TODO\|FIXME\|HACK\|XXX" <src> excluding tests/generated. Report up to 20 with
file:line, prioritising those mentioning "Sprint", "deferred", or "later".

### 7. Doc/runbook drift
For docs/INFRA.md and README.md, quote 1-2 lines for any reference to:
- Resources/services that no longer exist
- Patterns superseded by recent PRs (cross-reference last 30 days of git log)
- Config keys / secrets not actually used by code

### 8. Redundant / orphaned planning artifacts at repo root
List every *.md at root (NOT archive/). For each: last commit date; whether referenced by
CLAUDE.md or AGENTS.md; whether it's a closed sprint / lessons / QA report that should be
archived.

### 9. Pipeline health
For every workflow in .github/workflows/, check: does any deploy workflow have a post-deploy
smoke step? If no, flag as 🔴 (5 sequential bugfix PRs all shipped
"successful" CI without a smoke gate).

Also grep every workflow for `pull_request:` triggers scoped with `branches:\s*\[main\]` (or
quoted). This filters the PR's *target* branch, not its source — a workflow meant to validate every
PR in a multi-level branch hierarchy (sprint → task, per `AGENTS.md §8`) silently skips every
task-branch PR with no error visible anywhere (a skipped check shows no red ❌, it just shows
nothing). Flag every hit as 🔴 unless the workflow's own comments document the restriction as
deliberate (e.g. a hygiene guard that only needs to fire at the main-merge boundary). *(Added
2026-07-18 after `ci-angular.yml` carried exactly this gap, undetected by the 2026-07-16 review's
own pass, only caught reactively by a later sprint's QA gate.)*

### 10. Anything else flagged by the rules
Up to 5 violations of any rule in .agents/rules/. Cite rule + file:line evidence.

Be specific with file paths and line numbers. Flag uncertainty. No code changes.
```

When the subagent reports back, **verify any claim that disputes a STRICT rule** by reading
the cited file directly. The subagent may misattribute or miss adjacent context.

## § 3. Analysis Phase [MANDATORY]

For every finding from §2, assign:

- **Severity:** 🔴 must-fix-before-pilot · 🟡 fix-this-quarter · 🟢 nice-to-have
- **Evidence:** file path + line number + a 1-line quote where possible
- **Proposed fix:** specific, actionable; not "review and improve"
- **Target sprint:** which existing or future sprint absorbs this

**Mechanical verification rule:** if you intend to mark a finding "Out
of Scope" or "deferred", the rationale MUST include the command (with output) that
mechanically proves the deferral is safe. Example:

```
"Out of Scope: SCSS audit. Verified: ls -la <spa-app>/src/app/**/*.scss | sort -k5 -n -r |
head -3 → top 3 files at 13.0/10.9/5.5 KB; production anyComponentStyle error budget = 8 KB
→ FAIL. Promote to in-scope."
```

If you can't run the verification command, the finding is in scope.

## § 4. Self-Criticism Phase [MANDATORY]

The retrospective MUST contain a `## What I (the agent) should have done differently`
section with at least 3 specific items. Each item:

- Names a specific PR or commit
- States the wrong call I made
- States what would have been right
- States the lesson going forward

This is the highest-leverage section because the user cannot see my reasoning, only my
outputs. Without explicit self-criticism, I appear infallible — which I am not, and the
user knows it. **Refusing to self-criticise breaks the trust the rest of the review needs.**

If you genuinely cannot identify 3 mistakes from the period under review, double-check —
the period almost certainly contains them. If still empty after a second pass, write
"No agent mistakes identified this period" with a one-paragraph justification, and expect
the user to push back.

## § 5. Synthesis — the PLAN file

Write the deliverable to `PLAN_recursive_review_<YYYY_MM_DD>.md` (or, for the very first
review, `PLAN_recursive_review.md` without date). Use this exact, proven section order:

1. Reading guide (one paragraph)
2. **Executive summary** — 60-second read; top 5 takeaways
3. **What's working** — honest praise, evidence-based
4. **What's not working** — severity-tagged critique
5. **What I (the agent) should have done differently** — §4 output
6. **New strategic ideas / business cases** — 5-10 items, each with cost + target sprint
7. **Recommendations for the agent system itself** — meta; permission to prune
8. **Proposed roadmap** — priority-ordered table of every actionable finding + idea
9. **Open questions for the Tech Lead** — 3-5 questions that block downstream planning
10. **Appendix: source evidence** — every PR, file, command cited

Keep the file under 500 lines. The Tech Lead should be able to read it in 15 minutes.

## § 6. PR + follow-up

1. Branch: `chore/recursive-review-<YYYY-MM-DD>` from `main`.
2. Commit: single commit, conventional `docs(plan): recursive review — <date>`.
3. PR title: `docs(plan): recursive review — <month YYYY>`.
4. PR body MUST include:
   - **Top 3 must-fix findings** with file:line evidence
   - **Open questions** copied verbatim from §9 of the doc
   - **Explicit ownership block** copied from §5 of the doc (the agent self-criticism)
5. Do NOT implement any of the findings in the same PR. The deliverable is the doc only.
   Findings get tracked into existing or new sprint plans as separate PRs.
6. **[MANDATORY] Translate every Tech-Lead decision into a `TODO.md` entry in the same resolution
   pass — never leave it as review-doc prose alone.** The Tech Lead typically answers §9 as PR
   review comments on the open PR, not by editing the doc directly — resolving that feedback (via
   `/resolve-pr` or equivalent) is the moment every resulting "approved" or "decided" item MUST get
   a real `TODO.md` entry (or sprint task, if concrete enough), created in the same PR that records
   the resolution. A decision that exists only inside a review PR's comment thread or the doc's §9b
   prose is functionally identical to an unapproved idea — it has no owner and decays the same way.
   *(Codified 2026-07-18 after `PLAN_recursive_review_2026-07-16.md` §9b item 3 — approved-per-
   no-objection — sat with zero downstream tracking for a full review cycle; see
   `PLAN_recursive_review_2026-07-18.md` §4.1/§5.3 for the full account.)*

## § 7. Carry-forward Rule

The next time this skill runs, the prior `PLAN_recursive_review_*.md` becomes mandatory
input (§1.1). Compare:

- Items in the previous roadmap that were NOT delivered → carry forward with a date stamp,
  flag if 2+ reviews have failed to deliver them
- Open questions that were NOT answered → re-pose, flag the count of unanswered cycles
- Self-criticism items → did I repeat the same mistake? Flag explicitly

This is the recursive part of the recursive review.

## § 8. Anti-patterns

- **Generic advice.** Every finding must be tied to a file path, line, or PR number.
  "Improve test coverage" is not a finding; "`<YourApp>.IntegrationTests` does not test
  the `PATCH /v1/requests/{id}/status` endpoint" is.
- **Padding.** A 1000-line review is unreadable. The Tech Lead needs to make decisions, not
  read prose.
- **Soft critique.** Per `AGENTS.md §0` Honesty over Compliance, do not soften findings to
  preserve a polite tone. The user explicitly asked for honest review; deliver it.
- **Skipping §4.** This is the temptation that kills the skill's value. Force at least 3
  agent-side mistakes.
- **Mixing review with execution.** This skill produces a doc + PR ONLY. Do not start
  fixing findings inline; that's the next sprint's job.
