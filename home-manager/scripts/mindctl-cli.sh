#!/usr/bin/env bash
set -euo pipefail

mindctl_binary="$1"
secrets_file="$2"
shift 2

if [[ "${1:-}" == history && -z "${MINDCTL_ENCRYPTION_KEY:-}" && -r "$secrets_file" ]]; then
  while IFS= read -r line; do
    if [[ "$line" == MINDCTL_ENCRYPTION_KEY=* ]]; then
      export MINDCTL_ENCRYPTION_KEY="${line#*=}"
      break
    fi
  done < "$secrets_file"
fi

exec "$mindctl_binary" "$@"
