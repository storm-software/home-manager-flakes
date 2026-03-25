{
  homeDirectory,
  pkgs,
  pkgsUnstable,
}:

let
  bin = import ./bin.nix {
    inherit homeDirectory;
    inherit (pkgs) writeScriptBin;
    inherit (pkgs.lib) fakeHash;
  };

  # databaseTools = with pkgs; [
  # sqlite
  # litestream
  # postgresql_18
  # refinery-cli
  # ];

  devOpsTools = [
    # pkgs.dapr-cli
    # pkgs.dive
    # pkgs.doctl
    # pkgs.doppler
    # pkgs.flyctl
    # pkgs.heroku
    # pkgs.packer
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
  ];

  misc = with pkgs; [
    code-cursor
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
    pinentry-gnome3
    keybase
    keychain
    gnupg
    direnv
  ];

  nixTools = with pkgs; [
    nix-direnv
    nixfmt
    vulnix
    statix
  ];

  devenvTools = with pkgsUnstable; [
    cachix
    devenv
  ];

  # virtualizationTools = with pkgs; [
  # vagrant
  # qemu
  # ];
in
bin ++ fonts ++ devOpsTools ++ gitTools ++ nixTools ++ devenvTools ++ misc
