---
name: todo-manager
description: Standardizes how the Agent reads, appends, marks, archives and sweeps entries in TODO.md.
---

# SKILL: todo-manager

## § 0. When to Use This Skill

Use this skill any time you need to:
- Add a new idea, backlog item, or future task to `TODO.md`
- Mark one or more TODO items as complete in-place
- Archive a fully-completed section out of `TODO.md`
- Audit `TODO.md` for items already delivered by past sprints
- **Sweep the whole file** at a sprint close-out or when it has stopped being readable (§ 7)

## § 1. Read-Before-Write Rule [MANDATORY]

**Always read `TODO.md` in full before any write.** Never append or edit blindly.
- Check for duplicate entries — do not add an item that already exists under a different heading.
- Note the current section structure so new items land in the correct `##` section.

## § 2. Appending a New Section or Item

**New standalone idea / backlog section:**
```markdown
## <Short imperative title>

<One-sentence description of the goal.>

- [ ] Sub-task or acceptance criterion
- [ ] Sub-task or acceptance criterion
```

Rules:
- Title must be an imperative phrase (e.g. `Add price to CatalogItem`, not `Price feature`).
- Every actionable item is a `- [ ]` checkbox. Non-actionable context goes in plain prose above the checklist.
- **[STRICT] A section MUST carry at least one `- [ ]`, even when the whole finding is one sentence.**
  §§ 3/4/6 are all checkbox-keyed, so a prose-only section is invisible to every lifecycle rule this
  skill has: it can never be marked, never be archived, and never appear in an audit. Measured
  2026-09-01: **51 of 167 sections had no checkbox**, and the skill could act on **7** — 4% of the
  file. A finding worth writing down is worth one checkbox.
- Do not add a `Commit:` line — that belongs in `PLAN.md`, not `TODO.md`.

**Adding a single item to an existing section:**
- Insert the new `- [ ]` line in the most relevant existing `##` section.
- Do not create a new section for a one-liner that fits an existing category.

## § 3. Marking Items Complete

Mark the checkbox in-place:
```markdown
- [x] Item that has been delivered
```

Do **not** delete completed lines immediately — leave them in place until the entire section is
done, then archive (§ 4). This preserves context during active sprints.

## § 4. Archiving Completed Sections

**No section with an open `- [ ]` is ever archivable.** That is the precondition on both tests
below — check it first, because a heading is a claim and an open item is evidence against it.

A section is archivable when it has **no open item** and **either** test passes:

- **(a) it has items and every one is `[x]`**, or
- **(b) it has no checkboxes at all and its heading declares the outcome** — `✅ RESOLVED`,
  `DELIVERED`, `SUPERSEDED`, `CLOSED`, `WON'T DO`.

Test (b) exists because test (a) alone could not fire. Measured 2026-09-01: **12 sections whose own
heading said `✅ RESOLVED`** were unarchivable under (a) — they were prose findings with no checkbox
to complete — and the oldest had been closed since **2026-08-13**. A rule that can only see checkboxes
cannot clean a file that is one-third prose.

**A resolved-looking heading over an open item is a contradiction, not an archive candidate.** The
heading says done and an item says open; exactly one is wrong. Resolve which, fix that half, and only
then re-test. **Seven sections were in that state on 2026-09-01** — which is why the no-open-item
precondition leads this section rather than trailing it.

**Two things the first real run of § 7 found about that test.**

