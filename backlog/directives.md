# Directives — rules, skills, workflows, sync engine

## Automate the hub → project sync: one PR per project after every hub change

The engine merges well; the friction is remembering to run it, so projects drift until someone does. The
Tech Lead weighed deleting the shared files from the projects and reading the hub live (one folder holding every
repository) and kept the copies: a session, an agent or CI that sees one repository needs them there, and a
pinned hub commit lets each project adopt a rule change in a reviewed PR rather than mid-sprint (2026-11-21).

- [ ] A hub script that runs `sync.sh` hub → each listed project checkout and opens one PR per project that
      changed, titled with the hub commit; a project with an open sync PR is skipped
- [ ] Decide where it runs: by hand after a hub merge, or a workflow on push to `main` with a token that can
      open PRs in the projects

**Verified 2026-11-21:** `scripts/standards/sync.sh` merges one pair of repositories per run; nothing in
`scripts/` loops over projects or opens a PR.

## Add `settingsStandard` — sync an allowlist of settings keys, not the whole file

⚖

`settings.json` mixes standard-worthy keys with project and personal keys (`model`, `permissions`,
MCP servers, plugins) that must never be clobbered, so whole-file sync is wrong. The hub would
declare a key allowlist and the engine deep-merges only those, hub-authoritative — the same model
as rules. Design: [`docs/settings-standard-sync-spec.md`](../docs/settings-standard-sync-spec.md), written for
the retired layout-converting engine. `scripts/standards/sync.sh` merges whole files line by line, which
is unsafe for JSON, so listing `.claude/settings.json` in the manifest is not the answer either.

- [ ] Decide whether this earns its complexity, or uniform keys stay hand-applied
- [ ] If yes: a key-level JSON merge step in `sync.sh`, scoped to an allowlist

**Verified 2026-10-18:** `ls docs/settings-standard-sync-spec.md` — the spec exists;
`.agents/standards-manifest.txt` lists no settings file.

## Decide whether a hooks section belongs in synced agent settings

⚖

A `hooks` section in the synced settings (a lint hook on write/edit, say) would let the hub enforce
a standard the agent cannot skip. It is also the most invasive thing the hub could push to a spoke.

- [ ] Decide: in scope for the hub, or repo-local by policy

**Verified 2026-09-20:** no `hooks` key in either repo's settings.

## Support Copilot through its own entry point, not a transformation

⏳ trigger: GitHub Copilot's agent-file conventions stabilise

The shared files live in `.agents/` for every agent; Claude Code reaches them through two folder links
in `.claude/`. A third agent should need the same kind of entry point (links, or an instructions file
that points at `AGENTS.md` and `.agents/`), never a converted copy.

- [ ] Re-check Copilot's conventions; add its entry point only if they are stable

**Verified 2026-10-18:** not re-checked — the trigger is external. `ls -l .claude/` shows the two links.

## Configure a Playwright MCP server so browser testing is native

🔍

The `verify` skill drives a browser for its viewport and walk steps, and the hub has no `.mcp.json`
to make Playwright MCP available.

- [ ] Add `.mcp.json`, or state in the workflow that the driver is provided per-repo

**Verified 2026-10-18:** `ls .mcp.json` — absent in the hub; the `test-browser` workflow that named
the driver was replaced by `verify`.
