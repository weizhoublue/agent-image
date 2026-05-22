# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker image (`ghcr.io/weizhoublue/agent-image:latest`) that bundles Claude Code CLI with optional MCP servers, plugins, and tools. Configuration and state live on mounted host volumes. Component toggling is exclusively via `docker run -e` environment variables — there is no `install-env` file baked into the image.

## Commands

```bash
make build              # Single-arch Docker build (current machine arch)
make smoke              # Build + smoke test (ENABLE_ALL=true, verifies entrypoint succeeds)
make run                # Start container locally with ENABLE_ALL=true
make buildx-push        # Multi-arch (amd64+arm64) build and push to GHCR
make clean              # Remove agent-claude container
```

To test a specific platform in smoke:
```bash
SMOKE_PLATFORM=linux/arm64 SMOKE_TIMEOUT=900 ./scripts/ci-smoke.sh <image:tag>
```

## Architecture: Root Install, Agent Run

Claude Code refuses to run as root with `--allow-dangerously-skip-permissions`. But the entrypoint needs root for `npm install -g`, `chown` on mounted volumes, and system-level installs. The solution:

- **Dockerfile stays as root** (no `USER` directive)
- **Entrypoint** (`images/script/entrypoint.sh`) runs as root, installs everything
- **`claude` wrapper** (`images/script/claude-wrapper.sh`) uses `gosu` to drop to uid 1000 (`agent`) before calling `claude.real`
- **`agent_run` / `claude_agent`** in `install-helpers.sh` are the canonical helpers for executing commands as uid 1000

## Entrypoint Flow

```
entrypoint.sh
  → install-helpers.sh (sourced: logging, is_enabled, agent_run, chown)
  → install-claude-code.sh (required; failure = exit 1)
  → run-optional-installs.sh (dispatches per ENABLE_* flags, accumulates INSTALL_FAILURES)
  → abort_if_install_failed (STRICT_INSTALL=true → exit 1 on any failure)
  → fix_agent_volume_permissions (chown mount volumes, skips .ssh/.gitconfig/.config/gh)
  → exec "$@" (default: sleep infinity)
```

## Adding an Optional Component

1. Create `images/script/install/install-<name>.sh` — `source install-helpers.sh`, use `return 1` on failure (never `exit`, since scripts are `source`d)
2. Add `is_enabled ENABLE_<NAME>` dispatch in `run-optional-installs.sh`
3. Add `ENV ENABLE_<NAME>=false` in Dockerfile
4. Update `docs/usage.md` env var table
5. Run `make smoke` to verify

`is_enabled` returns true when either `ENABLE_ALL=true` or the specific `ENABLE_<NAME>=true`.

## Key Constraints

- Install scripts are `source`d — use `return`, never `exit`
- MCP/plugin install steps that call `claude` must go through `claude_agent` or `agent_run` (not direct root)
- `agent-browser` skips entirely on `aarch64` (no Chrome for Testing) — must `return 0`, not count as failure
- `query-session` downloads from GitHub Releases per architecture (`linux-amd64` / `linux-arm64`)

## CI

| Workflow | Trigger | Behavior |
|----------|---------|----------|
| `pr.yml` | PR → main | Multi-arch build (no push) + amd64 smoke |
| `release.yml` | tag `v*` | Build + smoke both archs → push GHCR → create GitHub Release |

## Secrets Handling

`log_secret_tail` in `install-helpers.sh` prints only the last 8 characters of sensitive values. API keys are never hardcoded — they are injected at runtime via `docker run -e`. Default values in Dockerfile and Makefile are either empty strings or `changeme` placeholders.
