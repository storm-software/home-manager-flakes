#!/usr/bin/env bash
set -euo pipefail

state_file="${STORM_AGENT_SETUP_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/storm/agent-setup.env}"

validate_mode() {
  case "$1" in
    mindctl|weave|direct) ;;
    *)
      echo "storm-agent-setup-mode: expected mindctl, weave, or direct, got '$1'" >&2
      exit 1
      ;;
  esac
}

read_mode() {
  local mode="${STORM_AGENT_ROUTER_MODE:-}"
  if [[ -z "$mode" && -r "$state_file" ]]; then
    local assignment
    IFS= read -r assignment < "$state_file" || true
    case "$assignment" in
      STORM_AGENT_ROUTER_MODE=*) mode="${assignment#STORM_AGENT_ROUTER_MODE=}" ;;
      STORM_SETUP_WEAVE_ROUTER=1) mode=weave ;;
      STORM_SETUP_WEAVE_ROUTER=0) mode=mindctl ;;
      *)
        echo "storm-agent-setup-mode: invalid state file '$state_file'" >&2
        exit 1
        ;;
    esac
  fi
  # Mindctl is the default until activation records another selection. Every
  # subsequent service start uses the persisted router mode.
  mode="${mode:-mindctl}"
  validate_mode "$mode"
  printf '%s\n' "$mode"
}

write_mode() {
  local mode="${1:-}"
  validate_mode "$mode"
  umask 077
  mkdir -p "$(dirname "$state_file")"
  local temporary
  temporary="$(mktemp "${state_file}.XXXXXX")"
  trap 'rm -f "$temporary"' EXIT
  printf 'STORM_AGENT_ROUTER_MODE=%s\n' "$mode" > "$temporary"
  mv -f "$temporary" "$state_file"
  trap - EXIT
}

case "${1:-read}" in
  read)
    read_mode
    ;;
  write)
    write_mode "${2:-}"
    ;;
  *)
    echo "usage: storm-agent-setup-mode [read|write mindctl|weave|direct]" >&2
    exit 2
    ;;
esac
