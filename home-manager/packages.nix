{
  pkgs,
  pkgsUnstable,
}:

let
  bin = import ./bin.nix {
    inherit (pkgs) writeScriptBin;
    inherit (pkgs.lib) fakeHash;
  };

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
  ];

  misc = with pkgs; [
    comma
    coreutils
    findutils
    libiconv
    open-policy-agent
    openssl
    pkg-config
    skopeo
    stow
    tailscale
    tree
    wget
    zstd
    pinentry-gnome3
    keychain
    gnupg
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
in
bin ++ fonts ++ gitTools ++ nixTools ++ misc
