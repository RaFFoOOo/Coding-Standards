---
name: run-qa
description: Pre-merge verification, console audit, UX testing, and QA report generation.
---

# SKILL: run-qa

## Description
This skill governs the verification, debugging, and usability auditing of the web application. It must be invoked **before** any Feature is marked as "Done" in `PLAN.md`.

## 0. Quick Pre-QA Scan
Run this self-review **before** launching the full QA process. If any item fails, fix the issue before proceeding.

### Correctness
1. **Error Identification**: Are there any potential runtime errors, null references, or unhandled edge cases?
2. **Logic Consistency**: Do all calculations, transformations, and data flows return consistent and correct results?

### Performance
3. **Performance Degradation**: Any obvious sources of performance issues? (e.g., unnecessary re-renders, missing `OnPush`, waterfall subscriptions)

### Reliability & Security
4. **Bug & Security Audit**: Are there potential bugs or security vulnerabilities? (e.g., unsanitized input, exposed secrets, missing error handling)

### Architecture
5. **Refactoring Check**: Do any components, services, or methods need refactoring? (e.g., methods exceeding 30 lines, duplicated logic)

### UI / UX
6. **Visual Polish**: Any graphical elements that could be improved? (e.g., alignment, spacing, responsiveness, missing transitions)
7. **Optimistic Logic**: Did you use optimistic logic for all user interactions where applicable?
8. **Design Consistency**: Is the UI and logic consistent with the PRD, product design, and established patterns?

### Standards Compliance
9. **Global Rules**: Did you comply with all global rules defined in `AGENTS.md`?
10. **Stack Rules**: Did you comply with all stack-specific rules? (e.g., `.agents/rules/stack-angular.md`)
11. **Skills**: Were all relevant skills followed? (e.g., `plan-sprint`)
11a. **Test scope**: Is every **added** test one that `AGENTS.md §3` *Testing* makes mandatory? An
    added component-wiring, mock-adapter or i18n-mapping test is out of scope — remove it rather
    than carrying its upkeep.

### Mock File Security [MANDATORY]
12. **SAS token scan**: Before committing any change that touches `assets/mock/`, run:
    ```bash
    grep -r "sig=" <spa-app>/src/assets/mock/
    ```
    Any non-empty match is a **blocking violation** — SAS tokens must never appear in
    version-controlled mock files. Secrets belong in `environment.development.ts` locally
    (never committed) and in the backend database (runtime fetch).

## 1. The Console Zero-Tolerance Policy

> **Claude Code:** Sections §1-§2 require browser access. Use the `/test-browser` skill with Playwright MCP if available, or ask the user to perform manual browser verification and report console output.

**Protocol:**
1.  Launch the application in the browser.
2.  Open the DevTools Console listener.
3.  Navigate through the user flow relevant to the current task.
4.  **CRITICAL:** If any `console.error` or `console.warn` appears:
    -   **Stop immediately.**
    -   Capture the stack trace.
    -   Do not proceed to UI validation until the console is clean.

## 2. Error Tracing & Debugging Workflow
**Trigger:** When an exception occurs or a test fails.
**Action:**
1.  **Snapshot:** Take a screenshot named `debug_error_[timestamp].png`.
2.  **State Dump:** Log the current state of:
    -   Local/Session Storage.
    -   Angular Component State (if accessible via debug tools).
    -   Network Request/Response payload (if API related).
3.  **Root Cause Analysis:**
    -   Map the stack trace line number to the actual source file.
    -   Cross-reference with the most recent changes in the Sprint.

## 3. Navigation Test Confirmation (INTERACTIVE STEP)
**Protocol:**
Before proceeding to Usability Standards, ask the User:
> "Do you want to proceed with a complete navigation and usability test for this task? (Yes/No)"

-   **If NO:** Skip Section 4 and proceed immediately to Reporting.
-   **If YES:** Execute Section 4 fully.

## 4. Usability & UX Verification Standards (Conditional)
**Protocol (Execute only if confirmed in Step 3):**

