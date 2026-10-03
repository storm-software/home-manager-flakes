{ pkgsUnstable, ... }:

# Proton Pass CLI (`pass-cli`) remains available for vault access. The nixpkgs
# wrapper sets PROTON_PASS_NO_UPDATE_CHECK; yubikey-agent owns SSH_AUTH_SOCK.
{
  home.packages = [ pkgsUnstable.proton-pass-cli ];

  home.sessionVariables = {
    # Store the vault key with the desktop's persistent Secret Service keyring.
    PROTON_PASS_LINUX_KEYRING = "dbus";
    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };
}
