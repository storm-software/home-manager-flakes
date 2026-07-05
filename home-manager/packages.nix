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
    git-crypt
    git-sync
    git-lfs
    difftastic
    codeowners
  ];

  buildTools = with pkgs.stable; [
    coreutils
    findutils
    libiconv
    cmake
    pkg-config
    skopeo
    stow
    tree
    direnv
    comma
    nix-direnv
    nixfmt
    vulnix
    statix
  ];

  waylandTools = with pkgs.stable; [
    avahi
    grim
    slurp
    swaylock
    wl-clipboard
    brightnessctl
    pavucontrol
    wtype
    dotool
  ];

  misc = with pkgs; [
    stable.egl-x11
    stable.xkeyboard-config
    stable.openssl
    unstable.tailscale
    stable.wget
    stable.zstd
    stable.keychain
    stable.gnupg
    stable.pinentry-gnome3
  ];

in
bin ++ fonts ++ gitTools ++ buildTools ++ waylandTools ++ misc
