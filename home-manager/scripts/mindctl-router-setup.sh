#!/usr/bin/env bash
set -euo pipefail

config_home="${MINDCTL_CONFIG_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}}"
state_home="${MINDCTL_STATE_HOME:-${XDG_STATE_HOME:-$HOME/.local/state}}"
config_dir="$config_home/mindctl"
state_dir="$state_home/mindctl"
config_file="$config_dir/config.yaml"
secrets_file="$state_dir/secrets.env"
laya_secrets_file="$state_dir/laya.env"
managed_marker="$state_dir/config-managed"

umask 077
mkdir -p "$config_dir" "$state_dir"
temporary_secrets=""
temporary_laya_secrets=""
temporary_config=""
trap 'rm -f "${temporary_secrets:-}" "${temporary_laya_secrets:-}" "${temporary_config:-}"' EXIT

if [[ ! -s "$secrets_file" ]]; then
  temporary_secrets="$(mktemp "${secrets_file}.XXXXXX")"
  printf 'MINDCTL_GATEWAY_TOKEN=%s\n' "$(openssl rand -hex 32)" > "$temporary_secrets"
  printf 'LAYA_CLASSIFIER_TOKEN=%s\n' "$(openssl rand -hex 32)" >> "$temporary_secrets"
  printf 'MINDCTL_ENCRYPTION_KEY=%s\n' "$(openssl rand -base64 32)" >> "$temporary_secrets"
  chmod 600 "$temporary_secrets"
  mv -f "$temporary_secrets" "$secrets_file"
fi

mindctl_gateway_token=""
laya_classifier_token=""
mindctl_encryption_key=""
while IFS= read -r line; do
  name="${line%%=*}"
  value="${line#*=}"
  case "$name" in
    MINDCTL_GATEWAY_TOKEN) mindctl_gateway_token="$value" ;;
    LAYA_CLASSIFIER_TOKEN) laya_classifier_token="$value" ;;
    MINDCTL_ENCRYPTION_KEY) mindctl_encryption_key="$value" ;;
  esac
done < "$secrets_file"
encryption_bytes=""
if ! encryption_bytes="$(printf '%s' "$mindctl_encryption_key" | openssl base64 -d -A 2>/dev/null | wc -c)" ||
  [[ ! "$mindctl_gateway_token" =~ ^[0-9a-f]{64}$ ]] ||
  [[ ! "$laya_classifier_token" =~ ^[0-9a-f]{64}$ ]] ||
  [[ "$encryption_bytes" != 32 ]]; then
  echo "mindctl-router-setup: invalid Mindctl secrets file '$secrets_file'; restore it or remove it only if no encrypted database must be retained" >&2
  exit 1
fi

temporary_laya_secrets="$(mktemp "${laya_secrets_file}.XXXXXX")"
printf 'LAYA_CLASSIFIER_TOKEN=%s\n' "$laya_classifier_token" > "$temporary_laya_secrets"
chmod 600 "$temporary_laya_secrets"
mv -f "$temporary_laya_secrets" "$laya_secrets_file"

if [[ -f "$config_file" && ! -e "$managed_marker" && ! -e "${config_file}.pre-home-manager" ]]; then
  cp -p "$config_file" "${config_file}.pre-home-manager"
  chmod 600 "${config_file}.pre-home-manager"
fi

temporary_config="$(mktemp "${config_file}.XXXXXX")"
cat > "$temporary_config" <<EOF
listen: 127.0.0.1:8080

client_auth:
  token_env: MINDCTL_GATEWAY_TOKEN
  header: X-Mindctl-Token
  max_body_bytes: 16777216

classifier:
  endpoint: http://127.0.0.1:8091
  token_env: LAYA_CLASSIFIER_TOKEN
  timeout: 0s
  max_retries: 3

sqlite:
  path: ${state_dir}/mindctl.db
  retention: 720h
  retention_maintenance_interval: 15m

encryption:
  active_key_id: primary
  keys:
    primary: MINDCTL_ENCRYPTION_KEY

routing:
  min_tier: T0
  max_tier: T6
  safe_fallback_tier: T4
  failure_escalation_cost_usd: 0
  latency_penalty_usd_per_second: 0
  min_success_probability: 0
  max_direct_cost_usd: 0
  max_expected_cost_usd: 0
  max_latency: 0s
  min_classifier_confidence: 0
  reasoning_floors: []
  coding_floors: []
  risk_floors: []
  underspecification_floors: []

providers:
  - id: openai
    base_url: https://chatgpt.com/backend-api/codex
    auth: chatgpt_oauth_passthrough

models:
  - id: gpt-5.6-terra
    provider: openai
    tier: T4
    capabilities: [chat, tools, images, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 0
    cached_input_price_usd_per_million: 0
    output_price: 0
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}
EOF
chmod 600 "$temporary_config"
mv -f "$temporary_config" "$config_file"
touch "$managed_marker"
chmod 600 "$managed_marker" "$secrets_file" "$laya_secrets_file" "$config_file"
trap - EXIT
