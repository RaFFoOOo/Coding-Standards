---
description: Post-development self-review checklist to run after implementing code changes
---

# Development Checklist

Run this checklist **after completing the code implementation** for each task. If any item fails, fix the issue and **re-run this entire checklist** until all items pass cleanly.

## Correctness
1. **Error Identification**: Review the code you just wrote. Are there any potential runtime errors, null references, or unhandled edge cases?
2. **Logic Consistency**: Do all calculations, transformations, and data flows return consistent and correct results? Trace through the key paths mentally.

## Performance
3. **Performance Degradation**: Are there any obvious sources of performance issues? (e.g., unnecessary re-renders, missing `OnPush`, unoptimized loops, redundant API calls, waterfall subscriptions)

## Reliability & Security
4. **Bug & Security Audit**: Are there potential bugs or security vulnerabilities? (e.g., unsanitized user input, exposed secrets, missing error handling on external calls)

## Architecture
5. **Refactoring Check**: Do any components, services, or methods need refactoring? (e.g., methods exceeding 30 lines, duplicated logic, poor separation of concerns)

## UI / UX
6. **Visual Polish**: Are there any graphical interface elements that could be improved? (e.g., alignment, spacing, responsiveness, missing transitions)
7. **Optimistic Logic**: Did you use optimistic logic for all user interactions where applicable? (e.g., immediate UI feedback before async confirmation)
8. **Design Consistency**: Is the UI and logic consistent with the PRD, product design, and established patterns across other pages?

## Standards Compliance
9. **Global Rules**: Did you comply with all global rules defined in `GEMINI.md` / user global memory?
10. **Stack Rules**: Did you comply with all stack-specific rules? (e.g., `.agent/rules/stack-angular.md`)
11. **Skills**: Were all relevant skills followed? (e.g., `QUALITY_ASSURANCE`, `SPRINT_MANAGER`)

## Outcome
- If **any item fails**: fix the issue, then **re-run this checklist from the top**.