#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

INSTALLER="/tmp/rtk-install.sh"

log "Installing rtk"

log_info "curl -fsSL .../install.sh -> ${INSTALLER}"
if ! curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh -o "${INSTALLER}"; then
  log_fail "download rtk install.sh failed"
  return 1
fi

log_info "bash ${INSTALLER}"
if ! bash "${INSTALLER}"; then
  log_fail "rtk install.sh failed"
  return 1
fi
rm -f "${INSTALLER}"

if [[ ! -x /root/.local/bin/rtk ]]; then
  log_fail "/root/.local/bin/rtk missing after install"
  return 1
fi

# 装到 /usr/local/bin，避免 agent 无法执行 /root/.local/bin 下的二进制
install -m 755 /root/.local/bin/rtk /usr/local/bin/rtk
log_info "rtk version: $(/usr/local/bin/rtk --version 2>/dev/null | head -1 || echo unknown)"

# rtk init 会写 ~/.claude/，需先存在且属主为 agent
mkdir -p "${AGENT_HOME}/.claude"
chown -R "${AGENT_UID}:${AGENT_GID}" "${AGENT_HOME}/.claude"

# 容器无 TTY：默认 N 不会 patch settings.json；--auto-patch 自动写入 PreToolUse hook
log_info "rtk init --global --auto-patch (as agent uid ${AGENT_UID})"
init_out="$(agent_run rtk init --global --auto-patch 2>&1)" || {
  while IFS= read -r line; do log_info "${line}"; done <<<"${init_out}"
  log_fail "rtk init --global --auto-patch failed"
  return 1
}
while IFS= read -r line; do log_info "${line}"; done <<<"${init_out}"

if ! agent_run rtk --version >/dev/null 2>&1; then
  log_fail "agent cannot run rtk"
  return 1
fi
log_info "agent rtk version: $(agent_run rtk --version 2>/dev/null | head -1 || echo unknown)"

if [[ -f "${AGENT_HOME}/.claude/settings.json" ]]; then
  if grep -q 'rtk hook claude' "${AGENT_HOME}/.claude/settings.json" 2>/dev/null; then
    log_info "settings.json: rtk PreToolUse hook present"
  else
    log_warn "settings.json exists but rtk hook not found (check init output)"
  fi
else
  log_warn "settings.json not created; hook may be registered elsewhere"
fi

log_ok "rtk ready"
return 0
