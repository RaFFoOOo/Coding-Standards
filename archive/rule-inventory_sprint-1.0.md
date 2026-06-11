# Rule Inventory — sprint/1.0-lean-standards baseline

Captured 2026-06-11 at HEAD before any lean-pass edits. Every line below carries a
`STRICT`/`MANDATORY`/`GLOBAL RULE`/`Zero-Tolerance`/`absolutely forbidden` marker. T6 re-derives
this list and diffs it; any disappearance blocks the sprint (meaning-loss guard).

```
AGENTS.md:104  No Downgrade Shortcut [STRICT]
AGENTS.md:105  Sprint Freshness Audit [MANDATORY]
AGENTS.md:109  Atomic Commits [GLOBAL RULE]
AGENTS.md:110  Protected Branch Safety
AGENTS.md:12  Session Efficiency [MANDATORY]
AGENTS.md:19  Best over Simplest [STRICT]
AGENTS.md:20  Prompt Coaching [MANDATORY — every response]
AGENTS.md:31  Only once the resulting mockup/design is approved (Mockup Gate) is it frozen for that sprint
AGENTS.md:32  Verify, don't assume [STRICT]
AGENTS.md:34  Self-Review Gate [MANDATORY]
AGENTS.md:43  Iterative Review Gate [STRICT]
AGENTS.md:48  Living Plan Enforcement [STRICT]
AGENTS.md:53  Decision Recording [MANDATORY]
AGENTS.md:67  Deprecation Zero-Tolerance
AGENTS.md:91  CI vs CD secret split [STRICT]
.agents/rules/stack-angular.md:101  [STRICT] Token Scope Awareness
.agents/rules/stack-angular.md:103  [STRICT] Component Style Budget
.agents/rules/stack-angular.md:111  [STRICT] Shared UI Primitives
.agents/rules/stack-angular.md:127  Route Param Signals [STRICT]
.agents/rules/stack-angular.md:148  [STRICT] Optimistic Server-State Updates
.agents/rules/stack-angular.md:15  [STRICT] Explicit Property Types
.agents/rules/stack-angular.md:167  9. ngx-translate Runtime Usage [STRICT]
.agents/rules/stack-angular.md:184  `@for` over translated arrays [STRICT]
.agents/rules/stack-angular.md:196  10. Multi-Tenant Architecture [STRICT]
.agents/rules/stack-angular.md:205  Mode Logic Centralization [STRICT]
.agents/rules/stack-angular.md:34  2a. Modern Angular Standards [STRICT]
.agents/rules/stack-angular.md:39  [STRICT] Service Decoupling from Templates
.agents/rules/stack-angular.md:44  [STRICT] ViewChild Clean Surface
.agents/rules/stack-angular.md:69  [STRICT] Data Layer vs. Shared Behavior Separation
.agents/rules/stack-angular.md:76  [STRICT] Interface Parameters Must Use Stable IDs
.agents/rules/stack-angular.md:82  [STRICT] Server-state interfaces expose Observable, not Signal
.agents/rules/stack-dotnet-core.md:104  A07 — Authentication Failures [STRICT]
.agents/rules/stack-dotnet-core.md:114  Isolated worker (Functions) DI stub [STRICT]
.agents/rules/stack-dotnet-core.md:131  A09 — Logging Failures [STRICT]
.agents/rules/stack-dotnet-core.md:142  9. Azure SQL Authentication with Microsoft.Data.SqlClient 7+ [STRICT]
.agents/rules/stack-dotnet-core.md:65  A02 — Cryptographic Failures [STRICT]
.agents/rules/stack-dotnet-core.md:75  **[MANDATORY]** All required secret names MUST be documented in `READM
.agents/rules/stack-dotnet-core.md:77  A03 — Injection [STRICT]
.agents/rules/stack-dotnet-core.md:89  A05 — Security Misconfiguration [STRICT]
.agents/rules/stack-github-actions.md:139  Azure Functions isolated worker — `.azurefunctions/` folder [STRICT]
.agents/rules/stack-github-actions.md:13  **[STRICT]** Any workflow that needs to post a PR comment, reference a
.agents/rules/stack-github-actions.md:17  Branch coverage for preview CI [STRICT]
.agents/rules/stack-github-actions.md:188  A06 — CVE Checks [STRICT]
.agents/rules/stack-github-actions.md:209  A08 — Supply-Chain Action Pinning [STRICT]
.agents/rules/stack-github-actions.md:32  **[STRICT]** Any `pull_request`-triggered workflow that calls a reusab
.agents/rules/stack-github-actions.md:45  CD Identity Separation [STRICT]
.agents/rules/stack-github-actions.md:90  Shared Build Extraction [STRICT]
.agents/skills/manage-artifacts/SKILL.md:37  Trigger — Live Sync Rules [MANDATORY]
.agents/skills/manage-artifacts/SKILL.md:64  One Canonical Plan File [STRICT]
.agents/skills/run-qa/SKILL.md:37  Mock File Security [MANDATORY]
.agents/skills/run-qa/SKILL.md:46  1. The Console Zero-Tolerance Policy
.agents/skills/todo-manager/SKILL.md:16  § 1. Read-Before-Write Rule [MANDATORY]
.agents/skills/todo-manager/SKILL.md:62  § 5. Promotion Rule — TODO → PLAN.md Gate [MANDATORY]
.agents/workflows/pause-session.md:26  Step 1 — Audit pending state [MANDATORY]
.agents/workflows/pause-session.md:43  Step 3 — Generate `__resume_prompt.txt` [MANDATORY]
.agents/workflows/pause-session.md:69  Step 5 — Report back [MANDATORY]
.agents/workflows/recursive-review.md:113  § 3. Analysis Phase [MANDATORY]
.agents/workflows/recursive-review.md:134  § 4. Self-Criticism Phase [MANDATORY]
.agents/workflows/recursive-review.md:29  § 1. Pre-flight [MANDATORY]
.agents/workflows/recursive-review.md:43  § 2. Inventory Phase [MANDATORY — delegate to Explore subagent]
.agents/workflows/recursive-review.md:72  5. STRICT-rule grep targets [MANDATORY]
.agents/workflows/resolve-pr.md:27  7. **Quick Pre-QA Scan [MANDATORY]**: Run the `§ 0. Quick Pre-QA Scan`
.agents/workflows/resolve-pr.md:28  8. **Atomic Commit [MANDATORY]**: Per AGENTS.md §8, commit each commen
.agents/workflows/resolve-pr.md:29  9. **Comment Resolution [MANDATORY]**: Using the GitHub CLI (`gh pr re
.agents/workflows/resolve-pr.md:34  Merge with base branch [MANDATORY]
.agents/workflows/resolve-workflow.md:67  § 2.3 Pause-for-human gate [MANDATORY]
.agents/workflows/resume-session.md:20  Step 1 — Load the checkpoint + bootstrap context [MANDATORY]
.agents/workflows/resume-session.md:25  Step 2 — Run PRIORITY 0 verification FIRST [MANDATORY]
.agents/workflows/resume-session.md:32  Step 3 — Execute priorities in order, honoring gates [MANDATORY]
.agents/workflows/resume-session.md:42  Step 5 — Report back [MANDATORY]
.agents/workflows/run-feature.md:112  Zero-Tolerance Gate
.agents/workflows/run-feature.md:14  Stale Branch Hygiene [MANDATORY — user confirmation always required]
.agents/workflows/run-feature.md:20  Source → PLAN.md Promotion [MANDATORY]
.agents/workflows/run-feature.md:23  Determine work scope [MANDATORY]
.agents/workflows/run-feature.md:34  Quick Pre-QA Scan [MANDATORY]
.agents/workflows/run-feature.md:36  Self-Review Gate [MANDATORY — AGENTS.md §1]
.agents/workflows/run-feature.md:38  Atomic Commit [MANDATORY]
.agents/workflows/run-feature.md:39  PLAN.md Live Sync [MANDATORY — do not defer]
.agents/workflows/run-feature.md:48  PLAN.md Full Sync Gate [MANDATORY]
.agents/workflows/run-feature.md:49  QUALITY_ASSURANCE Strict Gate [MANDATORY]
.agents/workflows/run-feature.md:50  Merge with base branch [MANDATORY]
.agents/workflows/run-feature.md:54  PR Review Gate [MANDATORY]
.agents/workflows/run-feature.md:86  PLAN.md Feature Close [MANDATORY]
.agents/workflows/run-feature.md:91  Recursive Update [MANDATORY]
.agents/workflows/run-feature.md:92  TODO Audit [MANDATORY — End of Sprint]
.agents/workflows/run-feature.md:96  Dependency Freshness Audit [MANDATORY — End of Sprint]
.agents/workflows/sync-templates.md:266  Step 6a — Update Sync History Ledger [MANDATORY]
.agents/workflows/sync-templates.md:56  Step 3b — Sync History Verification [MANDATORY]
```

Total tagged rules: 81
