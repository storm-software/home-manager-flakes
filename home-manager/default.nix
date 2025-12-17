{
  homeDirectory,
  pkgs,
  pkgs-unstable,
  stateVersion,
  system,
  username,
  signingKey,
  gitUser,
}:

let
  # The packages to load into the PATH
  packages = import ./packages.nix { inherit homeDirectory pkgs; };
in
{
  fonts = {
    fontconfig = {
      enable = true;
    };
  };
  editorconfig = {
    enable = true;
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
  };

  home = {
    inherit
      homeDirectory
      packages
      stateVersion
      username
      ;

    shell.enableZshIntegration = true;
    shellAliases = {
      reload-home-manager-config = "home-manager switch --flake ${builtins.toString ./.}";
    };
  };

  xdg.autostart.enable = true;

  nix = import ./nix.nix { inherit pkgs; };
  nixpkgs = import ./nixpkgs.nix { inherit system; };

  programs = import ./programs.nix {
    inherit
      username
      signingKey
      homeDirectory
      pkgs
      pkgs-unstable
      gitUser
      ;
  };
  services = import ./services.nix { inherit homeDirectory pkgs; };
}
