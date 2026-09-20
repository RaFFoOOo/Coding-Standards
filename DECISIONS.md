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

## 2026-09-20 — A sync ledger asserts only its own repo's state

**Context:** `Step 6a` appended the *same* `fileDigests` map — every participant's
column — to every participant's ledger, and `Step 3b.2` then selected the single
latest-dated entry across all ledgers as the baseline for everyone. The entry is staged
before its PR merges, so an abandoned PR leaves every *other* ledger asserting a state
that repo never reached, and the next run consumes that fiction as its baseline.

Found live: two ledgers each carry a `2026-09-04` entry recording digests for a third
participant whose own ledger stops at `2026-07-16` and whose sync PR is still open. Its
`AGENTS.md` has not changed since its initialization commit. Every concept read as
"changed in that repo" when nothing there had moved.

**Decision:** An entry's `fileDigests` carries one column — the repo whose ledger it is.
`Step 3b` takes each participant's baseline from its own ledger, and cross-checks: if
repo A's entry names repo B on a date B's ledger does not have, that sync never landed
for B, the foreign column is discarded and the user is told. A run scoped to a subset of
concepts records digests only for the ones it actually resolved.

**Consequences:** Ledger and content now share a fate — both live in the same PR, so an
abandoned PR leaves no stale claim anywhere. Verified against the live ledgers: the new
cross-check flags exactly the two poisoned entries and nothing else.

## 2026-09-20 — The backlog is a directory, not a single file

**Context:** `todo-manager` governed one `TODO.md`. In a mature project that file reached
5 428 lines and 167 sections, a third of it prose with no checkbox — and §§ 3/4/6 are all
checkbox-keyed, so the mandated sweep ran and was structurally blind to 96 % of it.

**Decision:** The backlog is `backlog/` — one file per area, indexed by `backlog/README.md`,
which also defines the markers (⚖ needs a decision · ⏳ trigger-gated · 🔍 unverified) and
the Parked/Rejected list. Every entry carries at least one `- [ ]` and a `Verified` line;
an entry with no evidence is a guess.

**Consequences:** `TODO.md` is swept out of all nine hub files in the same commit — a rename
adopted in one file leaves two conventions, which is worse than either. The skill keeps its
name so `/todo-manager` still resolves.

## 2026-09-20 — The lessons gate asserts a heading, and the lesson must reach a rule

**Context:** `run-qa`'s sprint-close check tested whether `LESSONS_LEARNED.md`'s last commit
date fell inside the sprint's range. That passes whenever *any* recent commit touched the
file — including the **previous** sprint's entry, which is how one gate went green with no
entry for its own sprint present. A shallow clone defeats it a second way: every
`git log -1 -- <path>` returns the graft commit, so every file reads as modified today.

**Decision:** Assert the sprint's own heading exists — `grep -qE "^#{1,3} .*Sprint <N>\b"`.
And gate the half that actually gets skipped: before `STATUS: PASS`, name the file and
section where this sprint's lesson landed as a rule, or say explicitly why no rule change
was needed.

**Consequences:** Two measurements motivate the second gate — of 10 lessons across a
20-sprint span, 4 had never become a rule; of 27 entries moved at an archive rotation, 7
named no rule and 1 named only an agent's local memory, 26 %. A lesson that exists only in
`LESSONS_LEARNED.md` is enforced by nothing: no bootstrap step reads that file.

## 2026-09-20 — Both logs are measured every sprint, rotated only on threshold

**Context:** `DECISIONS.md` and `LESSONS_LEARNED.md` grow every sprint and neither has a
natural end. One project's rotation took its lessons file from 158 797 B to 41 155 B, and
eight days later it was back to 61 289 B with no trigger saying when to do it again. Its
`DECISIONS.md` meanwhile reached 302 951 B — larger than its own archive, and read in full
at every bootstrap.

