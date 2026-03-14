---
name: Browser Test
description: Plan and execute structured browser tests for each completed feature before merging.
---

# Browser Test Workflow

> [!NOTE]
> This workflow is **OPTIONAL**. Always ask the user for confirmation before executing browser tests to optimize token usage.

Run this workflow **after the build passes** and **before creating a Pull Request**, but only if explicitly approved by the user.

## Step 1 — Determine Test Scope

| Change Size | Test Scope |
|---|---|
| **Targeted** (1-2 components, isolated fix) | Test only the affected features + immediate regressions |
| **Massive** (3+ components, refactoring, cross-cutting) | Full critical-path test covering all key user flows |

Use Full Scope if: shared components were changed, routing was modified, or the sprint involved 3+ features.

## Step 2 — Write the Test Plan

Create a sprint-specific test plan file in the project: `TEST_PLAN_sprint_[N].md` alongside `PLAN.md`.

**Do NOT embed project-specific test cases in this workflow.** The test plan is project-specific and must live in the project repository.

**Test Plan format:**
```markdown
# Test Plan — Sprint [N]

## Scope: Targeted | Full Critical Path
**Changed features:** [list]
**Reason for scope:** [brief rationale]

## Test Cases

### [Feature/Page Name]
- [ ] [User action] → [Expected outcome]
- [ ] [Edge case] → [Expected outcome]

### Regression
- [ ] [Adjacent area] → [Expected state]
```

## Step 3 — Start the Dev Server

```bash
nohup bash -c "cd [project]/[webapp-dir] && npx ng serve --port 4200 2>&1" > /tmp/devserver_log.txt &
# Wait for: Application bundle generation complete
```

## Step 4 — Execute in the Browser

Use the `browser_subagent` tool. Open the local dev URL and execute each test case from the sprint test plan.

For each test case, mark ✅ PASS or ❌ FAIL (with description of actual vs expected behavior).

## Step 5 — Handle Failures

For every ❌ FAIL:
1. Document the bug in the sprint test plan under a `## Bugs Found` section
2. Add a bug-fix task to `PLAN.md` **before any remaining sprint tasks** so it is resolved before moving on
3. Fix, rebuild, and re-test only the failed items

## Step 6 — Stop the Dev Server

```bash
nohup bash -c "pkill -f 'ng serve'" > /dev/null &
```
