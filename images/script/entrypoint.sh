#!/bin/bash
set -euo pipefail

# shellcheck source=install-helpers.sh
source /script/install-helpers.sh

export NPM_CONFIG_PREFIX=/usr/local

INIT_MARKER="/_entrypoint-initialized"

log "agent-claude entrypoint start"
log_install_config

if [[ -f "${INIT_MARKER}" ]]; then
  log "Already initialized — skipping install (remove container to force reinstall)"
  exec "$@"
fi

log "Core: claude-code"
# shellcheck source=install/install-claude-code.sh
if ! source /script/install/install-claude-code.sh; then
  log_fail "Claude Code is required"
  exit 1
fi

# shellcheck source=run-optional-installs.sh
source /script/run-optional-installs.sh

abort_if_install_failed

# Fix .claude directory permissions (may be created during claude first run)
if [[ -d "${AGENT_HOME}/.claude" ]]; then
  chown -R "${AGENT_UID}:${AGENT_GID}" "${AGENT_HOME}/.claude" 2>/dev/null || true
  log "Fixed .claude directory permissions"
fi

# Install agent-run wrapper (gosu shortcut for npm/npx/...)
log "Installing agent-run wrapper"
cat > /usr/local/bin/agent-run << 'EOF'
#!/bin/bash
# Fix .claude directory permissions in case it was created by root
if [[ -d "/home/agent/.claude" ]]; then
  chown -R 1000:1000 /home/agent/.claude 2>/dev/null || true
fi
exec gosu 1000 "$@"
EOF
chmod +x /usr/local/bin/agent-run

touch "${INIT_MARKER}"

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
