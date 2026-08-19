{
  pkgs,
  config,
  lib,
  ...
}:

# ClamAV is a system antivirus on NixOS (`services.clamav`), but this flake is
# Home Manager on a foreign distro. Mirror the NixOS module with user units:
# clamd, hourly freshclam, and a daily clamdscan of readable system paths.
let
  inherit (lib.strings) escapeRegex concatStringsSep;

  stateDir = "${config.xdg.stateHome}/clamav";
  configDir = "${config.xdg.configHome}/clamav";
  clamdConf = "${configDir}/clamd.conf";
  freshclamConf = "${configDir}/freshclam.conf";
  socket = "${stateDir}/clamd.ctl";

  # Same defaults as nixpkgs services.clamav.scanner, minus /var/lib (not
  # readable as a user). Unreadable files are skipped rather than failing.
  scanDirectories = [
    "/home"
    "/tmp"
    "/etc"
    "/var/tmp"
  ];

  excludePaths = [
    "/nix/store"
    "/proc"
    "/sys"
    "/dev"
    "/run"
    stateDir
    "${config.home.homeDirectory}/.cache"
    "${config.home.homeDirectory}/.nix-profile"
    "${config.home.homeDirectory}/.local/share/nix"
  ];
in
{
  home.packages = [ pkgs.clamav ];

  xdg.configFile."clamav/clamd.conf".text = ''
    DatabaseDirectory ${stateDir}
    LocalSocket ${socket}
    LocalSocketMode 600
    PidFile ${stateDir}/clamd.pid
    TemporaryDirectory /tmp
    Foreground true
    MaxThreads 4
    ${concatStringsSep "\n" (map (path: "ExcludePath ^${escapeRegex path}") excludePaths)}
  '';

  xdg.configFile."clamav/freshclam.conf".text = ''
    DatabaseDirectory ${stateDir}
    DatabaseMirror database.clamav.net
    Foreground true
    Checks 12
    NotifyClamd ${clamdConf}
  '';

  systemd.user.services.clamav-freshclam = {
    Unit = {
      Description = "ClamAV virus database updater (freshclam)";
      Documentation = [ "man:freshclam(1)" ];
    };
    Service = {
      Type = "oneshot";
      # freshclam exits 1 when signatures are already up to date.
      SuccessExitStatus = "1";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${stateDir}";
      ExecStart = "${pkgs.clamav}/bin/freshclam --config-file=${freshclamConf}";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.timers.clamav-freshclam = {
    Unit = {
      Description = "Timer for ClamAV virus database updater (freshclam)";
    };
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "10m";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };

  systemd.user.services.clamav-daemon = {
    Unit = {
      Description = "ClamAV daemon (clamd)";
      Documentation = [ "man:clamd(8)" ];
      After = [ "clamav-freshclam.service" ];
      Wants = [ "clamav-freshclam.service" ];
    };
    Service = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${stateDir}";
      ExecStart = "${pkgs.clamav}/bin/clamd --config-file=${clamdConf}";
      ExecReload = "${pkgs.coreutils}/bin/kill -USR2 $MAINPID";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };

  systemd.user.services.clamdscan = {
    Unit = {
      Description = "ClamAV virus scanner";
      Documentation = [ "man:clamdscan(1)" ];
      After = [
        "clamav-daemon.service"
        "clamav-freshclam.service"
      ];
      Wants = [
        "clamav-daemon.service"
        "clamav-freshclam.service"
      ];
    };
    Service = {
      Type = "oneshot";
      # Home-wide scans routinely exceed systemd's 90s default.
      TimeoutStartSec = "6h";
      Nice = "19";
      ExecStart = concatStringsSep " " (
        [
          "${pkgs.clamav}/bin/clamdscan"
          "--config-file=${clamdConf}"
          "--multiscan"
          "--fdpass"
          "--infected"
          "--allmatch"
        ]
        ++ scanDirectories
      );
    };
  };

  systemd.user.timers.clamdscan = {
    Unit = {
      Description = "Timer for ClamAV virus scanner";
    };
    Timer = {
      # Match nixpkgs services.clamav.scanner.interval (04:00 daily).
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
