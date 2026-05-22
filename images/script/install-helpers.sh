#!/bin/bash
# 公共库：日志、配置、agent 执行环境。由各 install/*.sh source。

if [[ -n "${_INSTALL_HELPERS_LOADED:-}" ]]; then
  :
else
_INSTALL_HELPERS_LOADED=1

# --- 日志 ---
log() { echo "=== $* ==="; }
log_ok() { echo "✅ $*"; }
log_fail() { echo "❌ $*"; }
log_warn() { echo "⚠️  $*"; }
log_info() { echo "    $*"; }
log_skip() { echo "⏭️  SKIP: $*"; }

# 打印密钥尾部 8 位便于核对（不输出完整值）
log_secret_tail() {
  local name="$1"
  local value="${2:-}"
  if [[ -z "${value}" ]]; then
    log_info "${name}=empty"
    return
  fi
  local tail="${value: -8}"
  log_info "${name}=set (len=${#value}, ...${tail})"
}

# --- 路径与用户 ---
AGENT_HOME="/home/agent"
AGENT_UID=1000
AGENT_GID=1000
AGENT_USER="$(getent passwd "${AGENT_UID}" | cut -d: -f1 || echo agent)"

STRICT_INSTALL="${STRICT_INSTALL:-true}"
INSTALL_FAILURES=0

# --- 配置 ---
is_enabled() {
  local flag="$1"
  [[ "${ENABLE_ALL:-}" == "true" ]] && return 0
  [[ "${!flag:-}" == "true" ]] && return 0
  return 1
}

# 组件开关由 docker run -e / Dockerfile ENV 注入，不读取 install-env 文件
log_install_config() {
  log "Configuration (from container environment)"
  log_info "STRICT_INSTALL=${STRICT_INSTALL}"
  log_info "ENABLE_ALL=${ENABLE_ALL:-false}"
  log_info "ENABLE_AGENT_BROWSER=${ENABLE_AGENT_BROWSER:-false}"
  log_info "ENABLE_MCP_EXA=${ENABLE_MCP_EXA:-false}"
  log_info "ENABLE_MCP_CONTEXT7=${ENABLE_MCP_CONTEXT7:-false}"
  log_info "ENABLE_MCP_GITHUB=${ENABLE_MCP_GITHUB:-false}"
  log_info "ENABLE_PLUGIN_SUPERPOWER=${ENABLE_PLUGIN_SUPERPOWER:-false}"
  log_info "ENABLE_RTK=${ENABLE_RTK:-false}"
  log_info "ENABLE_QUERY_SESSION=${ENABLE_QUERY_SESSION:-false}"
  log_secret_tail "ANTHROPIC_AUTH_TOKEN" "${ANTHROPIC_AUTH_TOKEN:-}"
  log_secret_tail "CONTEXT7_API_KEY" "${CONTEXT7_API_KEY:-}"
  log_secret_tail "GITHUB_API_KEY" "${GITHUB_API_KEY:-}"
  log_info "agent: ${AGENT_USER} uid=${AGENT_UID} home=${AGENT_HOME}"
}

# 以 agent 用户执行（Claude / MCP / skill 必须非 root）
agent_run() {
  gosu "${AGENT_UID}" env HOME="${AGENT_HOME}" USER="${AGENT_USER}" PATH="${PATH}" "$@"
}

claude_agent() {
  agent_run /usr/local/bin/claude.real "$@"
}

# 修正挂载卷属主（跳过常见只读 bind mount）
fix_agent_volume_permissions() {
  local ro_paths=(
    "${AGENT_HOME}/.ssh"
    "${AGENT_HOME}/.gitconfig"
    "${AGENT_HOME}/.config/gh"
  )
  local entry base p skip

  mkdir -p "${AGENT_HOME}"
  chown "${AGENT_UID}:${AGENT_GID}" "${AGENT_HOME}" 2>/dev/null || true
  log "Fixing volume ownership (uid=${AGENT_UID})"

  for entry in "${AGENT_HOME}"/* "${AGENT_HOME}"/.[!.]*; do
    [[ -e "${entry}" ]] || continue
    base="${entry##*/}"
    skip=0
    for p in "${ro_paths[@]}"; do
      if [[ "${entry}" == "${p}" || "${entry}" == "${p}/"* ]]; then
        log_info "skip chown: ${base} (read-only mount)"
        skip=1
        break
      fi
    done
    (( skip )) && continue
    if chown -R "${AGENT_UID}:${AGENT_GID}" "${entry}" 2>/dev/null; then
      log_info "chown ok: ${base}"
    else
      log_warn "chown failed: ${base}"
    fi
  done
}

abort_if_install_failed() {
  if (( INSTALL_FAILURES > 0 )); then
    log_fail "${INSTALL_FAILURES} component(s) failed"
    if [[ "${STRICT_INSTALL}" == "true" ]]; then
      log_fail "STRICT_INSTALL=true, aborting startup"
      exit 1
    fi
    log_warn "STRICT_INSTALL=false, continuing anyway"
  fi
}

fi
