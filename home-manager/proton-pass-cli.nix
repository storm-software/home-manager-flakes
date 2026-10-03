{ pkgsUnstable, ... }:

# Proton Pass CLI (`pass-cli`) is a user tool. The nixpkgs wrapper already
# sets PROTON_PASS_NO_UPDATE_CHECK. The SSH agent owns SSH_AUTH_SOCK
# (gpg-agent SSH is disabled in services.nix).
{
  services.proton-pass-agent = {
    enable = true;
    package = pkgsUnstable.proton-pass-cli;
  };

  home.sessionVariables = {
    # Use the default Linux kernel keyring so the session expires on reboot.
    # `pass-cli login` then uses Proton's browser flow for YubiKey authentication.

    PROTON_PASS_DISABLE_TELEMETRY = "true";
  };
}
