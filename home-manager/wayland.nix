{ pkgs, lib, ... }:

let
  stable = pkgs.stable;

  displaylinkSetup = stable.writeShellScript "displaylink-setup" (
    builtins.readFile ./scripts/displaylink-setup.sh
  );

  # Storm Software palette (aligned with ghostty.nix / fzf.nix)
  colors = {
    background = "#1e2023";
    foreground = "#adbac7";
    accent = "#3be4be";
    accentDim = "#1fb2a6";
    blue = "#539bf5";
    urgent = "#f47067";
    unfocused = "#545d68";
    border = "#2d333b";
  };

  terminal = "${stable.foot}/bin/foot";
  launcher = "${stable.wofi}/bin/wofi --show drun";
  lock = "${stable.swaylock}/bin/swaylock -fF";
in
{
  wayland = {
    systemd.target = "sway-session.target";

    windowManager.sway = {
      enable = true;
      checkConfig = true;
      xwayland = true;

      systemd = {
        enable = true;
        xdgAutostart = true;
      };

      # DisplayLink USB monitors need --unsupported-gpu and WLR_EVDI_RENDER_DEVICE;
      # displaylink-setup.sh writes ~/.config/sway/displaylink-env on switch.
      extraOptions = [ "--unsupported-gpu" ];

      extraSessionCommands = ''
        export SDL_VIDEODRIVER=wayland
        export QT_QPA_PLATFORM=wayland
        export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
        export _JAVA_AWT_WM_NONREPARENTING=1
        export MOZ_ENABLE_WAYLAND=1
        export NIXOS_OZONE_WL=1
        export XDG_CURRENT_DESKTOP=sway
        export XDG_SESSION_TYPE=wayland
        if [ -f "$HOME/.config/sway/displaylink-env" ]; then
          . "$HOME/.config/sway/displaylink-env"
        fi
      '';

      config = {
        modifier = "Mod4";
        terminal = terminal;
        menu = launcher;

        fonts = {
          names = [ "Ubuntu Sans" ];
          size = 10.0;
        };

        window = {
          titlebar = false;
          border = 2;
          hideEdgeBorders = "smart";
        };

        floating = {
          titlebar = false;
          border = 2;
        };

        focus = {
          followMouse = true;
          wrapping = "no";
          newWindow = "smart";
        };

        gaps = {
          inner = 4;
          outer = 4;
          smartGaps = true;
        };

        bars = [ ];

        colors = {
          focused = {
            border = colors.accent;
            background = colors.background;
            text = colors.foreground;
            indicator = colors.accent;
            childBorder = colors.accentDim;
          };
          focusedInactive = {
            border = colors.border;
            background = colors.background;
            text = colors.unfocused;
            indicator = colors.border;
            childBorder = colors.border;
          };
          unfocused = {
            border = colors.border;
            background = colors.background;
            text = colors.unfocused;
            indicator = colors.border;
            childBorder = colors.border;
          };
          urgent = {
            border = colors.urgent;
            background = colors.background;
            text = colors.foreground;
            indicator = colors.urgent;
            childBorder = colors.urgent;
          };
        };

        output = {
          "*" = {
            bg = "${colors.background} solid_color";
          };
        };

        startup = [
          {
            command = "systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP";
            always = true;
          }
        ];
      };

      extraConfig = ''
        default_border pixel 2
        default_floating_border pixel 2

        exec_always systemctl --user set-environment XDG_CURRENT_DESKTOP=sway

        bindsym Mod4+Shift+l exec ${lock}
        bindsym Print exec ${stable.grim}/bin/grim -g "$( ${stable.slurp}/bin/slurp )" - | ${stable.wl-clipboard}/bin/wl-copy
        bindsym Shift+Print exec ${stable.grim}/bin/grim - | ${stable.wl-clipboard}/bin/wl-copy
      '';
    };
  };

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
  };

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = with stable; [
      xdg-desktop-portal-gtk
      xdg-desktop-portal-wlr
    ];
    config = {
      common = {
        default = [
          "gtk"
          "wlr"
        ];
      };
      sway = {
        default = [
          "wlr"
          "gtk"
        ];
      };
    };
  };

  programs.foot = {
    enable = true;
    server.enable = true;
    settings = {
      main = {
        term = "xterm-256color";
        font = "JetBrains Mono Nerd Font:size=11";
        dpi-aware = "yes";
        pad = "4x4";
      };
      colors = {
        foreground = colors.foreground;
        background = colors.background;
        regular0 = colors.background;
        regular1 = colors.urgent;
        regular2 = colors.accent;
        regular3 = "#c69026";
        regular4 = colors.blue;
        regular5 = "#b083f0";
        regular6 = colors.accentDim;
        regular7 = colors.foreground;
        bright0 = colors.unfocused;
        bright1 = "#ff938a";
        bright2 = "#6bc46d";
        bright3 = "#daaa3f";
        bright4 = "#6cb6ff";
        bright5 = "#dcbdfb";
        bright6 = "#56d4dd";
        bright7 = "#cdd9e5";
      };
      cursor = {
        style = "Bibata-Modern-Classic";
        beam-thickness = 2;
      };
      mouse = {
        hide-when-typing = "yes";
      };
    };
  };

  programs = {
    waybar = {
      enable = true;
      systemd = {
        enable = true;
        targets = [ "sway-session.target" ];
      };
      settings = [
        {
          layer = "top";
          position = "top";
          height = 30;
          spacing = 4;
          modules-left = [
            "sway/workspaces"
            "sway/mode"
          ];
          modules-center = [ "sway/window" ];
          modules-right = [
            "pulseaudio"
            "network"
            "cpu"
            "memory"
            "tray"
            "clock"
          ];
          "sway/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };
          "sway/mode" = {
            format = "<span style=\"italic\">{}</span>";
          };
          "sway/window" = {
            max-length = 80;
          };
          pulseaudio = {
            format = "{icon} {volume}%";
            format-muted = "🔇 muted";
            on-click = "${stable.pavucontrol}/bin/pavucontrol";
          };
          network = {
            format-wifi = "🌐 {signalStrength}%";
            format-ethernet = "🔗 connected";
            format-disconnected = "🔴 offline";
          };
          cpu = {
            format = "💻 {usage}%";
            interval = 2;
          };
          memory = {
            format = "💾 {}%";
          };
          clock = {
            format = "{:%a %b %d  %H:%M}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          };
          tray = {
            spacing = 10;
          };
        }
      ];
      style = ''
        * {
          font-family: "Ubuntu Sans", "JetBrainsMono Nerd Font", sans-serif;
          font-size: 13px;
          min-height: 0;
        }

        window#waybar {
          background-color: ${colors.background};
          color: ${colors.foreground};
          border-bottom: 2px solid ${colors.accentDim};
        }

        #workspaces button {
          padding: 0 6px;
          color: ${colors.unfocused};
        }

        #workspaces button.active {
          color: ${colors.accent};
          border-bottom: 2px solid ${colors.accent};
        }

        #workspaces button.urgent {
          color: ${colors.urgent};
        }

        #pulseaudio,
        #network,
        #cpu,
        #memory,
        #clock,
        #tray {
          padding: 0 8px;
        }
      '';
    };
  };

  services = {
    clipman.enable = true;

    # kanshi = {
    #   enable = true;
    #   profiles = {
    #     "default" = {
    #       output = {
    #         "*" = {
    #           bg = "${colors.background} solid_color";
    #         };
    #       };
    #     };
    #   };
    # };

    swaync = {
      enable = true;
      style = ''
        :root {
          /* Storm Software palette (matches ghostty.nix / waybar) */
          --cc-bg: ${colors.background}eb;
          --noti-border-color: ${colors.border};
          --noti-bg: 30, 32, 35;
          --noti-bg-alpha: 0.95;
          --noti-bg-darker: rgb(24, 26, 29);
          --noti-bg-hover: ${colors.border};
          --noti-bg-focus: ${colors.accentDim}26;
          --noti-close-bg: ${colors.border};
          --noti-close-bg-hover: ${colors.accentDim};

          --text-color: ${colors.foreground};
          --text-color-disabled: ${colors.unfocused};
          --bg-selected: ${colors.accent};

          --border-radius: 12px;
          --notification-shadow: 0 0 0 1px rgba(0, 0, 0, 0.3),
            0 1px 3px 1px rgba(0, 0, 0, 0.7), 0 2px 6px 2px rgba(0, 0, 0, 0.3);
          --font-size-body: 13px;
          --font-size-summary: 14px;
        }

        * {
          font-family: "Ubuntu Sans", "JetBrainsMono Nerd Font", sans-serif;
        }

        .notification-row {
          outline: none;
        }

        .notification-row:focus,
        .notification-row:hover {
          background: var(--noti-bg-focus);
        }

        .notification {
          border-radius: var(--border-radius);
          margin: 6px 12px;
          box-shadow: var(--notification-shadow);
          padding: 0;
        }

        .control-center {
          border: 2px solid ${colors.accentDim};
        }
      '';
    };

    swayidle = {
      enable = true;
      timeouts = [
        {
          timeout = 300;
          command = "brightnessctl -q s 10";
          resumeCommand = "brightnessctl -q r";
        }
        {
          timeout = 600;
          command = lock;
        }
        {
          timeout = 900;
          command = ''swaymsg "output * dpms off"'';
          resumeCommand = ''swaymsg "output * dpms on"'';
        }
      ];
      events = {
        before-sleep = lock;
        lock = lock;
      };
    };
  };

  # displaylink-server is a system unit; setup runs automatically on switch.
  # See home-manager/scripts/displaylink-setup.sh and the Displaylink wiki.
  # The activation PATH is minimal, so host system dirs are prepended to resolve
  # sudo/systemctl/udevadm/install; nix binaries are appended via the inherited PATH.
  home.activation.displaylink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD env NIXPKGS=${stable.path} \
      PATH="/run/wrappers/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH" \
      ${displaylinkSetup}
  '';
}
