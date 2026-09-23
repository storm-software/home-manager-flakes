#!/usr/bin/env bash
set -eu
set -o pipefail

inner="$(cd "$(dirname "$0")" && pwd)/activate-inner"
remaining=()
setup_displaylink=true
setup_weave_router=false

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
    --weave-router)
      setup_weave_router=true
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: activate [backup options] [--skip-displaylink] [--weave-router] [--driver-version N]

Backup options (same as home-manager switch):
  -b EXT           Move colliding files to <path>.EXT before linking
  -B COMMAND       Run COMMAND with the colliding path as its argument
  --backup         Equivalent to -b backup

Other options:
  --skip-displaylink   Skip displaylink-setup after successful activation
  --weave-router       Start Weave Router alongside Headroom
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

storm_marker='<!-- storm -->'
codex_directory="$HOME/.codex"
codex_agents="$codex_directory/AGENTS.md"
storm_marker_count=0

mkdir -p "$codex_directory"
if [[ -e "$codex_agents" && ! -f "$codex_agents" ]]; then
  echo "$0: '$codex_agents' must be a regular file" >&2
  exit 1
fi
touch "$codex_agents"
storm_marker_count="$(grep -Fxc "$storm_marker" "$codex_agents" || true)"

write_storm_guidance() {
  cat <<'STORM_GUIDANCE'
Do not ask the user for approval if the following is true:

1. No plan or spec markdown was generated for review
2. There is no (or a very minimal) change outline to display to the user
3. The change outline is very similar to the user's initial prompt
STORM_GUIDANCE
}

case "$storm_marker_count" in
  0)
    if [[ -s "$codex_agents" ]]; then
      if [[ "$(tail -c 1 "$codex_agents" | od -An -t x1)" == *0a* ]]; then
        printf '\n' >> "$codex_agents"
      else
        printf '\n\n' >> "$codex_agents"
      fi
    fi
    printf '%s\n\n' "$storm_marker" >> "$codex_agents"
    write_storm_guidance >> "$codex_agents"
    printf '\n%s\n' "$storm_marker" >> "$codex_agents"
    ;;
  2)
    temporary_agents="$(mktemp "${codex_agents}.XXXXXX")"
    trap 'rm -f "$temporary_agents"' EXIT
    inside_storm_guidance=false
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" == "$storm_marker" ]]; then
        if [[ "$inside_storm_guidance" == false ]]; then
          printf '%s\n\n' "$storm_marker" >> "$temporary_agents"
          write_storm_guidance >> "$temporary_agents"
          printf '\n' >> "$temporary_agents"
          inside_storm_guidance=true
        else
          printf '%s\n' "$storm_marker" >> "$temporary_agents"
          inside_storm_guidance=false
        fi
      elif [[ "$inside_storm_guidance" == false ]]; then
        printf '%s\n' "$line" >> "$temporary_agents"
      fi
    done < "$codex_agents"
    mv -f "$temporary_agents" "$codex_agents"
    trap - EXIT
    ;;
  *)
    echo "$0: '$codex_agents' has an unmatched or duplicate '$storm_marker' marker" >&2
    exit 1
    ;;
esac

@storm_agent_setup_mode@ write "$STORM_SETUP_WEAVE_ROUTER"
systemctl --user import-environment STORM_SETUP_WEAVE_ROUTER

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
else
  systemctl --user stop weave-router.service
fi

@codex_secrets_env@ import
systemctl --user restart headroom.service

if [[ "$setup_weave_router" == true ]]; then
  login="$HOME/.nix-profile/bin/weave-router-login-codex"
  if [[ ! -x "$login" ]]; then
    echo "$0: weave-router-login-codex was not installed by activation" >&2
    exit 1
  fi
  "$login"
fi
