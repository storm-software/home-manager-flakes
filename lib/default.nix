{ eachDefaultSystem, pkgs }:

let
  inherit (pkgs.stable.lib) optionals;
  inherit (pkgs.stable.stdenv) isDarwin isLinux;
in
rec {
  darwinOnly = ls: optionals isDarwin ls;
  linuxOnly = ls: optionals isLinux ls;

  getHomeDirectory = username: if isDarwin then "/Users/${username}" else "/home/${username}";

  mkEnv =
    {
      toolchains ? [ ],
      extras ? [ ],
      shellHook ? "",
      env ? { },
    }:

    eachDefaultSystem (
      system:
      let
        inherit (pkgs.stable) mkShell;
      in
      {
        devShells = {
          default = mkShell {
            buildInputs = toolchains ++ extras;
            inherit shellHook;

            env = env;
          };
        };
      }
    );

  toolchains = {
    builds = with pkgs.stable; [
      cue
      dhall
      buildkit
      cmake
      buf
      protobuf
      capnproto
    ];

    kubernetes = with pkgs.stable; [
      kubectx
      kubectl
      minikube
      tilt
    ];

    elixir =
      let
        darwinDeps = darwinOnly ((with pkgs.stable; [ terminal-notifier ]) ++ (with pkgs.stable; [ apple-sdk ]));
        linuxDeps = linuxOnly (
          with pkgs.stable;
          [
            inotify-tools
            libnotify
          ]
        );
      in
      with pkgs.stable;
      [ elixir ] ++ darwinDeps ++ linuxDeps;

    go = with pkgs.stable; [
      go
      go2nix
      gotools
    ];

    node =
      with pkgs.stable;
      [ nodejs_latest ]
      ++ (with pkgs.stable.nodePackages; [
        pnpm
        typescript
        typescript-language-server
      ]);

    python =
      with pkgs.stable;
      [ python313 ]
      ++ (with pkgs.stable.python313Packages; [
        httpie
        pip
        virtualenv
      ]);

    ruby =
      with pkgs.stable;
      [
        rbenv
        rubyBuild
      ]
      ++ (with pkgs.stable.rubyPackages; [
        bundler
        rubocop
        solargraph
      ]);

    java = with pkgs.stable; [
      gradle
      maven
      openjdk17
      openjdk21
    ];

    wasm = with pkgs.stable; [
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

    rust = with pkgs.stable; [
      devRust
      cargo
      cargo-audit
      cargo-cross
      cargo-deny
      cargo-edit
      cargo-expand
      cargo-fuzz
      cargo-make
      cargo-chef
      cargo-outdated
      cargo-profiler
      cargo-lambda
      rustc
      clippy
      rustfmt
      rust-analyzer
    ];
  };
}
