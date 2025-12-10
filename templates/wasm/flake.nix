{
  description = "WebAssembly - Local Development Environment";

  inputs = { storm.url = "github:storm-software/home-manager-flakes"; };

  outputs = { self, storm, ... }:
    storm.lib.mkEnv {
      toolchains = with storm.lib.toolchains; builds ++ wasm;
      extras = with storm.pkgs; [ jq ];
      shellHook = ''
        echo "Welcome to this Nix-provided project env!"
      '';
    };
}
