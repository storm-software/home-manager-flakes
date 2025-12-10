{ homeDirectory, pkgs }:

let
    bin = import ./bin.nix {
        inherit homeDirectory;
        inherit (pkgs) writeScriptBin;
        inherit (pkgs.lib) fakeHash;
    };

    buildTools = with pkgs; [
        buf
        just
        pnpm
        cmake
        protobuf
    ];

    configTools = with pkgs; [
        cue
        dhall
    ];

    databaseTools = with pkgs; [
        postgresql_18
        refinery-cli
        materialize
    ];

    devOpsTools = with pkgs; [
        dapr-cli
        dive
        doctl
        doppler
        flyctl
        heroku
        packer
        terraform
        terragrunt
    ];

    fonts = with pkgs.nerd-fonts; [
        fira-code
        fira-mono
        jetbrains-mono
    ];

    gitTools = with pkgs; [
        diff-so-fancy
        codeowners
        gitflow
    ] ++ (with pkgs; [ difftastic git-annex git-crypt git-sync ]);

    javaTools = with pkgs; [
        gradle
        maven
    ];

    kubernetesTools = with pkgs; [
        kubectx
        kubectl
        minikube
        tilt
    ];

    macTools = with pkgs; [
        apple-sdk
        reattach-to-user-namespace
    ];

    misc = with pkgs; [
        comma
        coreutils
        findutils
        gleam
        htmltest
        hugo
        keybase
        libiconv
        litestream
        ncurses
        open-policy-agent
        openssl
        pikchr
        pkg-config
        skopeo
        sqlite
        statix
        stow
        subversion
        tailscale
        tree
        treefmt
        vale
        wget
        youtube-dl
        yt-dlp
        zstd
        gcr
        pinentry-gnome3
        keepassxc
        keychain
        gnupg
        devenv
        direnv
    ];

    nixTools = with pkgs; [
        cachix
        lorri
        nixfmt
        vulnix
    ];

    pythonTools = with pkgs; [ python313 ] ++ (with pkgs.python313Packages; [ httpie pip virtualenv ]);

    rubyTools = with pkgs; [
        rbenv
    ];

    rustTools = with pkgs; [
        rustc
        cargo
        clippy
        rustfmt
        rust-analyzer
        cargo-deny
        cargo-lambda
        sqlx-cli
    ];

    virtualizationTools = with pkgs; [ vagrant qemu ];

    wasmTools = with pkgs; [
        binaryen
        wabt
        wapm
        wasmer
        wasm3
        wasm-bindgen-cli_0_2_104
        wasm-pack
        wasm-text-gen
        wasmtime
        wast-refmt
        webassemblyjs-cli
        webassemblyjs-repl
    ];
in
bin
++ buildTools
++ configTools
++ databaseTools
++ devOpsTools
++ fonts
++ gitTools
++ kubernetesTools
++ macTools
++ misc
++ nixTools
++ pythonTools
++ rustTools
++ virtualizationTools
++ wasmTools
