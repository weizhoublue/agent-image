#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

if [[ -z "${CONTEXT7_API_KEY:-}" ]]; then
  log_skip "MCP context7 — CONTEXT7_API_KEY empty"
  return 0
fi

log "Installing MCP context7"
log_secret_tail "CONTEXT7_API_KEY" "${CONTEXT7_API_KEY}"

log_info "claude mcp remove context7 -s user (ignore if missing)"
claude_agent mcp remove context7 -s user 2>/dev/null || true

log_info "claude mcp add context7 https://mcp.context7.com/mcp"
if ! claude_agent mcp add -s user --transport http context7 https://mcp.context7.com/mcp \
  --header "CONTEXT7_API_KEY: ${CONTEXT7_API_KEY}" \
  --header "Accept: application/json, text/event-stream"; then
  log_fail "claude mcp add context7 failed"
  return 1
fi

if ! claude_agent mcp list 2>&1 | grep -qE '^context7:'; then
  log_fail "context7 not found in: $(claude_agent mcp list 2>&1 | tr '\n' ' ')"
  return 1
fi

log_ok "MCP context7 ready"
return 0
