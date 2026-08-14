{ pkgs, user }:
{
  enable = true;
  package = pkgs.stable.thunderbird;

  # Use external gpg-agent (services.gpg-agent in services.nix) so
  # Thunderbird/OpenPGP reuses the existing keyring at ~/.gnupg
  # and pinentry-gnome3.
  profiles."personal" = {
    isDefault = true;
    withExternalGnupg = true;

    settings = {
      # General
      "mailnews.start_page.enabled" = false;
      "mail.shell.checkDefaultClient" = false;
      "mailnews.default_sort_order" = 2; # descending
      "mailnews.default_sort_type" = 18; # by date
      "mail.spellcheck.inline" = true;

      # Privacy / telemetry — keep local-only
      "privacy.donottrackheader.enabled" = true;
      "toolkit.telemetry.enabled" = false;
      "datareporting.healthreport.uploadEnabled" = false;
      "app.normandy.enabled" = false;

      # Security — Proton Bridge is PGP-encrypted; enforce OpenPGP
      "mail.openpgp.allow_external_gnupg" = true;
      "mailnews.display.disallow_mime_handlers" = 0;

      # IMAP/SMTP tuning for Bridge (local, no IDLE push delay)
      "mail.server.default.check_all_folders_for_new" = true;
      "mail.imap.use_status_for_biff" = false;

      # Calendar (Lightning) — Thunderbird ships calendar built-in.
      # Proton Calendar has no CalDAV; subscribe via ICS URL
      # (Proton Calendar > Settings > ICS link). This mirrors
      # accounts.calendar remote http URL so Thunderbird shows events.
      # Manual step: Calendar > New Calendar > On the Network > paste
      # ICS URL from ~/.cert/proton/calendar-ics-url, or let
      # vdirsyncer + khal handle offline storage and import ICS here.
      "calendar.timezone.local" = "auto";
      "calendar.view.daystart" = 8;
      "calendar.view.dayend" = 20;
      "calendar.view.visiblehours" = 10;
      "calendar.week.d0sSundaySoWorkWeek" = false;
    };
  };
}
