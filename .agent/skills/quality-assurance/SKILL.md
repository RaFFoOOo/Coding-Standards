# SKILL: QUALITY_ASSURANCE

## Description
Governs verification, debugging, and usability auditing. Invoked **before** any Feature is marked "Done".

## 1. The Console Zero-Tolerance Policy
**Protocol:**
1.  Launch app in browser.
2.  Open DevTools Console.
3.  Navigate user flow.
4.  **CRITICAL:** If `console.error` or `console.warn` appears, **STOP**, capture stack trace, and fix before proceeding.

## 2. Error Tracing & Debugging
**Trigger:** Exception or test failure.
**Action:**
1.  **Snapshot:** Save screenshot `debug_error_[timestamp].png`.
2.  **State Dump:** Log LocalStorage, Component State, Network payloads.
3.  **Root Cause:** Map stack trace to source file.

## 3. Usability & UX Verification
**Protocol:**
1.  **Responsiveness:** Render at **375px** (Mobile) and **1920px** (Desktop). Check for horizontal scroll (Forbidden).
2.  **Interaction:** Click all interactive elements. Verify "Active"/"Hover" states.
3.  **Aesthetics:** Verify Font Family ('Montserrat'/'Malone') and Colors (`#79C1B0`/`#4A4A4A`).

## 4. Reporting
Generate `QA_REPORT.md`:
- [ ] Console Cleanliness
- [ ] Mobile/Desktop Validation
- [ ] Tested Interaction Paths