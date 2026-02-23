---
description: Synchronize the Coding-Standards templates into the current project repository (Pull Model)
---
# Template Synchronization Workflow

This workflow automates the process of pulling standard configurations, rules, skills, and CI/CD pipelines from the central `Coding-Standards` repository into the **current** repository. It leverages the standard `feature-cycle.md` steps and maintains a local `.agent/sync-state.json` file to remember explicit exclusions.

## Prerequisites
- This workflow must be executed from **the root directory of the target project repository** (verify with `git rev-parse --show-toplevel`).
- For the very first execution in a new project, this file (`.agent/workflows/sync-template.md`) must be manually copied from the `Coding-Standards` repo into the target project first.

## Execution Sequence

1. **Invoke Feature Cycle Validation:**
    - Run `gh pr list`. If there are any open, unmerged PRs in the current repository, **STOP and warn the user**.
    - If clear, checkout a new branch: `git checkout -b chore/sync-standards`

2. **Identify Source:**
    - Ask the user: "Please provide the absolute path to your local `Coding-Standards` repository."
    - Verify the provided path contains the `.agent/` and `.gemini/` directories.

3. **Global Rules Sync:**
    - Ask the user: "Do you want to update your global `~/.gemini/GEMINI.md` file using the latest version from your standards repository?"
    - If yes: Execute the copy command from the user-provided Coding-Standards `.gemini/GEMINI.md` to `~/.gemini/GEMINI.md`.

4. **Load Local State:**
    - Look for `./.agent/sync-state.json` in the current repository.
    - If it exists, read the array of paths under the `skipList` key. These files must be completely ignored during the diff/sync phase.

5. **Diff & Plan Review:**
    - Recursively compare the contents of the *Source* repository (`.agent/`, `.github/`) against the current *Target* repository root.
    - Filter out any files present in the `skipList`.
    - Present a categorization to the user:
        - `[ADD]`: Standard file missing in current repo.
        - `[MODIFY]`: Current file differs from the standard.
        - `[SKIP]`: Skipped due to `.agent/sync-state.json`.
    - Ask the user: "Do you approve this synchronization plan? Respond 'yes' to proceed, or list specific files to add to the `[SKIP]` list permanently."
        - If new skills provided: update internal list, recalculate, repeat Review.

6. **Execution:**
    - For all `[ADD]` and `[MODIFY]` files, copy them from the *Source* repository into the exact corresponding relative path in the *Current* repository (using `mkdir -p` where needed).
    - Write the final, approved array of skipped relative paths securely to `./.agent/sync-state.json`.

7. **Finalization:**
    - Commit all staged additions and modifications (including `sync-state.json`) with the message `chore(standards): sync template updates`.
    - Push the branch and instruct the user to open a Pull Request to merge the updated standards.
