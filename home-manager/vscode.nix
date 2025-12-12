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
    profiles = {
        ${username} = {
            enableExtensionUpdateCheck = true;
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
                
            ];
            userSettings =
                builtins.fromJSON (builtins.readFile ./config/vscode-settings.json);
        };
    };
}
