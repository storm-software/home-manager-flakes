{
  pkgs,
  lib,
  config,
  ...
}:

# KeePassXC FdoSecrets only exposes collection/session. Bridge's
# secret-service helper needs gnome-keyring's collection/login.
# Vault persistence uses pass; the systemd unit must encrypt without
# interactive GPG trust prompts.
let
  waitForGpg = pkgs.writeShellScript "wait-for-gpg-agent" ''
    set -euo pipefail
    for _ in $(${pkgs.coreutils}/bin/seq 1 180); do
      if ${pkgs.gnupg}/bin/gpg-connect-agent /bye >/dev/null 2>&1; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done
    echo "gpg-agent is not available; Proton Bridge cannot use pass as its keychain." >&2
    exit 1
  '';
in
{
  services.gnome-keyring = {
    enable = true;
    components = [
      "pkcs11"
      "secrets"
    ];
  };

  services.protonmail-bridge = {
    enable = true;
    extraPackages = with pkgs; [
      pass
      gnupg
      gnome-keyring
    ];
    logLevel = "info";
  };

  # Thunderbird does not read accounts.email.passwordCommand. It talks to
  # Bridge's IMAP, and Bridge has no mailbox until this login is done once.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "protonmail-bridge-login";
      runtimeInputs = [
        config.services.protonmail-bridge.package
      ];
      text = ''
        export PASSWORD_STORE_DIR="${config.home.homeDirectory}/.password-store"
        export PASSWORD_STORE_GPG_OPTS="--trust-model=always"

        echo "Stopping the Bridge daemon (only one instance can run)..."
        systemctl --user stop protonmail-bridge.service

        echo
        echo "Log in with your Proton account (email, password, 2FA)."
        echo "Do not use the password Thunderbird is prompting for."
        echo
        echo "  login"
        echo "  info      # copy the mailbox password"
        echo "  quit"
        echo
        echo "Then in Thunderbird: paste that mailbox password once and"
        echo "check Use Password Manager to remember this password."
        echo

        protonmail-bridge --cli

        systemctl --user start protonmail-bridge.service
      '';
    })
  ];

  systemd.user.services.gnome-keyring = {
    Unit.PartOf = [ "sway-session.target" ];
    Install.WantedBy = [ "sway-session.target" ];
  };

  systemd.user.services.protonmail-bridge = {
    Unit.After = [
      "graphical-session.target"
      "gpg-agent.socket"
      "gnome-keyring.service"
    ];
    Service = {
      Environment = [
        "PASSWORD_STORE_DIR=${config.home.homeDirectory}/.password-store"
        "PASSWORD_STORE_GPG_OPTS=--trust-model=always"
      ];
      ExecStartPre = "${waitForGpg}";
      RestartSec = "5";
    };
  };

  home.activation.setProtonBridgeKeychain = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.config/protonmail/bridge-v3"
    $DRY_RUN_CMD printf '%s\n' '{"Helper":"pass","DisableTest":false}' > "${config.home.homeDirectory}/.config/protonmail/bridge-v3/keychain.json"
    $DRY_RUN_CMD chmod 600 "${config.home.homeDirectory}/.config/protonmail/bridge-v3/keychain.json"
  '';
}
