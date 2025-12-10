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
          path = ./template/starter;
          description = "Project starter template";
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
