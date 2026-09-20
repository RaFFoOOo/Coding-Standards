# Backlog

Work that is not in a sprint yet. Replaces `TODO.md`.

## Files — pick by what the item changes

| File | Holds |
|---|---|
| [`directives.md`](directives.md) | rules, skills, workflows, the sync engine, docs |

Add a file when an area earns one — a spoke project will typically need `frontend.md`,
`backend.md`, `testing.md`, `infra.md`, `ux.md` and `product.md` as well. One item lives in one file.

## Markers

| Marker | Meaning |
|---|---|
| ⚖ | needs a Tech-Lead decision before it can be scheduled |
| ⏳ | trigger-gated — do not schedule until the named trigger fires |
| 🔍 | the evidence is old and needs re-checking before the item is scheduled |

## Entry shape

```markdown
## <Imperative title>

⚖ / ⏳ trigger: … / 🔍 …            ← only the markers that apply

<1–3 sentences: the finding, the number that makes it real, the file:line.>

- [ ] <actionable item>

**Verified YYYY-MM-DD:** <the command or file:line showing it is still open>
```

Lifecycle — adding, marking, closing, auditing and the sprint-close sweep — is
[`.agents/skills/todo-manager/SKILL.md`](../.agents/skills/todo-manager/SKILL.md).
