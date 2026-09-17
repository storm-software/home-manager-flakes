#!/usr/bin/env bash
set -eu
set -o pipefail

inner="$(cd "$(dirname "$0")" && pwd)/activate-inner"
remaining=()
setup_displaylink=true
setup_weave_router=true

# Back up colliding files by default (equivalent to `-b backup`) unless the
# caller already requested a specific backup extension/command or -B.
export HOME_MANAGER_BACKUP_EXT="${HOME_MANAGER_BACKUP_EXT:-backup}"

while (( $# > 0 )); do
  opt="$1"
  shift

  case "$opt" in
    -b)
      if (( $# == 0 )); then
        echo "$0: option '-b' requires an argument" >&2
        exit 1
      fi
      export HOME_MANAGER_BACKUP_EXT="$1"
      shift
      ;;
    -B)
      if (( $# == 0 )); then
        echo "$0: option '-B' requires an argument" >&2
        exit 1
      fi
      export HOME_MANAGER_BACKUP_COMMAND="$1"
      shift
      ;;
    --backup)
      export HOME_MANAGER_BACKUP_EXT="${HOME_MANAGER_BACKUP_EXT:-backup}"
      ;;
    --skip-displaylink)
      setup_displaylink=false
      ;;
    --skip-weave-router)
      setup_weave_router=false
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: activate [backup options] [--skip-displaylink] [--skip-weave-router] [--driver-version N]

Backup options (same as home-manager switch):
  -b EXT           Move colliding files to <path>.EXT before linking
  -B COMMAND       Run COMMAND with the colliding path as its argument
  --backup         Equivalent to -b backup

Other options:
  --skip-displaylink   Skip displaylink-setup after successful activation
  --skip-weave-router  Skip starting Weave Router after successful activation
  --driver-version N
                   Activation driver version (0 or 1)
  -h, --help       Show this help message
USAGE
      exit 0
      ;;
    *)
      remaining+=("$opt")
      ;;
  esac
done

if [[ "$setup_weave_router" == true ]]; then
  export STORM_SETUP_WEAVE_ROUTER=1
else
  export STORM_SETUP_WEAVE_ROUTER=0
fi

"$inner" "${remaining[@]}"

if [[ "$setup_displaylink" == true ]]; then
  setup="$HOME/.nix-profile/bin/displaylink-setup"
  if [[ ! -x "$setup" ]]; then
    echo "$0: displaylink-setup was not installed by activation" >&2
    exit 1
  fi

  echo "Starting DisplayLink setup..."
  "$setup"
fi

if [[ "$setup_weave_router" == true ]]; then
  systemctl --user restart weave-router.service
  @codex_secrets_env@ import
  systemctl --user restart headroom.service

  login="$HOME/.nix-profile/bin/weave-router-login-codex"
  if [[ ! -x "$login" ]]; then
    echo "$0: weave-router-login-codex was not installed by activation" >&2
    exit 1
  fi
  "$login"
fi
