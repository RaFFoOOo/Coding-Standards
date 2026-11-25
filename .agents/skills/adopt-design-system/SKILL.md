---
name: adopt-design-system
description: Take a new version of the shared design-system packages into this app — read every release note in between from the installed package, apply each checklist, render what changed, judge motion on a preview from a release candidate, and open the PR.
---

# adopt-design-system

For an app that consumes the shared design-system packages (`{ds-packages}`, the UI one `{ds-ui}`). A change the app
needs *from* the design system is not this skill: it is a PR in `{ds-repo}` first (its README), then this skill. Rules
cited by title are in `AGENTS.md`.

## 1. Measure what is installed and what is new
```bash
grep -n '{ds-scope}' {webapp}/package.json                                   # the installed version of each package
NODE_AUTH_TOKEN=$(gh auth token) npm view {ds-ui} dist-tags --prefix {webapp}  # latest, and next (a release candidate)
```
All four packages move together; a mixed set is the first thing to fix. A pre-release is taken only for a preview,
pinned exactly.

## 2. Read the documentation of the version you take
Install first, then read it from the package, so it matches the code:
```bash
cd {webapp} && NODE_AUTH_TOKEN=$(gh auth token) npm i <every {ds-scope} package>@^X.Y.Z
ls node_modules/{ds-ui}/docs/releases/            # one note per version
```
- **Every note after the installed version, oldest first.** Copy each note's checklist into the PR body: it is the
  task list. A breaking item names what to rename or remove.
- **`docs/adopting.md`** for each set-up step a note mentions: a partial to `@use`, an icon to register, a service to
  provide, a text bundle to copy.
- **`docs/components/<entry>.md`** for each component the app renders that a note touches: its inputs and outputs,
  every icon it and the components it uses draw, the services it injects, the tokens it reads, its text keys.

A note that is wrong or silent about something the code does is a design-system defect: fix it there (its docs are
generated or checked in CI), never by working around it in the app.

## 3. Branch
Standalone work: `chore/design-system-<X.Y.Z>` from `main`. Inside a sprint: a task branch, as `build` says.

## 4. Apply each checklist, oldest note first
- One commit per note is easiest to review; a rename across many files is its own commit.
- Where the app keeps its own copy of what the design system now ships (a partial's rules, a component), keep only
  what is the app's and load the package's; record the choice in `DECISIONS.md`.
- Register every icon a rendered component draws: an unregistered icon renders nothing and logs an error.

## 5. Check
```bash
cd {webapp} && npx ngc -p tsconfig.app.json --noEmit && npm run lint && npm test -- --watch=false && npm run build
```
Then the app's required-tokens check against the installed `required-tokens.txt`: every token the libraries read is
defined by the app. Report the initial bundle against the last measured number.

## 6. Render it
`RENDER IT LOCALLY BEFORE YOU COMMIT IT` applies to every component a note touched: on the app's specimens page and
on each page that uses it, at 375 and desktop, on two tenants whose fonts differ. Read the rendered DOM — sizes,
overflow, the actual text in both bundles — and require 0 console errors. A component that stages owner edits is
exercised through the real UI.

**Motion, video and anything that moves is judged live, never on screenshots:** take the release candidate
(`X.Y.Z-rc.N`, pinned exactly), deploy the branch to the preview, and send the Tech Lead the steps to try it.

## 7. Approval and PR
Screenshots go to the Tech Lead in the chat; the PR body carries the notes' checklists ticked, the numbers measured
in steps 5–6, and every decision recorded. Merge after the Tech Lead approves what they saw.
