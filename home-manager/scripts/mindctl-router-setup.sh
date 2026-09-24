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
EOF

if [[ -n "${DEEPSEEK_API_TOKEN:-}" ]]; then
  cat >> "$temporary_config" <<'EOF'
  - id: deepseek
    base_url: https://api.deepseek.com
    auth: api_key
    api_key_env: DEEPSEEK_API_TOKEN
EOF
fi

if [[ -n "${MUSE_API_TOKEN:-}" ]]; then
  cat >> "$temporary_config" <<'EOF'
  - id: meta
    base_url: https://api.meta.ai/v1
    auth: api_key
    api_key_env: MUSE_API_TOKEN
EOF
fi

cat >> "$temporary_config" <<'EOF'
models:
  - id: gpt-6-astra
    provider: openai
    tier: T6
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 10
    cached_input_price_usd_per_million: 1
    output_price: 50
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-6-sol
    provider: openai
    tier: T5
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 2
    cached_input_price_usd_per_million: 0.2
    output_price: 10
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-6-luna
    provider: openai
    tier: T3
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 0.1
    cached_input_price_usd_per_million: 0.01
    output_price: 0.5
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-5.6-sol
    provider: openai
    tier: T5
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 4
    cached_input_price_usd_per_million: 0.4
    output_price: 20
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-5.6-terra
    provider: openai
    tier: T4
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 2
    cached_input_price_usd_per_million: 0.2
    output_price: 12
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-5.6-luna
    provider: openai
    tier: T2
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 0.2
    cached_input_price_usd_per_million: 0.02
    output_price: 1.2
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: gpt-5.3-codex
    provider: openai
    tier: T4
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    available: true
    input_price: 3.5
    cached_input_price_usd_per_million: 0.35
    output_price: 28
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors:
      coding: 1

  - id: gpt-5.3-codex-spark
    provider: openai
    tier: T4
    capabilities: [chat, tools, images, json_schema, web_search]
    context_window: 128000
    max_output_tokens: 16384
    # This research preview is not available to every ChatGPT Pro account.
    # Keep the proven default route deterministic until the user enables it.
    available: false
    input_price: 0
    cached_input_price_usd_per_million: 0
    output_price: 0
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors:
      coding: 1
EOF

if [[ -n "${MUSE_API_TOKEN:-}" ]]; then
  cat >> "$temporary_config" <<'EOF'
  - id: muse-spark-1.3
    provider: meta
    tier: T4
    capabilities: [chat, tools, images, json_schema]
    context_window: 1048576
    max_output_tokens: 131072
    available: true
    input_price: 1.25
    cached_input_price_usd_per_million: 0.15
    output_price: 4.25
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: muse-spark-1.3-contributor
    provider: meta
    tier: T4
    capabilities: [chat, tools, images, json_schema]
    context_window: 1048576
    max_output_tokens: 131072
    available: true
    input_price: 0.10
    cached_input_price_usd_per_million: 0.002
    output_price: 0.20
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}
EOF
fi

if [[ -n "${DEEPSEEK_API_TOKEN:-}" ]]; then
  cat >> "$temporary_config" <<'EOF'
  - id: deepseek-v4-flash
    provider: deepseek
    tier: T3
    capabilities: [chat, tools, images, json_schema]
    context_window: 1000000
    max_output_tokens: 384000
    available: true
    input_price: 0.14
    cached_input_price_usd_per_million: 0.028
    output_price: 0.28
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}

  - id: deepseek-v4-pro
    provider: deepseek
    tier: T5
    capabilities: [chat, tools, json_schema]
    context_window: 1000000
    max_output_tokens: 384000
    available: true
    input_price: 1.74
    cached_input_price_usd_per_million: 0.145
    output_price: 3.48
    per_request_price_usd: 0
    latency_p95: 0s
    success_prior: 1
    task_success_priors: {}
EOF
fi
chmod 600 "$temporary_config"
mv -f "$temporary_config" "$config_file"
touch "$managed_marker"
chmod 600 "$managed_marker" "$secrets_file" "$laya_secrets_file" "$config_file"
trap - EXIT
