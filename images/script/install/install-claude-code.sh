#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

CLAUDE_DIR="${AGENT_HOME}/.claude"
DEFAULT_CLAUDE_MD="/script/install/CLAUDE.md"
DEFAULT_SETTINGS_JSON="/script/install/settings.json"

log "Initializing ${CLAUDE_DIR}"
mkdir -p "${CLAUDE_DIR}"

if [[ ! -f "${CLAUDE_DIR}/CLAUDE.md" ]]; then
  if [[ ! -f "${DEFAULT_CLAUDE_MD}" ]]; then
    log_fail "default ${DEFAULT_CLAUDE_MD} missing"
    return 1
  fi
  log_info "cp ${DEFAULT_CLAUDE_MD} -> ${CLAUDE_DIR}/CLAUDE.md"
  cp "${DEFAULT_CLAUDE_MD}" "${CLAUDE_DIR}/CLAUDE.md"
else
  log_info "${CLAUDE_DIR}/CLAUDE.md exists, skip"
fi

if [[ ! -f "${CLAUDE_DIR}/settings.json" ]]; then
  if [[ ! -f "${DEFAULT_SETTINGS_JSON}" ]]; then
    log_fail "default ${DEFAULT_SETTINGS_JSON} missing"
    return 1
  fi
  log_info "cp ${DEFAULT_SETTINGS_JSON} -> ${CLAUDE_DIR}/settings.json"
  cp "${DEFAULT_SETTINGS_JSON}" "${CLAUDE_DIR}/settings.json"
else
  log_info "${CLAUDE_DIR}/settings.json exists, skip"
fi

chown -R "${AGENT_UID}:${AGENT_GID}" "${CLAUDE_DIR}"

log "Installing @anthropic-ai/claude-code (global)"
export NPM_CONFIG_PREFIX=/usr/local
rm -f /usr/local/bin/claude

log_info "npm install -g @anthropic-ai/claude-code@latest"
if ! npm install -g @anthropic-ai/claude-code@latest --no-audit --no-fund; then
  log_fail "npm install @anthropic-ai/claude-code failed"
  return 1
fi
log_info "npm list: $(npm list -g @anthropic-ai/claude-code --depth=0 2>/dev/null | tail -1 || echo unknown)"

if [[ ! -x /usr/local/bin/claude ]]; then
  log_fail "/usr/local/bin/claude missing after npm install"
  return 1
fi
mv -f /usr/local/bin/claude /usr/local/bin/claude.real
log_info "binary: /usr/local/bin/claude.real"

log_info "cp claude-wrapper.sh -> /usr/local/bin/claude"
if ! cp /script/claude-wrapper.sh /usr/local/bin/claude; then
  log_fail "failed to install claude wrapper"
  return 1
fi
chmod +x /usr/local/bin/claude

ver="$(claude_agent --version 2>/dev/null | head -1 | tr -d '\r' || true)"
if [[ -z "${ver}" ]]; then
  log_fail "claude --version failed (agent user)"
  return 1
fi
log_ok "Claude Code ready: ${ver}"
return 0
