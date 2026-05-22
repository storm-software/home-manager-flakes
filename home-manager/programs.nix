{ user, pkgs }:

{
  bat.enable = true;

  broot = {
    enable = true;
    enableZshIntegration = true;
  };

  direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  gh = import ./gh.nix { inherit user; };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = true;
      addKeysToAgent = "yes";
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "${user.system.homeDirectory}/.ssh/known_hosts";
    };
  };

  keepassxc = import ./keepassxc.nix { inherit user pkgs; };

  git = import ./git.nix { inherit user pkgs; };

  gpg = {
    enable = true;
    homedir = "${user.system.homeDirectory}/.gnupg";
    mutableKeys = true;
    mutableTrust = true;
  };

  home-manager = {
    enable = true;
  };

  jq.enable = true;

  delta = {
    enable = true;
    enableGitIntegration = true;
  };

  nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  nix-your-shell = {
    enable = true;
    enableZshIntegration = true;
  };

  pandoc = {
    enable = true;
    defaults = {
      metadata = {
        author = "Storm Software";
      };
    };
  };

  neovim = import ./neovim.nix { inherit pkgs; };

  tmux = import ./tmux.nix { inherit pkgs; };

  fzf = import ./fzf.nix;

  fd = {
    enable = true;
    hidden = true;
    ignores = [
      ".git"
      ".nx"
      ".devenv"
      ".tamagui"
      ".next"
      ".next-dev"
      ".docusaurus"
      ".tsbuildinfo"
      "node_modules"
      "bower_components"
      "coverage"
      "out"
      "out-dev"
      "dist"
      "dist-dev"
      "public"
      "public-dev"
      "storybook-static"
      "storybook-static-dev"
    ];
  };

  atuin = import ./atuin.nix;

  carapace = {
    enable = true;
    enableZshIntegration = true;
  };

  man.enable = true;

  vscode = {
    enable = true;
    package = pkgs.unstable.vscode;
    mutableExtensionsDir = true;
  };

  cursor = {
    enable = true;
    package = pkgs.unstable.cursor;
    mutableExtensionsDir = true;
  };

  zsh = import ./zsh.nix {
    inherit user;
    inherit (pkgs) substituteAll;
  };

  zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
