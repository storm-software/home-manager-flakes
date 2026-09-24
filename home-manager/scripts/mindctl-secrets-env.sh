#!/usr/bin/env bash
set -euo pipefail

: "${SECRETSPEC_FILE:?SECRETSPEC_FILE must name the Mindctl SecretSpec manifest}"

if (( $# == 0 )); then
  echo "mindctl-secrets-env requires a command" >&2
  exit 64
fi

export SECRETSPEC_REASON="${SECRETSPEC_REASON:-Resolve Mindctl provider secrets}"

start_mindctl() {
  if [[ -n "${MINDCTL_SETUP_COMMAND:-}" ]]; then
    "$MINDCTL_SETUP_COMMAND"
  fi
  exec "$@"
}

if [[ "${MINDCTL_SECRETS_INJECTED:-}" == 1 ]]; then
  start_mindctl "$@"
fi

if secretspec -f "$SECRETSPEC_FILE" check --profile mindctl --no-prompt >/dev/null 2>&1; then
  exec secretspec -f "$SECRETSPEC_FILE" run --profile mindctl -- \
    env MINDCTL_SECRETS_INJECTED=1 bash "$0" "$@"
fi

echo "Proton Pass secrets unavailable; starting Mindctl without optional provider credentials." >&2
start_mindctl "$@"
