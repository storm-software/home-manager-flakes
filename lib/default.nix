{ eachDefaultSystem, pkgs }:

let
  inherit (pkgs.lib) optionals;
  inherit (pkgs.stdenv) isDarwin isLinux;
in
rec {
  darwinOnly = ls: optionals isDarwin ls;
  linuxOnly = ls: optionals isLinux ls;

  getHomeDirectory = username:
    if isDarwin then "/Users/${username}" else "/home/${username}";

  mkEnv = { toolchains ? [ ], extras ? [ ], shellHook ? "" }:

    eachDefaultSystem (system:
    let
      inherit (pkgs) mkShell;
    in
    {
      devShells = {
        default = mkShell {
          buildInputs = toolchains ++ extras;
          inherit shellHook;
        };
      };
    });

  toolchains = {
    elixir =
      let
        darwinDeps = darwinOnly ((with pkgs; [ terminal-notifier ])
          ++ (with pkgs; [ apple-sdk ]));
        linuxDeps = linuxOnly (with pkgs; [ inotify-tools libnotify ]);
      in
      with pkgs; [ elixir ] ++ darwinDeps ++ linuxDeps;

    go = with pkgs;
      [ go go2nix gotools ];

    node = with pkgs; [ nodejs_24 ] ++ (with pkgs.nodePackages; [ pnpm ]);

    protobuf = with pkgs; [ buf protobuf ];

    rust = with pkgs; [
      devRust
      cargo-audit
      cargo-cross
      cargo-deny
      cargo-edit
      cargo-expand
      cargo-fuzz
      cargo-make
      cargo-outdated
      cargo-profiler
      openssl
      pkg-config
      rust-analyzer
    ];
  };
}
