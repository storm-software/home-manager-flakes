#!/usr/bin/env bash
set -euo pipefail
umask 077
mkdir -p "$WEAVE_STATE"
chmod 700 "$WEAVE_STATE"
exec 9>"$WEAVE_STATE/setup.lock"
flock 9

if [[ ! -f "$WEAVE_STATE/secrets.env" ]]; then
  if [[ -e "$WEAVE_STATE/router-key" ]]; then
    echo 'secrets.env is missing for an existing installation; restore it from backup.' >&2
    exit 1
  fi
  python - "$WEAVE_STATE/secrets.env" <<'PY'
import secrets
import sys
from pathlib import Path
Path(sys.argv[1]).write_text(
    f"POSTGRES_PASSWORD={secrets.token_hex(32)}\n"
    f"ROUTER_ADMIN_PASSWORD={secrets.token_hex(32)}\n"
)
PY
fi
if [[ ! -f "$WEAVE_STATE/providers.env" ]]; then
  cat > "$WEAVE_STATE/providers.env" <<'ENV'
# Add at least one upstream provider key here, then restart weave-router.
# These are paid API credentials, not the local rk_ client key.
# OPENROUTER_API_KEY=sk-or-v1-...
# ANTHROPIC_API_KEY=sk-ant-...
# OPENAI_API_KEY=sk-...
# GOOGLE_API_KEY=...
ENV
fi
chmod 600 "$WEAVE_STATE/secrets.env" "$WEAVE_STATE/providers.env"

export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:?}/weave-docker/docker.sock"
for _ in {1..60}; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

# Boot and migrate the database before issuing keys. Never seed on every
# restart: upstream seed rotates the installation's only active API key.
weave-router-compose up -d postgres pubsub-emulator migrate
if ! grep -q '^EXTERNAL_KEY_ENCRYPTION_KEY=' "$WEAVE_STATE/secrets.env"; then
  weave-router-compose run --rm --no-deps -T seed go run /keygen.go > "$WEAVE_STATE/keyset.tmp"
  keyset=$(jq -ce . "$WEAVE_STATE/keyset.tmp")
  printf "EXTERNAL_KEY_ENCRYPTION_KEY='%s'\n" "$keyset" >> "$WEAVE_STATE/secrets.env"
  rm "$WEAVE_STATE/keyset.tmp"
fi
# Nix's Docker CLI knows its Buildx plugin path; standalone Compose does not.
# Reuse an already built image for this source revision on subsequent logins.
if ! docker image inspect "$WEAVE_IMAGE" >/dev/null 2>&1; then
  docker buildx build --load --tag "$WEAVE_IMAGE" \
    --build-arg "ROUTER_SHA=$WEAVE_REVISION" "$WEAVE_SOURCE"
fi
weave-router-compose up -d --no-build server
ready=false
for _ in {1..120}; do
  if curl -fsS --max-time 5 http://127.0.0.1:8080/readyz >/dev/null; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "$ready" != true ]]; then
  echo 'Weave Router did not become ready; inspect weave-router-compose logs server.' >&2
  exit 1
fi
if [[ ! -s "$WEAVE_STATE/router-key" ]]; then
  weave-router-compose run --rm -T seed > "$WEAVE_STATE/seed.log"
  sed -nE 's/^  (rk_[[:alnum:]_]+)$/\1/p' "$WEAVE_STATE/seed.log" > "$WEAVE_STATE/router-key.tmp"
  test -s "$WEAVE_STATE/router-key.tmp"
  mv "$WEAVE_STATE/router-key.tmp" "$WEAVE_STATE/router-key"
  rm "$WEAVE_STATE/seed.log"
fi
export WEAVE_ROUTER_KEY
WEAVE_ROUTER_KEY=$(cat "$WEAVE_STATE/router-key")
# Do not put the key in curl's argv or the journal.
printf 'header = "X-Weave-Router-Key: %s"\n' "$WEAVE_ROUTER_KEY" |
  curl --config - -fsS --max-time 10 http://127.0.0.1:8080/validate >/dev/null

# Upstream owns its four supported integrations and preserves unrelated
# settings, including Codex OAuth and RTK hooks. Logs can contain credentials.
for client in claude codex opencode pi; do
  if ! bash "$WEAVE_SOURCE/install/install.sh" --"$client" --scope user \
    --base-url http://127.0.0.1:8080 --non-interactive \
    > "$WEAVE_STATE/install-$client.log" 2>&1; then
    echo "Weave $client configuration failed; inspect $WEAVE_STATE/install-$client.log privately." >&2
    exit 1
  fi
done
python "$WEAVE_CONFIGURE"
echo 'Weave Router ready at http://127.0.0.1:8080/ui/.'
echo "Provider keys: $WEAVE_STATE/providers.env; dashboard password: $WEAVE_STATE/secrets.env."
echo 'Restart your agents. See ~/.config/weave-router/README.md for Cursor.'
