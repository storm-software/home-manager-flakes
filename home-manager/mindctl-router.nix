{
  config,
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  version = "0.1.26";
  source = pkgs.fetchFromGitHub {
    owner = "storm-software";
    repo = "mindctl";
    rev = "v${version}";
    hash = "sha256-n9iibGwvwSm2I88okY5NB+UXAqhWHUJaXw2+ZGQ4nzQ=";
  };
  mindctl = pkgs.buildGoModule {
    pname = "mindctl";
    inherit version;
    src = source;
    subPackages = [ "cmd/mindctl" ];
    vendorHash = "sha256-8MCbBdii/V+mase7ZNNs3j4jX34MSp59ImKJlYDlHuI=";
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
  mindctlCli = pkgs.writeShellApplication {
    name = "mindctl";
    runtimeInputs = [ pkgs.bash ];
    text = ''
      exec bash ${./scripts/mindctl-cli.sh} ${mindctl}/bin/mindctl ${lib.escapeShellArg "${state}/secrets.env"} "$@"
    '';
  };
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
  secretspecPassCli = pkgs.writeShellApplication {
    name = "secretspec-pass-cli";
    runtimeInputs = [
      pkgs.bash
      pkgsUnstable.proton-pass-cli
    ];
    text = ''
      exec bash ${./scripts/secretspec-pass-cli.sh} "$@"
    '';
  };
  mindctlSecretsEnv = pkgs.writeShellApplication {
    name = "mindctl-secrets-env";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.secretspec
      secretspecPassCli
      mindctl
    ];
    text = ''
      export SECRETSPEC_FILE=${lib.escapeShellArg "${../secretspec.toml}"}
      export SECRETSPEC_PROTONPASS_CLI_PATH=${lib.escapeShellArg "${secretspecPassCli}/bin/secretspec-pass-cli"}
      export MINDCTL_SETUP_COMMAND=${lib.escapeShellArg "${setup}/bin/mindctl-router-setup"}
      exec bash ${./scripts/mindctl-secrets-env.sh} ${mindctl}/bin/mindctl "$@"
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
    home.packages = [ mindctlCli ];
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
          # Managed Headroom provisions its pinned runtime under here.
          "XDG_CACHE_HOME=${config.xdg.cacheHome}"
        ];
        EnvironmentFile = "${state}/secrets.env";
        ExecCondition = "${mindctlEnabled}/bin/mindctl-router-enabled";
        ExecStart = "${mindctlSecretsEnv}/bin/mindctl-secrets-env";
        Restart = "on-failure";
        RestartSec = 5;
        UMask = "0077";
      };
      Install.WantedBy = [ "default.target" ];
    };

    storm.mindctl.setupPackage = setup;
  };
}
