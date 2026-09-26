# Local Mindctl Router

Home Manager installs Mindctl v0.1.26 and the matching local Laya System 1
classifier. The activation wrapper selects Mindctl by default, writes
`$XDG_CONFIG_HOME/mindctl/config.yaml`, starts Laya on `127.0.0.1:8091`, starts
Mindctl on `127.0.0.1:8080`, and routes Codex through `mindctl-auto` while
preserving ChatGPT OAuth.

The first Laya start builds the pinned sidecar image and downloads the pinned
`convaiinnovations/laya` model into
`$XDG_STATE_HOME/mindctl/laya-model-cache`. This can take several minutes.
Mindctl safely uses its configured fallback tier while the classifier is not
ready.

Activation owns the complete Mindctl YAML file. Before the first managed
write, an existing file is preserved as `config.yaml.pre-home-manager`.
Generated gateway, classifier, and encryption values live only in the private
`$XDG_STATE_HOME/mindctl/secrets.env`; repeated activations preserve them. The
Laya container receives a separate `laya.env` containing only its classifier
token.
SQLite data is stored in `$XDG_STATE_HOME/mindctl/mindctl.db`.
The managed `mindctl` shell command reads the existing encryption key from
`secrets.env` only for `mindctl history`; the key is passed to that process,
not exported into the interactive shell. The router service continues to use
its own systemd `EnvironmentFile`.

Optional `DEEPSEEK_API_KEY` and `MUSE_API_KEY` values are resolved from the
`mindctl` SecretSpec profile when the service starts. The legacy
`DEEPSEEK_API_TOKEN` and `MUSE_API_TOKEN` names remain supported when the
corresponding key is absent. They remain outside the Nix store and enable
Mindctl's DeepSeek and Muse providers; if Proton Pass is unavailable, the
ChatGPT OAuth route still starts without those providers.
Anthropic's Claude subscription models are also cataloged with caller-managed
OAuth passthrough. Responses requests require a valid `X-Mindctl-Claude-Token`
header to select them; Codex requests without it continue to use their ChatGPT
OAuth route. Claude Code's Messages requests use its own OAuth bearer instead.
Claude Code sends Messages requests through Headroom to Mindctl in the default
router mode. Headroom reads the private Mindctl gateway token at startup and
adds `X-Mindctl-Token` to requests for its configured Mindctl upstream; it forwards
Claude Code's own OAuth bearer separately. The `mindctl-auto` option is added
to Claude Code's model picker without replacing its subscription credentials.
All Claude models in this mode use Mindctl's catalog; unlisted model IDs are
rejected by the router.
In direct and Weave modes, Claude Code still follows their existing Anthropic
upstreams; `mindctl-auto` requires Mindctl mode.

Mindctl performs context compression itself (`headroom.enabled: true`, cache
mode) for both Codex and Claude Code. On first start it downloads a pinned
Headroom runtime into `$XDG_CACHE_HOME/mindctl`, which requires network
access. In this mode the standalone Headroom proxy runs with `--no-optimize`,
`--no-cache`, and `--no-ccr` so it only relays Claude Code and injects the
gateway token; requests are never compressed twice. Compression is
fail-closed: if the managed runtime is unavailable, Mindctl returns HTTP 503
`headroom_unavailable` instead of forwarding uncompressed input. Direct and
Weave modes keep compression in the standalone Headroom proxy.

Use `--skip-mindctl-router` to stop Mindctl and Laya and run standalone
Headroom. Use `--weave-router` to stop Mindctl and Laya and select Weave; Weave
wins if both flags are present.

Useful checks:

```sh
systemctl --user status mindctl-router mindctl-laya weave-docker
journalctl --user -u mindctl-router -u mindctl-laya
curl --fail http://127.0.0.1:8080/readyz
curl --fail http://127.0.0.1:8091/readyz
```

No OpenAI API key is configured. Codex owns OAuth login and refresh; Mindctl
forwards the request-scoped bearer and ChatGPT account ID only to the ChatGPT
Codex backend.
