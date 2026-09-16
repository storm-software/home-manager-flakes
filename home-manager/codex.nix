{
  config,
  lib,
  pkgs,
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
        remoteEnvHeaders =
          if name == "upstash/context7" then
            { Authorization = "CONTEXT7_AUTHORIZATION"; }
          else
            lib.mapAttrs (_header: stripDollar) server.headers;
      in
      {
        url = server.url;
      }
      // lib.optionalAttrs (remoteEnvHeaders != { }) {
        env_http_headers = remoteEnvHeaders;
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
    model_provider = "weave";
    model_reasoning_effort = "high";
    personality = "pragmatic";
    service_tier = "default";
    forced_login_method = "chatgpt";
    openai_base_url = "http://127.0.0.1:8080/v1";

    features = {
      hooks = true;
      memories = true;
      plugins = true;
    };
    memories = {
      generate_memories = true;
      use_memories = true;
    };
    model_providers.weave = {
      name = "Weave Router";
      base_url = "http://127.0.0.1:8080/v1";
      wire_api = "responses";
      requires_openai_auth = true;
      supports_websockets = false;
      http_headers.X-App = "codex";
      env_http_headers = {
        X-Weave-Router-Key = "WEAVE_ROUTER_KEY";
        ChatGPT-Account-ID = "CODEX_CHATGPT_ACCOUNT_ID";
      };
    };
    mcp_servers = codexMcpServers;
    plugins."prisma@plugins-cli".enabled = true;

    projects =
      lib.genAttrs
        [
          "/home/development"
          "/home/development/.config/orca/rate-limit-pty-cwd"
          "/home/development/repos/cyclone-ui"
          "/home/development/repos/home-manager-flakes"
          "/home/development/repos/media-kit"
          "/home/development/repos/powerlines"
          "/home/development/repos/razorwind"
          "/home/development/repos/shell-shock"
          "/home/development/repos/sourcebook"
          "/home/development/repos/storm-dev"
          "/home/development/repos/storm-ops"
          "/home/development/repos/stryke"
        ]
        (_path: {
          trust_level = "trusted";
        });
  };

  codexConfig = tomlFormat.generate "codex-config.toml" codexSettings;

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

  codex = pkgs.writeShellApplication {
    name = "codex";
    runtimeInputs = [ codexRouterEnv ];
    text = ''
      exec ${codexRouterEnv}/bin/codex-router-env exec ${pkgs.codex}/bin/codex "$@"
    '';
    meta = pkgs.codex.meta // {
      mainProgram = "codex";
    };
  };
in
{
  options.storm.codex.routerEnvPackage = lib.mkOption {
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
        assertion = !(codexSettings.model_providers.weave.http_headers ? X-Weave-Force-Model);
        message = "Codex must not force a Weave model";
      }
      {
        assertion = !(codexSettings.model_providers.weave ? env_key);
        message = "Codex must use ChatGPT OAuth, not OPENAI_API_KEY";
      }
      {
        assertion = !(codexSettings ? hooks);
        message = "The Weave installer owns Codex hook registrations; the Nix baseline must not duplicate them";
      }
    ];

    home.packages = [
      codex
      codexRouterEnv
      installCodexConfig
    ];

    home.activation.installCodexConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${installCodexConfig}/bin/install-codex-config \
        ${codexConfig} ${lib.escapeShellArg config.home.homeDirectory}
    '';

    storm.codex.routerEnvPackage = codexRouterEnv;
  };
}
