{ homeDirectory, substituteAll }:

{
  enable = true;
  enableAutosuggestions = true;
  enableCompletion = true;
  enableVteIntegration = true;

  history = {
    append = true;
    share = true;
    save = 90000;
    size = 90000;
    ignoreDups = true;
    saveNoDups = true;
    extended = true;
  };

  historySubstringSearch.enabled = true;

#   oh-my-zsh = {
#     custom = ".oh-my-zsh/custom";
#     theme = "drofloh";
#     plugins = [
# #             {
# #                 name = "enhancd";
# #                 file = "init.sh";
# #                 src = pkgs.fetchFromGitHub {
# #                 owner = "b4b4r07";
# #                 repo = "enhancd";
# #                 rev = "v2.2.1";
# #                 sha256 = "0iqa9j09fwm6nj5rpip87x3hnvbbz9w9ajgm6wkrd5fls8fn8i5g";
# #                 };
# #         }
#
#       "git"
#       "nix-shell"
#       "direnv"
#       "battery"
#     ];
#     extraConfig = ''
# if [ -e ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ]; then . ${config.home.homeDirectory}/.nix-profile/etc/profile.d/nix.sh; fi
# eval "$(atuin init zsh)"
#     '';
#     enable = true;
#   };

  initExtra = (builtins.readFile ./scripts/init.sh);
  shellAliases = (import ./aliases.nix { inherit homeDirectory; }).shell;
}

