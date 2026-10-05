{ config, pkgsUnstable, ... }:

# Proton Pass CLI (`pass-cli`) remains available for vault access. The nixpkgs
# wrapper sets PROTON_PASS_NO_UPDATE_CHECK; yubikey-agent owns SSH_AUTH_SOCK.
{
  home.packages = [ pkgsUnstable.proton-pass-cli ];

  home.sessionVariables = {
    # Keep the vault key in the session directory (0600) instead of a keyring.
    # The kernel keyring is cleared on reboot, and the D-Bus Secret Service is
    # not yet unlocked when session services (mindctl-router, ssh agent) call
    # pass-cli at login; either case makes pass-cli force-logout and wipe the
    # session. See https://protonpass.github.io/pass-cli/help/troubleshoot/
    PROTON_PASS_KEY_PROVIDER = "fs";
    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };

  systemd.user.sessionVariables.PROTON_PASS_KEY_PROVIDER =
    config.home.sessionVariables.PROTON_PASS_KEY_PROVIDER;
}
