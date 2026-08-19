{ pkgs }:

# Proton Pass CLI (`pass-cli`) is a user tool, so it lives in Home Manager
# rather than a system profile. The nixpkgs wrapper already sets
# PROTON_PASS_NO_UPDATE_CHECK. SSH agent support is left off: gpg-agent already
# owns SSH_AUTH_SOCK (`services.gpg-agent.enableSshSupport`), and enabling
# `services.proton-pass-agent` would replace it.
{
  home.packages = [ pkgs.unstable.proton-pass-cli ];

  home.sessionVariables = {
    # Persist the vault encryption key across reboots via Secret Service
    # (GNOME Keyring). The default kernel keyring is wiped on reboot and
    # forces another `pass-cli login`.
    PROTON_PASS_LINUX_KEYRING = "dbus";

    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };
}
