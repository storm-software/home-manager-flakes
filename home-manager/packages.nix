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
    diff-so-fancy
    codeowners
  ];

  misc = with pkgs; [
    stable.comma
    stable.coreutils
    stable.findutils
    stable.libiconv
    stable.open-policy-agent
    stable.openssl
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

  nixTools = with pkgs; [
    stable.nix-direnv
    stable.nixfmt
    stable.vulnix
    stable.statix
    unstable.cachix
    unstable.devenv
  ];
in
bin ++ fonts ++ gitTools ++ nixTools ++ misc