**Decision:** Measure both at the sprint close-out, in the same step that archives the PLAN
and QA report, and rotate whichever is over its threshold. Rotate, never truncate: the
recent epoch stays in the live file, everything earlier moves verbatim to the archive, and
an index at the foot of the live file names what each archived entry became.

**Consequences:** Rejected the simpler rule of rotating both every sprint. `DECISIONS.md` is
read at every full bootstrap precisely because old decisions still govern; a fixed cadence
would push governing decisions behind an index and make the bootstrap worse, while the
index-building judgment — which is what reveals the entries that became nothing — would run
every sprint for a few KB of content.

## 2026-09-20 — A workaround is retired only with evidence it is obsolete everywhere

**Context:** The spoke's `agent-workarounds.md` dropped the broken-stdout-pipe entry when it
reorganised the file. The hub took the reorganisation.

**Decision:** The entry stays, re-filed under *Processes and shells*. A spoke not hitting a
platform trap is evidence about that spoke, not about every repo the hub serves. Per the
sync workflow's deletion branch, a concept is removed from the hub only as a confirmed
global retirement.

## 2026-09-20 — Stack rules split mechanically; content reconciliation is a separate job

**Context:** The hub carried 3 stack rule files against its spoke's 10. `stack-angular.md` was
68 225 B across 17 sections and loaded in full whenever any `.ts`, `.html` or `.scss` file was
read. The decision to adopt the split was already recorded; this is how it was executed.

**Decision:** Split **mechanically** — cut each monolith at its own `## ` section boundaries into
the target files, changing no content. Verified by invariant: all 26 section bodies are
byte-identical before and after. `stack-github-actions.md` stays one file, as it is in both repos.

**Why not a content merge with the spoke's versions.** The topics map cleanly — 16 of 17 hub
sections have a spoke counterpart — but the prose diverged almost completely, so reconciling would
mean reading ~120 KB and judging line by line, with silently dropping a real rule as the failure
mode. Splitting first delivers the decided benefit at zero risk of loss and leaves reconciliation
as per-file units small enough to review. An exact-string diff suggested 149 of 160 directives were
hub-only; sampling showed 9 of 12 of those concepts *do* exist in the spoke, so that number measured
wording, not coverage, and was not used to justify anything.

**Consequences:** 9 stack files, largest Angular file 21 303 B (from 68 225). Section numbers are
kept as stable identifiers, so a file now legitimately starts at `## 7`. Twelve sections changed
file, and every cross-reference was repointed and verified to resolve. `stack-css.md` is **not**
created — the hub has no CSS content to put in it; it arrives when the spoke's version is reconciled.

## 2026-09-20 — The hygiene guards job discovers its guards instead of listing them

**Context:** The spoke's `validate-archive.yml` runs each `scripts/ci/*.sh` guard as its own
hardcoded step — about 20 of them. Adopting it into the hub unchanged would have fanned out a
workflow invoking 18 scripts that only one participant ships. Measured: the spoke has 20 guards,
the hub 0, the third participant 1, and that participant has
`DISABLE_PIPELINES_FOR_TEMPLATE=false`, so the job would have run there and failed 18 steps with
exit 127. The spoke's own comment names this failure and relies on the template flag to avoid it —
a defence the third participant does not have.

**Decision:** The job discovers `scripts/ci/*.sh` and runs what it finds, grouping output per guard
and failing with the names of those that failed. `check-schema-drift.sh` is excluded by name: it is
the one guard needing the .NET SDK, so it stays in the job where that toolchain exists.

**Consequences:** The file is portable — a repo reuses it unchanged and runs exactly the guards it
ships, including none. It also removes a second inventory that drifts from the first: a new guard
previously ran nowhere until someone added a step, and a deleted one failed with exit 127. This is
the same principle as deriving the guard count rather than writing it down. Verified by running the
harness against fixtures: empty repo exits 0, a failing guard exits 1 and names itself, and the
excluded guard is skipped even when it would fail.
