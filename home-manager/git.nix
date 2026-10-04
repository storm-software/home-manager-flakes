{ pkgs, user }:

{
  enable = true;
  package = pkgs.stable.gitFull;
  lfs.enable = true;

  maintenance = {
    enable = true;
    # Only the git repos from the trusted list (skips the home directory and other non-repo paths).
    repositories = builtins.filter (
      path: pkgs.stable.lib.hasPrefix "${user.system.homeDirectory}/repos/" path
    ) (import ./trusted-projects.nix);
  };

  # Sign with the yubikey-agent PIV key. yubikey-agent holds the YubiKey
  # exclusively, so OpenPGP signing through scdaemon cannot share the card.
  signing = {
    key = null;
    signByDefault = true;
    format = "ssh";
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
    # Still used to verify older OpenPGP-signed commits.
    gpg.program = "${pkgs.stable.gnupg}/bin/gpg";
    # Git requires a key:: prefix, which ssh-add -L does not print for ECDSA keys.
    gpg.ssh.defaultKeyCommand = "${pkgs.stable.writeShellScript "git-ssh-signing-key" ''
      key=$(${pkgs.stable.openssh}/bin/ssh-add -L) || exit 1
      printf 'key::%s\n' "''${key%%$'\n'*}"
    ''}";
    merge.tool = "vscode";
    help.autocorrect = "true";
    branch.autosetuprebase = "always";
    github.user = user.name;
    commit.gpgsign = "true";
    tag.gpgSign = "true";
    rebase.autoStash = "true";
    pull.rebase = "true";
    push.default = "tracking";
    init.defaultBranch = "main";
    alias = (import ./aliases.nix { inherit user; }).git;
  };
}
