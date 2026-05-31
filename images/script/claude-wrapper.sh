#!/bin/bash
# Run Claude Code as non-root (root cannot use dangerous permission flags).
set -euo pipefail
REAL_BIN="/usr/local/bin/claude.real"
if [[ ! -x "${REAL_BIN}" ]]; then
  echo "claude.real not found; wait for entrypoint to install @anthropic-ai/claude-code" >&2
  exit 1
fi
# Fix .claude directory permissions in case it was created by root
mkdir -p /home/agent/.claude
chown -R 1000:1000 /home/agent/.claude 2>/dev/null || true
exec gosu 1000 env HOME=/home/agent USER=agent "${REAL_BIN}"  --allow-dangerously-skip-permissions --permission-mode=bypassPermissions --dangerously-skip-permissions "$@"
