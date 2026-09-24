{
  config,
  lib,
  pkgs,
  ...
}:

let
  version = "0.1.6";
  source = pkgs.fetchFromGitHub {
    owner = "storm-software";
    repo = "mindctl";
    rev = "7ca5657";
    hash = "sha256-EEZvoT9F/CElGVVY3tpVsGoEIMGbsJSBmhFnd3SbWYQ=";
  };
  mindctl = pkgs.buildGoModule {
    pname = "mindctl";
    inherit version;
    src = source;
    subPackages = [ "cmd/mindctl" ];
    vendorHash = "sha256-8MCbBdii/V+mase7ZNNs3j4jX34MSp59ImKJlYDlHuI=";
    # v0.1.6's provider command test expects the later --all CLI flag; keep
    # source builds reproducible until the next release carries that test fix.
    doCheck = false;
    meta = {
      description = "LLM router with deterministic policy and System 1 classification";
      homepage = "https://github.com/storm-software/mindctl";
      license = lib.licenses.asl20;
      mainProgram = "mindctl";
      platforms = lib.platforms.unix;
    };
  };
  sourceFingerprint = builtins.substring 0 32 (builtins.baseNameOf "${source}");
  layaImage = "mindctl-laya:${version}-${sourceFingerprint}";
  state = "${config.xdg.stateHome}/mindctl";
  setup = pkgs.writeShellApplication {
    name = "mindctl-router-setup";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.openssl
    ];
    text = ''
      export MINDCTL_CONFIG_HOME=${lib.escapeShellArg config.xdg.configHome}
      export MINDCTL_STATE_HOME=${lib.escapeShellArg config.xdg.stateHome}
      exec bash ${./scripts/mindctl-router-setup.sh} "$@"
    '';
  };
  laya = pkgs.writeShellApplication {
    name = "mindctl-laya";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.docker
      pkgs.gnugrep
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required for the rootless Docker socket}"
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR}/weave-docker/docker.sock"
      mkdir -p ${lib.escapeShellArg "${state}/laya-model-cache"}
      if ! docker image inspect ${lib.escapeShellArg layaImage} >/dev/null 2>&1; then
        docker build --file ${source}/Dockerfile.laya --tag ${lib.escapeShellArg layaImage} ${source}
      fi
      exec docker run --rm --name mindctl-laya \
        --publish 127.0.0.1:8091:8091 \
        --user "$(id -u):$(id -g)" \
        --env-file ${lib.escapeShellArg "${state}/laya.env"} \
        --volume ${lib.escapeShellArg "${state}/laya-model-cache:/home/laya/.cache/huggingface"} \
        ${lib.escapeShellArg layaImage}
    '';
  };
  stopLaya = pkgs.writeShellApplication {
    name = "mindctl-laya-stop";
    runtimeInputs = [ pkgs.docker ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required for the rootless Docker socket}"
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR}/weave-docker/docker.sock"
      docker stop mindctl-laya >/dev/null 2>&1 || true
    '';
  };
  mindctlEnabled = pkgs.writeShellApplication {
    name = "mindctl-router-enabled";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
    ];
    text = ''
      export STORM_AGENT_SETUP_STATE=${lib.escapeShellArg "${config.xdg.stateHome}/storm/agent-setup.env"}
      [[ "$(bash ${./scripts/storm-agent-setup-mode.sh})" == mindctl ]]
    '';
  };
in
{
  options.storm.mindctl.setupPackage = lib.mkOption {
    type = lib.types.package;
    readOnly = true;
    internal = true;
  };

  config = {
    home.packages = [ mindctl ];
    xdg.configFile."mindctl/README.md".source = ./mindctl-router.md;

    # WantedBy may start the router during Home Manager's systemd reload. Make
    # its config and EnvironmentFile available before that reload occurs; the
    # outer activation wrapper repeats this idempotently before explicit start.
    home.activation.setupMindctlRouter = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ "''${STORM_AGENT_ROUTER_MODE:-mindctl}" = mindctl ]; then
        $DRY_RUN_CMD ${setup}/bin/mindctl-router-setup
      fi
    '';

    systemd.user.services.mindctl-laya = {
      Unit = {
        Description = "Local Laya System 1 classifier for Mindctl";
        Requires = [ "weave-docker.service" ];
        After = [ "weave-docker.service" ];
      };
      Service = {
        ExecCondition = "${mindctlEnabled}/bin/mindctl-router-enabled";
        ExecStart = "${laya}/bin/mindctl-laya";
        ExecStop = "${stopLaya}/bin/mindctl-laya-stop";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStartSec = "infinity";
        TimeoutStopSec = 120;
        UMask = "0077";
      };
    };

    systemd.user.services.mindctl-router = {
      Unit = {
        Description = "Mindctl model router";
        Requires = [ "mindctl-laya.service" ];
        After = [ "mindctl-laya.service" ];
      };
      Service = {
        Environment = [
          "XDG_CONFIG_HOME=${config.xdg.configHome}"
          "XDG_STATE_HOME=${config.xdg.stateHome}"
        ];
        EnvironmentFile = "${state}/secrets.env";
        ExecCondition = "${mindctlEnabled}/bin/mindctl-router-enabled";
        ExecStart = "${mindctl}/bin/mindctl";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };

    storm.mindctl.setupPackage = setup;
  };
}
