{ homeDirectory, substituteAll }:

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

  syntaxHighlighting = {
    enable = true;
    highlighters = [
      "main"
      "pattern"
    ];
  };

  oh-my-zsh = {
    custom = "${homeDirectory}/.oh-my-zsh/custom";
    theme = "storm-software";
    plugins = [
      "git"
      "gh"
      "github"
      "terraform"
      "pulumi"
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
      "opentofu"
      "battery"
      "pnpm-shell-completion"
      "zoxide"
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
    save = 900000;
    size = 900000;
    ignoreDups = true;
    saveNoDups = true;
    extended = true;
  };

  initContent = (builtins.readFile ./scripts/init.sh);
  shellAliases = (import ./aliases.nix { inherit homeDirectory; }).shell;
}
