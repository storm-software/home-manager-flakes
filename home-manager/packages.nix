{
  homeDirectory,
  pkgs,
}:

let
  bin = import ./bin.nix {
    inherit homeDirectory;
    inherit (pkgs) writeScriptBin;
    inherit (pkgs.lib) fakeHash;
  };

  databaseTools = with pkgs; [
    sqlite
    litestream
    postgresql_18
    refinery-cli
  ];

  devOpsTools = with pkgs; [
    dapr-cli
    dive
    doctl
    doppler
    flyctl
    heroku
    packer
    terraform
    terragrunt
  ];

  fonts = with pkgs.nerd-fonts; [
    hack
    fira-code
    fira-mono
    jetbrains-mono
  ];

  gitTools = with pkgs; [
    gitFull
    git-annex
    git-crypt
    git-sync
    git-lfs
    difftastic
    diff-so-fancy
    codeowners
    gitflow
    pre-commit
    lefthook
  ];

  misc = with pkgs; [
    comma
    coreutils
    findutils
    htmltest
    libiconv
    open-policy-agent
    openssl
    pikchr
    pkg-config
    skopeo
    stow
    subversion
    tailscale
    tree
    treefmt
    wget
    zstd
    gcr
    pinentry-gnome3
    keepassxc
    keybase
    keychain
    gnupg
    direnv
  ];

  nixTools = with pkgs; [
    cachix
    devenv
    nix-direnv
    nixfmt
    vulnix
    statix
  ];

  virtualizationTools = with pkgs; [
    vagrant
    qemu
  ];
in
bin ++ fonts ++ databaseTools ++ devOpsTools ++ gitTools ++ nixTools ++ virtualizationTools ++ misc
