{ nix }:

{
  package = nix;

  gc = {
    automatic = true;
    persistent = true;
    dates = [ "daily" ];
  };

  settings = {
    sandbox = true;
    substituters = [ "https://cache.nixos.org" ];
    experimental-features = [ "flakes" "nix-command" ];
  };
}
