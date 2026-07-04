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

  pipewire = {
    enable = true;
    clientConfigs = {
      stream.properties = {
        node.latency = 1024/48000;
        node.autoconnect = true;

        #resample.disable = false
        #resample.quality = 4
        #monitor.channel-volumes = false
        #channelmix.disable = false
        #channelmix.min-volume = 0.0
        #channelmix.max-volume = 10.0
        #channelmix.normalize = false
        #channelmix.mix-lfe = true
        #channelmix.upmix = true
        #channelmix.upmix-method = psd  # none, simple
        #channelmix.lfe-cutoff = 150.0
        #channelmix.fc-cutoff  = 12000.0
        #channelmix.rear-delay = 12.0
        #channelmix.stereo-widen = 0.0
        #channelmix.hilbert-taps = 0
        #dither.noise = 0
        #dither.method = none # rectangular, triangular, triangular-hf, wannamaker3, shaped5
        #debug.wav-path = ""
      };

    #   loopback.properties = {
    #     node.latency = 1024/48000;
    #     node.autoconnect = true;
    #   };

    #   pulse.properties = {
    #     node.latency = 1024/48000;
    #     node.autoconnect = true;
    #   };

      alsa.properties = {
        alsa.deny = false;
        alsa.format = 0;
        alsa.rate = 0;
        alsa.channels = 0;
        alsa.period-bytes = 0;
        alsa.buffer-bytes = 0;
        alsa.volume-method = cubic; # linear, cubic
        alsa.rules = [
          {
            matches = [ { application.process.binary = "resolve" } ];
            actions = {
              update-props = {
                alsa.buffer-bytes = 131072;
              };
            };
          }
        ];
      };
    };

    configPackages = [
      (pkgs.stable.writeTextDir "share/pipewire/pipewire.conf.d/10-loopback.conf" ''
        context.modules = [
          {
            name = libpipewire-module-loopback
            args = {
              node.description = "Scarlett Focusrite Line 1"
              capture.props = {
                audio.position = [ FL ]
                stream.dont-remix = true
                node.target = "alsa_input.usb-Focusrite_Scarlett_Solo_USB_Y7ZD17C24495BC-00.analog-stereo"
                node.passive = true
              }
              playback.props = {
                node.name = "SF_mono_in_1"
                media.class = "Audio/Source"
                audio.position = [ MONO ]
              }
            }
          }
        ]
      '')
    ];
  };

  voxtype = import ./voxtype.nix { inherit pkgs; };
}
