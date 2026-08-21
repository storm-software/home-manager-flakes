{ pkgs }:

# Proton Pass CLI (`pass-cli`) is a user tool. The nixpkgs wrapper already
# sets PROTON_PASS_NO_UPDATE_CHECK. The SSH agent owns SSH_AUTH_SOCK
# (gpg-agent SSH is disabled in services.nix).
{
  services.proton-pass-agent = {
    enable = true;
    package = pkgs.unstable.proton-pass-cli;
  };

  home.sessionVariables = {
    # Persist the vault encryption key across reboots via Secret Service
    # (GNOME Keyring). The default kernel keyring is wiped on reboot and
    # forces another `pass-cli login`.
    PROTON_PASS_LINUX_KEYRING = "dbus";

    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };
}
