{ pkgs, user }:
{
  email = {
    # Base path for local maildir (used by mbsync/notmuch if enabled later)
    maildirBasePath = "${user.system.homeDirectory}/Mail";

    accounts."personal" = {
      address = user.email;
      realName = user.displayName;
      userName = user.email;
      primary = true;

      # ProtonMail via local Bridge — not a well-known flavor
      flavor = "plain";

      # Used by mbsync/msmtp only. Thunderbird never reads passwordCommand;
      # it stores the Bridge mailbox password in its own password manager
      # after a successful login (run protonmail-bridge-login first).
      passwordCommand = "sh -c 'if ${pkgs.stable.pass}/bin/pass show proton/bridge/${user.email} >/dev/null 2>&1; then ${pkgs.stable.pass}/bin/pass show proton/bridge/${user.email}; else cat ${user.system.homeDirectory}/.cert/protonmail/bridge-password; fi'";
      # Proton Bridge exposes unauthenticated TLS on loopback only.
      # TLS is intentionally disabled here — traffic never leaves localhost
      # and is encrypted end-to-end by Proton's PGP layer. The bridge
      # itself terminates TLS locally on 127.0.0.1.
      imap = {
        host = "127.0.0.1";
        port = 1143;
        tls.enable = false;
      };

      smtp = {
        host = "127.0.0.1";
        port = 1025;
        tls.enable = false;
        tls.useStartTls = false;
      };

      thunderbird = {
        enable = true;
        # Don't IMAP-login on startup until Bridge has a mailbox. A failed
        # auto-login is what shows the password dialog on every Thunderbird open.
        settings = id: {
          "mail.server.server_${id}.login_at_startup" = false;
        };
      };

      # Sign by default with the user's existing PGP key; encryption
      # opportunistic (Proton recipients will be PGP-encrypted server-side)
      gpg = {
        key = user.signingKey;
        signByDefault = true;
        encryptByDefault = false;
      };

      # Local search/sync — disabled by default, enable when you want
      # offline maildir:
      # mbsync.enable = true;
      # mbsync.create = "maildir";
      # msmtp.enable = true;
      # notmuch.enable = true;
      # lieer.enable = false;
    };
  };

  calendar = {
    # Local storage for synced calendars — vdirsyncer + khal use this
    basePath = "${user.system.homeDirectory}/.calendar";

    accounts."personal" = {
      primary = true;

      # Proton Calendar is end-to-end encrypted and does NOT expose
      # native CalDAV. The supported sync is an ICS subscription URL
      # per calendar (Proton Calendar > Settings > Calendar > Export /
      # ICS link). This is read-only sync; writes remain via Proton
      # web/mobile to preserve E2EE. Bridge does not expose calendars.
      # Create ~/.cert/proton/calendar-ics-url containing the full
      # https://calendar.proton.me/api/calendar/v1/ics/... URL (chmod 600).
      # For multiple calendars, duplicate this block as "personal_work" etc.
      remote = {
        type = "http";
        urlCommand = [
          "cat"
          "${user.system.homeDirectory}/.cert/proton/calendar-ics-url"
        ];
      };

      local = {
        type = "filesystem";
        fileExt = ".ics";
      };

      # vdirsyncer integration — http collection is discovered as single file
      vdirsyncer = {
        enable = true;
        collections = null;
        conflictResolution = "remote wins";
        metadata = [
          "color"
          "displayname"
        ];
      };

      khal = {
        enable = true;
        type = "discover";
      };
    };
  };
}
