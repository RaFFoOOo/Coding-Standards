---
name: todo-manager
description: Standardizes how the Agent reads, appends, marks, closes and sweeps entries in the backlog/ files.
---

# SKILL: todo-manager

The backlog is **`backlog/`** — one file per area, indexed by `backlog/README.md`, which also defines
the markers (⚖ needs a decision · ⏳ trigger-gated · 🔍 unverified) and the Parked/Rejected list. It
replaced a single `TODO.md`; the skill keeps its name so `/todo-manager` still works.

## § 0. When to Use This Skill

- Add an idea, follow-up or finding to the backlog
- Mark items complete
- Close an entry whose work is done or retired
- Audit the backlog against delivered work and recorded decisions
- **Sweep every file** at a sprint close-out (§ 7)

## § 1. Read Before Write [MANDATORY]

1. Read `backlog/README.md` and **the target file** in full. Choose the file by what the item
   changes (the README's table), not by where it was found.
2. **Grep all of `backlog/` for the concept** before adding — a duplicate in another file is still a
   duplicate:
   ```bash
   grep -rn -i "<concept>" backlog/
   ```
3. Grep `DECISIONS.md` and its archive too. A recorded decision may already answer, retire or forbid
   the item.

## § 2. Adding an Entry

```markdown
## <Imperative title>

⚖ / ⏳ trigger: … / 🔍 …            ← only the markers that apply

<1–3 sentences: the finding, the number that makes it real, the file:line.>

- [ ] <actionable item>

**Verified YYYY-MM-DD:** <the command or file:line showing it is still open>
```

- **Title:** an imperative phrase (`Add price to CatalogItem`, not `Price feature`).
- **[STRICT] At least one `- [ ]`**, even for a one-sentence finding. §§ 3/4/6 are checkbox-keyed, so
  a prose-only entry is invisible to every lifecycle rule. Measured once: 51 of 167 sections had no
  checkbox, and the skill could act on 4 % of the file.
- **[STRICT] A `Verified` line.** An entry with no evidence is a guess (`AGENTS.md §0` *Measured
  Recommendations*). When the evidence cannot be obtained cheaply, add 🔍 and say exactly what is
  unverified. Measured at one split: **65 of 149** entries turned out to be shipped, retired or
  superseded.
- **[STRICT] "Logged to the backlog" means the entry is in the same commit.** A decision, PLAN or PR
  claiming an item was logged, with no entry behind it, loses the finding silently — one such claim
  hid a guard defect for 19 days until every claim was checked.
- One item lives in one file. No `Commit:` lines — those belong in a PLAN.

## § 3. Marking Items Complete

Mark in place with the PR that closed it — `- [x] Add barrel exports — #31`. Leave the entry until
every item is done; that keeps context during a sprint.

## § 4. Closing an Entry

**No entry with an open `- [ ]` is ever closed.** Check that first: a heading is a claim, an open
item is evidence against it.

An entry closes when it has no open item **and** either (a) every item is `[x]`, or (b) it has no
checkboxes and its heading declares the outcome (`RESOLVED`, `SUPERSEDED`, `WON'T DO`, …). Test (b)
exists because (a) alone cannot fire on a prose finding — 12 entries whose own heading said
`RESOLVED` were unclosable without it, the oldest closed for over two months.

- **A resolved-looking heading over an open item is a contradiction.** Exactly one half is wrong; fix
  that half, then re-test. Most are honest partials — a heading saying what shipped over items
  tracking what deliberately did not — so match on the keyword to *find* candidates, never to
  *classify* them.
- **Quoted history defeats the precondition.** Checkboxes preserved under a resolution banner stay
  `- [ ]` forever, because they are history rather than open work. Give them their real outcome:
  `[x] **DONE**` where the work happened, `[x] **MOOT — dissolved, not fixed**` where it did not.
  "We stopped needing this" is an outcome; an unchecked box is not.
- **Closing = deleting the entry.** Git keeps it. When a *decision* retired the item rather than
  work, name that decision in the commit or PR before the entry goes.
- Commit: `chore(backlog): close "<title>"`.

## § 5. Promotion Gate — Backlog → PLAN [MANDATORY]

**Never execute items directly from the backlog.**

1. Remove the entry, or mark it `→ promoted to PLAN_sprint_<N> T<n>`.
2. Decompose it in the PLAN into Acceptance Criteria, implementation steps and progress.
3. Present the PLAN for approval before any execution.

Absolute — features, chores, bugfixes and spikes alike.

## § 6. Audit — Two Axes

1. **Delivered.** Check each open item **and each prose entry** against the code and merged PRs —
   never against its own title. Mark confirmed items `[x]` with the PR.
2. **[STRICT] Decided.** Grep each surviving item against `DECISIONS.md` and its archive, and read
   every hit. A locked decision retires an item without anyone touching the entry. Measured at one
   split: **twelve** items were closed by a recorded decision, several with nothing in the code to
   show it — among them a migration contradicting a locked decision, and a redesign listed three
   weeks after the feature it redesigned had been retired.
3. Close whatever now passes § 4, and report what was found.

## § 7. Full Sweep [every sprint close-out]

**Measure first, and report the numbers** — a sweep without numbers is indistinguishable from a
no-op:

```bash
grep -c '^## ' backlog/*.md                                   # entries per file
grep -h '^\s*- \[ \]' backlog/*.md | wc -l                    # open items
grep -h '^\s*- \[x\]' backlog/*.md | wc -l                    # done items
for f in backlog/[a-z]*.md; do                                # entries missing evidence
  echo "$f $(grep -c '^## ' "$f") entries / $(grep -c '^\*\*Verified' "$f") verified"
done
```

Then the passes, **in this order — closing is last**, because passes 1–4 are what make entries
closable:

| # | Pass | Catches |
|---|---|---|
| 1 | **Delivered but unmarked** (§ 6.1) | open items the code shows as shipped |
| 2 | **Contradictions** | a resolved heading over an open item |
| 3 | **Duplicates** | the same finding in two entries or two files — compare what it is *about*, never titles; keep the better-evidenced wording |
| 4 | **Decisions and artifacts** (§ 6.2) | items a decision, a PLAN or a review has since closed — name the artifact |
| 5 | **Close** (§ 4) | every entry that now passes |

- **Never close an item from its title.** Verify against the code or the PR.
- **A sweep only deletes what something else records** — git for closed work, a named decision for
  retired work.
- **Report before/after:** entries, open items, closed, reconciled.
- **Refresh stale `Verified` dates** you re-checked; add 🔍 to any you could not.
- **A structural finding about the backlog goes into this skill**, not into a backlog file.
