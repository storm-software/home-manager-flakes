{
  description = "Storm Software - Development User";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      self,
      flake-utils,
      home-manager,
      nixpkgs,
      nixpkgs-unstable,
      rust-overlay,
    }:
    let
      username = "development";
      system = "x86_64-linux";
      stateVersion = "25.11";
      homeDirectory = self.lib.getHomeDirectory username;

      # User specific settings
      gitUser = {
        name = "Pat Sullivan";
        email = "pat@patsullivan.org";
      };
      signingKey = "67216ED35A5544A9";

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnsupportedSystem = true;
          xdg = {
            configHome = homeDirectory;
          };
        };
        overlays = [
          (import rust-overlay)
        ]
        ++ (with self.overlays; [
          go
          node
          rust
        ]);
      };

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config = {
          allowUnfree = true;
          allowUnsupportedSystem = true;
          xdg = {
            configHome = homeDirectory;
          };
        };
        overlays = [
          (import rust-overlay)
        ]
        ++ (with self.overlays; [
          go
          node
          rust
        ]);
      };

      inherit (flake-utils.lib) eachDefaultSystem;
      inherit (home-manager.lib) homeManagerConfiguration;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          f {
            inherit system;
            pkgs = import nixpkgs { inherit system; };
          }
        );
    in
    {
      homeConfigurations.${username} = homeManagerConfiguration {
        inherit pkgs;
        modules = [
          (import ./home-manager {
            inherit
              homeDirectory
              pkgs
              pkgs-unstable
              stateVersion
              system
              username
              gitUser
              signingKey
              ;
          })
        ];
      };

      lib = import ./lib {
        inherit eachDefaultSystem pkgs;
      };

      overlays = import ./overlays;

      inherit pkgs;

      devShells = forEachSupportedSystem (
        { pkgs, system }:
        {
          default =
            let
              getSystem = "SYSTEM=$(nix eval --impure --raw --expr 'builtins.currentSystem')";
              forEachDir = exec: ''
                for dir in */; do
                  (
                    cd "''${dir}"

                    ${exec}
                  )
                done
              '';
              script =
                name: runtimeInputs: text:
                pkgs.writeShellApplication {
                  inherit name runtimeInputs text;
                  bashOptions = [
                    "errexit"
                    "pipefail"
                  ];
                };
            in
            pkgs.mkShellNoCC {
              packages =
                with pkgs;
                [
                  (script "build" [ ] ''
                    ${getSystem}

                    ${forEachDir ''
                      echo "building ''${dir}"
                      nix build ".#devShells.''${SYSTEM}.default"
                    ''}
                  '')
                  (script "check" [ nixfmt ] (forEachDir ''
                    echo "checking ''${dir}"
                    nix flake check --all-systems --no-build
                  ''))
                  (script "format" [ nixfmt ] ''
                    git ls-files '*.nix' | xargs nix fmt
                  '')
                  (script "check-formatting" [ nixfmt ] ''
                    git ls-files '*.nix' | xargs nixfmt --check
                  '')
                ]
                ++ [ self.formatter.${system} ];
            };
        }
      );

      formatter = forEachSupportedSystem ({ pkgs, ... }: pkgs.nixfmt);

      packages = forEachSupportedSystem (
        { pkgs, ... }:
        rec {
          default = dvt;
          dvt = pkgs.writeShellApplication {
            name = "dvt";
            bashOptions = [
              "errexit"
              "pipefail"
            ];
            text = ''
              if [ -z "''${1}" ]; then
                echo "No template specified..."
                exit 1
              fi

              TEMPLATE=$1

              nix \
                --experimental-features 'nix-command flakes' \
                flake init \
                --template \
                "github:storm-software/home-manager-flakes#''${TEMPLATE}"
            '';
          };
        }
      );
    }

    //

      {
        templates = rec {
          default = starter;

          starter = {
            path = ./templates/starter;
            description = "A minimal/starter development environment";
          };

          go = {
            path = ./templates/go;
            description = "A development environment for Go projects";
          };

          java = {
            path = ./templates/java;
            description = "A development environment for Java projects";
          };

          node = {
            path = ./templates/node;
            description = "A development environment for Node.js projects";
          };

          elixir = {
            path = ./templates/elixir;
            description = "A development environment for Elixir projects";
          };

          python = {
            path = ./templates/python;
            description = "A development environment for Python projects";
          };

          ruby = {
            path = ./templates/ruby;
            description = "A development environment for Ruby projects";
          };

          rust = {
            path = ./templates/rust;
            description = "A development environment for Rust projects";
          };

          wasm = {
            path = ./templates/wasm;
            description = "A development environment for WebAssembly projects";
          };

          kubernetes = {
            path = ./templates/kubernetes;
            description = "A development environment for Kubernetes projects";
          };

          kitchen-sink = {
            path = ./templates/kitchen-sink;
            description = "A development environment with many popular languages/tools";
          };
        };
      };
}
