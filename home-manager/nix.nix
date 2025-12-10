{ pkgs }:

{
  package = pkgs.nix;

  gc = {
    automatic = true;
    persistent = true;
    dates = [ "daily" ];
  };

  settings = {
    sandbox = true;
    substituters = [ "https://cache.nixos.org" ];
    experimental-features = [ "flakes" "nix-command" ];
    system-features = [ "big-parallel" "kvm" "recursive-nix" ];
  };
}
