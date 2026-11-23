---
paths:
  - "backlog/**"
  - "PLAN_*.md"
---

# Backlog — work that is not in a sprint yet

Every project keeps its backlog in `backlog/`, one file per area, never a single `TODO.md`. Each entry
carries a category and a priority from closed sets, and a `Verified` line, so a sprint is scoped from
the backlog by measurement instead of by whichever entry reads best. The project's
`backlog/README.md` lists its own files and counts; this rule is the format.

## Files — pick by what the item changes

| File | Holds | Usually decided by |
|---|---|---|
| `frontend.md` | defects and refactors in `{webapp}` code | the Agent, on evidence |
| `backend.md` | defects, refactors, trigger-gated work in `{services}` | the Agent, on evidence |
| `testing.md` | suites, fixtures, walk coverage | the Agent, on evidence |
| `infra.md` | CI/CD, deploys, security, provisioning, operator data | the Agent + an operator |
| `ux.md` | usability, accessibility, design questions | the Tech Lead |
| `product.md` | new capabilities, legal, integrations | the Tech Lead |
| `directives.md` | rules, skills, docs | the Agent, reviewed |

A project adds a file only when it has an item for it. One item lives in one file.

## Markers

| Marker | Meaning |
|---|---|
| ⚖ | needs a Tech-Lead decision before it can be scheduled |
| ⏳ | trigger-gated — do not schedule until the named trigger fires |
| 🔍 | the evidence is old or needs a render / live run to confirm — a candidate for `verify` |

## Category — what kind of work it is

Both fields are **closed sets**. A free-text label is one nobody can filter on.

| Value | Means |
|---|---|
| `bug` | Shipped behaviour is wrong — against its own spec, a rule, or what the copy promises |
| `change-request` | Shipped behaviour is correct but should be different: copy, layout, a flow |
| `feature` | A capability that does not exist |
| `debt` | Refactor, test, fixture or dependency work with no user-visible change |
| `infra` | CI/CD, deploys, provisioning, security, operator-owned data |
| `process` | A rule, a skill or a project doc |
| `decision` | ⚖ — nothing can be built until the Tech Lead decides |

## Priority — keyed to evidence, not to feeling

| Value | Means |
|---|---|
| `critical` | A user is blocked, data is wrong, or a gate can report green on untested code |
| `high` | A user-visible defect, or a flow that costs repeated work; a pilot user would hit it |
| `medium` | Quality or debt with a measured cost, no user-visible symptom today |
| `low` | Opportunistic, or small enough that it only travels with a file someone is already in |

- **A ⏳ entry carries the priority it will have WHEN its trigger fires.** The marker decides
  scheduling, not the number.
- **A priority is a claim about a moment** (`AGENTS.md §0`), re-read at the sweep. A `critical` still
  open two sprints later is either wrong, or was never critical.

## Entry shape

```markdown
## <Imperative title>

⚖ / ⏳ trigger: … / 🔍 …            ← only the markers that apply
**Category:** bug · **Priority:** high

<1–3 sentences: the finding, the number that makes it real, the file:line.>

- [ ] <actionable item>

**Verified <yyyy-mm-dd>:** <the command or file:line showing it is still open>
```

The `Category` / `Priority` line goes **last** in the marker block, so a wrapped marker sentence stays
whole. A backlog item with no evidence is a guess: if the evidence cannot be obtained cheaply, add 🔍
and say what is unverified.

## Rules

- **Add an entry in the shape above** after grepping `backlog/`, `DECISIONS.md` and its archive;
  `build` marks items with the PR that ships them; `close` runs the sweep.
- **Never execute from here.** Promote to a sprint PLAN first (`plan` step 4), and mark the entry
  `→ promoted to PLAN_sprint_<N> T<n>` in the same commit.
- **One home per item.** Grep all of `backlog/` before adding — a duplicate in another file is still a
  duplicate.
- **Moving items into the backlog re-checks them.** Whatever no longer holds against the code or
  `DECISIONS.md` is deleted, not relocated; a decision can retire an item without anyone touching it.
- **Check:** `scripts/ci/generic/check-backlog-taxonomy.sh` fails on an entry without one valid
  category and priority pair, or with the pair in the wrong place.
