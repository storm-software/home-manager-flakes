#!/usr/bin/env bash
set -euo pipefail

state_file="${STORM_AGENT_SETUP_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/storm/agent-setup.env}"

validate_mode() {
  case "$1" in
    0|1) ;;
    *)
      echo "storm-agent-setup-mode: expected setup mode 0 or 1, got '$1'" >&2
      exit 1
      ;;
  esac
}

read_mode() {
  local mode="${STORM_SETUP_WEAVE_ROUTER:-}"
  if [[ -z "$mode" && -r "$state_file" ]]; then
    local assignment
    IFS= read -r assignment < "$state_file" || true
    case "$assignment" in
      STORM_SETUP_WEAVE_ROUTER=*) mode="${assignment#STORM_SETUP_WEAVE_ROUTER=}" ;;
      *)
        echo "storm-agent-setup-mode: invalid state file '$state_file'" >&2
        exit 1
        ;;
    esac
  fi
  # Keep Weave Router opt-in until activation records a selection. Every
  # subsequent service start uses the persisted selection.
  mode="${mode:-0}"
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
  printf 'STORM_SETUP_WEAVE_ROUTER=%s\n' "$mode" > "$temporary"
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
    echo "usage: storm-agent-setup-mode [read|write 0|1]" >&2
    exit 2
    ;;
esac
