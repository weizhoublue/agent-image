#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

REPO="weizhoublue/query-session"
REAL_BIN="/usr/local/bin/query-session.real"
WRAPPER_BIN="/usr/local/bin/query-session"
TMP_BIN="/tmp/query-session.bin"

query_session_asset_for_arch() {
  case "$(uname -m)" in
    x86_64)  echo "query-session-linux-amd64" ;;
    aarch64) echo "query-session-linux-arm64" ;;
    *)
      log_fail "unsupported architecture for query-session: $(uname -m)"
      return 1
      ;;
  esac
}

log "Installing query-session"

asset="$(query_session_asset_for_arch)" || return 1
log_info "target asset: ${asset}"

log_info "fetch latest release tag from GitHub API"
api_json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest")" || {
  log_fail "GitHub API releases/latest failed"
  return 1
}

tag="$(python3 -c 'import json,sys; print(json.load(sys.stdin)["tag_name"])' <<<"${api_json}" 2>/dev/null)" || {
  log_fail "could not parse tag_name from releases/latest"
  return 1
}
log_info "release tag: ${tag}"

url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
log_info "curl -fsSL ${url}"
if ! curl -fsSL -o "${TMP_BIN}" "${url}"; then
  log_fail "download ${asset} failed"
  return 1
fi

if [[ ! -s "${TMP_BIN}" ]]; then
  log_fail "downloaded binary empty"
  return 1
fi

chmod 755 "${TMP_BIN}"
install -m 755 "${TMP_BIN}" "${REAL_BIN}"
rm -f "${TMP_BIN}"

log_info "cp query-session-wrapper.sh -> ${WRAPPER_BIN}"
if ! cp /script/query-session-wrapper.sh "${WRAPPER_BIN}"; then
  log_fail "failed to install query-session wrapper"
  return 1
fi
chmod +x "${WRAPPER_BIN}"

if [[ ! -x "${REAL_BIN}" ]] || [[ ! -x "${WRAPPER_BIN}" ]]; then
  log_fail "query-session binaries missing after install"
  return 1
fi

log_info "query-session installed tag=${tag} asset=${asset} real=${REAL_BIN} wrapper=${WRAPPER_BIN}"

log_info "verify: wrapper runs as agent (HOME=/home/agent)"
mkdir -p "${AGENT_HOME}/.claude/projects"
chown -R "${AGENT_UID}:${AGENT_GID}" "${AGENT_HOME}/.claude" 2>/dev/null || true
if ! "${WRAPPER_BIN}" >/dev/null 2>&1; then
  log_fail "query-session wrapper failed (check ${AGENT_HOME}/.claude/projects)"
  return 1
fi

log_ok "query-session ready (tag=${tag})"
return 0
