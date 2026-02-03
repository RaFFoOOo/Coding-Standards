# SKILL: QUALITY_ASSURANCE

## Description
This skill governs the verification, debugging, and usability auditing of the web application. It must be invoked **before** any Feature is marked as "Done" in `PLAN.md`.

## 1. The Console Zero-Tolerance Policy
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
1.  **Responsiveness Check:**
    -   Render page at **375px** (Mobile) and **1920px** (Desktop).
    -   *Verification:* Check for horizontal scrolling on mobile (Forbidden).
    -   *Verification:* Check for overlapping text or button unobstructiveness.
2.  **Interaction Integrity:**
    -   Click every interactive element (Buttons, Links, Inputs) created in the current Feature.
    -   Verify "Active" and "Hover" states provide visual feedback.
3.  **"Cementine" Aesthetic Check:**
    -   Verify the Font Family is strictly 'Montserrat' or 'Malone Clemettine Script'.
    -   Verify primary colors match `#79C1B0` or `#4A4A4A`.

## 5. Reporting
Generate a `QA_REPORT.md` in the artifact folder containing:
-   [ ] Console Cleanliness Status.
-   [ ] Navigation Test Status (Skipped/Passed).
-   [ ] Mobile Viewport Validation (if tested).
-   [ ] Desktop Viewport Validation (if tested).
-   [ ] List of interaction paths tested.