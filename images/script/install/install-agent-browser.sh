#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

# Linux arm64 无 Chrome-for-Testing，整组件跳过（不报错、不计入失败）
if [[ "$(uname -m)" == "aarch64" ]]; then
  log_skip "agent-browser — linux aarch64 不支持，已跳过（请使用 linux/amd64 镜像或在本机 macOS 使用）"
  return 0
fi

log "Installing agent-browser"
export NPM_CONFIG_PREFIX=/usr/local

log_info "npm install -g agent-browser@latest"
if ! npm install -g agent-browser@latest --no-audit --no-fund; then
  log_fail "npm install agent-browser failed"
  return 1
fi
log_info "npm list: $(npm list -g agent-browser --depth=0 2>/dev/null | tail -1 || echo unknown)"

if [[ -d /usr/local/lib/node_modules/agent-browser/bin ]]; then
  chmod -R a+rx /usr/local/lib/node_modules/agent-browser/bin 2>/dev/null || true
fi
if [[ -e /usr/local/bin/agent-browser ]]; then
  chmod a+rx /usr/local/bin/agent-browser 2>/dev/null || true
  target="$(readlink -f /usr/local/bin/agent-browser 2>/dev/null || true)"
  [[ -n "${target}" && -e "${target}" ]] && chmod a+rx "${target}" 2>/dev/null || true
fi

if [[ ! -x /usr/local/bin/agent-browser ]]; then
  log_fail "/usr/local/bin/agent-browser missing or not executable"
  return 1
fi
if ! agent_run /usr/local/bin/agent-browser -h >/dev/null 2>&1; then
  log_fail "uid ${AGENT_UID} cannot execute agent-browser"
  return 1
fi

log_info "agent-browser install (browser dependencies)"
if ! agent_run agent-browser install; then
  log_fail "agent-browser install failed"
  return 1
fi

log_info "npx skills add vercel-labs/agent-browser -y -g"
if ! agent_run npx --yes skills add vercel-labs/agent-browser -y -g; then
  log_fail "agent-browser skill install failed"
  return 1
fi

log_ok "agent-browser ready"
return 0
