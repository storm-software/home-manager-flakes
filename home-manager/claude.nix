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
in
{
  home.packages = [
    pkgs.claude-code
    configureClaude
  ];

  # Claude Code retains its own subscription session. This activation only
  # supplies the local proxy endpoint and removes any legacy API-key override.
  home.activation.configureClaude = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD ${configureClaude}/bin/configure-claude
  '';
}
