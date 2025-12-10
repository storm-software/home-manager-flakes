{
    description = "Rust - Local Development Environment";

    inputs = {
        storm.url = "github:storm-software/home-manager-flakes";
        naersk.url = "github:nix-community/naersk/master";
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, storm, ... }:
    storm.lib.mkEnv {
        toolchains = with storm.lib.toolchains; builds ++ node ++ rust;
        extras = with storm.pkgs; [ jq ];
        shellHook = ''
            echo "Welcome to this Nix-provided project env!"
        '';
    };
}
