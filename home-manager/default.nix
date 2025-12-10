{ homeDirectory
, pkgs
, stateVersion
, system
, username
}:

let
  # The packages to load into the PATH
  packages = import ./packages.nix { inherit homeDirectory pkgs; };
in
{
  # Fonts config
  fonts = { fontconfig = { enable = true; }; };

  home = {
    inherit homeDirectory packages stateVersion username;

    shell.enableZshIntegration = true;
    shellAliases = {
      reload-home-manager-config = "home-manager switch --flake ${builtins.toString ./.}";
    };
  };

  xdg.autostart.enable = true;

  editorconfig = {
    settings = {
      "*" = {
        charset = "utf-8";
        end_of_line = "lf";
        trim_trailing_whitespace = true;
        insert_final_newline = true;
        max_line_width = 78;
        indent_style = "space";
        indent_size = 4;
      };
    };
    enable = true;
  };

  # Configure Nix itself (using an unstable version)
  nix = import ./nix.nix { nix = pkgs.nixUnstable; };

  # Nixpkgs config
  nixpkgs = import ./nixpkgs.nix { inherit system; };

  # Configurations for programs directly supported by Home Manager
  programs = import ./programs.nix { inherit homeDirectory pkgs; };

  services = import ./services.nix { inherit homeDirectory pkgs; };
}
