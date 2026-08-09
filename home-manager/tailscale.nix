{ pkgs, user }:

{
  # Userspace tailscaled for standalone home-manager (Manjaro/Arch, no NixOS services.tailscale). Provides the daemon that
  # services.tailscale-systray requires at /var/run/tailscale/tailscaled.sock when no privileged system daemon is available.
  # Remove this block if you use the host package: `sudo pacman -S tailscale && sudo systemctl enable --now tailscaled`.
  tailscaled = {
    Unit = {
      Description = "Tailscale daemon (userspace)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.stable.tailscale}/bin/tailscaled --tun=userspace-networking --state=${user.system.homeDirectory}/.local/share/tailscale/tailscaled.state --socket=${user.system.homeDirectory}/.cache/tailscale/tailscaled.sock --port 41641";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [
      "graphical-session.target"
      "default.target"
    ];
  };

  tailscale-systray = {
    Unit = {
      After = [
        "tailscaled.service"
        "tray.target"
        "graphical-session.target"
      ];
      Requires = [ "tray.target" ];
      Wants = [ "tailscaled.service" ];
    };
    Service = {
      Environment = "TS_SOCKET=${user.system.homeDirectory}/.cache/tailscale/tailscaled.sock";
      ExecStart = pkgs.stable.lib.mkForce "${pkgs.stable.tailscale}/bin/tailscale --socket ${user.system.homeDirectory}/.cache/tailscale/tailscaled.sock systray";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
