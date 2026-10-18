---
paths:
  - "**/*.ts"
  - "**/*.html"
  - "**/src/assets/i18n/**"
  - "**/src/assets/mock/*/lang/**"
  - "**/services/translation/**"
  - "scripts/ci/project/check-i18n-completeness.sh"
---

# i18n — text, bundles and ngx-translate

These are `stack-angular.md` §4 *Text Content* and §9; the headings keep the numbers, so those
citations land here. Paths are relative to `{webapp}/src/`.

## 4. Text Content

- **No user-facing text in a template or a component.** Every string is a key in a translation bundle.
- **Read a label from every bundle's value, never from its key name** — `AGENTS.md §0` *No Fabrication*.
- **Owner-facing copy says what is wrong, who it affects and what to do — never a metric, threshold or
  spec term.** *"Il minimo è 4,5:1"* shipped onto a tab whose jargon had been removed twice before
  (S35, S36 T5); the sentence a shopkeeper would say is *"«Colore dei Titoli» non si distingue
  abbastanza dal suo sfondo: i tuoi clienti faranno fatica a leggerlo."* Keep the number for tooltips
  and logs, and avoid a direction that can be wrong ("too light" on a dark failure).
- **Trace every behavioural claim in a hint to the code before the string ships.** Sprint 44 shipped
  three hints that were false about the product — *"customers cannot send you orders"* when the flag
  only picks a channel (`archive/LESSONS_LEARNED_ARCHIVE.md`, Sprint 44 §1).

## 9. ngx-translate Runtime Usage [STRICT]

### Where a key lives

| Content | Bundle | Namespace |
|---|---|---|
| Global UI strings (`NAV`, `CONTACT`, …) | `assets/i18n/{lang}.json` | not `TENANT` |
| Per-tenant copy (slogans, page text) | `assets/mock/{tenant}/lang/{lang}.json` | `TENANT.*` |
| A language's display name | `assets/i18n/{lang}.json` | `LANG.{code}` |

**Config holds language codes, never labels.** `TenantConfig.supportedLanguages` is `['it', 'en']`
(`{webapp}/projects/platform/src/models/tenant-config.models.ts:20`); the label comes from `LANG.{code}` at runtime — never
hardcoded in a component or in tenant config.

### `instant()` only after `use()` has resolved

Called before `translate.use(lang)` completes, `TranslateService.instant()` silently returns the raw
key: the HTTP loader is lazy.

```typescript
this.translate.setTranslation(lang, tenantData, true);   // 1. merge the tenant keys
await firstValueFrom(this.translate.use(lang));          // 2. wait for the global bundle
const label = this.translate.instant('LANG.it');         // 3. now safe
```

In the code: `{webapp}/projects/platform/src/services/translation/static-language.service.ts:33` merges,
`translation.service.ts:88` waits.

### Never `@for` straight over a translated array

A missing or unresolved key makes the pipe return the key string, and `@for` iterates its characters.

```html
<!-- ✅ -->
@if (arrayKey() | translate; as items) {
  @if ($any(items).length) {
    @for (item of items; track $index) { … }
  }
}
<!-- ❌ -->
@for (item of (arrayKey() | translate); track $index) { … }
```

### What `check-i18n-completeness.sh` proves — and what it cannot [STRICT]

| Case | Result |
|---|---|
| A language a tenant can select has a missing key or a blank value | **FAIL** |
| A complete bundle that no tenant can select | **FAIL** |
| A **static** key the source asks for resolves in no bundle — including a key written into the wrong namespace identically in every bundle | **FAIL** |
| A key the reference `it.json` no longer has, left in another bundle | WARN |
| A bundle key that nothing references | WARN |
| A key built at runtime — `'ACCOUNT.ORDER_STATUS.' + status`, `` `LANG.${code}` `` | **not checked** |
| A `TENANT.*` key | **not checked** |

A static reference is `'KEY' | translate`, `.instant('KEY')` (or `.get` / `.stream`), or a bare
attribute such as `message="KEY"`. **A runtime-built key or a `TENANT.*` key is verified by rendering
it** — a green guard says nothing about either.
