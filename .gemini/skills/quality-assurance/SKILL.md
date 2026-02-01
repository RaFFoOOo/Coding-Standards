# SKILL: QUALITY_ASSURANCE (GLOBAL)

## Description
Governs verification, debugging, and usability auditing. This skill is universally available.

## 1. Context Detection
Before running, detect the environment:
- **Web Project:** (HTML/CSS/JS detected) -> Run Browser/Console Protocols.
- **Backend Project:** (C#/Python/Go detected) -> Run Unit Test & Exception Log Protocols.

## 2. Web Protocol (The Console Zero-Tolerance Policy)
**Trigger:** Web projects only.
1.  Launch app in browser/headless mode.
2.  **CRITICAL:** If `console.error` or `console.warn` appears, **STOP**, capture stack trace.
3.  **Usability:** Check for responsiveness (Mobile/Desktop) if UI is present.

## 3. General Debugging Protocol
**Trigger:** Any exception or failure.
1.  **Snapshot:** Save state (Screenshot or Log Dump).
2.  **Root Cause:** Map stack trace to source file.

## 4. Reporting
Generate `QA_REPORT.md` summarizing the health of the current implementation.