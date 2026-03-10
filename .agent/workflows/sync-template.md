---
description: Synchronize template artifacts (.agent/, .github/) between the current repository and a remote repository (Push or Pull Model)
---
# Template Synchronization Workflow

This workflow automates the process of pulling or pushing standard configurations, rules, skills, and CI/CD pipelines between the **current** repository and another local repository (e.g., the `Coding-Standards` template repository). It leverages the standard `feature-cycle.md` steps and maintains `.agent/sync-state.json` skip lists in the target repository to remember explicit exclusions.

## Prerequisites
- This workflow must be executed from **the root directory of the current project repository** (verify with `git rev-parse --show-toplevel`).
- For the very first execution in a new project, this file (`.agent/workflows/sync-template.md`) must be manually copied from the `Coding-Standards` repo into the target project first.

## Execution Sequence

1. **Invoke Feature Cycle Validation:**
    - Ask the user: "Do you want to **PULL** templates from another repository into the current one, or **PUSH** templates from the current repository into another?"
    - Define the **Target** repository (the repo receiving changes) and **Source** repository (the repo sending changes) based on the direction.
    - Ask the user for the absolute path of the peer repository.
    - Run `gh pr list` in the **Target** repository. If there are any open, unmerged PRs in the Target repository, **STOP and warn the user**.
    - If clear, checkout a new branch in the **Target** repository: `git checkout -b chore/sync-standards`

2. **Identify Source & Target:**
    - Verify both Source and Target absolute paths contain the `.agent/` directory.

3. **Load Local State:**
    - Look for `<Target_Repo>/.agent/sync-state.json`.
    - If it exists, read the array of paths under the `skipList` key. These files must be completely ignored during the diff/sync phase.

4. **Diff & Plan Review:**
    - Recursively compare the contents of the *Source* repository (`AGENTS.md`, `.agent/`, `.github/`) against the *Target* repository root.
    - Filter out any files present in the `skipList`.
    - Present a categorization to the user:
        - `[ADD]`: Source file missing in Target repo.
        - `[MODIFY]`: Target file differs from the Source.
        - `[SKIP]`: Skipped due to `<Target_Repo>/.agent/sync-state.json`.
    - Ask the user: "Do you approve this synchronization plan? Respond 'yes' to proceed, or list specific files to add to the `[SKIP]` list permanently."
        - If new skips provided: update internal list, recalculate, repeat Review.

5. **Execution:**
    - For all `[ADD]` and `[MODIFY]` files, copy them from the *Source* repository into the exact corresponding relative path in the *Target* repository. Use `mkdir -p` where directories are missing.
    - Write the final, approved array of skipped relative paths securely to `<Target_Repo>/.agent/sync-state.json`.

6. **Finalization:**
    - In the *Target* repository, commit all staged additions and modifications (including `sync-state.json`) with the message `chore(standards): sync template updates`.
    - Push the branch and instruct the user to open a Pull Request in the *Target* repository to merge the updated standards.
