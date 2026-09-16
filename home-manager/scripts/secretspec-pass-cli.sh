#!/usr/bin/env bash
# SecretSpec can pass Proton Pass IDs as separate arguments. An ID beginning
# with '-' would then be parsed as an option by pass-cli, so make those two
# option/value pairs unambiguous without changing any other argument.
set -euo pipefail

args=()
while (( $# )); do
  case "$1" in
    --share-id|--item-id)
      if (( $# < 2 )); then
        exec pass-cli "$@"
      fi
      args+=("$1=$2")
      shift 2
      ;;
    *)
      args+=("$1")
      shift
      ;;
  esac
done

exec pass-cli "${args[@]}"
