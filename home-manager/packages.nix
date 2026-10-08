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
    # Project `.mcp.json` servers (e.g. cyclone-ui's graphify) launch `uv`
    # outside any devenv shell.
    uv
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
  # Load the host wrapper rather than libpcsclite_real.so.1: only the wrapper
  # exports pcsc_stringify_error and the g_rgSCard*Pci globals, and pyscard
  # segfaults when they are missing. The wrapper dlopens its backend by soname,
  # which Nix's loader cannot find in /usr/lib, so name it explicitly.
  yubikey-manager =
    (pkgs.stable.yubikey-manager.override {
      python3Packages = pkgs.stable.python3Packages.overrideScope (
        _: prev: {
          pyscard = prev.pyscard.overrideAttrs (old: {
            postPatch = old.postPatch + ''
              substituteInPlace src/smartcard/scard/winscarddll.c \
                --replace-fail "${pkgs.stable.lib.getLib pkgs.stable.pcsclite}/lib/libpcsclite.so" \
                  "/usr/lib/libpcsclite.so.1"
            '';
            # The host library is not visible inside the build sandbox.
            doInstallCheck = false;
            pythonImportsCheck = [ ];
          });
        }
      );
    }).overrideAttrs
      (old: {
        makeWrapperArgs = (old.makeWrapperArgs or [ ]) ++ [
          "--set-default"
          "LIBPCSCLITE_DELEGATE"
          "/usr/lib/libpcsclite_real.so.1"
        ];
      });

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
