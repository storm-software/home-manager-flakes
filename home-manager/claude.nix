{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Claude Code expands `${VAR}` in MCP config; the shared servers use `$VAR`.
  envRef =
    value:
    if lib.hasPrefix "$" value then
      "\${${lib.removePrefix "$" value}}"
    else
      throw "Claude secret-bearing MCP values must be environment references beginning with '$'";

  # Mirrors the Codex translation so both agents authenticate identically.
  claudeMcpServer =
    name: server:
    if server.url != null then
      {
        type = "http";
        url = server.url;
        headers =
          if name == "upstash/context7" then
            { Authorization = envRef "$CONTEXT7_AUTHORIZATION"; }
          else if
            lib.elem name [
              "github/github-mcp-server"
              "io.github.github/github-mcp-server"
            ]
          then
            { Authorization = "Bearer ${envRef "$CODEX_GITHUB_PERSONAL_ACCESS_TOKEN"}"; }
          else
            lib.mapAttrs (_header: envRef) server.headers;
      }
    else
      {
        type = "stdio";
        command = server.command;
        args = server.args;
        env = lib.mapAttrs (
          _variable: value: if lib.hasPrefix "$" value then envRef value else value
        ) server.env;
      };

  # Baseline merged into the mutable settings.json. The Weave installer and
  # Orca also write there (router headers, status line, hooks), so Home
  # Manager must not replace it with a read-only store symlink.
  claudeSettings = {
    forceLoginMethod = "claudeai";
    effortLevel = "medium";
    autoMemoryEnabled = true;
    enabledPlugins."prisma@prisma" = true;
    includeCoAuthoredBy = false;
    attribution = {
      commit = "Co-Authored-By: Mindctl Router <bot@stormsoftware.com>";
      pr = "🤖 Generated with [Mindctl Router](https://stormsoftware.com/projects/mindctl)";
    };
    permissions = {
      allow = [
        "Bash(git diff:*)"
        "Bash(curl:*)"
        "Bash(nix build *)"
        "Bash(nix flake *)"
        "Bash(nix eval *)"
        "Bash(nix-build *)"
        "Bash(nix-prefetch-url *)"
        "Bash(devenv *)"
        "Bash(home-manager switch *)"
        "Bash(tar *)"
        "Bash(go mod *)"
        "Bash(go test *)"
        "Bash(go build *)"
        "Bash(gofmt *)"
        "Bash(npm *)"
        "Bash(npx *)"
        "Bash(pnpm *)"
        "Bash(pnpx *)"
        "Bash(bun *)"
        "Bash(bunx *)"
        "Bash(cargo *)"
        "Bash(python3 *)"
        "Bash(sqlite3 *)"
        "Bash(echo *)"
        "Bash(jq *)"
        "Bash(ls *)"
        "Bash(grep *)"
        "Bash(curl *)"
        "Bash(awk *)"
        "Bash(secretspec *)"
        "Bash(xxd -r -p)"
        "Bash(grep *)"
        "Bash(pkill -f \"http.server *\")"
        "WebFetch"
        "Read(//tmp/**)"
        "Read(./.env)"
        "Edit"
      ];
      ask = [
        "Bash(git push:*)"
        "Bash(git commit:*)"
      ];
      defaultMode = "acceptEdits";
    };
  };

  jsonFormat = pkgs.formats.json { };
  claudeSettingsFile = jsonFormat.generate "claude-settings.json" claudeSettings;
  trustedProjectsFile = jsonFormat.generate "claude-trusted-projects.json" (
    import ./trusted-projects.nix
  );

  configureClaude = pkgs.writeShellApplication {
    name = "configure-claude";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./scripts/configure-claude.py} \
        ${lib.escapeShellArg config.home.homeDirectory} \
        ${claudeSettingsFile} \
        ${trustedProjectsFile}
    '';
  };
  installClaudeVscode = pkgs.writeShellApplication {
    name = "install-claude-vscode";
    runtimeInputs = [ pkgs.bash ];
    text = ''
      exec bash ${./scripts/install-claude-vscode.sh} "$@"
    '';
  };

  # Load the same Proton Pass MCP credentials as Codex. The version is kept so
  # the Home Manager module still loads MCP servers as a personal plugin.
  claude =
    (pkgs.writeShellApplication {
      name = "claude";
      runtimeInputs = [ config.storm.codex.secretsEnvPackage ];
      text = ''
        exec ${config.storm.codex.secretsEnvPackage}/bin/codex-secrets-env exec ${pkgs.claude-code}/bin/claude "$@"
      '';
      meta = pkgs.claude-code.meta // {
        mainProgram = "claude";
      };
    }).overrideAttrs
      { inherit (pkgs.claude-code) version; };
in
{
  assertions = [
    {
      assertion = !(claudeSettings ? env);
      message = "configure-claude owns the Claude env block (Headroom endpoint, no API key)";
    }
    {
      assertion = !(claudeSettings ? hooks) && !(claudeSettings ? statusLine);
      message = "The Weave and Orca installers own Claude hooks and status line; the Nix baseline must not duplicate them";
    }
  ];

  programs.claude-code = {
    enable = true;
    package = claude;
    enableMcpIntegration = true;
    mcpServers = lib.mapAttrs claudeMcpServer config.programs.mcp.servers;
  };

  home.packages = [
    configureClaude
    installClaudeVscode
  ];

  # Claude Code retains its own subscription session. This activation supplies
  # the local proxy endpoint, removes any legacy API-key override, merges the
  # Nix settings baseline, and trusts the shared project list.
  home.activation.configureClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${configureClaude}/bin/configure-claude
  '';

  home.activation.installClaudeVscode = lib.hm.dag.entryAfter [ "configureClaude" ] ''
    $DRY_RUN_CMD ${installClaudeVscode}/bin/install-claude-vscode
  '';
}
