{ username, pkgs }:

let
  inherit (pkgs.vscode-utils) buildVscodeMarketplaceExtension;

  extension = { publisher, name, version, sha256 }:
    buildVscodeMarketplaceExtension {
      mktplcRef = { inherit name publisher sha256 version; };
    };
in
{
    enable = true;
    package = pkgs.vscode;
    extensions = with pkgs.vscode-extensions; [
        # Provided by Nixpkgs
        bbenoist.nix
        bierner.markdown-mermaid
        dbaeumer.vscode-eslint
        donjayamanne.githistory
        eamodio.gitlens
        esbenp.prettier-vscode
        formulahendry.auto-close-tag
        kamikillerto.vscode-colorize
        ms-azuretools.vscode-docker
        redhat.vscode-yaml
        rust-lang.rust-analyzer
        unifiedjs.vscode-mdx
        tamasfe.even-better-toml
        yzhang.markdown-all-in-one
        davidanson.vscode-markdownlint
        streetsidesoftware.code-spell-checker
        editorconfig.editorconfig
        firsttris.vscode-jest-runner
        mikestead.dotenv

        # Not in Nixpkgs
        (extension {
            publisher = "antfu";
            name = "pnpm-catalog-lens";
            version = "1.0.0";
            sha256 = "sha256:98230157165121bdc96a8d57492ec4411417dd8dafae4a409b2ea5752a996bd7";
        })
        (extension {
            publisher = "nrwl";
            name = "angular-console";
            version = "18.81.0";
            sha256 = "sha256:47d19f63826b8d3dbc2ef96aab1987433088c9da72c8763bd38b0c1f38eb76d1";
        })
        (extension {
            publisher = "golang";
            name = "Go";
            version = "0.35.1";
            sha256 = "sha256-MHQrFxqSkcpQXiZQoK8e+xVgRjl3Db3n72hrQrT98lg=";
        })
        (extension {
            publisher = "ms-vscode";
            name = "makefile-tools";
            version = "0.5.0";
            sha256 = "sha256-oBYABz6qdV9g7WdHycL1LrEaYG5be3e4hlo4ILhX4KI=";
        })
        (extension {
            publisher = "jallen7usa";
            name = "vscode-cue-fmt";
            version = "0.1.1";
            sha256 = "sha256-juOcZgSfhM1BnyVQPleP86rbuRt0peGIr2aDh7WmNQk=";
        })
        (extension {
            publisher = "nickgo";
            name = "cuelang";
            version = "0.0.1";
            sha256 = "sha256-dAMV1SQUSuq2nze5us6/x1DGYvxzFz3021++ffQoafI=";
        })
        (extension {
            publisher = "bufbuild";
            name = "vscode-buf";
            version = "0.5.0";
            sha256 = "sha256-ePvmHgb6Vdpq1oHcqZcfVT4c/XYZqxJ6FGVuKAbQOCg=";
        })
        (extension {
            publisher = "brettm12345";
            name = "nixfmt-vscode";
            version = "0.0.1";
            sha256 = "sha256-8yglQDUc0CXG2EMi2/HXDJsxmXJ4YHvjNjTMnQwrgx8=";
        })
        (extension {
            publisher = "PKief";
            name = "material-icon-theme";
            version = "4.19.0";
            sha256 = "sha256-RBXs7S0iyuutUn11hFqc0VyTs4NFDFLBRvY0u8id86s=";
        })
        (extension {
            publisher = "ms-vscode";
            name = "vscode-typescript-next";
            version = "4.8.20220805";
            sha256 = "sha256-Nz1uAJ2gQXDDvmu1rnyzW5U1fQFbJDpcxNfujHNEsUI=";
        })
        (extension {
            publisher = "bradlc";
            name = "vscode-tailwindcss";
            version = "0.8.6";
            sha256 = "sha256-v15KuD3eYFCsrworCJ1SZAMkyZKztAwWKmfwmbirleI=";
        })
    ];
    userSettings =
        builtins.fromJSON (builtins.readFile ./config/vscode-settings.json);
}
