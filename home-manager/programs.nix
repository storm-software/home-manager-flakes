{
  username,
  signingKey,
  homeDirectory,
  gitUser,
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

  gh = import ./gh.nix { inherit gitUser; };

  #   git-credential-oauth = {
  #     enable = true;
  #     package = pkgsUnstable.git-credential-keepassxc;
  #     # hosts = [ "https://github.com" ];
  #   };

  ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*" = {
      forwardAgent = true;
      addKeysToAgent = "yes";
      serverAliveInterval = 0;
      serverAliveCountMax = 3;
      hashKnownHosts = false;
      userKnownHostsFile = "${homeDirectory}/.ssh/known_hosts";
    };
  };

  keepassxc = import ./keepassxc.nix { inherit homeDirectory pkgs pkgsUnstable; };

  #   git-credential-keepassxc = {
  #     enable = true;
  #     package = pkgs.git-credential-keepassxc;
  #     groups = [ "Vault - Root" ];
  #     # hosts = [ "https://github.com" ];
  #   };

  git = import ./git.nix {
    inherit
      signingKey
      gitUser
      pkgs
      homeDirectory
      ;
  };

  gpg = {
    enable = true;
    homedir = "${homeDirectory}/.gnupg";
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

  #   nushell = {
  #     enable = true;
  #   };

  pandoc = {
    enable = true;
    defaults = {
      metadata = {
        author = "Storm Software";
      };
    };
  };

  tmux = import ./tmux.nix { inherit homeDirectory pkgs pkgsUnstable; };

  fzf = import ./fzf.nix;

  #   ghostty = import ./ghostty.nix;

  atuin = import ./atuin.nix;

  carapace = {
    enable = true;
    enableZshIntegration = true;
  };

  man.enable = true;

  # Disabling vscode for now since it causes a lot of issues with the extension manager
  #   vscode = import ./vscode.nix { inherit username pkgs pkgsUnstable; };

  zsh = import ./zsh.nix {
    inherit homeDirectory;
    inherit (pkgs) substituteAll;
  };

  zoxide = {
    enable = true;
    enableZshIntegration = true;
  };
}
