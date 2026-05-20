{
  pkgs,
  currentUser
}:

{
  enable = true;
  package = pkgs.gitFull;
  lfs.enable = true;

  maintenance = {
    enable = true;
    repositories = [
      "${currentUser.system.homeDirectory}/repos/storm-ops"
      "${currentUser.system.homeDirectory}/repos/stryke"
      "${currentUser.system.homeDirectory}/repos/powerlines"
      "${currentUser.system.homeDirectory}/repos/earthquake"
      "${currentUser.system.homeDirectory}/repos/acidic"
      "${currentUser.system.homeDirectory}/repos/shell-shock"
      "${currentUser.system.homeDirectory}/repos/storm-dev"
      "${currentUser.system.homeDirectory}/repos/media-kit"
      "${currentUser.system.homeDirectory}/repos/home-manager-flakes"
    ];
  };

  signing = {
    key = currentUser.signingKey;
    signByDefault = true;
    format = "openpgp";
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
    "npm-debug.log"
  ];

  settings = {
    user = {
      name = currentUser.name;
      email = currentUser.email;
    };
    lfs = {
      enable = "true";
      allowincompletepush = "true";
    };
    core = {
      editor = "code-insiders --wait";
      autocrlf = "input";
      whitespace = "trailing-space,space-before-tab";
      #   askPass = ""; # needs to be empty to use terminal for ask password prompt
    };
    merge.tool = "vscode";
    help.autocorrect = "true";
    branch.autosetuprebase = "always";
    github.user = currentUser.name;
    commit.gpgsign = "true";
    tag.gpgSign = "true";
    pull.rebase = "true";
    push.default = "tracking";
    init.defaultBranch = "main";
    alias = (import ./aliases.nix { inherit currentUser; }).git;
  };
}
