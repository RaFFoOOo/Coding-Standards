---
name: Agent Workarounds
trigger: always_on
description: Platform-specific terminal workarounds for agent environments
---

# Agent-Specific Workarounds

Platform-specific issues and mitigations that do not belong in the global constitution.

## Known Terminal Issue — Broken stdout pipe in `run_command`

Some agent platforms spawn a shell where stdout is broken: commands that produce output block indefinitely in `command_status`, while commands with no output complete normally.

### Diagnosis
If `echo test` works but `git status` or `ls` hang, this is the issue.

### Workaround
Redirect all output to a temp file and read it via `view_file`:
```bash
nohup bash -c "your-command 2>&1" > /tmp/log.txt &
# Then read with view_file /tmp/log.txt
```

For long-running commands (build, push), poll the log file with a `sleep N && cat /tmp/log.txt` pattern.

**Claude Code note:** Claude Code uses the `Bash` tool for terminal commands, which does not have this stdout pipe issue. This workaround applies to other agent platforms only.

## Known IDE Issue — Ghost File Resurrections during Refactoring

When an Agent performs a destructive mass-deletion of a structural directory via `rm -rf` (e.g., component consolidation), if the user accidentally has any of those targeted files focused natively in an active IDE tab, the IDE's automated persistence loop will instantly resurrect the deleted files immediately back into the system environment causing severe ghost compilation errors.

### Workaround
- **Diagnostics:** If an Angular build fails explicitly citing an import mismatch inside a domain you just deleted, immediately assume IDE Resurrection.
- **Agent Duty:** Warn the user to forcibly close those editor tabs, and re-execute the UNIX `rm -rf` command blindly before re-triggering compilers.

**Claude Code note:** This issue applies identically in VSCode when using Claude Code. The `Bash` tool executes `rm -rf` correctly, but IDE tab resurrection can still occur. Follow the same workaround.
