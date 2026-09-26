#!/usr/bin/env bash

set -euo pipefail

code_insiders="${1:-code-insiders}"
if ! command -v "$code_insiders" >/dev/null 2>&1; then
  echo "install-claude-vscode: Code Insiders is not installed; skipping" >&2
  exit 0
fi

installed_extensions="$("$code_insiders" --list-extensions)"
while IFS= read -r extension; do
  if [[ "${extension,,}" == "anthropic.claude-code" ]]; then
    exit 0
  fi
done <<< "$installed_extensions"

exec "$code_insiders" --install-extension anthropic.claude-code
