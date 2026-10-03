# YubiKey setup for SSH, Proton Pass, KeePassXC, and Git signing

The Home Manager configuration installs `ykman` and the YubiKey personalization
tools, enables `yubikey-agent` for SSH and GnuPG smartcard access for Git signing,
and points Git at the managed GnuPG executable. Activation does not provision
the YubiKey, change the KeePassXC database credential, or move private GPG keys.
Those operations require the physical key and a verified recovery path.

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

## SSH agent

`services.yubikey-agent` provides the SSH agent socket at
`$XDG_RUNTIME_DIR/yubikey-agent/yubikey-agent.sock`. Home Manager sets
`SSH_AUTH_SOCK` to this socket and starts the socket-activated user service.
The Proton Pass CLI remains installed for vault access, but its SSH agent is
disabled. GnuPG's SSH agent remains disabled as well.

The agent uses the YubiKey PIV application. Check whether that application is
already in use before running `yubikey-agent -setup`, because setup changes
credentials on the physical key. After provisioning, use `ssh-add -L` to check
that the agent exposes the key, then register that public key with SSH services
that should accept it. A FIDO-only Security Key cannot provide this PIV key.

## Proton Pass CLI

Register the YubiKey with the Proton account in Proton's account settings before
relying on it for login. After each reboot, run `pass-cli login` and complete the
browser sign-in with the YubiKey. Proton Pass CLI supports hardware-key
authentication only through this web login flow; do not use `--interactive` for
this purpose. The CLI uses the default Linux kernel keyring, which clears its
vault key on reboot. The Proton account controls whether its web sign-in asks
for a passkey or uses the key as a second factor. On the first login after
switching from D-Bus key storage, if the CLI reports an encryption-key mismatch,
run `pass-cli logout --force` to reset its local session, then `pass-cli login`.

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

This key has an Ed25519 primary key that can sign and certify, a Curve25519
encryption subkey, and an RSA4096 signing subkey. A single OpenPGP card has
one signature slot and one decryption slot, so the primary key and signing
subkey cannot both provide signatures from this YubiKey. For this host, put
the RSA4096 signing subkey in the signature slot and the Curve25519 subkey in
the decryption slot. Keep the Ed25519 primary secret key in a tested offline
backup, separate from the daily GnuPG keyring.

Git uses OpenPGP signing and `flake.nix` pins the existing RSA4096 signing
subkey by its full fingerprint. After making and testing a complete offline
secret-key backup, move the signing and encryption subkeys to the YubiKey.
Verify `gpg --card-status`, a test signature, and decryption with the card
inserted before removing the local primary secret key. Keep the GnuPG SSH
agent disabled; `yubikey-agent` handles SSH separately from OpenPGP signing.

To identify the on-card signing key, run
`gpg --list-secret-keys --keyid-format LONG --with-subkey-fingerprints` with
the YubiKey inserted. Select the key marked for signing (`[S]` or `[SC]`) and
shown as stored on a card (`ssb>` or `sec>`). Configure Git with that key's
full fingerprint followed by `!` to select it exactly. The key in `flake.nix`
is the managed setting; check `git config --show-origin --get user.signingkey` after
activation to catch an override in `~/.gitconfig`. Test a signed commit in a
scratch repository and inspect it with `git log -1 --show-signature`.

### GitHub verification

If the same public key and signing subkey were already registered with GitHub,
moving its private subkey to the YubiKey requires no GitHub change. If this is
a new OpenPGP key, export the **public** key with
`gpg --armor --export <PRIMARY_FINGERPRINT>`. In GitHub, open **Settings > SSH
and GPG keys > New GPG key**, paste the complete armored public key, and save
it. If you added a signing subkey to an existing public key, check that the
public key registered with GitHub includes the new subkey; upload the updated
public key if needed. Never upload a secret key.

The email on the public key must match the Git commit email and be a verified
email on the GitHub account. After pushing a signed commit, confirm GitHub
shows **Verified**. Adding an OpenPGP signing key does not change the SSH key
used for Git transport; register that key separately only if using SSH.

Sources: [yubikey-agent](https://github.com/FiloSottile/yubikey-agent), [Proton Pass CLI login](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/commands/login.md), [Proton Pass CLI logout](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/commands/logout.md), [Proton Pass CLI keyring configuration](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/get-started/configuration.md), [KeePassXC database credentials](https://github.com/keepassxreboot/keepassxc/blob/develop/docs/topics/DatabaseOperations.adoc), [KeePassXC challenge-response recovery](https://github.com/keepassxreboot/keepassxc/blob/develop/utils/keepassxc-cr-recovery/README.md), [YubiKey Manager CLI](https://github.com/yubico/yubikey-manager/blob/main/_autodocs/api-reference/ykman.cli.md), [GnuPG key selection](https://www.gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html), and [GitHub GPG key setup](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account).
