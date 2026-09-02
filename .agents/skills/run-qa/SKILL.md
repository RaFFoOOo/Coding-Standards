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
> **not** fixed inline during QA. Log it as a `TODO.md` entry (scoped for a future sprint, not this
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
-   [ ] **`LESSONS_LEARNED.md` check [MANDATORY — sprint-close QA runs only]:** If this QA run is the
    one gating a sprint's archive (`run-feature/SKILL.md` step 22's Sprint Archive Check finds all
    features `[x]`/`[-]`), verify `git log -1 --format=%ad --date=short -- LESSONS_LEARNED.md`
    falls within the current sprint's date range **before** issuing `STATUS: PASS`. If it doesn't,
    generate the entry (step 23) first — do not pass the gate on an unenforced "MUST." *(Added
    2026-07-18 after 4 consecutive sprints, 31–34, closed without one despite step 23's own
    MANDATORY wording — a directive with no gate checking it reliably gets skipped; see
    `PLAN_recursive_review_2026-07-18.md` §4.1/§9 Q3.)*

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
    (`archive/PLAN_recursive_review_2026-08-04.md §4.1`). The live smoke walk already does this — *"the
    account button's accessible name is correct for the session state"* — this makes the skill teach
    the same check rather than the weaker one.
-   The same distinction applies to every "does X exist" check in this file: **a file existing is
    not a translation being complete, a route being declared is not a route resolving, and a hint
    rendering is not a hint being announced.** Prefer the resolved/computed value in every case.

## 8. Performance Budget
-   **Bundle Size:** Ensure no unexpected large third-party dependencies were leaked into the frontend bundle.
-   **Lighthouse Target:** Any new page must visually target a Lighthouse Performance score > 90 on Desktop.