{ pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    enableMcpIntegration = true;

    # Zed's Nix extension discovers nixd and nixfmt via the editor PATH.
    extraPackages = [
      pkgs.nixd
      pkgs.nixfmt
    ];

    extensions = [
      "nix"
      "toml"
      "yaml"
      "dockerfile"
      "terraform"
      "just"
    ];

    userSettings = {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      terminal.shell = {
        program = "zsh";
      };

      agent = {
        profiles.write = {
          name = "Write";
          tools = {
            read_file = true;
            grep = true;
            terminal = true;
            edit_file = true;
          };
          enable_all_context_servers = true;
          context_servers = { };
        };
      };

      # Zed owns the ACP adapter lifecycle; Codex itself continues to use the
      # router-managed ~/.codex configuration and its ChatGPT OAuth session.
      agent_servers.codex-acp = {
        type = "registry";
      };

      format_on_save = "on";
      languages.Nix = {
        language_servers = [ "nixd" ];
        formatter = {
          external = {
            command = "nixfmt";
            arguments = [ ];
          };
        };
      };
    };

    userTasks = [
      {
        label = "Nix: format flake";
        command = "nix";
        args = [
          "fmt"
          "$ZED_WORKTREE_ROOT"
        ];
      }
      {
        label = "Nix: flake check";
        command = "nix";
        args = [
          "flake"
          "check"
          "--no-build"
          "$ZED_WORKTREE_ROOT"
        ];
      }
    ];
  };
}
