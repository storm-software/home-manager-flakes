{
  config,
  lib,
  pkgs,
  ...
}:

let
  configureClaude = pkgs.writeShellApplication {
    name = "configure-claude";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./scripts/configure-claude.py} ${lib.escapeShellArg config.home.homeDirectory}
    '';
  };
  installClaudeVscode = pkgs.writeShellApplication {
    name = "install-claude-vscode";
    runtimeInputs = [ pkgs.bash ];
    text = ''
      exec bash ${./scripts/install-claude-vscode.sh} "$@"
    '';
  };
in
{
  home.packages = [
    pkgs.claude-code
    configureClaude
    installClaudeVscode
  ];

  # Claude Code retains its own subscription session. This activation only
  # supplies the local proxy endpoint and removes any legacy API-key override.
  home.activation.configureClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${configureClaude}/bin/configure-claude
  '';

  home.activation.installClaudeVscode = lib.hm.dag.entryAfter [ "configureClaude" ] ''
    $DRY_RUN_CMD ${installClaudeVscode}/bin/install-claude-vscode
  '';
}
