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
    pkg-config
    skopeo
    stow
    tree
    direnv
    comma
    nixd
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
    egl-wayland
    wayland-protocols
    wayland-utils
  ];

  # The host pcscd uses a newer protocol than Nix's bundled PC/SC client.
  # Point pyscard at the host client library so ykman can list PC/SC readers.
  yubikey-manager = pkgs.stable.yubikey-manager.override {
    python3Packages = pkgs.stable.python3Packages.overrideScope (
      _: prev: {
        pyscard = prev.pyscard.overrideAttrs (old: {
          postPatch = old.postPatch + ''
            substituteInPlace src/smartcard/scard/winscarddll.c \
              --replace-fail "${pkgs.stable.lib.getLib pkgs.stable.pcsclite}/lib/libpcsclite.so" \
                "/usr/lib/libpcsclite_real.so.1"
          '';
          # The host library is not visible inside the build sandbox.
          doInstallCheck = false;
          pythonImportsCheck = [ ];
        });
      }
    );
  };

  misc = with pkgs.stable; [
    glibc
    mesa
    libdrm
    libGL
    libGLX
    xkeyboard-config
    openssl
    tailscale
    wget
    zstd
    keychain
    gnupg
    pinentry-gnome3
    yubikey-manager
    yubikey-personalization
    proton-authenticator
  ];

in
bin ++ fonts ++ gitTools ++ buildTools ++ waylandTools ++ misc
