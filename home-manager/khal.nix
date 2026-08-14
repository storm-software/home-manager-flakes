{ pkgs }:
{
  enable = true;
  package = pkgs.stable.khal;

  locale = {
    # Align with Proton Calendar UI — adapt to your locale
    longDateFormat = "%Y-%m-%d";
    dateFormat = "%Y-%m-%d";
    longDatetimeFormat = "%Y-%m-%d %H:%M";
    datetimeFormat = "%Y-%m-%d %H:%M";
    timeFormat = "%H:%M";
    weekNumbers = "off";
    firstweekday = 0; # Monday (1 = Sunday in some locales, keep 0 for ISO)
  };

  settings = {
    default = {
      default_calendar = "personal";
      highlight_event_days = true;
    };
    view = {
      theme = "dark";
    };
  };
}
