#!/usr/bin/env bash
set -euo pipefail

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
key_file="$state_home/weave-router/router-key"
auth_file="$codex_home/auth.json"

if [[ -s "$key_file" ]]; then
  IFS= read -r WEAVE_ROUTER_KEY < "$key_file"
  if [[ -n "$WEAVE_ROUTER_KEY" ]]; then
    export WEAVE_ROUTER_KEY
  fi
fi

if [[ -e "$auth_file" ]]; then
  if account_id="$(jq -er '.tokens.account_id | select(type == "string" and length > 0)' "$auth_file" 2>/dev/null)"; then
    export CODEX_CHATGPT_ACCOUNT_ID="$account_id"
  elif ! jq -e . "$auth_file" >/dev/null 2>&1; then
    echo "$auth_file is invalid JSON; continuing without CODEX_CHATGPT_ACCOUNT_ID" >&2
  fi
fi

case "${1:-}" in
  exec)
    shift
    if (( $# == 0 )); then
      echo "codex-router-env exec requires a command" >&2
      exit 64
    fi
    exec "$@"
    ;;
  import)
    names=()
    [[ -n "${WEAVE_ROUTER_KEY:-}" ]] && names+=(WEAVE_ROUTER_KEY)
    [[ -n "${CODEX_CHATGPT_ACCOUNT_ID:-}" ]] && names+=(CODEX_CHATGPT_ACCOUNT_ID)
    if (( ${#names[@]} > 0 )); then
      exec systemctl --user import-environment "${names[@]}"
    fi
    ;;
  *)
    echo "usage: codex-router-env.sh {exec COMMAND [ARG ...]|import}" >&2
    exit 64
    ;;
esac