> **Usability gaps vs. correctness bugs [MANDATORY distinction, the Tech Lead 2026-07-26]:** a genuine
> **correctness bug** found live (wrong data, silent data loss, a crash, a console error, a feature
> that doesn't do what it claims) still follows §5 below (`test-browser/SKILL.md` Step 5): document
> it, fix it, re-test, before reporting done. A **usability gap** — rough-but-working UX, missing
> polish, friction that doesn't lose data or break a flow, a "this could be nicer" observation — is
> **not** fixed inline during QA. Log it as a `backlog/` entry (scoped for a future sprint, not this
> one) and continue the QA pass. Do not let a legitimate polish idea balloon QA into an unplanned
> mid-gate feature session — that is exactly the kind of scope creep the sprint task list exists to
> prevent.

1.  **Responsiveness Check:**
    -   Render page at **375px** (Mobile) and **1920px** (Desktop).
    -   *Verification:* Check for horizontal scrolling on mobile (Forbidden).
    -   *Verification:* Check for overlapping text or button unobstructiveness.
2.  **Interaction Integrity:**
    -   Click every interactive element (Buttons, Links, Inputs) created in the current Feature.
    -   Verify "Active" and "Hover" states provide visual feedback.
3.  **Design System Compliance:**
    -   Verify the Font Family aligns strictly with the defined Project Design Tokens.
    -   Verify primary colors match the defined CSS variables or design constants.

## 5. Reporting
Generate a `QA_REPORT.md` in the artifact folder containing:
-   **CRITICAL REQUIREMENT:** If all tests and the console pass cleanly, the report MUST begin with the exact string: `STATUS: PASS` to unlock the `run-feature.md` PR gate.
-   [ ] Console Cleanliness Status.
-   [ ] Navigation Test Status (Skipped/Passed).
-   [ ] Mobile Viewport Validation (if tested).
-   [ ] Desktop Viewport Validation (if tested).
-   [ ] List of interaction paths tested.
-   [ ] **PLAN task-table check [MANDATORY — sprint-close QA runs only]:** every task row in the
    plan's task table carries `✅` or `~~struck~~`. Run it, and paste the output:

    ```bash
    # NF>=6 scopes it to the 5-column task table: the acceptance and rule-mapping tables are
    # keyed by the same task ids and would otherwise print as false failures.
    awk -F'|' 'NF>=6 && $2 ~ /^ \*{0,2}T[0-9]/' PLAN_sprint_<N>.md | grep -vE '✅|~~'
    ```

    A row that prints is either real open work — in which case the sprint is **not** closing — or a
    finished task nobody marked. **Seen to fail on real data:** at one gate it printed seven rows,
    every one already marked done in the same file's progress log and merged three days earlier; two
    had shipped inside another task. The session before the gate went looking for work that was done.
    The first draft of this check dropped the `awk` scope and printed 11 rows, all false.

    **Why a step and not a guard:** only a sprint-close run knows the sprint is closing, and two
    halves of one file disagreeing is exactly what one `grep` can see. `AGENTS.md §1` *Living Plan
    Enforcement* already forbade the stale row and was enforced by nothing.

-   [ ] **`LESSONS_LEARNED.md` check [MANDATORY — sprint-close QA runs only]:** If this QA run is the
    one gating a sprint's archive (`run-feature/SKILL.md` step 22's Sprint Archive Check finds all
    features `[x]`/`[-]`), assert **this sprint's entry exists in the file**, by heading:

    ```bash
    grep -qE "^#{1,3} .*Sprint <N>\b" LESSONS_LEARNED.md || echo "MISSING: no '## Sprint <N>' entry"
    ```

    If it is missing, generate the entry (step 23) **before** issuing `STATUS: PASS` — do not pass
    the gate on an unenforced "MUST."

    **Assert the heading, never the file's commit date.** This check tested whether
    `git log -1 --date=short -- LESSONS_LEARNED.md` fell inside the sprint's range, which passes
    whenever *any* recent commit touched the file — including the **previous** sprint's entry. That
    is how one gate went green with no entry for its own sprint present at all. A shallow clone
    defeats the date form a second way: every `git log -1 -- <path>` returns the graft commit, so
    every file reads as modified today.

