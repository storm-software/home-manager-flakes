{ user, pkgs }:

{
  # git-sync = {
  #     enable = true;
  #     package = pkgs.git-sync;
  #     repositories = {
  #         storm-ops = {
  #             path = "${homeDirectory}/repos/storm-ops";
  #             uri = "git@github.com:storm-software/storm-ops.git";
  #             interval = 1000;
  #         };
  #         stryke = {
  #             path = "${homeDirectory}/repos/stryke";
  #             uri = "git@github.com:storm-software/stryke.git";
  #             interval = 1000;
  #         };
  #         powerlines = {
  #             path = "${homeDirectory}/repos/powerlines";
  #             uri = "git@github.com:storm-software/powerlines.git";
  #             interval = 1000;
  #         };
  #         earthquake = {
  #             path = "${homeDirectory}/repos/earthquake";
  #             uri = "git@github.com:storm-software/earthquake.git";
  #             interval = 1000;
  #         };
  #         acidic = {
  #             path = "${homeDirectory}/repos/acidic";
  #             uri = "git@github.com:storm-software/acidic.git";
  #             interval = 1000;
  #         };
  #     };
  # };

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
    enableSshSupport = true;
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

  protonmail-bridge = {
    enable = true;
    extraPackages = with pkgs.unstable; [
      keepassxc
    ];
    logLevel = "info";
  };

  syncthing = {
    enable = true;
    guiAddress = "127.0.0.1:8384";
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
        crashReportingEnabled = false;
        announceLANAddresses = false;

        # Hardening for LAN-only or static-address setups:
        globalAnnounceEnabled = false;
        localAnnounceEnabled = false;
        relaysEnabled = false;
        natEnabled = false;
        # listenAddresses = [ "tcp://127.0.0.1:22000" "quic://127.0.0.1:22000" ];
      };

      gui = {
        theme = "black";
        metricsWithoutAuth = false;
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
}
