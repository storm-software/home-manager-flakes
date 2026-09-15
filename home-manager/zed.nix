{ config, pkgs, ... }:

let
  # The router key is created at runtime by weave-router-setup. Keep it out of
  # the Nix store and expose it only to the Zed process that is launched from
  # the dedicated desktop entry below.
  zedWeaveRouter = pkgs.writeShellApplication {
    name = "zed-weave-router";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.zed-editor
    ];
    text = ''
      key_file="${config.xdg.stateHome}/weave-router/router-key"
      if [[ ! -s "$key_file" ]]; then
        echo 'Weave Router is not ready. Start weave-router.service before launching Zed.' >&2
        exit 1
      fi

      export WEAVE_ROUTER_API_KEY
      WEAVE_ROUTER_API_KEY="$(cat "$key_file")"
      exec zeditor "$@"
    '';
  };
in
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

      # Use the existing local router for Zed Agent. Zed resolves the
      # provider's API key from WEAVE_ROUTER_API_KEY, which zed-weave-router
      # reads from the runtime-only router state.
      language_models.openai_compatible."weave-router" = {
        api_url = "http://127.0.0.1:8080/v1";
        available_models = [
          {
            name = "claude-sonnet-4-6";
            display_name = "Weave Router (automatic)";
            max_tokens = 200000;
            max_output_tokens = 16384;
            capabilities = {
              tools = true;
              images = false;
              parallel_tool_calls = false;
              prompt_cache_key = false;
              chat_completions = true;
              interleaved_reasoning = false;
              max_tokens_parameter = false;
            };
          }
        ];
      };

      agent = {
        default_model = {
          provider = "weave-router";
          model = "gpt-5.6-terra";
        };
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

  home.packages = [ zedWeaveRouter ];

  xdg.desktopEntries.zed-weave-router = {
    name = "Zed (Weave Router)";
    comment = "Zed editor with the local Weave Router credential";
    exec = "${zedWeaveRouter}/bin/zed-weave-router %U";
    icon = "zed";
    terminal = false;
    categories = [
      "Development"
      "IDE"
      "TextEditor"
    ];
    mimeType = [
      "text/plain"
      "text/x-nix"
      "inode/directory"
    ];
  };
}
