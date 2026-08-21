{
  config,
  lib,
  pkgs,
  ...
}:

let
  rtkVersion = "0.45.0";
  rtkSources = {
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
  rtkSource = rtkSources.${pkgs.stdenv.hostPlatform.system};
  rtk = pkgs.stdenvNoCC.mkDerivation {
    pname = "rtk";
    version = rtkVersion;

    src = pkgs.fetchurl {
      url = "https://github.com/rtk-ai/rtk/releases/download/v${rtkVersion}/rtk-${rtkSource.target}.tar.gz";
      inherit (rtkSource) hash;
    };

    sourceRoot = ".";
    installPhase = ''
      runHook preInstall
      install -Dm755 rtk "$out/bin/rtk"
      runHook postInstall
    '';

    meta = {
      description = "CLI output proxy that reduces token usage by AI coding agents";
      homepage = "https://www.rtk-ai.app";
      license = lib.licenses.mit;
      mainProgram = "rtk";
      platforms = builtins.attrNames rtkSources;
    };
  };

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

  rtkInitMarker = "${config.xdg.stateHome}/rtk/home-manager-init-${rtkVersion}";
in
{
  home.packages = [
    caveman
    rtk
  ];

  # RTK's integrations are not all expressible as Home Manager options. Run
  # each global initializer once per pinned RTK version so upgrades can refresh
  # hook formats without rewriting agent-owned files on every activation.
  home.activation.configureRtk = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${rtkInitMarker}" ]; then
      export HOME="${config.home.homeDirectory}"
      export RTK_TELEMETRY_DISABLED=1

      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --auto-patch
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --copilot
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --gemini
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --opencode
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --codex
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --agent cursor
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --agent pi
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --agent droid
      $DRY_RUN_CMD ${rtk}/bin/rtk init --global --agent vibe
      $DRY_RUN_CMD ${rtk}/bin/rtk init --agent hermes

      $DRY_RUN_CMD mkdir -p "$(dirname "${rtkInitMarker}")"
      $DRY_RUN_CMD touch "${rtkInitMarker}"
    fi
  '';
}
