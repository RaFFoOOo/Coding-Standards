---
paths:
  - "**/Dockerfile"
  - "**/compose*.yml"
  - "**/compose*.yaml"
  - "**/settings*.py"
  - "**/config*.py"
  - "infra/**"
  - ".github/workflows/**"
---

# Portability — the system moves to another host without a rewrite

For a project whose final host is chosen by someone else. Each rule keeps a host-specific service
behind something the project owns.

| Concern | Rule | Check |
|---|---|---|
| Runtime | The backend is **one container image** (`Dockerfile`, non-root user, health endpoint). No serverless programming model (bindings, durable orchestrations) in the domain. | the image runs locally with `docker compose up` |
| Local system | `docker compose up` starts **everything**: API, database, object storage emulator, frontend dev server | the README's first command |
| Configuration | Twelve-factor: every host-specific value is an environment variable; one example file (`.env.example`) lists them all, with no secret | settings class fails fast on a missing value |
| Identity | **Generic OIDC**: issuer, audience and the role claim are configuration. No claim only one provider emits; roles come from the application's own user table | a second issuer works by configuration alone |
| Files | Object storage behind the storage `Protocol`: S3-compatible, Azure Blob or local disk, chosen by configuration | the tests run on the local adapter |
| Database | Standard PostgreSQL only: no extension the target hosts may lack without a fallback named in `DECISIONS.md` | migrations run on a plain `postgres` image |
| Long jobs | A job table plus a worker process from the same image, not a host-specific orchestrator | — |
| Infrastructure as code | Host-specific code lives in `infra/<host>/` only; nothing outside it names the host | `grep` for the host's SDK outside `infra/` |
| Data | An export of the whole dataset (database dump + object storage) is one documented command | run before each release |

A host-specific service is allowed **behind an adapter** and with its replacement named in
`DECISIONS.md`; never in the domain package.
