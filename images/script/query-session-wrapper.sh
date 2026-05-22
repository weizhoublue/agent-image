#!/bin/bash
# Run query-session as agent (reads ~/.claude / ~/.codex / ~/.cursor under /home/agent).
set -euo pipefail
REAL_BIN="/usr/local/bin/query-session.real"
if [[ ! -x "${REAL_BIN}" ]]; then
  echo "query-session.real not found; set ENABLE_QUERY_SESSION=true and wait for entrypoint" >&2
  exit 1
fi
exec gosu 1000 env HOME=/home/agent USER=agent "${REAL_BIN}" "$@"
