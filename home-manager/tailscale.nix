{ pkgs, user }:

{
  # Userspace tailscaled for standalone home-manager (Manjaro/Arch, no NixOS
  # services.tailscale). Provides the daemon + TS_SOCKET that systray needs.
  #
  # Do NOT set AmbientCapabilities/CapabilityBoundingSet on this user unit:
  # the user manager only has CAP_WAKE_ALARM, so CAP_NET_* causes
  # status=218/CAPABILITIES and a crash loop (seen after the kernel-TUN attempt).
  #
  # Apps like Orca dial Tailscale 100.x addresses directly. Userspace
  # networking cannot install those kernel routes (and ProtonVPN's tun0 can
  # black-hole 100.64.0.0/10). For Orca remote runtimes, use the host package
  # instead, then remove this user `tailscaled` block:
  #   sudo pacman -S tailscale && sudo systemctl enable --now tailscaled
  # Point systray at /var/run/tailscale/tailscaled.sock after that.
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
