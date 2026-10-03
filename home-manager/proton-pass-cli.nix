{ pkgsUnstable, ... }:

# Proton Pass CLI (`pass-cli`) remains available for vault access. The nixpkgs
# wrapper sets PROTON_PASS_NO_UPDATE_CHECK; yubikey-agent owns SSH_AUTH_SOCK.
{
  home.packages = [ pkgsUnstable.proton-pass-cli ];

  home.sessionVariables = {
    # Use the default Linux kernel keyring so the session expires on reboot.
    # `pass-cli login` then uses Proton's browser flow for YubiKey authentication.

    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };
}
