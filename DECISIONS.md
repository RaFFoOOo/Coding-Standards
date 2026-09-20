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
