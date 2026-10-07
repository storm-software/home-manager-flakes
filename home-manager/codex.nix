{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  stripDollar =
    value:
    if lib.hasPrefix "$" value then
      lib.removePrefix "$" value
    else
      throw "Codex secret-bearing MCP values must be environment references beginning with '$'";

  codexMcpServer =
    name: server:
    if server.url != null then
      let
        # `$VAR` headers carry secrets and are read from the environment;
        # anything else is a literal, non-secret header value.
        remoteEnvHeaders = lib.mapAttrs (_header: stripDollar) (
          lib.filterAttrs (_header: lib.hasPrefix "$") server.headers
        );
        remoteLiteralHeaders = lib.filterAttrs (_header: value: !lib.hasPrefix "$" value) server.headers;
      in
      {
        url = server.url;
      }
      // lib.optionalAttrs (remoteLiteralHeaders != { }) {
        http_headers = remoteLiteralHeaders;
      }
      // lib.optionalAttrs (remoteEnvHeaders != { }) {
        env_http_headers = remoteEnvHeaders;
      }
      // lib.optionalAttrs (name == "github") {
        bearer_token_env_var = "CODEX_GITHUB_PERSONAL_ACCESS_TOKEN";
      }
    else
      let
        inheritedEnv = lib.filterAttrs (
          _variable: value: builtins.isString value && lib.hasPrefix "$" value
        ) server.env;
        literalEnv = lib.filterAttrs (
          _variable: value: builtins.isString value && !lib.hasPrefix "$" value
        ) server.env;
      in
      {
        command = server.command;
        args = server.args;
      }
      // lib.optionalAttrs (literalEnv != { }) { env = literalEnv; }
      // lib.optionalAttrs (inheritedEnv != { }) {
        env_vars = map stripDollar (lib.attrValues inheritedEnv);
      };

  codexMcpServers = lib.mapAttrs codexMcpServer config.programs.mcp.servers;
  tomlFormat = pkgs.formats.toml { };
  codexSettings = {
    model = "gpt-5.6-terra";
    model_reasoning_effort = "high";
    personality = "pragmatic";
    service_tier = "default";
    forced_login_method = "chatgpt";
    features = {
      hooks = true;
      memories = true;
      plugins = true;
    };
    memories = {
      generate_memories = true;
      use_memories = true;
    };
    tui = {
      status_line = [
        "model"
        "context-window-size"
        "context-remaining"
      ];
    };
    mcp_servers = codexMcpServers;
    plugins."prisma@plugins-cli".enabled = true;

    projects = lib.genAttrs (import ./trusted-projects.nix) (_path: {
      trust_level = "trusted";
    });
  };

  mindctlCodexSettings = codexSettings // {
    model = "mindctl-auto";
    model_provider = "mindctl";
    openai_base_url = "http://127.0.0.1:8080/v1";
    model_providers.mindctl = {
      name = "Mindctl";
      base_url = "http://127.0.0.1:8080/v1";
      wire_api = "responses";
      requires_openai_auth = true;
      supports_websockets = false;
      http_headers.X-App = "codex";
      env_http_headers = {
        X-Mindctl-Token = "MINDCTL_GATEWAY_TOKEN";
        ChatGPT-Account-ID = "CODEX_CHATGPT_ACCOUNT_ID";
      };
    };
  };

  directCodexConfig = tomlFormat.generate "codex-config-direct.toml" codexSettings;
  mindctlCodexConfig = tomlFormat.generate "codex-config-mindctl.toml" mindctlCodexSettings;

  installCodexConfig = pkgs.writeShellApplication {
    name = "install-codex-config";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.python3
    ];
    text = ''
      exec bash ${./scripts/install-codex-config.sh} "$@"
    '';
  };

  codexRouterEnv = pkgs.writeShellApplication {
    name = "codex-router-env";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.jq
      pkgs.systemd
    ];
    text = ''
      exec bash ${./scripts/codex-router-env.sh} "$@"
    '';
  };

  secretspecPassCli = pkgs.writeShellApplication {
    name = "secretspec-pass-cli";
    runtimeInputs = [
      pkgs.bash
      pkgsUnstable.proton-pass-cli
    ];
    text = ''
      exec bash ${./scripts/secretspec-pass-cli.sh} "$@"
    '';
  };

  codexSecretsEnv = pkgs.writeShellApplication {
    name = "codex-secrets-env";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.secretspec
      secretspecPassCli
      codexRouterEnv
    ];
    text = ''
      export SECRETSPEC_FILE=${lib.escapeShellArg "${../secretspec.toml}"}
      export SECRETSPEC_PROTONPASS_CLI_PATH=${lib.escapeShellArg "${secretspecPassCli}/bin/secretspec-pass-cli"}
      export CODEX_ROUTER_ENV=${lib.escapeShellArg "${codexRouterEnv}/bin/codex-router-env"}
      exec bash ${./scripts/codex-secrets-env.sh} "$@"
    '';
  };

  codex = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ codexSecretsEnv ];
    text = ''
      exec ${codexSecretsEnv}/bin/codex-secrets-env exec ${pkgs.codex}/bin/codex "$@"
    '';
    meta = pkgs.codex.meta // {
      mainProgram = "codex";
    };
  };

  codexVscode = pkgs.writeShellApplication {
    name = "codex-vscode";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      codexSecretsEnv
    ];
    text = ''
      export CODEX_SECRETS_ENV=${lib.escapeShellArg "${codexSecretsEnv}/bin/codex-secrets-env"}
      exec bash ${./scripts/codex-vscode.sh} "$@"
    '';
  };

  configureCodexVscode = pkgs.writeShellApplication {
    name = "configure-codex-vscode";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./scripts/configure-codex-vscode.py} "$@"
    '';
  };
