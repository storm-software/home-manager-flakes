{
  signingKey,
  gitUser,
  pkgs,
  homeDirectory,
}:

{
  enable = true;
  package = pkgs.gitFull;
  lfs.enable = true;

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
    help.autocorrect = "true";
    lfs.enable = "true";
    branch.autosetuprebase = "always";
    github.user = gitUser.name;
    commit.gpgsign = "true";
    gpg.program = "gpg2";
    credential = {
      helper = "keepassxc";
      credentialstore = "gpg";
      "https://github.com.helper" = "!/usr/bin/gh auth git-credential";
    };
    pull.rebase = "true";
    push.default = "tracking";
    init.defaultBranch = "main";
    alias = (import ./aliases.nix { inherit homeDirectory; }).git;
  };
}
