{
  homeDirectory,
  pkgs,
  pkgsUnstable,
  stateVersion,
  system,
  username,
  signingKey,
  gitUser,
}:

let
  # The packages to load into the PATH
  packages = import ./packages.nix {
    inherit
      homeDirectory
      pkgs
      pkgsUnstable
      ;
  };
in
{
  fonts.fontconfig = import ./fontconfig.nix;
  editorconfig = import ./editorconfig.nix;

  home = {
    inherit
      homeDirectory
      packages
      stateVersion
      username
      ;

    shell.enableZshIntegration = true;
    shellAliases = {
      reload-home-manager-config = "home-manager switch -b backup --flake ${builtins.toString ./.}";
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
      pkgsUnstable
      gitUser
      ;
  };
  services = import ./services.nix {
    inherit
      homeDirectory
      username
      pkgs
      pkgsUnstable
      ;
  };
}
