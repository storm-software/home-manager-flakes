{
  pkgs,
  pkgsUnstable,
  currentUser,
}:

let
  # The packages to load into the PATH
  packages = import ./packages.nix { inherit pkgs pkgsUnstable currentUser; };
  lib = {
    teams = {
      storm = {
        name = "Storm Software";
        email = "contact@stormsoftware.com";
      };
    };
    maintainers = {
      sullivanpj = {
        name = "Pat Sullivan";
        email = "pat@patsullivan.org";
      };
    };
  };
in
{
  meta = {
    maintainers = with lib.maintainers; [ sullivanpj ];
    teams = with lib.teams; [ storm ];
  };

  manual = {
    html.enable = true;
    json.enable = true;
    manpages.enable = true;
  };

  news.display = "show";

  fonts.fontconfig = import ./fontconfig.nix;
  editorconfig = import ./editorconfig.nix;

  home = {
    inherit packages;

    stateVersion = "25.11";
    username = currentUser.system.username;
    homeDirectory = currentUser.system.homeDirectory;

    shell.enableZshIntegration = true;
    shellAliases = (import ./aliases.nix { inherit currentUser; }).shell;
  };

  xdg.autostart.enable = true;

  nix = import ./nix.nix { inherit pkgs; };
  nixpkgs = import ./nixpkgs.nix;

  programs = import ./programs.nix { inherit pkgs pkgsUnstable currentUser; };
  services = import ./services.nix { inherit pkgs pkgsUnstable currentUser; };
}
