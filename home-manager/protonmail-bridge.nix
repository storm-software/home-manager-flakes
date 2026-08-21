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
  # Bridge IMAP. Bridge has no mailbox until Proton login is done once.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "protonmail-bridge-login";
      runtimeInputs = [
        config.services.protonmail-bridge.package
        pkgs.coreutils
        pkgs.gnugrep
      ];
      text = ''
        export PASSWORD_STORE_DIR="${config.home.homeDirectory}/.password-store"
        export PASSWORD_STORE_GPG_OPTS="--trust-model=always"

        if [[ ! -t 0 ]]; then
          echo "protonmail-bridge-login must run in a terminal (it asks for your Proton password and 2FA)." >&2
          exit 1
        fi

        echo "Stopping the Bridge daemon (only one instance can run)..."
        systemctl --user stop protonmail-bridge.service

        echo
        echo "This is Proton Bridge login, not Thunderbird."
        echo "Use your Proton account password and 2FA, then run:"
        echo
        echo "  login"
        echo "  info      # copy the mailbox password for Thunderbird"
        echo "  quit"
        echo

        protonmail-bridge --cli

        echo
        echo "Checking that Bridge has an account..."
        list_out="$(printf 'list\nquit\n' | protonmail-bridge --cli 2>/dev/null || true)"
        if printf '%s\n' "$list_out" | grep -qi 'no active accounts'; then
          echo "No Proton account is logged into Bridge yet." >&2
          echo "Run protonmail-bridge-login again and complete the login command." >&2
          systemctl --user start protonmail-bridge.service
          exit 1
        fi

        systemctl --user start protonmail-bridge.service
        echo "Bridge is running. In Thunderbird, Get Messages and paste the mailbox password from 'info'."
      '';
    })
  ];

  xdg.desktopEntries.protonmail-bridge-login = {
    name = "Proton Mail Bridge Login";
    comment = "Log your Proton account into Bridge (required before Thunderbird IMAP works)";
    exec = "protonmail-bridge-login";
    terminal = true;
    categories = [
      "Network"
      "Email"
    ];
  };

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
