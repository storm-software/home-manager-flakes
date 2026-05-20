{
  currentUser,
  pkgs,
  pkgsUnstable,
}:

{
  # Fancy replacement for cat
  bat.enable = true;

  # Navigate directory trees
  broot = {
    enable = true;
    enableZshIntegration = true;
  };

  direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  gh = import ./gh.nix { inherit currentUser; };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = true;
      addKeysToAgent = "yes";
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "${currentUser.system.homeDirectory}/.ssh/known_hosts";
    };
  };

  keepassxc = import ./keepassxc.nix { inherit currentUser pkgsUnstable; };

  #   git-credential-keepassxc = {
  #     enable = true;
  #     package = pkgs.git-credential-keepassxc;
  #     groups = [ "Vault - Root" ];
  #     # hosts = [ "https://github.com" ];
  #   };

  git = import ./git.nix { inherit currentUser pkgs; };

  gpg = {
    enable = true;
    homedir = "${currentUser.system.homeDirectory}/.gnupg";
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

  ghostty = import ./ghostty.nix;

  atuin = import ./atuin.nix;

  carapace = {
    enable = true;
    enableZshIntegration = true;
  };

  man.enable = true;

  # Disabling vscode for now since it causes a lot of issues with the extension manager
  #   vscode = import ./vscode.nix { inherit username pkgs pkgsUnstable; };

  zsh = import ./zsh.nix {
    inherit currentUser;
    inherit (pkgs) substituteAll;
  };

  zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
