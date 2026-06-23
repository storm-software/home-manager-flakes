{ pkgs }:

let
  bin = import ./bin.nix {
    inherit (pkgs.stable) writeScriptBin;
    inherit (pkgs.stable.lib) fakeHash;
  };

  fonts = with pkgs.stable.nerd-fonts; [
    hack
    fira-code
    fira-mono
    jetbrains-mono
    ubuntu
    ubuntu-sans
    space-mono
    martian-mono
  ];

  gitTools = with pkgs.stable; [
    gitFull
    git-annex
    git-crypt
    git-sync
    git-lfs
    difftastic
    codeowners
  ];

  misc = with pkgs; [
    stable.coreutils
    stable.findutils
    stable.libiconv
    stable.openssl
    stable.cmake
    stable.pkg-config
    stable.skopeo
    stable.stow
    stable.tailscale
    stable.tree
    stable.wget
    stable.zstd
    unstable.pinentry-gnome3
    stable.keychain
    stable.gnupg
    stable.direnv
  ];

  nixTools = with pkgs.stable; [
    comma
    nix-direnv
    nixfmt
    vulnix
    statix
  ];
in
bin ++ fonts ++ gitTools ++ nixTools ++ misc
