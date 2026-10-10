# YubiKey setup for SSH, Proton Pass, KeePassXC, and Git signing

The Home Manager configuration installs `ykman` and the YubiKey personalization
tools, and enables `yubikey-agent` for SSH and Git commit signing. GnuPG
smartcard access remains available for OpenPGP use. Activation does not
provision the YubiKey, change the KeePassXC database credential, or move private
GPG keys. Those operations require the physical key and a verified recovery path.

## Check the key and host

Run `ykman info` to confirm the exact model and enabled applications. KeePassXC
challenge response requires a YubiKey with the OTP HMAC-SHA1 application, and
`yubikey-agent` requires the PIV application. A FIDO-only Security Key cannot
do either. On this non-NixOS host, USB permissions and any PC/SC service
are host responsibilities; Home Manager cannot set them up.

Run `gpg --card-status` to check that GnuPG can see the OpenPGP application.

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

YubiKeys with firmware 5.7 or later ship with an AES-192 default management
key, which `yubikey-agent -setup` rejects with "The default Management Key did
not work" before it changes anything. Check `ykman piv info`; if it reports
the default management key with algorithm AES192, switch it to TDES with the
same default value, and setup then replaces it with a random key:

```sh
k=010203040506070801020304050607080102030405060708
ykman piv access change-management-key -a tdes -m $k -n $k -f
```

Signing asks for the PIV PIN in a pinentry window, which gives up after about
a minute. The agent then logs `smart card error 6982: security status not
satisfied`, and the signing fails with "agent refused operation".

The service refuses `systemctl --user restart` because it may only be started
by its socket. To load a new build, run `systemctl --user stop
yubikey-agent.service`; the socket starts it again on the next connection.

`yubikey-agent` holds the whole YubiKey exclusively once it has used it, so
`gpg`, `ykman`, and scdaemon cannot reach the card meanwhile. Run `ssh-add -D`
to release it (the PIN is asked for again on next use). The reverse also
applies: after using the card with GnuPG, run `gpgconf --kill scdaemon` so
`yubikey-agent` can open it.

## Backup YubiKey

The OpenPGP subkeys (encryption `0x284E334E100F4A2A`, signing
`0x67216ED35A5544A9`) are on two YubiKeys: a Nano (serial 37603779) and a 5C
NFC (serial 37522951). Each key has its own PIV SSH signing key, and each one
is registered on GitHub as a signing key.

The PIV key cannot be copied. On another YubiKey, run `yubikey-agent -setup`
with only that key plugged in, and register the new `ssh-add -L` key on GitHub.

`keytocard` removes the private subkeys from the local keyring, so copying them
to another card needs the secret subkey backup exported before the first
`keytocard`. Import it into a throwaway keyring so the stubs in `~/.gnupg` are
left alone:

```sh
systemctl --user stop yubikey-agent.socket yubikey-agent.service
gpgconf --kill scdaemon
export GNUPGHOME=$(mktemp -d -p "$XDG_RUNTIME_DIR")
cp ~/.gnupg/scdaemon.conf ~/.gnupg/gpg-agent.conf "$GNUPGHOME"/
gpg --import /path/to/secret-subkeys-backup.asc
gpg --edit-key 0xE6ADC420DA5C4C2D   # keytocard each subkey into its slot, then save
gpgconf --kill all; rm -rf "$GNUPGHOME"; unset GNUPGHOME
gpgconf --kill scdaemon
gpg-connect-agent "scd serialno" "learn --force" /bye
```

`learn --force` adds the new card to the existing stubs; the stub files under
`~/.gnupg/private-keys-v1.d/` then list one `Token:` per card, and GnuPG uses
whichever card is plugged in. `gpg --card-status` reporting `Card error` after
swapping cards usually means an scdaemon left over from the previous card;
`gpgconf --kill scdaemon` fixes it.

## Proton Pass CLI

Register the YubiKey with the Proton account in Proton's account settings before
relying on it for login. The CLI keeps its vault key in
`~/.local/share/proton-pass-cli/.session/local.key` (`PROTON_PASS_KEY_PROVIDER=fs`)
so the session survives reboots and is available to session services. The
kernel keyring loses the key on reboot, and the D-Bus Secret Service is not
unlocked when `mindctl-router` runs `pass-cli` at login (SDDM's PAM stack only
unlocks KWallet); in both cases `pass-cli` force-logs out and deletes the
session as a safety measure. Home Manager also sets the filesystem provider in
the systemd user environment: the router can start before shell session
variables are imported, and a call using the default keyring may erase a
session created with the filesystem provider. A CLI login is only needed when
setting up the account or if the Proton session expires. Proton Pass CLI
supports hardware-key authentication through its browser login flow; do not use
`--interactive` for this purpose. The Proton account controls whether web
sign-in asks for a passkey or uses the key as a second factor. After switching
key providers, run
`pass-cli logout --force` to reset the local session, then `pass-cli login`.

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

Git signs commits and tags over SSH with the `yubikey-agent` PIV key
(`gpg.format = ssh`). `gpg.ssh.defaultKeyCommand` takes the first key from
`ssh-add -L`, so no key is pinned in this repository and a new key needs no
configuration change. The key generated by `yubikey-agent -setup` requires a
touch for every signature, so a rebase that re-signs many commits asks for one
touch per commit. The key exists only on the YubiKey and cannot be backed up;
replacing the YubiKey means generating and registering a new key.

`gpg.program` still points at the managed GnuPG so that older OpenPGP-signed
commits can be verified. Check `git config --show-origin --get user.signingkey`
after activation: an override left in `~/.gitconfig` takes precedence and would
break SSH signing. Activation removes the former OpenPGP key from there.

Test a signed commit in a scratch repository. Verifying SSH signatures locally
with `git log --show-signature` also needs an allowed signers file
(`programs.git.signing.allowedSigners`), which is not configured.

### GitHub verification

In GitHub, open **Settings > SSH and GPG keys > New SSH key**, set **Key type**
to **Signing Key**, and paste the output of `ssh-add -L`. A key added as an
authentication key is not used for signature verification; add it a second
time with each type if it is used for both. The commit email must be a
verified email on the GitHub account. After pushing a signed commit, confirm
GitHub shows **Verified**. Keep the existing GPG key on the account so commits
signed with it stay verified.

Sources: [yubikey-agent](https://github.com/FiloSottile/yubikey-agent), [Proton Pass CLI login](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/commands/login.md), [Proton Pass CLI logout](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/commands/logout.md), [Proton Pass CLI keyring configuration](https://github.com/protonpass/pass-cli/blob/main/docs/public/docs/get-started/configuration.md), [KeePassXC database credentials](https://github.com/keepassxreboot/keepassxc/blob/develop/docs/topics/DatabaseOperations.adoc), [KeePassXC challenge-response recovery](https://github.com/keepassxreboot/keepassxc/blob/develop/utils/keepassxc-cr-recovery/README.md), [YubiKey Manager CLI](https://github.com/yubico/yubikey-manager/blob/main/_autodocs/api-reference/ykman.cli.md), [GnuPG key selection](https://www.gnupg.org/documentation/manuals/gnupg/Specify-a-User-ID.html), [GitHub GPG key setup](https://docs.github.com/en/authentication/managing-commit-signature-verification/adding-a-gpg-key-to-your-github-account), and [GitHub SSH signing key setup](https://docs.github.com/en/authentication/managing-commit-signature-verification/telling-git-about-your-signing-key).
