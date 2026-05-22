{ user, substituteAll }:

{
  enable = true;
  enableCompletion = true;
  enableVteIntegration = true;

  autosuggestion = {
    enable = true;
    highlight = "fg=#a3f2e0,bold";
    strategy = [
      "history"
      "completion"
    ];
  };

  oh-my-zsh = {
    custom = "${user.system.homeDirectory}/.oh-my-zsh/custom";
    theme = "storm-software";
    plugins = [
      "git"
      "gh"
      "github"
      "vscode"
      "tmux"
      "rust"
      "npm"
      "node"
      "kate"
      "tmux"
      "systemd"
      "repo"
      "fzf"
      "dotenv"
      "archlinux"
      "battery"
      "pnpm-shell-completion"
      "zoxide"
    ];

    extraConfig = ''
      if [ -e ${user.system.homeDirectory}/.nix-profile/etc/profile.d/nix.sh ]; then . ${user.system.homeDirectory}/.nix-profile/etc/profile.d/nix.sh; fi
      eval "$(devenv hook zsh)"
      eval "$(atuin init zsh)"
    '';
    enable = true;
  };

  history = {
    append = true;
    share = true;
    save = 900000;
    size = 900000;
    ignoreDups = true;
    saveNoDups = true;
    extended = true;
  };

  initContent = (builtins.readFile ./scripts/init.sh);
  shellAliases = (import ./aliases.nix { inherit user; }).shell;
}
