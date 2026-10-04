{ pkgs }:

# Copilot CLI stores user settings in settings.json. Home Manager's
# programs.github-copilot-cli.settings still writes config.json, which Copilot
# treats as auto-managed runtime state: it migrates those keys into
# settings.json and replaces the HM symlink. The next activation then tries to
# back up config.json onto an existing config.json.backup and aborts.
{ config, ... }:

let
  jsonFormat = pkgs.unstable.formats.json { };

  settings = {
    autoUpdate = false;
    autoUpdatesChannel = "stable";

    model = "auto";
    effortLevel = "medium";
    theme = "github";

    stream = true;
    renderMarkdown = true;
    respectGitignore = true;
    includeCoAuthoredBy = true;

    banner = "once";
    mouse = true;
    screenReader = false;
    showTipsOnStartup = true;
    updateTerminalTitle = true;
    terminalProgress = true;

    # Prefer OS keychain over plaintext token storage.
    storeTokenPlaintext = false;

    askUser = true;
    stayInAutopilot = true;

    # Leave sandbox off by default (needs bubblewrap on Linux). Pre-configure
    # auth injection and local-network access for when `/sandbox enable` is used.
    sandbox = {
      enabled = false;
      allowBypass = true;
      gitAuth = true;
      ghAuth = true;
      userPolicy = {
        network = {
          allowLocalNetwork = true;
        };
      };
    };

    ide = {
      autoConnect = true;
      openDiffOnEdit = true;
    };

    mergeStrategy = "rebase";
  };

  copilotHome = "${config.home.homeDirectory}/.copilot";
in
{
  programs.github-copilot-cli = {
    enable = true;
    package = pkgs.unstable.github-copilot-cli;

    # Context7 matches the VS Code MCP setup. Set CONTEXT7_API_KEY in the
    # environment for higher rate limits ($ denotes an env-var reference).
    mcpServers = {
      context7 = {
        type = "http";
        url = "https://mcp.context7.com/mcp";
        headers = {
          CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
        };
        tools = [ "*" ];
      };
    };
  };

  home.file."${copilotHome}/settings.json" = {
    force = true;
    source = jsonFormat.generate "github-copilot-cli-settings.json" settings;
  };

  # Copilot may replace this symlink after writing MCP state; force avoids a
  # second backup-collision on activate.
  home.file."${copilotHome}/mcp-config.json".force = true;
}
