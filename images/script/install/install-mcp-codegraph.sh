#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

log "Installing MCP codegraph"

log_info "npm install -g @colbymchenry/codegraph"
if ! npm install -g @colbymchenry/codegraph; then
  log_fail "npm install @colbymchenry/codegraph failed"
  return 1
fi

log_info "codegraph install -t all -y (as agent uid ${AGENT_UID})"
if ! agent_run codegraph install -t all -y; then
  log_fail "codegraph install failed"
  return 1
fi

if ! agent_run codegraph --version >/dev/null 2>&1; then
  log_fail "agent cannot run codegraph"
  return 1
fi
log_info "agent codegraph version: $(agent_run codegraph --version 2>/dev/null | head -1 || echo unknown)"

log_ok "MCP codegraph ready"
return 0
