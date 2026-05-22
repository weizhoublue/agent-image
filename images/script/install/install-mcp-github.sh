#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

if [[ -z "${GITHUB_API_KEY:-}" ]]; then
  log_skip "MCP github — GITHUB_API_KEY empty"
  return 0
fi

log "Installing MCP github"
log_secret_tail "GITHUB_API_KEY" "${GITHUB_API_KEY}"

log_info "claude mcp remove github -s user (ignore if missing)"
claude_agent mcp remove github -s user 2>/dev/null || true

log_info "claude mcp add github https://api.githubcopilot.com/mcp"
if ! claude_agent mcp add -s user github "https://api.githubcopilot.com/mcp" \
  --transport http \
  --header "Authorization: Bearer ${GITHUB_API_KEY}" \
  --header "X-MCP-Toolsets: context,issues,repos,pull_requests"; then
  log_fail "claude mcp add github failed"
  return 1
fi

if ! claude_agent mcp list 2>&1 | grep -qE '^github:'; then
  log_fail "github not found in: $(claude_agent mcp list 2>&1 | tr '\n' ' ')"
  return 1
fi

log_ok "MCP github ready"
return 0
