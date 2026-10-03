# YubiKey setup for KeePassXC and Git signing

The Home Manager configuration installs `ykman` and the YubiKey personalization
tools, enables GnuPG smartcard access, and points Git at the managed GnuPG
executable. Activation does not change the KeePassXC database credential or
move private GPG keys. Both operations require the physical key and a verified
recovery path.

## Check the key and host

Run `ykman info` to confirm the exact model and enabled applications. KeePassXC
challenge response requires a YubiKey with the OTP HMAC-SHA1 application, and
OpenPGP Git signing requires the OpenPGP application. A FIDO-only Security Key
cannot do either. On this non-NixOS host, USB permissions and any PC/SC service
are host responsibilities; Home Manager cannot set them up.

Run `gpg --card-status` to check that GnuPG can see the OpenPGP application.
Do not move the current Git signing key until its secret-key backup has been
made and tested. The configured key ID in `flake.nix` remains unchanged until
the intended on-card signing subkey is verified.

## KeePassXC database

The installed KeePassXC build already includes YubiKey support. The key is
selected as a **database credential**, not a Home Manager setting.

1. Make an offline backup of `~/sync/vault/vault.kdbx`, and verify that it opens
   with the current credentials.
2. Prepare a recovery method before programming the YubiKey: save the
   HMAC-SHA1 challenge-response secret offline, or program a second compatible
   YubiKey with the same secret. The secret cannot be extracted from a YubiKey
   after programming. Keep it out of shell history, the Nix store, and Git.
3. Program an available OTP slot for HMAC-SHA1 challenge response. Check the
   slot before writing; programming it replaces any existing configuration.
4. In KeePassXC, open the database and use **Database > Database Security** to
   add the YubiKey as another credential. Keep the current password. Save,
   close, and reopen the database with the YubiKey before relying on the new
   setup. Check other devices that use the synced database, too.

KeePassXC's challenge-response recovery tool can derive a key file from the
database and the saved HMAC secret if the key is lost. That recovery depends on
having saved the secret **before** programming the key.

## Git signing

Git still uses OpenPGP signing and the existing configured key ID. After
backing up the current secret key, move or create a signing subkey on a
compatible YubiKey, then verify `gpg --card-status` and a test signature with
the card inserted. If a new public key is created, register it with GitHub and
update `user.signingKey` in `flake.nix`. Keep the GnuPG SSH agent disabled;
Proton Pass remains the SSH agent.

Sources: [KeePassXC database credentials](https://github.com/keepassxreboot/keepassxc/blob/develop/docs/topics/DatabaseOperations.adoc), [KeePassXC challenge-response recovery](https://github.com/keepassxreboot/keepassxc/blob/develop/utils/keepassxc-cr-recovery/README.md), and [YubiKey Manager CLI](https://github.com/yubico/yubikey-manager/blob/main/_autodocs/api-reference/ykman.cli.md).
