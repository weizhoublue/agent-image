#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

log "Installing MCP exa"

log_info "claude mcp remove exa -s user (ignore if missing)"
claude_agent mcp remove exa -s user 2>/dev/null || true

log_info "claude mcp add -s user --transport http exa https://mcp.exa.ai/mcp"
if ! claude_agent mcp add -s user --transport http exa https://mcp.exa.ai/mcp; then
  log_fail "claude mcp add exa failed"
  return 1
fi

# mcp list 无 -s 参数；输出多在 stderr，需 2>&1
if ! claude_agent mcp list 2>&1 | grep -qE '^exa:'; then
  log_fail "exa not found in: $(claude_agent mcp list 2>&1 | tr '\n' ' ')"
  return 1
fi

log_ok "MCP exa ready"
return 0
