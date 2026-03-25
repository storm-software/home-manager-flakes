{
  homeDirectory,
  username,
  pkgs,
  pkgsUnstable,
}:

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
    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
    maxCacheTtlSsh = 7200;
    grabKeyboardAndMouse = true;
    pinentry = {
      package = pkgsUnstable.pinentry-gnome3;
      program = "pinentry-gnome3";
    };
    enableSshSupport = true;
    enableScDaemon = true;
    enableZshIntegration = true;
  };

  #   cachix-agent = {
  #     enable = true;
  #     credentialsFile = "${homeDirectory}/.cachix/auth-token";
  #     name = "storm-software";
  #     profile = "development";
  #     package = pkgsUnstable.cachix;
  #   };

  ssh-agent = {
    enable = true;
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
    extraPackages = with pkgs; [
      pass
      gnome-keyring
    ];
    logLevel = "info";
  };

  syncthing = {
    enable = false;
    guiAddress = "127.0.0.1:8384";
    cert = "${homeDirectory}/.cert/syncthing/cert.pem";
    key = "${homeDirectory}/.cert/syncthing/key.pem";
    settings = {
      defaultFolderPath = "${homeDirectory}/sync";
      defaultFolderRescanIntervalS = 3600;
      defaultFolderType = "readwrite";
      gui = {
        theme = "black";
        user = "${username}";
        metricsWithoutAuth = false;
      };
      options = {
        listenAddresses = [ "default" ];
        globalAnnounceEnabled = true;
        localAnnounceEnabled = true;
        relaysEnabled = true;
        natEnabled = true;
        urAccepted = -1;
        globalAnnounceServers = [ "default" ];
        localAnnouncePort = 21027;
        localAnnounceMCAddr = "[ff12::8384]:21027";
        maxSendKbps = 0;
        maxRecvKbps = 0;
        reconnectionIntervalS = 60;
        relayReconnectIntervalM = 10;
        startBrowser = true;
        natLeaseMinutes = 60;
        natRenewalMinutes = 30;
        natTimeoutSeconds = 10;
        urSeen = 3;
        urUniqueID = "";
        urURL = "https://data.syncthing.net/newdata";
        urPostInsecurely = false;
        urInitialDelayS = 1800;
        autoUpgradeIntervalH = 12;
        upgradeToPreReleases = false;
        keepTemporariesH = 24;
        cacheIgnoredFiles = false;
        progressUpdateIntervalS = 5;
        limitBandwidthInLan = false;
        minHomeDiskFree = {
          unit = "%";
          value = 1;
        };
        releasesURL = "https://upgrades.syncthing.net/meta.json";
        overwriteRemoteDeviceNamesOnConnect = false;
        tempIndexMinBlocks = 10;
        trafficClass = 0;
        setLowPriority = true;
        maxFolderConcurrency = 0;
        crashReportingURL = "https://crash.syncthing.net/newcrash";
        crashReportingEnabled = true;
        stunKeepaliveStartS = 180;
        stunKeepaliveMinS = 20;
        stunServers = [ "default" ];
        maxConcurrentIncomingRequestKiB = 0;
        announceLANAddresses = true;
        sendFullIndexOnUpgrade = false;
        auditEnabled = false;
        auditFile = "";
        connectionLimitEnough = 0;
        connectionLimitMax = 0;
        connectionPriorityTcpLan = 10;
        connectionPriorityQuicLan = 20;
        connectionPriorityTcpWan = 30;
        connectionPriorityQuicWan = 40;
        connectionPriorityRelay = 50;
        connectionPriorityUpgradeThreshold = 0;
      };
    };
  };
}