-   [ ] **The lesson must reach a RULE, not just the file [MANDATORY]:** `run-feature/SKILL.md`
    step 23 already requires that, *after* the entry is written, the relevant rule, skill or
    workflow is updated to carry it. **That half is the one that gets skipped.** Two independent
    samples: of 10 lessons drawn from a 20-sprint span, **4 had never become a rule**; of 27 entries
    moved at an archive rotation, **7 named no rule and 1 named only an agent's local memory — 26 %**.
    One of them had sat as narrative for eight sprints while the global rules already named the file
    it belonged in.

    Before `STATUS: PASS`, state **where this sprint's lesson landed as a rule** — a file and a
    section, or an explicit *"no rule change needed, because …"*. A lesson that exists only in
    `LESSONS_LEARNED.md` is a lesson nothing enforces: no bootstrap step reads that file.

-   [ ] **Log rotation check [MANDATORY — sprint-close QA runs only]:** `DECISIONS.md` and
    `LESSONS_LEARNED.md` both grow every sprint and neither has a natural end. Measure both at the
    close-out, in the same step that archives the sprint's PLAN and QA report, and rotate whichever
    is over its threshold:

    ```bash
    wc -c DECISIONS.md LESSONS_LEARNED.md
    ```

    **Rotate, don't truncate.** Keep the recent epoch in full in the live file, move everything
    earlier verbatim to its archive, and leave an index at the foot of the live file where each
    archived entry names what it became — the rule for a lesson, the decision it superseded. That
    index is the point: building it is what reveals the entries that became nothing.

    **Check every sprint, rotate only when the threshold trips.** `DECISIONS.md` is read at every
    full bootstrap ("recent epoch in full"), so its entries stay live while they still govern —
    rotating it on a fixed cadence pushes governing decisions behind an index and makes the bootstrap
    worse. `LESSONS_LEARNED.md` is in no bootstrap path, so its threshold is about readability alone.

## 6. Backend Verification (If Applicable)
-   **API Responses:** Verify all implemented API endpoints return the expected HTTP 2xx or HTTP 4xx (handled properly) status codes.
-   **Payload Validation:** Verify JSON payloads for structure and missing fields.
-   **Error Formats:** Ensure expected Domain Exceptions map precisely to standard ProblemDetails or the standard API envelope.

## 7. Accessibility Baseline (a11y)
-   **Color Contrast:** Text and interactive elements must have sufficient contrast.
-   **Keyboard Navigation:** Verify that it is possible to tab through all newly created interactive elements and that they have visible focus states.
-   **Semantic HTML & ARIA:** Verify that appropriate HTML5 elements are used (nav, main, article) and that every pure icon button has an accessible name.
-   **[STRICT] Assert the name is CORRECT for the current state, not merely present.** Resolve the
    **computed accessible name** (the browser's own value, not the presence of an `aria-label`
    attribute) and check it against what the control does *right now*. A presence check passes a
    label that says the opposite of the truth: the account button announced **"Login"** while the
    user was authenticated, and every prior gate passed it because a label was carried
    The live smoke walk already does this — *"the
    account button's accessible name is correct for the session state"* — this makes the skill teach
    the same check rather than the weaker one.
-   The same distinction applies to every "does X exist" check in this file: **a file existing is
    not a translation being complete, a route being declared is not a route resolving, and a hint
    rendering is not a hint being announced.** Prefer the resolved/computed value in every case.

## 8. Performance Budget
-   **Bundle Size:** Ensure no unexpected large third-party dependencies were leaked into the frontend bundle.
-   **Lighthouse Target:** Any new page must visually target a Lighthouse Performance score > 90 on Desktop.