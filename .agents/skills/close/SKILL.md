---
name: close
description: Close a sprint in one session — task-table check, the gate in the sprint PR body, backlog sweep, CLAUDE.md pointer, plan archived, merge commit to main. No per-sprint QA report, dependency audit or lessons file.
---

# close

Runs once, when every task PR is merged into the sprint branch. The dependency audit and the
lessons entry belong to the monthly `review`, not here — **except a lesson's rule**: any lesson this
sprint recorded with a "Rule:" line (a PR body, `LESSONS_LEARNED.md`) is written into `AGENTS.md`, a
stack rule, a skill or a guard in the close PR, or the close stops. A rule left as a lesson is not a rule.

## 1. Preconditions
```bash
git checkout sprint/<N>-<slug> && git pull origin sprint/<N>-<slug>
git fetch origin main && git merge origin/main            # the sprint branch is current with main
```
No open task PR into the sprint branch.

## 2. Task table — prints nothing, or the sprint is not closing
```bash
# Reads only the first table whose header names `#` and `Task`; with a Status column it reads that cell alone.
awk -F'|' '
  /^\| *# *\|.*Task/ { t = 1; s = 0; for (i = 2; i < NF; i++) if ($i ~ /^ *(Status|State) *$/) s = i; next }
  t && !/^\|/ { exit }
  t && $2 ~ /T[0-9]/ { if ((s ? $s : $0) !~ /\[x\]|\[-\]|✅|~~/) print }
' PLAN_sprint_<N>.md
```
A printed row is real open work or an unmarked finished task; fix whichever it is. A task that
shipped under another task's id is marked in both rows.

## 3. The gate
Run `verify` at sprint scope, then the full battery:
```bash
cd {webapp} && npm test && npm run lint && npx ngc -p tsconfig.app.json --noEmit && npm run build   # headroom = 1 000 kB − initial total
npm audit --audit-level=high
cd ../{services} && dotnet build && dotnet test -c Release                                          # count carries its configuration
dotnet list package --vulnerable --include-transitive
ls -1 scripts/ci/*/*.sh | wc -l                                          # derived, never written
for s in scripts/ci/*/*.sh; do grep -rlq "$(basename "$s")" .github/workflows .github/actions || echo "orphan: $s"; done
bash scripts/ci/generic/check-log-size.sh                                      # rotate whichever is over (recipe in each file's index)
```
The smoke walk runs on the sprint PR (`ci-angular.yml` at the sprint gate). Paste every number,
with the command that produced it, into the **sprint PR body** as the `STATUS: PASS` block from
`verify §8`. Numbers are pasted, never typed from memory.

## 4. Backlog sweep — measure first, then six passes, closing last
```bash
grep -c '^## ' backlog/*.md                                   # entries per file
grep -h '^\s*- \[ \]' backlog/*.md | wc -l                    # open items
grep -h '^\s*- \[x\]' backlog/*.md | wc -l                    # done items
for f in backlog/[a-z]*.md; do echo "$f $(grep -c '^## ' "$f") entries / $(grep -c '^\*\*Verified' "$f") verified"; done
grep -h '^\*\*Category:\*\*' backlog/[a-z]*.md | sed 's/.*\*\*Priority:\*\* //' | sort | uniq -c
bash scripts/ci/generic/check-backlog-taxonomy.sh
```
1. **Delivered but unmarked** — check each open item against the code and merged PRs, never its
   title; mark `- [x] … — #<PR>`.
2. **Contradictions** — a resolved heading over an open item: fix the wrong half.
3. **Duplicates** — same finding in two entries; keep the better-evidenced wording.
4. **Decisions** — grep each surviving item against `DECISIONS.md` and its archive; a decision
   retires an item without touching the entry.
5. **Re-read every `critical` and `high`** — re-price or say why it waited.
6. **Close** — an entry with no open item and every item `[x]` (or a heading that declares the
   outcome) is deleted; git keeps it. Commit `chore(backlog): S<N> sweep — <before → after>`.
Report before/after: entries, open items, closed, reconciled. Refresh `Verified` dates you
re-checked; add 🔍 to any you could not.

## 5. README
Update `README.md` if setup, secrets, variables, modes or major features changed this sprint
(`check-readme-modes.sh` guards the modes table).

## 6. `CLAUDE.md` pointer
- The Active Sprint block becomes the closed block: one paragraph — branch, sprint PR, gate line
  (the numbers from §3), what shipped, what was deferred and where. Under ten lines.
- The previous sprint's block moves verbatim to `archive/SPRINT_HISTORY.md` (newest first) minus
  its "next sprint" pointer. **Current sprint + its predecessor stay inline, nothing older.**
- Name the next plan if one is committed; `check-log-size.sh` caps the file.

## 7. Archive
```bash
sed -i '0,/STATUS: In Progress/s//STATUS: CLOSED/' PLAN_sprint_<N>.md      # then fix the date by hand
git mv PLAN_sprint_<N>.md archive/ && git mv mockup_sprint_<N>_*.md archive/ 2>/dev/null
bash scripts/ci/generic/validate-archive.sh
```
Commit `docs(sprint-<N>): close — gate, sweep, archive`.

## 8. Merge
Mark the sprint PR ready for review; body carries the `STATUS: PASS` block and the list of task PRs.
After the Tech Lead approves, merge with a **merge commit** (never squash a sprint). CD deploys on
merge — watch both smoke gates; a red one is work now. Then delete the task branches whose
upstream is gone, with the Tech Lead's confirmation:
```bash
git fetch --prune origin && git branch -vv | grep ': gone]' | awk '{print $1}'
```
