#!/usr/bin/env bash
set -euo pipefail

: "${SECRETSPEC_FILE:?SECRETSPEC_FILE must name the Codex SecretSpec manifest}"
: "${CODEX_ROUTER_ENV:?CODEX_ROUTER_ENV must name the Codex router environment helper}"

if (( $# == 0 )); then
  echo "usage: codex-secrets-env.sh {exec COMMAND [ARG ...]|import}" >&2
  exit 64
fi

export SECRETSPEC_REASON="${SECRETSPEC_REASON:-Resolve Codex runtime secrets}"

if secretspec -f "$SECRETSPEC_FILE" check --profile agents --no-prompt >/dev/null 2>&1; then
  exec secretspec -f "$SECRETSPEC_FILE" run --profile agents -- \
    "$CODEX_ROUTER_ENV" --from-secretspec "$@"
fi

echo "Proton Pass secrets unavailable; using local Codex router/OAuth fallback and leaving MCP integrations unauthenticated." >&2
exec "$CODEX_ROUTER_ENV" "$@"
