{ homeDirectory, substituteAll }:

{
  enable = true;
  enableCompletion = true;
  enableVteIntegration = true;

  autosuggestion = {
    enable = true;
    highlight = "fg=#1fb2a6,bold";
  };

  oh-my-zsh = {
    custom = "${homeDirectory}/.oh-my-zsh/custom";
    theme = "storm-software";
    plugins = [
      "git"
      "gh"
      "github"
      "nix-shell"
      "terraform"
      "pulumi"
      "vscode"
      "tmux"
      "rust"
      "npm"
      "node"
      "kate"
      "direnv"
      "archlinux"
      "postgres"
      "opentofu"
      "battery"
      "pnpm-shell-completion"
    ];

    extraConfig = ''
      if [ -e ${homeDirectory}/.nix-profile/etc/profile.d/nix.sh ]; then . ${homeDirectory}/.nix-profile/etc/profile.d/nix.sh; fi
      eval "$(atuin init zsh)"
    '';
    enable = true;
  };

  history = {
    append = true;
    share = true;
    save = 90000;
    size = 90000;
    ignoreDups = true;
    saveNoDups = true;
    extended = true;
  };

  initExtra = (builtins.readFile ./scripts/init.sh);
  shellAliases = (import ./aliases.nix { inherit homeDirectory; }).shell;
}
