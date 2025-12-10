{ signingKey, gitUser, pkgs }:

{
    enable = true;
    package = pkgs.gitAndTools.gitFull;

    delta = { enable = true; };
    lfs = { enable = true; };

    signing = {
        key = signingKey;
        signByDefault = true;
    };

    ignores = [
        ".cache/"
        ".DS_Store"
        ".direnv/"
        ".devenv/"
        ".idea/"
        "*.swp"
        "built-in-stubs.jar"
        "dumb.rdb"
        ".elixir_ls/"
        ".vscode/"
        "npm-debug.log"
    ];

    aliases = (import ./aliases.nix { inherit homeDirectory; }).git;

    settings = {
        user = {
            name = gitUser.name;
            email = gitUser.email;
        };
        core = {
            editor = "code --wait";
            autocrlf = "input";
            whitespace = "trailing-space,space-before-tab";
            askPass = ""; # needs to be empty to use terminal for ask password prompt
        };
        merge.tool = "vscode";
        help.autocorrect = true;
        lfs.enable = true;
        branch.autosetuprebase = "always";
        commit.gpgsign = true;
        github.user = gitUser.name;
        protocol.keybase.allow = "always";
        credential.helper = "store";
        pull.rebase = true;
        push.default = "tracking";
        init.defaultBranch = "main";
    };
}
