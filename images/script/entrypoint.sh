#!/bin/bash
set -euo pipefail

# shellcheck source=install-helpers.sh
source /script/install-helpers.sh

export NPM_CONFIG_PREFIX=/usr/local

log "agent-claude entrypoint start"
log_install_config

log "Core: claude-code"
# shellcheck source=install/install-claude-code.sh
if ! source /script/install/install-claude-code.sh; then
  log_fail "Claude Code is required"
  exit 1
fi

# shellcheck source=run-optional-installs.sh
source /script/run-optional-installs.sh

abort_if_install_failed


log "Environment ready"

log_info "ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}"
log_secret_tail "ANTHROPIC_AUTH_TOKEN" "${ANTHROPIC_AUTH_TOKEN:-}"
log_info "ANTHROPIC_MODEL=${ANTHROPIC_MODEL}"
log_info "ANTHROPIC_DEFAULT_HAIKU_MODEL=${ANTHROPIC_DEFAULT_HAIKU_MODEL}"
log_info "ANTHROPIC_DEFAULT_SONNET_MODEL=${ANTHROPIC_DEFAULT_SONNET_MODEL}"
log_info "ANTHROPIC_DEFAULT_OPUS_MODEL=${ANTHROPIC_DEFAULT_OPUS_MODEL}"
log_info "CLAUDE_CODE_SUBAGENT_MODEL=${CLAUDE_CODE_SUBAGENT_MODEL}"
log_info "CLAUDE_CODE_EFFORT_LEVEL=${CLAUDE_CODE_EFFORT_LEVEL}"

exec "$@"
