#!/bin/bash
# shellcheck source=install-helpers.sh
source /script/install-helpers.sh

fix_agent_volume_permissions
log "Optional components"

if is_enabled ENABLE_AGENT_BROWSER; then
  # shellcheck source=install/install-agent-browser.sh
  source /script/install/install-agent-browser.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "agent-browser — ENABLE_AGENT_BROWSER / ENABLE_ALL not set"
fi

if is_enabled ENABLE_MCP_EXA; then
  # shellcheck source=install/install-mcp-exa.sh
  source /script/install/install-mcp-exa.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "MCP exa — ENABLE_MCP_EXA / ENABLE_ALL not set"
fi

if is_enabled ENABLE_MCP_CONTEXT7; then
  # shellcheck source=install/install-mcp-context7.sh
  source /script/install/install-mcp-context7.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "MCP context7 — ENABLE_MCP_CONTEXT7 / ENABLE_ALL not set"
fi

if is_enabled ENABLE_MCP_GITHUB; then
  # shellcheck source=install/install-mcp-github.sh
  source /script/install/install-mcp-github.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "MCP github — ENABLE_MCP_GITHUB / ENABLE_ALL not set"
fi

if is_enabled ENABLE_PLUGIN_SUPERPOWER; then
  # shellcheck source=install/install-plugin-superpowers.sh
  source /script/install/install-plugin-superpowers.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "plugin superpowers — ENABLE_PLUGIN_SUPERPOWER / ENABLE_ALL not set"
fi

if is_enabled ENABLE_RTK; then
  # shellcheck source=install/install-rtk.sh
  source /script/install/install-rtk.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "rtk — ENABLE_RTK / ENABLE_ALL not set"
fi

if is_enabled ENABLE_QUERY_SESSION; then
  # shellcheck source=install/install-query-session.sh
  source /script/install/install-query-session.sh || INSTALL_FAILURES=$((INSTALL_FAILURES + 1))
else
  log_skip "query-session — ENABLE_QUERY_SESSION / ENABLE_ALL not set"
fi
