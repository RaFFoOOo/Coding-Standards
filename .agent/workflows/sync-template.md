---
description: Synchronize the Coding-Standards templates to a target project repository
---
# Template Synchronization Workflow

This workflow automates the process of copying the master configurations, rules, skills, and CI/CD pipelines from the central `Coding-Standards` repository into another project repository. It uses a state file (`.agent/sync-state.json`) in the target repository to remember which files the user explicitly excluded in previous syncs.

## Prerequisites
Ensure there are no uncommitted changes in the `Coding-Standards` repository before beginning.

## Configuration & Target Identification

1. **Ask for Target Project:** Ask the user: "Please provide the absolute path to the target project repository where you want to apply the standards."
2. **Validate Target Path:** Ensure the path exists and is a valid directory.
3. **Global Rules Sync:** Ask the user: "Do you want to update the global `GEMINI.md` file in your standard `~/.gemini/` directory?"
    - If yes, execute: `cp /home/raffoooo/Projects/Coding-Standards/.gemini/GEMINI.md ~/.gemini/GEMINI.md`
    - *(Note: Ensure paths are accurate based on the user's OS and home directory).*

## State Management and Diffing

4. **Load Exclusion State:** In the target project repository, look for the file `.agent/sync-state.json`.
    - If it exists, read its contents. It should contain an array of relative file paths that the user previously chose to `[SKIP]`.
    - If it does not exist, assume the exclusion list is empty.

5. **Compare Repositories:** Use terminal commands (e.g., recursive `fd` or `find`) to identify all relevant standards files in the `Coding-Standards` repository. Relevant files are everything inside:
    - `.agent/` (excluding `workflows/deploy-azure.md` if unnecessary, but default to all)
    - `.github/workflows/`
    - `README.md`
    - `.gemini/` (if targeting a project-level override, though usually global)

    Compare these files against the target repository structure, paying close attention to the paths loaded in the exclusion list from Step 4.

## Review and Approval

6. **Present Synchronisation Plan:** Display a categorized list to the user showing what will happen to each file:
    - `[ADD]`: New standard file missing in the target.
    - `[MODIFY]`: Existing file in target differs from the standard.
    - `[SKIP]`: File is ignored because it is listed in the `.agent/sync-state.json` exclusion list.

7. **Ask for User Feedback:** Ask the user: "Do you approve this synchronization plan? You can reply with 'yes' to proceed, or you can list specific files you want to add to the `[SKIP]` list to ignore them permanently."
    - If the user provides new files to skip, update the internal exclusion list, recalculate the plan, and repeat Step 6.

## Execution

8. **Execute Synchronization:** For every file marked as `[ADD]` or `[MODIFY]`, copy the file from the `Coding-Standards` repository to the exact corresponding path in the target repository. Use `mkdir -p` to create any necessary parent directories in the target.
9. **Save Exclusion State:** Write the final, approved array of excluded relative paths back to the `.agent/sync-state.json` file in the target repository. This guarantees that `[SKIP]` preferences are remembered for the next execution.

## Finalization

10. **Confirm Success:** Inform the user that the synchronization was successful, summarizing how many files were copied. Point out that the target repository now has an updated `.agent/sync-state.json` tracking their preferences.
