---
paths:
  - "**/*.py"
  - "**/pyproject.toml"
  - "**/uv.lock"
---

# Python — services and libraries

`AGENTS.md` applies as written; this file gives each rule its Python form. Paths are relative to
`{services}/`.

## 1. Toolchain [STRICT]

| Concern | Tool | Check |
|---|---|---|
| Interpreter and dependencies | `uv`, one `pyproject.toml` per package, `uv.lock` committed | `uv sync --locked` in CI fails a stale lock |
| Lint and format | `ruff check` + `ruff format --check` | CI |
| Types | `mypy --strict` on the package (no `Any` without a comment saying why) | CI |
| Tests | `pytest`, run as CI runs it: `uv run pytest` | CI |

Never install into the system interpreter; never `pip install` outside `uv`. A tool's configuration
lives in `pyproject.toml`, not in a separate dotfile.

## 2. Structure

- **The domain is a package with no I/O** (`{Backend}_core`): parsing, computation, rendering. It
  imports no web framework, database driver or cloud SDK, so it runs the same in a test, a CLI, a
  worker and the API.
- **Every adapter sits behind a `typing.Protocol` the core owns**: storage, repository, identity,
  clock. The composition root (the API's startup) picks the implementation from configuration.
- **The HTTP layer is thin.** A FastAPI route validates its input with a Pydantic model, calls one
  service function, and maps the result; it holds no business rule.
- **Settings come from the environment** through one `pydantic-settings` class, read once at startup.
  No module reads `os.environ` on its own; no default carries a secret.
- **Public functions are typed and documented** (one-line docstring: purpose, parameters, return);
  private helpers start with `_`.

## 3. Errors and async

- **Raise a domain exception; map it to a status in one exception handler** that returns a uniform
  problem body (`application/problem+json`). A route never builds an error response by hand.
- **I/O is `async` all the way down** in the API: an async driver (`asyncpg` / SQLAlchemy async),
  `httpx.AsyncClient`. A CPU-bound step (parsing a large spectrum, rendering a PDF) runs in a thread
  pool (`anyio.to_thread.run_sync`), never on the event loop.
- **Validate at the boundary, server side** (`AGENTS.md §3` *Dual-Side Validation*): every body,
  query and path parameter through a Pydantic model with explicit bounds; a typed `4xx` on failure.

## 4. Tests

- **Parsers are tested on real files** committed under `tests/fixtures/`: the happy path, a boundary
  (empty file, one row), the specific error (wrong separator, missing header), and a decimal comma.
- **Time, randomness and identity are injected**, never patched globally.
- **A database test runs against a real Postgres** (a CI service container or Testcontainers), never
  SQLite standing in for it.
