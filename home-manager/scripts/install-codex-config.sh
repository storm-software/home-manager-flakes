#!/usr/bin/env bash
set -euo pipefail
umask 077

if (( $# != 2 )); then
  echo "usage: install-codex-config.sh TEMPLATE HOME_DIRECTORY" >&2
  exit 64
fi

template="$1"
home="$2"
directory="$home/.codex"
destination="$directory/config.toml"

if [[ -e "$destination" || -L "$destination" ]]; then
  if ! python3 - "$destination" <<'PY'
import pathlib
import sys
import tomllib

path = pathlib.Path(sys.argv[1])
try:
    with path.open("rb") as stream:
        tomllib.load(stream)
except Exception as error:
    print(f"{path} is invalid TOML: {error}; refusing to overwrite it", file=sys.stderr)
    raise SystemExit(1)
PY
  then
    exit 1
  fi
fi

for backup in "$destination".pre-*; do
  if [[ -e "$backup" || -L "$backup" ]]; then
    echo "Existing Codex backup may contain historical credentials: $backup" >&2
  fi
done

mkdir -p "$directory"
chmod 700 "$directory"
temporary="$(mktemp "$directory/.config.toml.XXXXXX")"
trap 'rm -f "$temporary"' EXIT
install -m 600 "$template" "$temporary"
mv -f "$temporary" "$destination"
trap - EXIT
