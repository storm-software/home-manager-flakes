{ pkgs, user }:
{
  enable = true;
  package = pkgs.stable.vdirsyncer;

  # accounts.calendar drives pair generation; this sets sync behavior
  # on top of it. Http calendars are read-only — sync interval 15m.
}
