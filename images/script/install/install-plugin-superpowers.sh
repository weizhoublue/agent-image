#!/bin/bash
# shellcheck source=../install-helpers.sh
source /script/install-helpers.sh

MARKETPLACE="claude-plugins-official"
# Claude Code 要求 owner/repo 简写；完整 .git URL 会导致 marketplace 为空壳，找不到插件
MARKETPLACE_SOURCE="anthropics/claude-plugins-official"

log "Installing plugin superpowers"

log_info "claude plugin marketplace list (before)"
list_out="$(claude_agent plugin marketplace list 2>&1 || true)"
while IFS= read -r line; do log_info "${line}"; done <<<"${list_out}"

if ! grep -q "${MARKETPLACE}" <<<"${list_out}"; then
  log_info "claude plugin marketplace add ${MARKETPLACE_SOURCE}"
  add_out="$(claude_agent plugin marketplace add "${MARKETPLACE_SOURCE}" 2>&1)" || {
    while IFS= read -r line; do log_info "${line}"; done <<<"${add_out}"
    log_fail "claude plugin marketplace add failed"
    return 1
  }
  while IFS= read -r line; do log_info "${line}"; done <<<"${add_out}"
else
  log_info "marketplace ${MARKETPLACE} already registered"
fi

log_info "claude plugin marketplace update ${MARKETPLACE}"
update_out="$(claude_agent plugin marketplace update "${MARKETPLACE}" 2>&1)" || {
  while IFS= read -r line; do log_info "${line}"; done <<<"${update_out}"
  log_fail "claude plugin marketplace update failed"
  return 1
}
while IFS= read -r line; do log_info "${line}"; done <<<"${update_out}"

log_info "claude plugin uninstall superpowers (ignore if missing)"
claude_agent plugin uninstall superpowers 2>&1 || true

log_info "claude plugin install superpowers@${MARKETPLACE}"
install_out="$(claude_agent plugin install superpowers@${MARKETPLACE} 2>&1)" || {
  while IFS= read -r line; do log_info "${line}"; done <<<"${install_out}"
  log_fail "claude plugin install superpowers failed"
  return 1
}
while IFS= read -r line; do log_info "${line}"; done <<<"${install_out}"

plugins_out="$(claude_agent plugin list 2>&1 || true)"
if ! grep -qi superpowers <<<"${plugins_out}"; then
  log_fail "superpowers not in plugin list"
  return 1
fi

log_ok "plugin superpowers ready"
return 0
