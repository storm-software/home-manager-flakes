{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Dedicated rootless daemon for Mindctl's Laya classifier and Headroom: does
  # not change the user's Docker context or expose an unauthenticated TCP
  # socket. Host uidmap helpers must be installed.
  systemd.user.services.agent-docker = {
    Unit.Description = "Rootless Docker for local agent services";
    Service = {
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.util-linux
          ]
        }:/run/wrappers/bin:/usr/bin:/bin"
        "DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR=%t/agent-docker/rootlesskit"
      ];
      RuntimeDirectory = "agent-docker";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless --host=unix://%t/agent-docker/docker.sock --data-root=${config.xdg.stateHome}/agent-docker --exec-root=%t/agent-docker/exec --pidfile=%t/agent-docker/docker.pid";
      Restart = "on-failure";
      RestartSec = 5;
      TimeoutStartSec = 0;
      Delegate = true;
      KillMode = "mixed";
      LimitNOFILE = "infinity";
      LimitNPROC = "infinity";
      TasksMax = "infinity";
    };
  };
}
