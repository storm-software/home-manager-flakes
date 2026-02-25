{ pkgs }:

{
  package = pkgs.nix;

  gc = {
    automatic = true;
    persistent = true;
    dates = [ "daily" ];
  };

  settings = {
    trusted-users = [
      "root"
      "development"
    ];
    substituters = [ "https://cache.nixos.org" ];
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
  };
}
