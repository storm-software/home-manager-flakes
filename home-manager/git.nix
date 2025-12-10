{ signingKey, gitUser, pkgs }:

{
    enable = true;
    package = pkgs.gitAndTools.gitFull;

    delta = { enable = true; };
    lfs = { enable = true; };

    signing = {
        format = "openpgp";
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
    aliases = (import ./aliases.nix).git;

    settings = {
        user = {
            name = gitUser.name;
            email = gitUser.email;
        };
        core = {
            editor = "code --wait";
            autocrlf = "input";
            whitespace = "trailing-space,space-before-tab";
        };
        merge.tool = "vscode";
        help.autocorrect = true;

        commit.gpgsign = "true";
        gpg.program = "gpg2";
        lfs.enable = true;

        protocol.keybase.allow = "always";
        credential.helper = "store";
        pull.rebase = true;
        push.default = "simple";
        init.defaultBranch = "main";
    };
}
