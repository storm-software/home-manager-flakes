{
  username,
  pkgs,
  pkgsUnstable,
}:

let
  inherit (pkgs.vscode-utils) buildVscodeMarketplaceExtension;

  extension =
    {
      publisher,
      name,
      version,
      sha256,
    }:
    buildVscodeMarketplaceExtension {
      mktplcRef = {
        inherit
          name
          publisher
          sha256
          version
          ;
      };
    };
in
{
  enable = true;
  package = pkgs.vscode;
  mutableExtensionsDir = true;
  profiles = {
    default = {
      enableUpdateCheck = false;
      enableExtensionUpdateCheck = false;
      extensions = with pkgs.vscode-extensions; [
        bbenoist.nix
        bierner.markdown-mermaid
        davidanson.vscode-markdownlint
        dbaeumer.vscode-eslint
        eamodio.gitlens
        donjayamanne.githistory
        esbenp.prettier-vscode
        formulahendry.auto-close-tag
        ms-azuretools.vscode-docker
        redhat.vscode-yaml
        rust-lang.rust-analyzer
        unifiedjs.vscode-mdx
        tamasfe.even-better-toml
        yzhang.markdown-all-in-one
        streetsidesoftware.code-spell-checker
        editorconfig.editorconfig
        firsttris.vscode-jest-runner
        mikestead.dotenv
        brettm12345.nixfmt-vscode
        pkief.material-icon-theme
        ms-vscode.makefile-tools
        golang.go
        github.copilot-chat
        github.vscode-pull-request-github

        (extension {
          publisher = "datakurre";
          name = "devenv";
          version = "0.5.0";
          sha256 = "sha256:e73c4388be4385ea0f32923a00a7004c837df631b611af4efe48dd4e896dfeb4";
        })
        (extension {
          publisher = "antfu";
          name = "pnpm-catalog-lens";
          version = "1.0.0";
          sha256 = "sha256:98230157165121bdc96a8d57492ec4411417dd8dafae4a409b2ea5752a996bd7";
        })
        # (extension {
        #   publisher = "nrwl";
        #   name = "angular-console";
        #   version = "18.91.0";
        #   sha256 = "sha256:ad2d0f1ec8e20441ad257355ad033fbc6d97b177b472da2791945e3eacbef182";
        # })
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
      userSettings = builtins.fromJSON (builtins.readFile ./config/vscode-settings.json);
      enableMcpIntegration = true;
      userMcp = builtins.fromJSON (builtins.readFile ./config/vscode-mcp.json);
    };
  };
}
