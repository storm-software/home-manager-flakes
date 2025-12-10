{
  description = "Local dev environment";

  inputs = { storm.url = "github:storm-software/home-manager-flakes"; };

  outputs = { self, storm, ... }:
    storm.lib.mkEnv {
      toolchains = with storm.lib.toolchains; elixir ++ go ++ node ++ protobuf ++ rust;
      extras = with storm.pkgs; [ jq ];
      shellHook = ''
        echo "Welcome to this Nix-provided project env!"
      '';
    };
}
