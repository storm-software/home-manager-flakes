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

  devenv = {
    enable = true;
    enableZshIntegration = true;
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

  zsh = import ./zsh.nix {
    inherit user;
    inherit (pkgs) substituteAll;
  };

  zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  kodi = {
    enable = true;
    datadir = "${user.system.homeDirectory}/.kodi";

    # package = pkgs.kodi.withPackages (exts: [ exts.pvr-iptvsimple ]);

    settings = {
      videolibrary = {
        showemptytvshows = "true";
        moviefolderfirst = "true";
      };
      audiolibrary = {
        albumsortingmethod = "1";
      };
    };

    sources = {
      video = {
        default = "movies";
        source = [
          {
            name = "movies";
            path = "${user.system.homeDirectory}/media/movies";
            allowsharing = "false";
          }
          {
            name = "tv";
            path = "${user.system.homeDirectory}/media/tv";
            allowsharing = "false";
          }
        ];
      };
      music = {
        default = "music";
        source = [
          {
            name = "music";
            path = "${user.system.homeDirectory}/media/music";
            allowsharing = "false";
          }
        ];
      };
    };

    # addonSettings = {
    #   "service.xbmc.versioncheck" = {
    #     versioncheck_enable = "false";
    #   };
    # };
  };
}
