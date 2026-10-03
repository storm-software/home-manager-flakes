{ user, pkgs }:

let
  reposDirectory = "${user.system.homeDirectory}/repos/";

  # Only the git checkouts under ~/repos are synced; other trusted workspaces
  # (e.g. the home directory itself) are not repositories.
  syncedProjects = builtins.filter (
    path: builtins.substring 0 (builtins.stringLength reposDirectory) path == reposDirectory
  ) (import ./trusted-projects.nix);

  # Repositories hosted outside the storm-software GitHub organization.
  repositoryOwners = {
    trading = "blackfunction";
  };

  # Pull-only replacement for upstream git-sync, which auto-commits (`git add -A`)
  # and pushes local work. This only fast-forwards opted-in branches
  # (branch.<name>.sync) and never commits, pushes, stashes, or rebases; git
  # refuses the fast-forward if it would overwrite pending changes.
  gitSyncPull = pkgs.stable.writeShellApplication {
    name = "git-sync";
    runtimeInputs = with pkgs.stable; [
      git
      openssh
    ];
    text = ''
      branch=$(git symbolic-ref --quiet --short HEAD) || {
        echo "git-sync: detached HEAD, skipping"
        exit 0
      }
      if [ "$(git config --get --bool "branch.$branch.sync" || true)" != "true" ]; then
        echo "git-sync: branch $branch not enabled via branch.$branch.sync, skipping"
        exit 0
      fi
      git fetch --quiet
      git merge --ff-only "@{upstream}"
    '';
  };

  # The home-manager module runs `git-sync-on-inotify`; poll on the interval
  # instead of on every file change, since nothing local is ever synced.
  gitSyncLoop = pkgs.stable.writeShellApplication {
    name = "git-sync-on-inotify";
    runtimeInputs = with pkgs.stable; [ coreutils ];
    text = ''
      cd "$GIT_SYNC_DIRECTORY"
      while true; do
        "$GIT_SYNC_COMMAND" || echo "git-sync: pull failed, retrying in ''${GIT_SYNC_INTERVAL}s" >&2
        sleep "$GIT_SYNC_INTERVAL"
      done
    '';
  };
in
{
  git-sync = {
    enable = true;
    package = pkgs.stable.symlinkJoin {
      name = "git-sync-pull-only";
      paths = [
        gitSyncPull
        gitSyncLoop
      ];
    };
    repositories = builtins.listToAttrs (
      map (
        path:
        let
          name = baseNameOf path;
        in
        {
          inherit name;
          value = {
            inherit path;
            uri = "https://github.com/${repositoryOwners.${name} or "storm-software"}/${name}.git";
            # Seconds between syncs (30 minutes).
            interval = 1800;
          };
        }
      ) syncedProjects
    );
  };

  gpg-agent = {
    enable = true;
    defaultCacheTtl = 12600;
    defaultCacheTtlSsh = 12600;
    maxCacheTtl = 18000;
    maxCacheTtlSsh = 18000;
    grabKeyboardAndMouse = true;
    pinentry = {
      package = pkgs.unstable.pinentry-gnome3;
      program = "pinentry-gnome3";
    };
    # SSH_AUTH_SOCK is provided by services.proton-pass-agent.
    enableSshSupport = false;
    enableScDaemon = true;
    enableZshIntegration = true;
  };

  home-manager.autoExpire = {
    enable = true;
    frequency = "weekly";
    store.cleanup = true;
    timestamp = "-7 days";
  };

  #   pantalaimon = {
  #     enable = false;
  #     settings = {
  #       Default = {
  #         LogLevel = "Debug";
  #         SSL = true;
  #       };
  #       local-matrix = {
  #         Homeserver = "https://matrix.org";
  #         ListenAddress = "127.0.0.1";
  #         ListenPort = 8008;
  #       };
  #     };
  #   };

  syncthing = {
    enable = true;
    guiAddress = "127.0.0.1:8384";
    # Syncthing 1.27+ requires --config and --data together, or --home for both.
    # Keep config.xml and index-v2 under XDG_STATE_HOME.
    extraOptions = [
      "--home=${user.system.homeDirectory}/.local/state/syncthing"
    ];
    cert = "${user.system.homeDirectory}/.cert/syncthing/cert.pem";
    key = "${user.system.homeDirectory}/.cert/syncthing/key.pem";

    tray = {
      enable = true;
    };

    guiCredentials = {
      username = user.system.username;
      passwordFile = "${user.system.homeDirectory}/.cert/syncthing/gui-password";
    };

    # Keep false until devices and folders are fully declarative in Nix.
    overrideDevices = true;
    overrideFolders = true;

    settings = {
      options = {
        urAccepted = -1;
        relaysEnabled = false;
      };

      devices = {
        megacore = {
          id = "R5ZKLRI-HPGP63B-N4RYWRK-QCXYEOV-LFZ56SN-XEDA7CN-MC2ZRVO-PI2PCQ3";
          autoAcceptFolders = false;
        };
        megabyte = {
          id = "LTDBCVU-3YB7772-EQZ2GTR-THUKO5V-HNQIHGI-BQCJ6IA-6IPHT53-YV5Y2A6";
          autoAcceptFolders = false;
        };
      };

      folders = {
        sync = {
          id = "sync";
          label = "Sync";
          path = "${user.system.homeDirectory}/sync";
          type = "sendreceive";
          devices = [ "megabyte" ];
          versioning = {
            type = "staggered";
            params.maxAge = "31536000";
          };
        };
      };
    };
  };

  tailscale-systray = {
    enable = true;
    theme = "dark";
  };

  udiskie = {
    enable = true;
    automount = true;
    settings = {
      icon_names = {
        media = [
          "media-optical"
        ];
      };
      program_options = {
        tray = true;
        udisks_version = 2;
      };
    };
    tray = "auto";
  };

  keybase.enable = false;
  kbfs.enable = false;
}
