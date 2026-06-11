---
name: recursive-review
description: Periodic, honest audit of the project — rules, skills, sprints, code, pipeline, planning artifacts, business direction. Surfaces drift, rule violations, redundancies, and strategic gaps. Produces a single PLAN_recursive_review_<date>.md deliverable.
---

# SKILL: recursive-review

> This workflow references gh CLI commands for GitHub operations. Substitute with your platform's equivalent GitHub tools where available.

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

## § 2. Inventory Phase [MANDATORY — delegate to Explore subagent]

Spawn an Explore subagent with the prompt template below. **Do not skip the grep targets** —
they encode lessons from prior reviews and prevent the audit from missing rule violations.

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
multiplier-over-error. **Note: line count is not the right gate for SCSS.**

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
"Out of Scope: SCSS audit. Verified: ls -la lc-webapp/src/app/**/*.scss | sort -k5 -n -r |
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
