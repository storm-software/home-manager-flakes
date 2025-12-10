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

    python = with pkgs; [ python313 ] ++ (with pkgs.python313Packages; [ httpie pip virtualenv ]);

    ruby = with pkgs; [
        rbenv
    ];

    java = with pkgs; [
        gradle
        maven
    ];

    wasm = with pkgs; [
        binaryen
        wabt
        wapm
        wasmer
        wasm-bindgen-cli_0_2_104
        wasm-pack
        wasm-text-gen
        wasmtime
        wast-refmt
        webassemblyjs-cli
        webassemblyjs-repl
    ];

    rust = with pkgs; [
        devRust
        cargo
        cargo-audit
        cargo-cross
        cargo-deny
        cargo-edit
        cargo-expand
        cargo-fuzz
        cargo-make
        cargo-outdated
        cargo-profiler
        cargo-lambda
        rustc
        clippy
        rustfmt
        openssl
        pkg-config
        rust-analyzer
    ];
  };
}
