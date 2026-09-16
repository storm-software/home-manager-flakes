#!/usr/bin/env bash
set -euo pipefail

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
codex_home="${CODEX_HOME:-$HOME/.codex}"
key_file="$state_home/weave-router/router-key"
auth_file="$codex_home/auth.json"

from_secretspec=false
if [[ "${1:-}" == "--from-secretspec" ]]; then
  from_secretspec=true
  shift
fi

if [[ "$from_secretspec" == true ]]; then
  secretspec_router_key="${WEAVE_ROUTER_KEY:-}"
  secretspec_account_id="${CODEX_CHATGPT_ACCOUNT_ID:-}"
  secretspec_context7_authorization="${CONTEXT7_AUTHORIZATION:-}"
  secretspec_context7_api_key="${CONTEXT7_API_KEY:-}"
  secretspec_firecrawl_api_key="${FIRECRAWL_API_KEY:-}"
fi

unset WEAVE_ROUTER_KEY CODEX_CHATGPT_ACCOUNT_ID \
  CONTEXT7_AUTHORIZATION CONTEXT7_API_KEY FIRECRAWL_API_KEY

if [[ "$from_secretspec" == true && -n "$secretspec_router_key" ]]; then
  export WEAVE_ROUTER_KEY="$secretspec_router_key"
elif [[ -s "$key_file" ]]; then
  if ! IFS= read -r WEAVE_ROUTER_KEY < "$key_file"; then
    : # read returns EOF for a key file without a trailing newline.
  fi
  if [[ -n "$WEAVE_ROUTER_KEY" ]]; then
    export WEAVE_ROUTER_KEY
  fi
fi

if [[ "$from_secretspec" == true && -n "$secretspec_account_id" ]]; then
  export CODEX_CHATGPT_ACCOUNT_ID="$secretspec_account_id"
elif [[ -e "$auth_file" ]]; then
  if account_id="$(jq -er '.tokens.account_id | select(type == "string" and length > 0)' "$auth_file" 2>/dev/null)"; then
    export CODEX_CHATGPT_ACCOUNT_ID="$account_id"
  elif ! jq -e . "$auth_file" >/dev/null 2>&1; then
    echo "$auth_file is invalid JSON; continuing without CODEX_CHATGPT_ACCOUNT_ID" >&2
  fi
fi

if [[ "$from_secretspec" == true ]]; then
  [[ -n "$secretspec_context7_authorization" ]] && export CONTEXT7_AUTHORIZATION="$secretspec_context7_authorization"
  [[ -n "$secretspec_context7_api_key" ]] && export CONTEXT7_API_KEY="$secretspec_context7_api_key"
  [[ -n "$secretspec_firecrawl_api_key" ]] && export FIRECRAWL_API_KEY="$secretspec_firecrawl_api_key"
fi

case "${1:-}" in
  exec)
    shift
    if (( $# == 0 )); then
      echo "codex-router-env exec requires a command" >&2
      exit 64
    fi
    if [[ "$from_secretspec" == true ]] && {
      [[ -z "${CONTEXT7_AUTHORIZATION:-}" ]] ||
      [[ -z "${CONTEXT7_API_KEY:-}" ]] ||
      [[ -z "${FIRECRAWL_API_KEY:-}" ]]
    }; then
      echo "Codex MCP credentials unavailable from Proton Pass; Context7 or Firecrawl may not authenticate." >&2
    fi
    exec "$@"
    ;;
  import)
    names=()
    absent_names=()
    for name in WEAVE_ROUTER_KEY CODEX_CHATGPT_ACCOUNT_ID; do
      if [[ -n "${!name:-}" ]]; then
        names+=("$name")
      else
        absent_names+=("$name")
      fi
    done
    # Clear stale credentials from earlier imports before delivering current
    # values. Both operations take names only; values stay in the environment.
    if (( ${#absent_names[@]} > 0 )); then
      systemctl --user unset-environment "${absent_names[@]}"
    fi
    if (( ${#names[@]} > 0 )); then
      exec systemctl --user import-environment "${names[@]}"
    fi
    ;;
  *)
    echo "usage: codex-router-env.sh [--from-secretspec] {exec COMMAND [ARG ...]|import}" >&2
    exit 64
    ;;
esac
