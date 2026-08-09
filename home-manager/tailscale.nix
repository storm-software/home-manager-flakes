{ pkgs, user }:

{
  # Kernel-TUN tailscaled for standalone home-manager (Manjaro/Arch, no
  # NixOS services.tailscale). Apps like Orca dial Tailscale 100.x addresses
  # directly, which userspace-networking cannot route. AmbientCapabilities
  # lets the user unit create /dev/net/tun (user systemd already holds
  # CAP_NET_ADMIN). Alternative: host package
  # `sudo pacman -S tailscale && sudo systemctl enable --now tailscaled`
  # and delete this block.
  #
  # Coexists with ProtonVPN (tun0) via separate interfaces; if routing
  # fights, prefer `tailscale set --accept-routes=false` over falling
  # back to userspace-networking.
  tailscaled = {
    Unit = {
      Description = "Tailscale daemon (kernel TUN)";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.stable.tailscale}/bin/tailscaled --tun=tailscale0 --state=${user.system.homeDirectory}/.local/share/tailscale/tailscaled.state --socket=${user.system.homeDirectory}/.cache/tailscale/tailscaled.sock --port 41641";
      AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_RAW";
      CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE";
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
