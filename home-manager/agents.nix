{
  config,
  lib,
  pkgs,
  ...
}:

let
  rtkCleanupVersion = "0.45.0";
  rtkCleanupSources = {
    "aarch64-darwin" = {
      target = "aarch64-apple-darwin";
      hash = "sha256-BkFRz8LVCyTYELBqCvLkG5yUXoNTTkxDjD0+rmB/w/Q=";
    };
    "aarch64-linux" = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-gKdG3TBe+UT/UO8BGuTOOHjdW6iN/jXYWdBUmBkWN8M=";
    };
    "x86_64-darwin" = {
      target = "x86_64-apple-darwin";
      hash = "sha256-nqAviJ1aJ3nk+3AN9Fh4JDA8WlfNoi6QPjAFgHn8oO8=";
    };
    "x86_64-linux" = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-xMA2+/GB/FXvMpeGyMF+DUJ5crBTuCWUTZaKaq/vG6Q=";
    };
  };
  rtkCleanupSource = rtkCleanupSources.${pkgs.stdenv.hostPlatform.system};
  rtkCleanup = pkgs.stdenvNoCC.mkDerivation {
    pname = "rtk-cleanup";
    version = rtkCleanupVersion;
    src = pkgs.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkCleanupVersion}/rtk-${rtkCleanupSource.target}.tar.gz";
      inherit (rtkCleanupSource) hash;
    };
    sourceRoot = ".";
    installPhase = ''
      install -Dm755 rtk "$out/bin/rtk"
    '';
  };
  rtkCleanupMarker = "${config.xdg.stateHome}/rtk/home-manager-removed-${rtkCleanupVersion}";
  cavemanVersion = "1.2.3";
  caveman = pkgs.stdenvNoCC.mkDerivation {
    pname = "caveman-cli";
    version = cavemanVersion;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/@caveman-ai/cli/-/cli-${cavemanVersion}.tgz";
      hash = "sha512-7IXNXfdIbZlvmgTLb/jgAICNZffNFc1Q267a7L+0WKlXr1q6WYa+zr90wUsYJ41ekq2FKP/PHAohG2dl0t729g==";
    };

    sourceRoot = "package";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec/caveman" "$out/bin"
      cp -R . "$out/libexec/caveman/"
      patchShebangs "$out/libexec/caveman/dist/index.js"
      ln -s "$out/libexec/caveman/dist/index.js" "$out/bin/caveman"
      ln -s caveman "$out/bin/cave"
      runHook postInstall
    '';

    nativeBuildInputs = [ pkgs.nodejs_24 ];

    meta = {
      description = "Wrap AI coding agents with the local Caveman compression proxy";
      homepage = "https://caveman.so/products/caveman-proxy";
      license = lib.licenses.mit;
      mainProgram = "caveman";
      platforms = lib.platforms.all;
    };
  };
  headroomImage = "ghcr.io/headroomlabs-ai/headroom@sha256:4e559273659ebc5ce8711a60278e288550fa596377af18a7058e10036d63ef0b";
  headroomHome = "${config.home.homeDirectory}/.headroom";
  headroomPython = pkgs.python3.withPackages (ps: [ ps.tomlkit ]);
  configureHeadroomClients = pkgs.writeShellApplication {
    name = "configure-headroom-clients";
    runtimeInputs = [ headroomPython ];
    text = ''
      exec ${headroomPython}/bin/python ${./scripts/configure-headroom-clients.py} \
        ${lib.escapeShellArg config.home.homeDirectory}
    '';
  };
  headroom = pkgs.writeShellApplication {
    name = "headroom";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.docker
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required for the rootless Docker socket}"
      mkdir -p ${lib.escapeShellArg headroomHome}
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR}/weave-docker/docker.sock"
      exec docker run --rm --entrypoint headroom \
        --network host \
        --user "$(id -u):$(id -g)" \
        --workdir /workspace \
        --env HOME=/tmp/headroom-home \
        --env HEADROOM_WORKSPACE_DIR=/tmp/headroom-home/.headroom \
        --env HEADROOM_CONFIG_DIR=/tmp/headroom-home/.headroom/config \
        --volume "$PWD:/workspace" \
        --volume ${lib.escapeShellArg "${headroomHome}:/tmp/headroom-home/.headroom"} \
        ${headroomImage} "$@"
    '';
  };
  headroomProxy = pkgs.writeShellApplication {
    name = "headroom-proxy";
    runtimeInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.docker
    ];
    text = ''
      : "''${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required for the rootless Docker socket}"
      mkdir -p ${lib.escapeShellArg headroomHome}
      export DOCKER_HOST="unix://''${XDG_RUNTIME_DIR}/weave-docker/docker.sock"
      upstream_args=()
      if [[ "''${STORM_SETUP_WEAVE_ROUTER:-1}" != 0 ]]; then
        upstream_args+=(
          --openai-api-url http://127.0.0.1:8080
          --anthropic-api-url http://127.0.0.1:8080
        )
      fi
      exec docker run --rm --name headroom-proxy \
        --network host \
        --user "$(id -u):$(id -g)" \
        --env HOME=/tmp/headroom-home \
        --env HEADROOM_WORKSPACE_DIR=/tmp/headroom-home/.headroom \
        --env HEADROOM_CONFIG_DIR=/tmp/headroom-home/.headroom/config \
        --env HEADROOM_BEACON=off \
        --env DO_NOT_TRACK=1 \
        --volume ${lib.escapeShellArg "${headroomHome}:/tmp/headroom-home/.headroom"} \
        ${headroomImage} \
          --host 127.0.0.1 \
          --port 8787 \
          --mode cache \
          "''${upstream_args[@]}" \
          --no-telemetry
    '';
  };
in
{
  imports = [ ./weave-router.nix ];

  home.packages = [
    caveman
    headroom
  ];

  # RTK writes global hooks and prompt files outside the Home Manager profile.
  # Remove the integrations this module formerly installed, once, before RTK
  # disappears from PATH with the new generation.
  home.activation.removeRtkIntegrations = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${rtkCleanupMarker}" ]; then
      export HOME="${config.home.homeDirectory}"

      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --copilot
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --gemini
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --opencode
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --codex
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --agent cursor
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --agent pi
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --agent droid
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --global --uninstall --agent vibe
      $DRY_RUN_CMD ${rtkCleanup}/bin/rtk init --uninstall --agent hermes

      $DRY_RUN_CMD mkdir -p "$(dirname "${rtkCleanupMarker}")"
      $DRY_RUN_CMD touch "${rtkCleanupMarker}"
    fi
  '';

  # Headroom uses the shared rootless Docker daemon. It sends requests through
  # Weave Router by default, or directly to native providers when Weave is
  # skipped during activation.
  systemd.user.services.headroom = {
    Unit = {
      Description = "Headroom context-optimization proxy";
      Requires = [ "weave-docker.service" ];
      After = [ "weave-docker.service" ];
    };
    Service = {
      ExecStartPre = "${configureHeadroomClients}/bin/configure-headroom-clients";
      ExecStart = "${headroomProxy}/bin/headroom-proxy";
      Restart = "on-failure";
      RestartSec = 5;
    };
    # The activation wrapper starts this after installing the agent settings.
    # It is started by activation, not default.target.
  };
}
