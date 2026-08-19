{ pkgs }:
{
  enable = true;
  package = pkgs.stable.khal;

  locale = {
    # Align with Proton Calendar UI — adapt to your locale
    longdateformat = "%Y-%m-%d";
    dateformat = "%Y-%m-%d";
    longdatetimeformat = "%Y-%m-%d %H:%M";
    datetimeformat = "%Y-%m-%d %H:%M";
    timeformat = "%H:%M";
    weeknumbers = "off";
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
