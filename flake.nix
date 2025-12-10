{
  description = "Storm Software - Development User";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    rust-overlay.url = "github:oxalica/rust-overlay";
  };

  outputs = { self, flake-utils, home-manager, nixpkgs, rust-overlay }:
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
          xdg = { configHome = homeDirectory; };
        };
        overlays = [ (import rust-overlay) ] ++ (with self.overlays; [ go node rust ]);
      };

      inherit (flake-utils.lib) eachDefaultSystem;
      inherit (home-manager.lib) homeManagerConfiguration;
    in
    {
      homeConfigurations.${username} = homeManagerConfiguration {
        inherit pkgs;

        modules =
          [ (import ./home-manager { inherit homeDirectory pkgs stateVersion system username gitUser signingKey; }) ];
      };

      lib = import ./lib {
        inherit eachDefaultSystem pkgs;
      };

      overlays = import ./overlays;

      inherit pkgs;

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
    } // eachDefaultSystem (system: {
      devShells.default =
        let
          pkgs = import nixpkgs { inherit system; };
          format = pkgs.writeScriptBin "format" ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt **/*.nix
          '';
        in
        pkgs.mkShell {
          buildInputs = [ format ];
        };
    });
}
