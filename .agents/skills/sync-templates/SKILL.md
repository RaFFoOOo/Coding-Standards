---
name: sync-templates
description: Merge the shared standards (AGENTS.md, the rules and skills in .agents/) between a project and the standards hub, in either direction, with a three-way merge that keeps both sides' changes.
---

# sync-templates

Numbered steps; run them in order. The work is done by `scripts/standards/sync.sh`; this checklist
is what the script cannot decide.

## How the sync works
- **The hub** is the repository holding `.agents/standards-hub`. Every other repository is a
  project. A sync always runs between the hub and one project.
- **What is shared** is what `.agents/standards-manifest.txt` lists. Anything else is the
  repository's own, and the sync never reads or writes it.
- **The common ancestor** of each file is its copy at the hub commit named in the project's
  `.agents/standards-version`. A file changed on one side is taken from that side. A file changed on
  both sides is merged, and overlapping edits are left as conflict markers. A project without the
  marker is syncing for the first time, so every difference is a conflict.
- **Nothing that names a project reaches the hub.** Merging into the hub, the script checks every
  result against the project's `scripts/standards/project-terms.txt` and writes nothing on a hit.
  Shared files name a project only through placeholders (`{webapp}`, `{services}`, …), and each
  project maps them to its values in its own agent instructions file.
- **Layout:** the files live in `.agents/`. `.claude/rules` and `.claude/skills` are folder links to
  them, because Claude Code reads only there. The script creates missing links.

## 1. Name the two repositories
Both must be local checkouts. One is the hub; say which direction:
- **project → hub:** a lesson learned in the project goes to everyone.
- **hub → project:** the project takes what the hub has.

A lesson that should reach a third project goes project → hub, then hub → that project.

## 2. Check the ground
```bash
git -C <hub> status --short && git -C <project> status --short     # both clean
git -C <hub> pull --ff-only && git -C <project> pull --ff-only
cat <project>/.agents/standards-version                              # the ancestor, or absent
```
Find any open PR in the target that touches `AGENTS.md` or `.agents/`. If there is one, stop and
finish it first; two sync PRs against one target conflict with each other.

## 3. Branch in the target
```bash
git -C <target> checkout -b chore/sync-standards-<yyyy-mm-dd>
```

## 4. Run the merge
```bash
<project>/scripts/standards/sync.sh <from> <to>
```
| Exit | Meaning | Next |
|---|---|---|
| 0 | merged cleanly | step 6 |
| 1 | conflicts left in the listed files | step 5 |
| 3 | a project term would reach the hub; the line is printed and nothing was written | rewrite that line in the project with a placeholder, merge that change there first, then rerun |
| 4 | the ancestor commit is not in the hub's history | fetch the hub fully (`git -C <hub> fetch --unshallow`). If the hub's history was rewritten, treat it as a first sync: delete the marker and rerun |

Run the hub's copy of `sync.sh`: it is the published one. A change to the script itself travels
like any other shared file.

## 5. Resolve each conflict by hand
For every `conflict <path>`, open the file and read both sides:
- **Different rules on the same topic:** keep the stronger one. If they really disagree, ask the
  Tech Lead; never pick one silently.
- **The same rule worded twice:** keep the shorter wording that still names its check.
- **A project fact on one side** (a path, a host, a number): it belongs in the project's own
  instructions, not here. Replace it with a placeholder or a concept.

Then `grep -rn '^<<<<<<<\|^>>>>>>>' AGENTS.md .agents` must print nothing.

## 6. Prove it in the target
- Run the target's own checks: its guard runner, or at least the size and term checks.
  ```bash
  scripts/standards/sync.sh --check .          # in a project: no project term in a shared file
  ```
- Each skill stays a numbered checklist of at most 8 KB.
- Start a fresh agent session in the target and confirm it loads the rules and lists the skills.
  With Claude Code: `claude -p "list this project's skills; quote the first heading of one rule"`.
  An empty answer means a `.claude/` link is missing or was checked out as a text file.
- Read the whole diff once (`git -C <target> diff --stat`, then the diff). It must contain only
  files from the manifest, plus the marker in a project.

## 7. Commit and open the PR
```bash
git -C <target> add -A AGENTS.md .agents .claude/rules .claude/skills scripts/standards/sync.sh
git -C <target> commit -m "chore(standards): sync from <source> @ <source-sha>

Hub ancestor <base-sha>; conflicts resolved: <paths, or none>."
```
Open the PR in the target. Its body lists every file changed, every conflict, and how each was
resolved.

## 8. Close the loop
- **hub → project:** the marker is already updated in the PR. Nothing else to do.
- **project → hub:** once the hub PR is merged, run `sync.sh <hub> <project>` once. It should
  report no changes and move the project's marker to the merged hub commit. Commit that one-line
  change in the project.
