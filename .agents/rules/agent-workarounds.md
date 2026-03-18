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

## Known IDE Issue — Antigravity v1.20.6 "ECONNREFUSED" Customizations Bug

Antigravity versions `1.20+` officially introduced support for the open `AGENTS.md` standard, but contain a significant regression where naming the workspace folder `.agents/` (plural) causes an `ECONNREFUSED` connect error, crashing the background indexing server.

### Stance
As per our Team Mission & Dynamics, we adhere strictly to the open `AGENTS.md` standard and prioritize absolute compliance over bending to specific buggy agent versions. We use the `.agents/` structure universally to ensure total cross-agent interoperability (Claude, Gemini, etc.), even if it temporarily breaks the UI in a specific version of Antigravity.