#!/usr/bin/env bash

set -euo pipefail

: "${CODEX_SECRETS_ENV:?CODEX_SECRETS_ENV must name the codex-secrets-env executable}"

extensions_dir="${CODEX_VSCODE_EXTENSIONS_DIR:-${HOME}/.vscode-insiders/extensions}"
shopt -s nullglob
candidates=("$extensions_dir"/openai.chatgpt-*/bin/linux-*/codex)
shopt -u nullglob

executable_candidates=()
for candidate in "${candidates[@]}"; do
  if [[ -x "$candidate" ]]; then
    executable_candidates+=("$candidate")
  fi
done

if (( ${#executable_candidates[@]} == 0 )); then
  echo "codex-vscode: no executable bundled Codex CLI found under '$extensions_dir'" >&2
  exit 1
fi

embedded_codex="$({ printf '%s\n' "${executable_candidates[@]}"; } | sort -V | tail -n 1)"
exec "$CODEX_SECRETS_ENV" exec "$embedded_codex" "$@"
