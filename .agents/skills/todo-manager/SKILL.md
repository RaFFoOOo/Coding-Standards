---
name: todo-manager
description: Standardizes how the Agent reads, appends, marks, and archives entries in TODO.md.
---

# SKILL: todo-manager

## § 0. When to Use This Skill

Use this skill any time you need to:
- Add a new idea, backlog item, or future task to `TODO.md`
- Mark one or more TODO items as complete in-place
- Archive a fully-completed section out of `TODO.md`
- Audit `TODO.md` for items already delivered by past sprints

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

When every item in a `##` section is `[x]`:
1. Delete the entire section from `TODO.md`.
2. The section's history is preserved in git — no separate archive file is needed for TODO items.
3. Commit the deletion with message: `chore(todo): archive completed section "<section title>"`.

When a section is **partially** complete, leave it in `TODO.md` — do not split it.

## § 5. Promotion Rule — TODO → PLAN.md Gate [MANDATORY]

**Never execute items directly from `TODO.md`.**

When picking up one or more TODO items for a sprint:
1. Remove them from `TODO.md` (or mark with a note `→ promoted to PLAN.md`).
2. Create a `PLAN.md` with the items fully decomposed into Acceptance Criteria,
   Technical Implementation steps, and Task Progress.
3. Present the `PLAN.md` to the user for approval before any execution begins.

This rule is absolute — it applies to features, chores, bugfixes, and spikes alike.

## § 6. Audit — Check TODO Against Delivered Sprints

At the end of a sprint (or when explicitly asked), scan `TODO.md` for items that have
already been implemented:
1. Cross-reference each `- [ ]` item against recent git log and merged PRs.
2. For each item confirmed delivered: mark `[x]` and note the PR reference in a comment
   (e.g. `- [x] Add barrel exports — delivered in #31`).
3. If the entire section is now `[x]`, archive it per § 4.
4. Report a summary of what was found and cleaned up.
