{
  homeDirectory,
  pkgs,
  pkgsUnstable,
  pkgsStable,
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

  devOpsTools = [
    pkgs.dapr-cli
    pkgs.dive
    pkgs.doctl
    pkgs.doppler
    pkgs.flyctl
    pkgs.heroku
    pkgs.packer
    pkgsUnstable.pulumi
    pkgs.terraform
    pkgs.terragrunt
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

  nixTools = [
    pkgs.cachix
    pkgs.devenv
    pkgs.nix-direnv
    pkgs.nixfmt
    pkgs.vulnix
    pkgs.statix
  ];

  virtualizationTools = with pkgs; [
    vagrant
    qemu
  ];
in
bin ++ fonts ++ databaseTools ++ devOpsTools ++ gitTools ++ nixTools ++ virtualizationTools ++ misc