1. **Most "contradictions" are honest partials — read before editing.** Nine sections matched on a
   resolution keyword plus an open item; **five were correct as written** — a heading saying what
   shipped, over items tracking what deliberately did not (*"the fix shipped, two follow-ups did
   not"*). Match on the keyword to *find* candidates, never to *classify* them.
2. **The `*Original entry, kept for the trail:*` block defeats this precondition by construction.**
   Four sections carried a resolution banner followed by the preserved original — whose checkboxes
   are still `- [ ]` because they are **quoted history, not open work**. The section is genuinely
   closed and permanently unarchivable, which is the same silent-no-op § 7 exists to end. When you
   resolve one, mark those items with their real outcome — `[x] **DONE (<sprint/task ref>)**` where the work
   happened, `[x] **MOOT — dissolved, not fixed**` where it did not — because *"we stopped needing
   this"* is an outcome and an unchecked box is not. Do not leave the trail's boxes open on the
   theory that they are only history: the precondition cannot tell the difference, and neither can
   the next reader.

Once a section passes:
1. Delete the entire section from `TODO.md`.
2. The section's history is preserved in git — no separate archive file is needed for TODO items.
3. Commit the deletion with message: `chore(todo): archive completed section "<section title>"`.

**Partial sections stay** — do not split one.

## § 5. Promotion Rule — TODO → PLAN.md Gate [MANDATORY]

**Never execute items directly from `TODO.md`.**

When picking up one or more TODO items for a sprint:
1. Remove them from `TODO.md` (or mark with a note `→ promoted to PLAN.md`).
2. Create a `PLAN.md` with the items fully decomposed into Acceptance Criteria,
   Technical Implementation steps, and Task Progress.
3. Present the `PLAN.md` to the user for approval before any execution begins.

This rule is absolute — it applies to features, chores, bugfixes, and spikes alike.

## § 6. Audit — Check TODO Against Delivered Sprints

Scan `TODO.md` for work that has already been implemented:
1. Cross-reference each `- [ ]` item **and each prose finding section** against recent git log and
   merged PRs. Do not scan only checkboxes — that is the blind spot § 2 and § 4 now guard against.
2. For each item confirmed delivered: mark `[x]` and note the PR reference in a comment
   (e.g. `- [x] Add barrel exports — delivered in #31`).
3. If the section is now archivable under **either** § 4 test, archive it.
4. Report a summary of what was found and cleaned up.

This is the *delivered-work* axis only. At a sprint close-out run the **full sweep (§ 7)**, of which
this is one pass — an audit alone has never been enough to keep the file readable.

## § 7. Full Sweep [use at sprint close-out, or when the file stops being readable]

**Measure first, and report the numbers.** A sweep that says "tidied up" and not *what it found* is
the reason this file drifts. Start here:

```bash
wc -l TODO.md
grep -c '^## ' TODO.md                                    # sections
grep -c '^\s*- \[ \]' TODO.md ; grep -c '^\s*- \[x\]' TODO.md   # open / done items
grep -cE "^## .*(RESOLVED|DONE|CLOSED|DELIVERED|SUPERSEDED|✅)" TODO.md
```

Then run all five passes **in this order. Archiving is LAST, and that is the whole point:** passes
1–4 each close open items, and § 4 refuses to archive any section that still has one. Archive first
and you delete nothing, then spend four passes making sections archivable with no pass left to
archive them.

| # | Pass | What it catches |
|---|---|---|
| 1 | **Delivered-but-unmarked** (§ 6) | Open items the git log shows as already shipped — mark them `[x]` |
| 2 | **Contradictions** | A heading claiming resolution over an open item; exactly one half is wrong. Fix that half |
| 3 | **Duplicate concepts** | The *same* finding filed twice under different titles, often weeks apart. Compare by **what the finding is about**, never by title similarity. Merge into one, keeping the better-evidenced wording |
| 4 | **Cross-artifact reconciliation** | Items a review, a sprint PLAN, or `DECISIONS.md` has since closed. Name the artifact that closed each one |
| 5 | **Archive** (§ 4) | Every section that now passes test (a) or (b). Usually the biggest single win, and most of it is invisible to § 6 alone |

**Rules that keep a sweep honest:**
- **Never mark an item delivered from its title.** Verify against the code or the PR that closed it —
  a plausible-sounding match is how a still-open finding gets archived and lost.
- **A sweep only deletes what something else records.** Git history holds archived sections (§ 4); a
  finding closed by a decision must name that decision *before* its section goes.
- **Report a before/after count.** "167 → N sections, 5 428 → N lines, X archived, Y reconciled" is
  the deliverable. Without it nobody can tell a sweep from a no-op.
- **Structural findings about `TODO.md` itself go to the skill, not the file.** If a pass keeps
  catching the same shape, the authoring rule in § 2 is what needs changing.
