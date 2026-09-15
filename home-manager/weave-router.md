# Local Weave Router

`agents.nix` imports `weave-router.nix`. Home Manager installs a dedicated
rootless Docker daemon and a user service for the pinned
[weave-os/router](https://github.com/weave-os/router) stack: PostgreSQL 15,
migrations, Pub/Sub emulator, ONNX scorer, router, and dashboard.
Only `127.0.0.1:8080` is published. Database and emulator ports stay private.
The optional HMM sidecar is not enabled.

## First start

Apply this Home Manager configuration using your normal rebuild command.
For a checkout containing new, untracked module files, use the `path:` flake
reference so Nix includes them:

```sh
nix build path:.#homeConfigurations.development.activationPackage
./result/activate
```

The activation wrapper starts the router and its dependent Headroom proxy by
default. Pass `--skip-weave-router` to skip starting those services, or
`--skip-displaylink` to skip DisplayLink setup. The initial container build
downloads Go/npm dependencies, native libraries and model weights; it can take
several minutes and requires network access and several GB of disk space.
The router source is pinned; upstream container base tags and dependency
downloads are resolved at container build time, not by a Nix sandbox build.

Rootless Docker needs host-provided `newuidmap`/`newgidmap` with their required
privileges, subordinate UID/GID ranges in `/etc/subuid` and `/etc/subgid`, and
unprivileged user namespaces. Home Manager cannot provision these host settings.
On Ubuntu, its AppArmor restrictions may also require a host policy for the
Nix rootlesskit binary. Inspect `journalctl --user -u weave-docker` if it fails.
This daemon uses its own socket and storage; your Docker context is unchanged.

The first start creates private files under `~/.local/state/weave-router/`
(or the configured XDG state directory):

- `providers.env`: optional upstream API keys, preferably `OPENROUTER_API_KEY`,
  expand routing beyond subscription-backed models. ChatGPT OAuth does not use
  `OPENAI_API_KEY` or `OPENAI_API_TOKEN`; setup removes either legacy assignment
  from an existing file on its next run.
- `secrets.env`: generated database password, dashboard admin password, and
  Tink encryption key for dashboard BYOK credentials.
- `router-key`: generated `rk_...` client credential, reused across restarts.
- `client.env`: runtime credentials/settings loaded by the Copilot wrapper.

Edit `providers.env`, then run:

```sh
systemctl --user restart weave-router
curl --fail http://127.0.0.1:8080/readyz
```

Open <http://127.0.0.1:8080/ui/> and use `ROUTER_ADMIN_PASSWORD` from
`secrets.env` to administer models and providers. Inference needs an upstream
API key or a supported subscription credential; an `rk_` key alone is not an
upstream credential. Upstream API usage is billed by the provider.
No credentials enter the Nix store. Prompt-content telemetry is disabled.

Activation enables the router's encrypted subscription pool and runs
`weave-router-login-codex` after the service is ready. On first use, follow the
printed OpenAI device-login URL and code to enroll the ChatGPT Pro account. A
later activation detects the enabled Codex account and skips login. The refresh
token is encrypted in the local PostgreSQL volume; it is not written to
`providers.env` or the Nix store. Run these commands to inspect or refresh it:

```sh
npx @weave-os/router status --codex
npx @weave-os/router accounts list --codex
weave-router-login-codex
```

No force-model or hard-pin setting is installed. The self-hosted router retains
its `cluster` default and scores each task automatically; session pinning may
still keep a multi-turn conversation on its initially routed model for
coherence.

## Client coverage

| Client from `agents.nix` | Configuration |
| --- | --- |
| Claude Code | Pinned upstream installer; local Messages API, preserves native auth and RTK hooks |
| Codex | Pinned upstream installer; local Responses provider, preserves ChatGPT OAuth for native Codex models; other routed providers need a Weave deployment credential or BYOK key |
| OpenCode | Pinned upstream installer; local provider selected |
| pi | Pinned upstream installer; local provider and upstream pi extension |
| Gemini | API-key auth, local Gemini base URL, explicit router authentication header in `.gemini/.env` |
| Copilot CLI | Package wrapper loads local OpenAI-compatible provider and key at every launch |
| Droid | Merged custom Anthropic model, selected for normal and spec sessions |
| Vibe | Merged OpenAI-compatible provider/model plus private `.vibe/.env` |
| Hermes | Named custom provider using Chat Completions, selected as default |
| Cursor | Manual Models setting, described below; no supported declarative setting in the upstream installer |

Cursor: open **Settings → Models → Override OpenAI Base URL**, enter
`http://127.0.0.1:8080/v1`, and paste the contents of `router-key` as the API
key. This covers Cursor features that honor its custom OpenAI endpoint;
Cursor Tab and other proprietary endpoints are not redirected. A remotely
executed Cursor client cannot reach this machine's loopback listener.

Restart clients after setup. User-scope defaults do not override explicit
project configuration, command-line model/provider overrides, or alternate
agent home directories. Vibe/pi integrations may fetch upstream runtime
extensions; upstream installer features are retained. Caveman remains
installed, but running an additional proxy wrapper may override these URLs.

## Operations and recovery

```sh
systemctl --user status weave-router weave-docker
journalctl --user -u weave-router -u weave-docker
weave-router-compose logs server
weave-router-compose ps
weave-router-setup  # repeat setup/merge using the existing key
```

Setup is serialized with a lock. Repeated runs preserve the router key and
merge settings; custom integrations save `.pre-weave` backups on first write.
Malformed client files stop setup instead of being replaced. Installer logs
are private `install-*.log` files because they may contain credentials.

Stopping the service stops containers without deleting volumes. Back up the
PostgreSQL volume and private state directory together. Do not delete
`secrets.env` while retaining database storage: its password and BYOK encryption
key must match the database. Do not delete `router-key` unless intentionally
rotating: upstream seed revokes the previous active key. If validation fails,
recover the current key from your backup/dashboard before rerunning setup.

To undo routing, stop the service, use the upstream installer's uninstall
commands for Claude/Codex/OpenCode/pi, restore the other clients' `.pre-weave`
files, disable Cursor's override, and revert the Copilot wrapper. Removing the
Nix import alone does not undo mutable client configuration or remove data.

Sources: [self-hosting](https://github.com/weave-os/router#or-self-host-the-whole-stack),
[configuration](https://github.com/weave-os/router/blob/main/docs/CONFIGURATION.md),
[client installer](https://github.com/weave-os/router/blob/main/install/README.md).
