{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Not in nixpkgs. The npm tarball is a self-contained bundle with no runtime
  # dependencies, so it is installed as-is rather than through buildNpmPackage.
  chromeDevtoolsMcpVersion = "1.10.1";
  chromeDevtoolsMcp = pkgs.stdenvNoCC.mkDerivation {
    pname = "chrome-devtools-mcp";
    version = chromeDevtoolsMcpVersion;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/chrome-devtools-mcp/-/chrome-devtools-mcp-${chromeDevtoolsMcpVersion}.tgz";
      hash = "sha512-Klw6HWDqHC/XS1JwZldd2r49aUhbUJN9m9Mvcx4SEueIPXtzuQX+QelxAViobv8YUkDZ7HWDrmViR6LeYK0wAw==";
    };

    sourceRoot = "package";
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/libexec/chrome-devtools-mcp" "$out/bin"
      cp -R . "$out/libexec/chrome-devtools-mcp/"
      chmod +x "$out/libexec/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
      patchShebangs "$out/libexec/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js"
      ln -s "$out/libexec/chrome-devtools-mcp/build/src/bin/chrome-devtools-mcp.js" "$out/bin/chrome-devtools-mcp"
      runHook postInstall
    '';

    nativeBuildInputs = [ pkgs.nodejs_24 ];

    meta = {
      description = "MCP server exposing Chrome DevTools to coding agents";
      homepage = "https://github.com/ChromeDevTools/chrome-devtools-mcp";
      license = lib.licenses.asl20;
      mainProgram = "chrome-devtools-mcp";
      platforms = lib.platforms.all;
    };
  };
in
{
  programs.mcp = {
    enable = true;
    servers = {
      github = {
        type = "http";
        url = "https://api.githubcopilot.com/mcp/";
        headers = {
          "X-MCP-Insiders" = "true";
        };
      };

      context7 = {
        url = "https://mcp.context7.com/mcp";
        headers.CONTEXT7_API_KEY = "$CONTEXT7_API_KEY";
      };

      # Store binaries rather than `npx`: resolving the npm package on every
      # launch overran Claude Code's 30s MCP connect timeout.
      playwright = {
        command = lib.getExe pkgs.playwright-mcp;
      };

      # No Chrome is installed on the host, so drive the Nix Chromium.
      # `--isolated` gives each session a throwaway profile; the shared default
      # profile is locked by the first agent and fails for concurrent sessions.
      chrome-devtools = {
        command = lib.getExe chromeDevtoolsMcp;
        args = [
          "--executable-path=${lib.getExe pkgs.chromium}"
          "--isolated"
          "--no-usage-statistics"
        ];
      };

      # Clients that advertise MCP roots replace this allowlist with their own.
      filesystem = {
        command = lib.getExe pkgs.mcp-server-filesystem;
        args = [ "${config.home.homeDirectory}/repos" ];
      };

      firecrawl = {
        command = lib.getExe pkgs.firecrawl-mcp;
        env.FIRECRAWL_API_KEY = "$FIRECRAWL_API_KEY";
      };

      deepwiki = {
        url = "https://mcp.deepwiki.com/mcp";
      };

      # Nixpkgs, NixOS and Home Manager option/package lookup; context7 does
      # not index these.
      nixos = {
        command = lib.getExe pkgs.mcp-nixos;
      };
    };
  };
}
