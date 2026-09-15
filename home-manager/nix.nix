{ pkgs, user }:

{
  package = pkgs.stable.nix;

  # access-tokens.conf is included from outside the store; skip build-time validation.
  checkConfig = false;

  gc = {
    automatic = true;
    persistent = true;
    dates = [ "daily" ];
  };

  settings = {
    allowed-users = [
      "root"
      "${user.system.username}"
    ];
    trusted-users = [
      "root"
      "${user.system.username}"
    ];
    substituters = [
      "https://cache.nixos.org"
      "https://storm-software.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "storm-software.cachix.org-1:Jbb6J3ZVqIQaF/7Ckd0b3qQlIPgoV4C1bEMxX1YTQEk="
    ];
    experimental-features = [
      "flakes"
      "nix-command"
    ];
    system-features = [
      "big-parallel"
      "kvm"
      "recursive-nix"
    ];
    stalled-download-timeout = 25000;
    connect-timeout = 0;
    download-buffer-size = 4611686018427387904;
    auto-optimise-store = true;
  };

  # Keep tokens out of the Nix store; see ~/.cert/nix/access-tokens.conf
  extraOptions = ''
    include ${user.system.homeDirectory}/.cert/nix/access-tokens.conf
  '';
}
