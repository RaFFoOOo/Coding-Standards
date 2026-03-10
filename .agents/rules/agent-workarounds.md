---
name: Agent Workarounds
trigger: always_on
description: Platform-specific terminal workarounds for agent environments
---

# Agent-Specific Workarounds

Platform-specific issues and mitigations that do not belong in the global constitution.

## Known Terminal Issue — Broken stdout pipe in `run_command`

Some agent platforms (e.g., Gemini Code Assist) spawn a shell where stdout is broken: commands that produce output block indefinitely in `command_status`, while commands with no output complete normally.

### Diagnosis
If `echo test` works but `git status` or `ls` hang, this is the issue.

### Workaround
Redirect all output to a temp file and read it via `view_file`:
```bash
nohup bash -c "your-command 2>&1" > /tmp/log.txt &
# Then read with view_file /tmp/log.txt
```

For long-running commands (build, push), poll the log file with a `sleep N && cat /tmp/log.txt` pattern.