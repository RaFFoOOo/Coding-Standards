# Architectural Decision Log

Per `AGENTS.md` §1 (Decision Recording): any deviation from an approved plan that adds
or removes a major dependency, library, or architectural pattern gets a one-paragraph
entry here, in the same PR. It is also the justification ledger required by
`sync-templates.md` Step 4c (Hub Completeness Validation) whenever a real rule/skill/
workflow concept is confirmed repo-local and permanently excluded from this repo's
canonical `.agents/` set.

Format:

```
## YYYY-MM-DD — <Title>
**Context:** …
**Decision:** …
**Consequences:** …
```

---

## 2026-09-20 — §3 Testing narrows from "all business logic" to what earns its upkeep

**Context:** §3 read *"Unit tests are mandatory for all business logic, covering Happy
Path, Edge Cases, and Null Inputs."* Applied literally in a real codebase it produced
test code at 114% of frontend production lines and 110% of backend. Over three months
of CI, frontend unit tests failed in 28 runs across 8 spec files and **not one fix
changed production code** — every failure was the test describing the old shape of a
component a walk still rendered correctly.

**Decision:** A test is mandatory for server-side rules, date/time/money logic,
database queries and migrations against a real database, and any regression of a
defect that shipped. Everything else gets no new test. An existing test outside that
scope stays only where a manual walk would not notice the break — a failure path, an
invisible effect, a security property, an accessible name or focus, or a
production-only branch.

**Consequences:** This reverses the hub's previous rule rather than extending it, so a
spoke that adopts it will find existing tests newly out of scope. Those are not deleted
on adoption: a change that breaks one gets the smallest fix that makes it pass, and
names it in the PR body as a prune candidate for the Tech Lead to approve.

## 2026-09-20 — §6 TODOs carry the concept, not a ticket id

**Context:** §6 required every `TODO` to reference a ticket or issue
(`TODO [Auth-123]: ...`). A sweep of a mature codebase found **40 dead pointers** —
sprint ids, review ids, paths to files that had moved — and 3 recorded recovery commits
that no longer resolved. Nothing fails when such a reference dies: no test asserts on a
comment, and the comment sits beside the code, so it reads as current.

**Decision:** A `TODO`, and every comment, states the concept in words and carries no
reference — no sprint or task ids, no ticket ids, no pointers to a decision log or
backlog, no commit hashes, no paths to other files. `TODO: paginate once a tenant
exceeds 500 orders`. Why a change was made and what was measured belong in this log or
the PR body, where `git blame` leads anyone who needs it.

**Consequences:** Reverses the hub's previous rule. Adopting spokes must sweep existing
`TODO [ID]` comments and rewrite them to state what is missing and when it matters.

## 2026-09-20 — The hub's wording budget is density, not file size

**Context:** `AGENTS.md` loads in every session in every repo that adopts it, so its
length is a real recurring cost and the instinct is to cap its bytes. This sync tested
that: the file was rewritten terse and a 30 000 B ceiling was set from the measured
compression of one section. The rewrite hit 185 bytes per instruction, down from 247,
and still landed at 34 316 B — because it gained 36 instructions. Closing the remaining
gap would have meant deleting rules, not prose.

**Decision:** The budget is per rule, not per file. Every rule is one imperative
sentence plus at most one concrete example; no `Why:` / `Measured:` / evidence
sub-bullets; no bullet over 400 characters; a rule with several distinct instructions
keeps them as one-line sub-bullets. The checkable targets are **no bullet over 400
characters** and **≤ 200 bytes per instruction**.

**Consequences:** A byte ceiling penalises adopting a rule; a density ceiling penalises
verbosity, which is the actual goal. Evidence for a rule — the incident, the
measurement, the sprint that produced it — lives in this log, in a lessons file, or in
the PR body, never in `AGENTS.md`.

## 2026-09-20 — UAT cases live in `docs/uat/`, never in a per-sprint test plan

**Context:** The `test-browser` workflow told the agent to write a
`TEST_PLAN_sprint_[N].md` beside `PLAN.md` for each run. In practice the acceptance
cases also accumulate in a persisted, per-feature directory, and the two lists drift:
the sprint file is written from the diff, the durable one from the product, and only
the durable one has a coverage guard watching it.

**Decision:** `docs/uat/` is the plan. A run enumerates cases from it through a listing
script that exits non-zero on a heading it cannot parse, so a malformed case surfaces
instead of being silently dropped. Never write a per-sprint test-plan file. A failure is
recorded in that case's own file, so the next run sees it.

**Consequences:** Reverses the workflow's previous instruction. The walk also gained a
mandatory UX review of every surface it touched, with a content-fingerprint checkpoint
so an unchanged surface is never re-reviewed, and a `⛔ BLOCKED` result that is reported
as its own value and never folded into a pass rate.

## 2026-09-20 — The hub adopts split stack rules over monoliths (pending)

**Context:** The hub carries 5 stack rule files where its spoke carries 12.
`stack-angular.md` is 68 225 B across 17 sections here against 14 462 B there, because
the spoke split testing, CSS, i18n, navigation and shared-UI into their own files; seven
of the spoke's rule files have no hub counterpart. The hub's monolith loads in full
whenever any matching file is read.

**Decision:** The hub adopts the split. This is the same argument that drove the
`AGENTS.md` rewrite — a rule nobody can scan is a rule nobody applies — and a
path-scoped rule should load only for the files it governs.

**Consequences:** Not executed in this PR. It retires three hub files and adds seven,
which is a larger change than the `AGENTS.md` rewrite and needs its own branch and
review. Recorded here so the next sync acts on the decision rather than re-deriving it.
