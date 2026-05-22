#!/usr/bin/env bash
# Run entrypoint install matrix then exit (CMD=true). Used by make smoke and GitHub Actions.
set -euo pipefail

IMAGE="${1:?usage: ci-smoke.sh <image:tag>}"
TIMEOUT="${SMOKE_TIMEOUT:-900}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}" 2>/dev/null || sudo rm -rf "${WORKDIR}" 2>/dev/null || true' EXIT

echo "=== Smoke test: ${IMAGE} ==="
if [[ -n "${SMOKE_PLATFORM:-}" ]]; then
  echo "=== platform: ${SMOKE_PLATFORM} ==="
fi
echo "=== env: ENABLE_ALL=true (MCP without API keys should skip) ==="

DOCKER_RUN=(docker run --rm)
if [[ -n "${SMOKE_PLATFORM:-}" ]]; then
  DOCKER_RUN+=(--platform "${SMOKE_PLATFORM}")
fi
DOCKER_RUN+=(
  --network host
  -e ENABLE_ALL=true
  -v "${WORKDIR}:/home/agent:rw"
  "${IMAGE}" true
)

run_smoke() {
  if command -v timeout >/dev/null 2>&1; then
    timeout "${TIMEOUT}" "${DOCKER_RUN[@]}"
  else
    "${DOCKER_RUN[@]}"
  fi
}

if ! out="$(run_smoke 2>&1)"; then
  echo "${out}"
  echo "=== Smoke FAILED (container exit non-zero) ===" >&2
  exit 1
fi
echo "${out}"

if grep -q "STRICT_INSTALL=true, aborting startup" <<<"${out}"; then
  echo "=== Smoke FAILED (strict install aborted) ===" >&2
  exit 1
fi
if grep -q "component(s) failed" <<<"${out}" && ! grep -q "Environment ready" <<<"${out}"; then
  echo "=== Smoke FAILED (install errors in log) ===" >&2
  exit 1
fi

echo "=== Smoke PASSED ==="