in
{
  options.storm.codex.secretsEnvPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    internal = true;
  };

  config = {
    assertions = [
      {
        assertion = lib.all (server: lib.all builtins.isString (lib.attrValues server.env)) (
          lib.attrValues config.programs.mcp.servers
        );
        message = "Codex MCP translation currently requires string env references";
      }
      {
        assertion = codexSettings.model == "gpt-5.6-terra";
        message = "Codex must use gpt-5.6-terra as its request model";
      }
      {
        assertion = !(mindctlCodexSettings.model_providers.mindctl ? env_key);
        message = "Mindctl must use ChatGPT OAuth, not OPENAI_API_KEY";
      }
      {
        assertion = !(codexSettings ? hooks);
        message = "Mindctl installs Codex hook registrations; the Nix baseline must not duplicate them";
      }
    ];

    home.packages = [
      codex
      codexRouterEnv
      codexSecretsEnv
      codexVscode
      configureCodexVscode
      installCodexConfig
    ];

    # Orca launches this standalone-install path directly instead of resolving
    # Codex from PATH. Route it through the managed wrapper so local router
    # credentials are loaded for every newly started Orca session.
    home.file.".local/bin/codex" = {
      source = "${codex}/bin/codex";
      force = true;
    };

    # Devenv can run arbitrary commands with Nix daemon access, which crosses
    # the normal Codex sandbox boundary. Require approval for every invocation
    # without replacing Codex's mutable default.rules file.
    home.file.".codex/rules/devenv.rules" = {
      force = true;
      text = ''
        prefix_rule(
            pattern = ["devenv"],
            decision = "prompt",
            justification = "Review each devenv command requiring Nix daemon access.",
            match = [
                "devenv shell -- true",
                "devenv --no-tui shell -- pnpm test",
            ],
            not_match = [
                "git status --short",
            ],
        )
      '';
    };

    home.activation.installCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      case "''${STORM_AGENT_ROUTER_MODE:-mindctl}" in
        mindctl) codex_config=${mindctlCodexConfig} ;;
        direct) codex_config=${directCodexConfig} ;;
        *)
          echo "Unknown agent router mode: ''${STORM_AGENT_ROUTER_MODE}" >&2
          exit 1
          ;;
      esac
      $DRY_RUN_CMD ${installCodexConfig}/bin/install-codex-config \
        "$codex_config" ${lib.escapeShellArg config.home.homeDirectory}
    '';

    # Mindctl owns its status/directive hooks and the matching toggle skills.
    # Run after the declarative template so the hook registrations survive each
    # activation without making the template itself mutable.
    home.activation.installMindctlCodexHelpers =
      lib.hm.dag.entryAfter
        [
          "installCodexConfig"
          "setupMindctlRouter"
        ]
        ''
          if [ "''${STORM_AGENT_ROUTER_MODE:-mindctl}" = mindctl ]; then
            $DRY_RUN_CMD ${config.storm.mindctl.package}/bin/mindctl --codex
          fi
        '';

    # The VS Code extension normally launches its bundled Codex directly,
    # bypassing the managed PATH wrapper. Point it at a compatibility launcher
    # that still selects the newest extension-bundled binary while loading the
    # same router credentials as terminal sessions.
    home.activation.configureCodexVscode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${configureCodexVscode}/bin/configure-codex-vscode \
        ${lib.escapeShellArg "${config.xdg.configHome}/Code - Insiders/User/settings.json"} \
        ${lib.escapeShellArg "${codexVscode}/bin/codex-vscode"}
    '';

    storm.codex.secretsEnvPackage = codexSecretsEnv;
  };
}
