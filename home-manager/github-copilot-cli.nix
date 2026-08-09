{ pkgs }:

{
  enable = true;
  package = pkgs.unstable.github-copilot-cli;

  # Nix owns the package binary; keep upstream auto-update off.
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

    # Prefer OS keychain over plaintext token storage in config.json.
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

    allowedUrls = [
      "*.github.com"
      "*.githubusercontent.com"
      "api.githubcopilot.com"
    ];

    ide = {
      autoConnect = true;
      openDiffOnEdit = true;
    };

    mergeStrategy = "rebase";
  };

  context = ''
    Prefer actionable findings and focused diffs over general commentary.
    Follow existing project conventions; do not introduce drive-by refactors.
    For Nix/Home Manager changes, keep overlays and package scope correct
    (especially with useGlobalPkgs) and avoid editing generated hardware configs.
  '';

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
}
