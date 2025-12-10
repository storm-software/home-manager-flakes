{ homeDirectory, pkgs }:

let
    bin = import ./bin.nix {
        inherit homeDirectory;
        inherit (pkgs) writeScriptBin;
        inherit (pkgs.lib) fakeHash;
    };

    buildTools = with pkgs; [
        buf
        protobuf
        capnproto
    ];

    configTools = with pkgs; [
        cue
        dhall
    ];

    databaseTools = with pkgs; [
        sqlite
        litestream
        postgresql_18
        refinery-cli
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
        lefthook
    ] ++ (with pkgs; [ difftastic git-annex git-crypt git-sync ]);

    kubernetesTools = with pkgs; [
        kubectx
        kubectl
        minikube
        tilt
    ];

    # macTools = with pkgs; [
    #     apple-sdk
    #     reattach-to-user-namespace
    # ];

    misc = with pkgs; [
        comma
        coreutils
        findutils
        htmltest
        libiconv
        open-policy-agent
        openssl
        pikchr
        pkg-config
        skopeo
        statix
        stow
        subversion
        tailscale
        tree
        treefmt
        wget
        zstd
        gcr
        pinentry-gnome3
        keepassxc
        keybase
        keychain
        gnupg
        direnv
    ];

    nixTools = with pkgs; [
        cachix
        devenv
        nix-direnv
        nixfmt
        vulnix
        statix
    ];

    rustTools = with pkgs; [
        sqlx-cli
    ];

    virtualizationTools = with pkgs; [ vagrant qemu ];
in
bin
++ buildTools
++ configTools
++ databaseTools
++ devOpsTools
++ fonts
++ gitTools
++ kubernetesTools
# ++ macTools
++ misc
++ nixTools
# ++ pythonTools
++ rustTools
++ virtualizationTools
