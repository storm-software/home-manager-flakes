{
  config,
  lib,
  pkgs,
  ...
}:

let
  revision = "7909ce56d6c79b1a341f774bb0fb36a36601392d";
  source = pkgs.applyPatches {
    name = "weave-router-${revision}-codex-oauth-routing";
    src = pkgs.fetchFromGitHub {
      owner = "weave-os";
      repo = "router";
      rev = revision;
      hash = "sha256-qVzEbpuYicdy2IQFwisC8GaJHPPQgpdq5clp8dd3WHg=";
    };
    patches = [ ./patches/weave-router-codex-env-headers.patch ];
    # Codex keeps its ChatGPT OAuth bearer in Authorization while the router
    # key is in X-Weave-Router-Key. The pinned server discovers that pair while
    # filtering models. Admit validated OAuth in the eligibility function,
    # before exclusions and gateway policy, and retain native dispatch auth.
    postPatch = ''
      target=internal/server/middleware/auth.go
      substituteInPlace "$target" --replace-fail \
        $'\t\tfinishAuthSpan(authSpan, nil)\n' \
        $'\t\t// Codex preserves its ChatGPT OAuth bearer in Authorization while the router key rides in X-Weave-Router-Key.\n\t\t// Validate the standard bearer and account-id pair before using it, so ordinary API keys never become subscriptions.\n\t\tif strings.TrimSpace(c.GetHeader(OpenAISubscriptionHeader)) == "" {\n\t\t\tif raw, ok := strings.CutPrefix(c.GetHeader("Authorization"), "Bearer "); ok {\n\t\t\t\tsub := strings.TrimSpace(raw)\n\t\t\t\tacct := strings.TrimSpace(c.GetHeader("ChatGPT-Account-ID"))\n\t\t\t\tif requestcontext.CodexSubscriptionCreds(sub, acct) != nil {\n\t\t\t\t\tctx = context.WithValue(ctx, proxy.OpenAISubscriptionContextKey{}, sub)\n\t\t\t\t\tctx = context.WithValue(ctx, proxy.OpenAIAccountIDContextKey{}, acct)\n\t\t\t\t}\n\t\t\t}\n\t\t}\n\t\tfinishAuthSpan(authSpan, nil)\n'
      substituteInPlace "$target" --replace-fail \
        $'\t"weave-os/router/internal/proxy"\n' \
        $'\t"weave-os/router/internal/proxy"\n\t"weave-os/router/internal/requestcontext"\n'
      target=internal/proxy/service.go
      substituteInPlace "$target" --replace-fail \
        $'\tif c := ExtractClientCredentials(providers.ProviderOpenAI, headers); c != nil && c.OAuth {\n\t\tout[providers.ProviderOpenAI] = struct{}{}\n\t}' \
        $'\tif raw, ok := strings.CutPrefix(headers.Get("Authorization"), "Bearer "); ok {\n\t\tif requestcontext.CodexSubscriptionCreds(raw, headers.Get("ChatGPT-Account-ID")) != nil {\n\t\t\tout[providers.ProviderOpenAI] = struct{}{}\n\t\t}\n\t}'
      substituteInPlace "$target" --replace-fail \
        $'\tif s.codexSubscriptionExhausted(ctx, r.Header) {\n\t\tctx = withSuppressedCodexSubscription(ctx)\n\t}\n\tctx = resolveAndInjectCredentials(ctx, decision.Provider, decision.Model, r.Header)\n\topts.FastMode = fastModeForAttempt(ctx, decision.Model, decision.Provider)\n' \
        $'\tif s.codexSubscriptionExhausted(ctx, r.Header) {\n\t\tctx = withSuppressedCodexSubscription(ctx)\n\t}\n\tctx = resolveAndInjectCredentials(ctx, decision.Provider, decision.Model, r.Header)\n\t// Codex preserves its ChatGPT OAuth bearer while using a router key. The\n\t// installation policy may have removed the transient subscription context,\n\t// so restore only a validated bearer for the native Codex model family.\n\t// This makes the OpenAI adapter choose chatgpt.com/backend-api/codex rather\n\t// than the API-key-only api.openai.com endpoint.\n\tif decision.Provider == providers.ProviderOpenAI && !servedOnCodexSubscription(ctx) {\n\t\tif raw, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer "); ok {\n\t\t\tif sub := requestcontext.CodexSubscriptionCreds(raw, r.Header.Get("ChatGPT-Account-ID")); sub != nil && requestcontext.CodexSubscriptionCoversModel(decision.Model) {\n\t\t\t\tctx = context.WithValue(ctx, CredentialsContextKey{}, sub)\n\t\t\t}\n\t\t}\n\t}\n\topts.FastMode = fastModeForAttempt(ctx, decision.Model, decision.Provider)\n'
      if grep -Fq 'local headers_parts="\"X-Weave-Router-Key\" = \"''${esc_key}\""' install/install.sh; then
        echo "Codex installer still serializes the Weave router key" >&2
        exit 1
      fi
      grep -Fq 'env_http_headers = { "X-Weave-Router-Key" = "WEAVE_ROUTER_KEY", "ChatGPT-Account-ID" = "CODEX_CHATGPT_ACCOUNT_ID" }' install/install.sh
      if grep -Fq 'forceModel = feats.Model' internal/proxy/service.go; then
        echo "Codex OAuth path must not force the incoming model" >&2
        exit 1
      fi
      grep -Fq 'if requestcontext.CodexSubscriptionCreds(raw, headers.Get("ChatGPT-Account-ID")) != nil {' internal/proxy/service.go
      grep -Fq 'if sub := requestcontext.CodexSubscriptionCreds(raw, r.Header.Get("ChatGPT-Account-ID")); sub != nil && requestcontext.CodexSubscriptionCoversModel(decision.Model) {' internal/proxy/service.go
      grep -Fq 'ctx = context.WithValue(ctx, CredentialsContextKey{}, sub)' internal/proxy/service.go
      ${pkgs.python3}/bin/python ${./scripts/test-weave-codex-readers.py} .
      ${pkgs.python3}/bin/python ${./scripts/test-weave-codex-routing.py} . ${pkgs.go}/bin/go ${./scripts/weave-codex-routing-fixture.go}
    '';
  };
  # The input-addressed source hash includes every patch and postPatch change.
  # Docker's image-exists shortcut must never reuse a differently patched tree.
  sourceFingerprint = builtins.substring 0 32 (builtins.baseNameOf "${source}");
  imageTag = "${revision}-${sourceFingerprint}";
  state = "${config.xdg.stateHome}/weave-router";
  python = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.tomlkit
  ]);
  # Keep upstream's dependency graph, migrations, native libraries and model
  # assets together. Only deployment-specific settings differ from upstream.
  composeFile = pkgs.runCommand "weave-router-compose.json" { } ''
    ${python}/bin/python ${./scripts/weave-compose.py} ${source} ${lib.escapeShellArg state} ${./scripts/weave-keygen.go} ${revision} weave-router:${imageTag} > "$out"
  '';
  compose = pkgs.writeShellApplication {
    name = "weave-router-compose";
    runtimeInputs = [
      pkgs.docker
      pkgs.docker-compose
    ];
    text = ''
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR:?}/weave-docker/docker.sock"
      export DOCKER_BUILDKIT=1
      exec docker-compose --project-name weave-router --env-file ${lib.escapeShellArg "${state}/secrets.env"} -f ${composeFile} "$@"
    '';
  };
  setup = pkgs.writeShellApplication {
    name = "weave-router-setup";
    runtimeInputs = [
      compose
      python
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.git
      pkgs.nodejs_24
      pkgs.util-linux
      pkgs.docker
    ];
    text = ''
      export WEAVE_STATE=${lib.escapeShellArg state}
      export WEAVE_SOURCE=${source}
      export WEAVE_IMAGE=weave-router:${imageTag}
      export WEAVE_REVISION=${revision}
      export WEAVE_CLIENT_HOME=${lib.escapeShellArg config.home.homeDirectory}
      export WEAVE_CONFIGURE=${./scripts/weave-clients.py}
      exec bash ${./scripts/weave-setup.sh} "$@"
    '';
  };
  loginCodex = pkgs.writeShellApplication {
    name = "weave-router-login-codex";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.openssl
    ];
    text = ''
      state=${lib.escapeShellArg state}
      key_file="$state/router-key"
      if [[ ! -s "$key_file" ]]; then
        echo 'Weave Router has no client key; start weave-router.service first.' >&2
        exit 1
      fi

      response="$(mktemp)"
      trap 'rm -f "$response"' EXIT
      status="$(${pkgs.coreutils}/bin/printf 'header = "X-Weave-Router-Key: %s"\n' "$(<"$key_file")" |
        curl --config - --silent --show-error --output "$response" --write-out '%{http_code}' \
          http://127.0.0.1:8080/v1/subscriptions/accounts)"
      if [[ "$status" != 200 ]]; then
        echo "Could not inspect Weave subscription accounts (HTTP $status)." >&2
        exit 1
      fi
      if jq -e 'any(.[]; .provider == "codex" and .enabled == true)' "$response" >/dev/null; then
        echo 'ChatGPT subscription is already enrolled with Weave Router.'
        exit 0
      fi
      if [[ ! -t 0 ]]; then
        echo 'ChatGPT OAuth enrollment requires an interactive terminal.' >&2
        echo 'Run weave-router-login-codex from a terminal.' >&2
        exit 1
      fi

      export WEAVE_ROUTER_KEY
      WEAVE_ROUTER_KEY="$(<"$key_file")"
      exec bash ${source}/install/install.sh login codex --codex --scope user \
        --base-url http://127.0.0.1:8080
    '';
  };
