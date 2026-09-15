# Codex Home Manager Configuration Design

## Context

Codex is currently installed by its standalone updater at version `0.154.0`.
The pinned nixpkgs input provides the same version. Its user configuration is a
mutable `~/.codex/config.toml` containing both ordinary settings and runtime
values written by the Weave Router installer. In particular, the local router
key and ChatGPT account ID are currently serialized as static HTTP headers.

The Home Manager configuration already owns the local Weave Router service,
activation wrapper, and post-install normalization. It must now also install
Codex, reproduce the useful parts of the current Codex setup, retain ChatGPT
OAuth, and allow Weave to select any eligible model automatically.

## Goals

- Install Codex from the flake-pinned `pkgs.codex` package.
- Make Nix the source of truth for non-secret Codex settings.
- Keep the router key and ChatGPT account ID out of `config.toml` and the Nix
  store.
- Keep MCP bearer values out of `config.toml` and the Nix store.
- Keep ChatGPT OAuth tokens in Codex's own private `auth.json` store.
- Route Codex requests through `http://127.0.0.1:8080/v1`.
- Require ChatGPT login rather than API-key login.
- Preserve automatic Weave model selection across OpenAI and non-OpenAI
  providers.
- Preserve the current Weave hooks, skills, MCP integration, plugins, memories,
  and user preferences that are suitable for declarative ownership.
- Keep repeated activation and router setup idempotent.

## Non-goals

- Do not copy OAuth access or refresh tokens into Nix expressions, generated
  configuration, shell command arguments, or the Nix store.
- Do not add an `OPENAI_API_KEY` or an OpenAI API-key fallback.
- Do not pin a model with `X-Weave-Force-Model`, a session force-model setting,
  or an internal router override.
- Do not uninstall the current standalone Codex installation or activate the
  new generation during implementation. The user will perform the uninstall
  before running the built activation script.
- Do not redesign unrelated MCP, Headroom, or router provider configuration.

## Selected Architecture

### Nix-owned baseline with a mutable rendered file

A dedicated `home-manager/codex.nix` module will define the non-secret Codex
baseline using Nix data and `pkgs.formats.toml`. The activation package will
install `pkgs.codex` and copy the rendered template into
`~/.codex/config.toml` as a regular user-writable file.

A regular file is intentional. The upstream Weave integration and its local
router toggle helpers update `config.toml` atomically and refuse or replace a
Home Manager store symlink. Reasserting the template during activation gives
Nix declarative ownership without breaking those runtime tools. Runtime edits
remain temporary and the next activation restores the declared baseline.

The declared baseline will reflect the current installation where practical:

- default model `gpt-5.6-sol` as the Codex wire/request model;
- high reasoning effort, pragmatic personality, and default service tier;
- ChatGPT-only login;
- Weave as the selected model provider;
- hooks and memories enabled;
- existing trusted project entries;
- existing declarative MCP and plugin settings, with authenticated HTTP headers
  represented by environment-variable names rather than credential values.

The default Codex model is not a Weave force-model instruction. With no force
header or persisted force pin, it is the input model identifier and Weave may
choose a different eligible model.

### Credential indirection

The Weave provider will use static, non-secret metadata in `http_headers` and
environment lookups for runtime identity values:

```toml
[model_providers.weave]
name = "Weave Router"
base_url = "http://127.0.0.1:8080/v1"
wire_api = "responses"
requires_openai_auth = true
supports_websockets = false

[model_providers.weave.http_headers]
X-App = "codex"

[model_providers.weave.env_http_headers]
X-Weave-Router-Key = "WEAVE_ROUTER_KEY"
ChatGPT-Account-ID = "CODEX_CHATGPT_ACCOUNT_ID"
```

The router key remains only in the existing mode-`0600` router state file. The
account ID remains in Codex's private `auth.json`. OAuth bearer and refresh
tokens remain entirely Codex-owned and are selected through
`requires_openai_auth = true` plus `forced_login_method = "chatgpt"`.

Authenticated MCP definitions will use the same indirection. For example, the
Context7 `Authorization` header will read a preformatted
`CONTEXT7_AUTHORIZATION` environment variable. Supplying that value remains the
responsibility of the existing external secret environment; Nix will neither
read nor serialize the token.

### Runtime environment delivery

The Nix-installed `codex` entry point will wrap the real `pkgs.codex` binary.
Immediately before execution it will read the router key from the private router
state file and the account ID from `~/.codex/auth.json`, export only those two
values, and then `exec` the real binary. Values will never appear in command
arguments or logs.

