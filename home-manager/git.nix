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

  maintenance = {
    enable = true;
    repositories = [
      "${homeDirectory}/repos/storm-ops"
      "${homeDirectory}/repos/stryke"
      "${homeDirectory}/repos/powerlines"
      "${homeDirectory}/repos/earthquake"
      "${homeDirectory}/repos/acidic"
      "${homeDirectory}/repos/shell-shock"
      "${homeDirectory}/repos/storm-dev"
      "${homeDirectory}/repos/media-kit"
      "${homeDirectory}/repos/home-manager-flakes"
    ];
  };

  signing = {
    key = signingKey;
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
      name = gitUser.name;
      email = gitUser.email;
    };
    core = {
      editor = "code --wait";
      autocrlf = "input";
      whitespace = "trailing-space,space-before-tab";
      #   askPass = ""; # needs to be empty to use terminal for ask password prompt
    };
    merge.tool = "vscode";
    help.autocorrect = "true";
    lfs.enable = "true";
    branch.autosetuprebase = "always";
    github.user = gitUser.name;
    commit.gpgsign = "true";
    # gpg.program = "gpg2";
    # credential = {
    #   helper = "keepassxc";
    #   credentialstore = "gpg";
    # };
    pull.rebase = "true";
    push.default = "tracking";
    init.defaultBranch = "main";
    alias = (import ./aliases.nix { inherit homeDirectory; }).git;
  };
}
