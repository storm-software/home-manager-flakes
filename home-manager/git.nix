{ pkgs, user }:

{
  enable = true;
  package = pkgs.stable.gitFull;
  lfs.enable = true;

  maintenance = {
    enable = true;
    repositories = [
      "${user.system.homeDirectory}/repos/storm-ops"
      "${user.system.homeDirectory}/repos/stryke"
      "${user.system.homeDirectory}/repos/power-plant"
      "${user.system.homeDirectory}/repos/powerlines"
      "${user.system.homeDirectory}/repos/earthquake"
      "${user.system.homeDirectory}/repos/acidic"
      "${user.system.homeDirectory}/repos/shell-shock"
      "${user.system.homeDirectory}/repos/storm-dev"
      "${user.system.homeDirectory}/repos/media-kit"
      "${user.system.homeDirectory}/repos/home-manager-flakes"
    ];
  };

  signing = {
    key = user.signingKey;
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
      name = user.name;
      email = user.email;
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
    github.user = user.name;
    commit.gpgsign = "true";
    tag.gpgSign = "true";
    pull.rebase = "true";
    push.default = "tracking";
    init.defaultBranch = "main";
    alias = (import ./aliases.nix { inherit user; }).git;
  };
}