After successful router setup, the activation wrapper will import the same two
variables into the systemd user-manager environment using
`systemctl --user import-environment`. This supports newly launched desktop or
IDE Codex processes that inherit that environment. Existing GUI processes must
be restarted after activation, matching the current router setup guidance.

The wrapper will not fail commands such as `codex login` merely because an
account ID is not present yet. It will export each value only when its owning
file contains a usable value.

### Weave writers

All writers that touch the Codex provider will converge on the same shape:

- `model_provider = "weave"`;
- local Weave base URL;
- `requires_openai_auth = true`;
- no `env_key`, direct bearer token, or API key;
- router key and account ID represented through `env_http_headers`;
- no static copies of those credential values;
- no `X-Weave-Force-Model` header.

The pinned upstream installer integration will be adjusted so it does not place
the router key in its managed Codex block. The local `weave-clients.py` and
Headroom configurator will normalize old installations by removing static
credential headers and replacing them with environment references. Existing
unrelated headers will be preserved.

Old first-install backups may already contain historical credentials. The
implementation will avoid creating new secret-bearing backups and will report
existing backup files for the user to rotate or remove; it will not delete them
without explicit authorization.

### Automatic routing

The worktree's uncommitted router patch currently contains a branch that sets
the internal `forceModel` variable to the incoming Codex model. That assignment
will be removed. The OAuth eligibility patch will remain so an OpenAI Codex
model can be selected when Weave chooses it, while configured non-OpenAI
providers remain eligible for automatic selection.

The router's force-model feature and skills may remain available for explicit
future user requests, but no activation or provider configuration will invoke
them or establish a pin.

## Activation Flow

1. Home Manager installs the wrapped `pkgs.codex` package and the Nix-rendered
   non-secret baseline.
2. The inner activation validates the existing TOML and atomically replaces it
   with the baseline as a mode-`0600` mutable `~/.codex/config.toml`. It does
   not create a new copy of secret-bearing legacy content. Existing `.pre-*`
   backups are left untouched and reported rather than deleted.
3. The outer activation starts or restarts Weave Router.
4. Weave refreshes client helpers and normalizes Codex to environment-backed
   headers.
5. Headroom's post-start configurator reasserts direct Codex-to-Weave routing
   without adding a force header.
6. The activation wrapper reads the two private source files into its process
   environment and imports the variables into the systemd user manager.
7. The interactive Weave ChatGPT enrollment helper runs as it does today.

`--skip-weave-router` will continue to skip service startup and credential
environment import. It will not remove Codex from the Home Manager profile.

## Error Handling

- Invalid existing TOML is never overwritten silently; activation exits with a
  path-specific error.
- Missing router state permits installation and `codex login`, but routed
  requests will clearly lack `WEAVE_ROUTER_KEY` until Weave setup succeeds.
- Missing or malformed `auth.json` does not expose or synthesize credentials;
  the user is directed to `codex login`.
- Static legacy credential headers are removed only from the known Weave and
  Headroom provider tables.
- Existing unrelated Codex settings are either declared in Nix or preserved by
  the narrowly scoped runtime normalizers.

## Verification Strategy

Implementation will follow a red-green cycle for the existing Python writers:

1. Extend fixtures to require `env_http_headers`, ChatGPT-only login, selected
   Weave provider, and absence of static router/account credentials.
2. Confirm those assertions fail against the current implementation.
3. Implement the minimal writer changes and confirm both focused suites pass,
   including consecutive runs.

Then verify the integrated result:

- format changed Nix files and run `git diff --check`;
- run the focused Weave and Headroom client tests;
- evaluate and build the full Home Manager activation package;
- inspect the generated Codex template for the declared values and absence of
  credential material;
- confirm the activation closure contains Codex `0.154.0` and the wrapper calls
  the pinned binary;
- inspect the patched router source to confirm OAuth eligibility remains and the
  internal automatic-routing force assignment is absent;
- do not claim service or request-routing proof because activation is reserved
  for the user's uninstall/reinstall test.

## Acceptance Criteria

- Removing the standalone Codex installation and running the activation script
  restores a working `codex` executable from the Nix profile.
- `codex login status` reports ChatGPT authentication after the existing OAuth
  state is retained or the user completes `codex login`.
- The effective provider is Weave at `127.0.0.1:8080/v1`.
- `config.toml` contains environment-variable names rather than the router key,
  account ID, OAuth tokens, or an OpenAI API key.
- Neither the provider headers nor the router patch establish a forced model.
- Weave can select eligible OpenAI or non-OpenAI models according to its normal
  automatic routing policy.
- Repeated setup remains valid TOML and does not duplicate provider or hook
  entries.
