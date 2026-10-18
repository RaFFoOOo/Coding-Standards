---
name: review
description: Monthly, one deliverable — the recursive review, the UX review as its second pass, the dependency audit, the month's lessons with the rule each became, and three scans (comment references, duplicated facts, rules without a check).
---

# review

Runs monthly, or before a pilot launch. Deliverable: `PLAN_recursive_review_<YYYY-MM-DD>.md` at
the root (the name `validate-archive.sh` allows), ≤ 500 lines, on `chore/review-<date>` from
`main`, one PR. **Analysis only — no finding is fixed in this PR.**

## 1. Pre-flight
Read `CLAUDE.md`, `AGENTS.md`, every `.agents/rules/*.md`, every root `.md`, `backlog/*.md`, the
previous review (carry forward: undelivered roadmap items with a date, unanswered questions with
the count, repeated self-criticism items), the last three sprint PRs, open PRs, the active plan.

## 2. Inventory — a positive control before every count
**Run each instrument against one known hit first**; a tool that reports 0 on its first run is
suspect until it has found something. Targets, in this order, ≤ 200 words each:
1. Frontend services: every `I*Service` interface, its Mock and Http adapters, the binding, any
   `TODO` in a `provideByMode` call.
2. Backend endpoints: every `[Function]` — name, route, methods, auth level.
3. Production files over 200 lines (`check-file-length.sh`), and the pile-up at 190–199.
4. Component SCSS over the `anyComponentStyle` error budget in `angular.json`.
5. STRICT-rule greps from every stack rule (`.Result;`/`.Wait()`, `\bany\b`, `!important`,
   `providedIn: 'root'` on a Mock class, `.subscribe(` without cleanup, SAS or connection strings,
   `debounceTime`/`throttleTime` on state paths) plus any added since the last review.
6. `TODO|FIXME|HACK` in source, prioritising "deferred", "later", a sprint id.
7. Doc drift in `docs/INFRA.md`, `README.md`, `docs/ARCHITECTURE.md` against the last 30 days.
8. Root artefacts: each `*.md`, last commit, referenced from `CLAUDE.md`?, should be archived?
9. Pipeline: deploy workflows without a post-deploy smoke step; `pull_request` triggers filtered
   with `branches: [main]` (skips task PRs silently); how long any check has been red on `main`.
10. Change-cost audit over the whole repo: forwarded inputs, inline domain fixtures, classes
    constructed inline at 10+ sites, values duplicated across mock records, comments naming
    another file. Rank by site count; 5+ files is a refactor task ahead of the next feature there.
11. Up to 5 other rule violations, each with `file:line`.
Verify any claim that disputes a STRICT rule by reading the file yourself.

## 3. The three scans
```bash
# comments carrying references (sprint, task, PR, SHA, document)
grep -rnE '\b(S[0-9]{2}|Sprint [0-9]+)( T[0-9]+)?\b|#[0-9]{3,4}\b|DECISIONS\.md|PLAN_|LESSONS_LEARNED' {webapp}/src {services} --include=*.ts --include=*.cs --include=*.html --include=*.scss | grep -vE 'spec\.ts|Tests\.cs' | grep -E '//|\*|<!--'
# facts duplicated across Markdown
npx jscpd --min-tokens 40 --reporters console --pattern '**/*.md' --ignore 'archive/**,node_modules/**' .
# rules with no check — each gets a check this month, or is deleted (one in, one out)
grep -n 'unenforced' AGENTS.md
```

## 4. UX pass — the rendered product, not the code
Target a **deployed** environment with real data (dev or a fresh preview); confirm the URL and
tenant with the Tech Lead. Build the page × role table from `app.routes.ts`. Per page and role, at
375 and 1920: navigate, screenshot (evidence), `console` (any app-origin error is 🔴), then judge:
system status visible · plain-language labels · cancel/back/undo · consistency with every other
page and the shared primitives · error prevention · recognition over recall · short common path ·
hierarchy and whitespace · errors that say what to do · the page serves the role's task within
2 seconds · WCAG-AA · icon-only buttons named correctly for their state · spacing hygiene ·
element sizing. One primary tenant at full depth, the others where business type or palette
diverges. Carry forward the previous UX review's open findings; cite a prior dismissal rather than
re-litigating it. A visual change proposed here is an idea for a Mockup Gate, not an approved design.

## 5. Dependency audit
`npm outdated` and `dotnet list package --outdated` in every project; every action in
`.github/workflows/**` **and** `.github/actions/**` against its current major and SHA pin; Node
default against the current LTS. Classify each `[SAFE]` or `[BREAKING]` (read the migration guide);
compare manifests against `main`, not only the diff. Upgrades become tasks in the next plan.
A pin below latest stable needs the locked-framework justification verbatim.

## 6. Analysis
Every finding: severity (🔴 must fix before the pilot moves · 🟡 this quarter · 🟢 opportunistic),
`file:line` evidence, a specific fix, a target sprint. A deferral carries the command and output
that proves it safe; if you cannot run it, the finding is in scope.

## 7. Self-criticism — at least three
Each names a PR or commit, the wrong call, what would have been right, the lesson. Check whether
the previous review's items repeated. Without this section the review is not trustworthy.

## 8. Lessons — one entry a month
Add `## <Month YYYY>` to `LESSONS_LEARNED.md`: each lesson in three lines, and **the rule, skill
or guard it became** — or *"none, because …"*. A lesson that reached no rule changes nothing.
Then `bash scripts/ci/generic/check-log-size.sh`; rotate whichever file is over.

## 9. Synthesis
1. Reading guide · 2. Executive summary, top five · 3. What works · 4. What does not, by severity ·
5. Self-criticism · 6. Strategic ideas with cost and target · 7. Recommendations for the rules and
skills, with permission to prune · 8. Roadmap table · 9. Open questions for the Tech Lead, each
with options · 10. Appendix: every command and file cited.
No generic advice, no padding, no softened finding. **Every Tech-Lead decision on the PR becomes a
`backlog/` entry or a plan task in the same resolution pass** — prose in a review is not a decision.
