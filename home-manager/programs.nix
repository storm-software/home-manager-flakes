{ username, signingKey, homeDirectory, gitUser, pkgs }:

{
    # Fancy replacement for cat
    bat.enable = true;

    # Navigate directory trees
    broot = {
        enable = true;
        enableZshIntegration = true;
    };

    direnv = {
        enable = true;
        enableZshIntegration = true;

        nix-direnv.enable = true;
    };

    fzf = {
        enable = true;
        enableZshIntegration = true;
    };

    gh = import ./gh.nix { inherit gitUser; };

    git = import ./git.nix { inherit signingKey gitUser pkgs; };

    keepassxc = import ./keepassxc.nix { inherit pkgs; };

    gpg.enable = true;

    home-manager = {
        enable = true;
        path = "...";
    };

    jq.enable = true;

    neovim = import ./neovim.nix {
        inherit (pkgs) vimPlugins;
    };

    nix-index = {
        enable = true;
        enableZshIntegration = true;
    };

    nushell = { enable = true; };

    pandoc = {
        enable = true;
        defaults = { metadata = { author = "Storm Software"; }; };
    };

    tmux = import ./tmux.nix;

    ghostty = import ./ghostty.nix;

    atuin = import ./atuin.nix;

    vscode = import ./vscode.nix { inherit username pkgs; };

    zsh = import ./zsh.nix {
        inherit homeDirectory;
        inherit (pkgs) substituteAll;
    };
}