in
{
  home.packages = [
    compose
    setup
    loginCodex
  ];

  # Dedicated rootless daemon: does not change the user's Docker context or
  # expose an unauthenticated TCP socket. Host uidmap helpers must be installed.
  systemd.user.services.weave-docker = {
    Unit.Description = "Rootless Docker for Weave Router";
    Service = {
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.util-linux
          ]
        }:/run/wrappers/bin:/usr/bin:/bin"
        "DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR=%t/weave-docker/rootlesskit"
      ];
      RuntimeDirectory = "weave-docker";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless --host=unix://%t/weave-docker/docker.sock --data-root=${state}/docker --exec-root=%t/weave-docker/exec --pidfile=%t/weave-docker/docker.pid";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStartSec = 0;
      Delegate = true;
      KillMode = "mixed";
      LimitNOFILE = "infinity";
      LimitNPROC = "infinity";
      TasksMax = "infinity";
    };
  };

  systemd.user.services.weave-router = {
    Unit = {
      Description = "Self-hosted Weave Router and agent configuration";
      Requires = [ "weave-docker.service" ];
      After = [ "weave-docker.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${setup}/bin/weave-router-setup";
      ExecStop = "${compose}/bin/weave-router-compose stop";
      TimeoutStartSec = "infinity";
      TimeoutStopSec = 120;
      UMask = "0077";
    };
    # Activation starts this after the router has configured its initial state.
    # Leaving it out of default.target prevents a second setup at login;
    # activation starts it after installing the client settings.
  };

  xdg.configFile."weave-router/README.md".source = ./weave-router.md;
}
