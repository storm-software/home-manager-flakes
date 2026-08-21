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
