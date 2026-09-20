# Directives — rules, skills, workflows, sync engine

## Project the `sync-templates` concept verbatim, never path-substituted

🔍

Step 5a's blanket `.agents/skills/` → `.claude/skills/` content substitution mangles any workflow
that discusses paths as *subject matter* rather than as its own operational paths — most acutely
`sync-templates` itself, whose shape-detection table reads `.agents/rules/ … else .claude/rules/`.
One sync delivered it verbatim as the correct behaviour without the rule being written down.

- [ ] Codify the exception in Step 5a: a concept flagged meta is projected verbatim
- [ ] Decide how a concept is flagged — a front-matter key, or a list in `sync-state.json`

**Verified 2026-09-20:** `grep -n 'ruleRoot' .agents/workflows/sync-templates.md` — the shape table
still contains both path forms, so the hazard still exists. Whether Step 5a still substitutes was
not re-read.

## Promote the GitHub Actions cost-discipline standards, genericized

🔍

A spoke's `stack-github-actions` carries generic standards entangled with project specifics:
preview CI as `workflow_dispatch`-only; one job per logical gate except trivial guards, because
billing rounds each job up to a whole minute; and the private-repo code-scanning licensing reality.
Deferred because promoting needs a genericization judgement, not a copy.

- [ ] Strip the project specifics and promote the three standards into the hub rule

**Verified 2026-09-20:** `rule:stack-github-actions` is still a multi-repo conflict in the current
sync run, so the content has not been reconciled either way.

## Add `settingsStandard` — sync an allowlist of settings keys, not the whole file

⚖

`settings.json` mixes standard-worthy keys with project and personal keys (`model`, `permissions`,
MCP servers, plugins) that must never be clobbered, so whole-file sync is wrong. The hub would
declare a key allowlist and the engine deep-merges only those, hub-authoritative — the same model
as rules. Design: [`docs/settings-standard-sync-spec.md`](../docs/settings-standard-sync-spec.md).

- [ ] Decide whether this earns its complexity, or uniform keys stay hand-applied
- [ ] If yes: implement the allowlist + deep-merge in Step 5

**Verified 2026-09-20:** `ls docs/settings-standard-sync-spec.md` — the spec exists; no
`settingsStandard` key appears in either repo's `sync-state.json`.

## Decide whether a hooks section belongs in synced agent settings

⚖

A `hooks` section in the synced settings (a lint hook on write/edit, say) would let the hub enforce
a standard the agent cannot skip. It is also the most invasive thing the hub could push to a spoke.

- [ ] Decide: in scope for the hub, or repo-local by policy

**Verified 2026-09-20:** no `hooks` key in either repo's settings.

## Add a Copilot transformation path to the sync engine

⏳ trigger: GitHub Copilot's agent-file conventions stabilise

The engine handles agent-specific shapes through `shapeProfile`. A third target would test whether
that abstraction holds or whether it is two hard-coded cases wearing a profile.

- [ ] Re-check the conventions; implement only if they are stable

**Verified 2026-09-20:** not re-checked this run — the trigger is external.

## Configure a Playwright MCP server so browser testing is native

🔍

The `test-browser` workflow names Playwright MCP as one of its two drivers, and the hub has no
`.mcp.json` to make it available.

- [ ] Add `.mcp.json`, or state in the workflow that the driver is provided per-repo

**Verified 2026-09-20:** `ls .mcp.json` — absent in the hub;
`.agents/workflows/test-browser.md` names the driver in its Step 4 table.
