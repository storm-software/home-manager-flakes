{
  description = "Local dev environment";

  inputs = { stormHomeManagerFlakes.url = "github:storm-software/home-manager-flakes"; };

  outputs = { self, stormHomeManagerFlakes, ... }:
    stormHomeManagerFlakes.lib.mkEnv {
      toolchains = with stormHomeManagerFlakes.lib.toolchains; elixir ++ go ++ node ++ protobuf ++ rust;
      extras = with stormHomeManagerFlakes.pkgs; [ jq ];
      shellHook = ''
        echo "Welcome to this Nix-provided project env!"
      '';
    };
}
