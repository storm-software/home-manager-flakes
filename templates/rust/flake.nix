{
    description = "Rust - Local Development Environment";

    inputs = {
        storm.url = "github:storm-software/home-manager-flakes";
        naersk.url = "github:nix-community/naersk/master";
        nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
        utils.url = "github:numtide/flake-utils";
    };

    outputs = { self, storm, ... }:
    {
        overlays.default = final: prev: {
            rustToolchain =
                with inputs.fenix.packages.${prev.stdenv.hostPlatform.system};
            combine (
                with stable; [
                    clippy
                    rustc
                    cargo
                    rustfmt
                    rust-src
                ]
            );
        };

        storm.lib.mkEnv {
            toolchains = with storm.lib.toolchains; builds ++ node ++ rust;
            extras = with storm.pkgs; [ jq ];
            shellHook = ''
                echo "Welcome to this Nix-provided project env!"
            '';
            env = {
                RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
            };
        };
    }
}
