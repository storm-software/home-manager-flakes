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

#   devOpsTools = [
#     # pkgs.dapr-cli
#     # pkgs.dive
#     # pkgs.doctl
#     # pkgs.doppler
#     # pkgs.flyctl
#     # pkgs.heroku
#     pkgs.packer
#     pkgsUnstable.pulumi
#     pkgs.terraform
#     pkgs.terragrunt
#   ];

  fonts = with pkgs.nerd-fonts; [
    hack
    fira-code
    fira-mono
    jetbrains-mono
    ubuntu
    ubuntu-sans
    space-mono
    martian-mono
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
    keychain
    keybase
    # gnupg
    direnv
  ];

  nixTools = [
    pkgs.nix-direnv
    pkgs.nixfmt
    pkgs.vulnix
    pkgs.statix
    pkgsUnstable.cachix
    pkgsUnstable.devenv
  ];

  # virtualizationTools = with pkgs; [
  # vagrant
  # qemu
  # ];
in
bin ++ fonts ++ gitTools ++ nixTools ++ misc
