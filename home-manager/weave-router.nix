{
  config,
  lib,
  pkgs,
  ...
}:

let
  revision = "5bd5d81a703175943259fafb7df45816b90a97b7";
  source = pkgs.fetchFromGitHub {
    owner = "weave-os";
    repo = "router";
    rev = revision;
    hash = "sha256-oyT9e8Y7K+ng+U3LXy36XLxVplTSAhVw4wKzTusO8iA=";
  };
  state = "${config.xdg.stateHome}/weave-router";
  python = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.tomlkit
  ]);
  # Keep upstream's dependency graph, migrations, native libraries and model
  # assets together. Only deployment-specific settings differ from upstream.
  composeFile = pkgs.runCommand "weave-router-compose.json" { } ''
    ${python}/bin/python ${./scripts/weave-compose.py} ${source} ${lib.escapeShellArg state} ${./scripts/weave-keygen.go} ${revision} > "$out"
  '';
  compose = pkgs.writeShellApplication {
    name = "weave-router-compose";
    runtimeInputs = [
      pkgs.docker
      pkgs.docker-compose
    ];
    text = ''
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR:?}/weave-docker/docker.sock"
      export DOCKER_BUILDKIT=1
      exec docker-compose --project-name weave-router --env-file ${lib.escapeShellArg "${state}/secrets.env"} -f ${composeFile} "$@"
    '';
  };
  setup = pkgs.writeShellApplication {
    name = "weave-router-setup";
    runtimeInputs = [
      compose
      python
      pkgs.bash
      pkgs.coreutils
      pkgs.curl
      pkgs.jq
      pkgs.gnugrep
      pkgs.gnused
      pkgs.gawk
      pkgs.git
      pkgs.nodejs_24
      pkgs.util-linux
      pkgs.docker
    ];
    text = ''
      export WEAVE_STATE=${lib.escapeShellArg state}
      export WEAVE_SOURCE=${source}
      export WEAVE_IMAGE=weave-router:${revision}
      export WEAVE_REVISION=${revision}
      export WEAVE_CLIENT_HOME=${lib.escapeShellArg config.home.homeDirectory}
      export WEAVE_CONFIGURE=${./scripts/weave-clients.py}
      exec bash ${./scripts/weave-setup.sh} "$@"
    '';
  };
in
{
  home.packages = [
    compose
    setup
  ];

  # Dedicated rootless daemon: does not change the user's Docker context or
  # expose an unauthenticated TCP socket. Host uidmap helpers must be installed.
  systemd.user.services.weave-docker = {
    Unit.Description = "Rootless Docker for Weave Router";
    Service = {
      Environment = [
        "PATH=${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.util-linux
          ]
        }:/run/wrappers/bin:/usr/bin:/bin"
        "DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR=%t/weave-docker/rootlesskit"
      ];
      RuntimeDirectory = "weave-docker";
      RuntimeDirectoryMode = "0700";
      ExecStart = "${pkgs.docker}/bin/dockerd-rootless --host=unix://%t/weave-docker/docker.sock --data-root=${state}/docker --exec-root=%t/weave-docker/exec --pidfile=%t/weave-docker/docker.pid";
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

  systemd.user.services.weave-router = {
    Unit = {
      Description = "Self-hosted Weave Router and agent configuration";
      Requires = [ "weave-docker.service" ];
      After = [ "weave-docker.service" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${setup}/bin/weave-router-setup";
      ExecStop = "${compose}/bin/weave-router-compose stop";
      TimeoutStartSec = "infinity";
      TimeoutStopSec = 120;
      UMask = "0077";
    };
    # Activation starts this after the router has configured its initial state.
    # Leaving it out of default.target prevents a second setup at login;
    # activation starts it after installing the client settings.
  };

  xdg.configFile."weave-router/README.md".source = ./weave-router.md;
}
